import { open, type FileHandle } from 'node:fs/promises';
import { StringDecoder } from 'node:string_decoder';
import { formatRow } from './format';

export type Metadata = { count: number; size: number; scanned: number; indexing: boolean; format?: 'jsonl' | 'parquet'; error?: string };
const PAGE_SIZE = 65536;

export class IndexedFile {
    private pages: Float64Array[] = [];
    private offsetCount = 0;
    private handle?: FileHandle;
    private size = 0;
    private scanned = 0;
    private finished = false;
    private modified = 0;

    get metadata(): Metadata {
        return { count: this.count, size: this.size, scanned: this.scanned, indexing: !this.finished };
    }

    get count(): number { return Math.max(0, this.offsetCount - (this.finished ? 0 : 1)); }

    private push(offset: number): void {
        const page = Math.floor(this.offsetCount / PAGE_SIZE);
        if (!this.pages[page]) this.pages[page] = new Float64Array(PAGE_SIZE);
        this.pages[page][this.offsetCount++ % PAGE_SIZE] = offset;
    }

    private offset(index: number): number { return this.pages[Math.floor(index / PAGE_SIZE)][index % PAGE_SIZE]; }

    async index(path: string, progress: (meta: Metadata) => void): Promise<void> {
        this.handle = await open(path, 'r');
        const stat = await this.handle.stat();
        if (!stat.isFile()) throw new Error('Open a regular JSONL file.');
        this.size = stat.size;
        this.modified = stat.mtimeMs;
        this.push(0);
        progress(this.metadata);
        const buffer = Buffer.allocUnsafe(1024 * 1024);
        let lastProgress = 0;

        while (this.scanned < this.size) {
            const { bytesRead } = await this.handle.read(buffer, 0, Math.min(buffer.length, this.size - this.scanned), this.scanned);
            if (!bytesRead) throw new Error('The file changed while indexing. Refresh to read it again.');
            let cursor = 0;
            while (cursor < bytesRead) {
                const newline = buffer.indexOf(10, cursor);
                if (newline < 0 || newline >= bytesRead) break;
                this.push(this.scanned + newline + 1);
                cursor = newline + 1;
            }
            this.scanned += bytesRead;
            if (Date.now() - lastProgress > 100) { progress(this.metadata); lastProgress = Date.now(); }
        }

        const finalStat = await this.handle.stat();
        if (finalStat.size !== this.size || finalStat.mtimeMs !== this.modified) {
            throw new Error('The file changed while indexing. Refresh to read it again.');
        }
        if (this.offset(this.offsetCount - 1) === this.size) this.offsetCount--;
        this.finished = true;
        progress(this.metadata);
    }

    private bounds(index: number): { start: number; length: number } {
        if (!Number.isInteger(index) || index < 0 || index >= this.count) throw new Error('Row is outside the indexed file.');
        const start = this.offset(index);
        const end = index + 1 < this.offsetCount ? this.offset(index + 1) : this.size;
        return { start, length: end - start };
    }

    private async read(index: number, limit: number): Promise<{ text: string; bytes: number; truncated: boolean }> {
        const { start, length } = this.bounds(index);
        const buffer = Buffer.allocUnsafe(Math.min(length, limit));
        let read = 0;
        while (read < buffer.length) {
            const result = await this.handle!.read(buffer, read, buffer.length - read, start + read);
            if (!result.bytesRead) throw new Error('The file changed. Refresh to read it again.');
            read += result.bytesRead;
        }
        const truncated = length > limit;
        const decoder = new StringDecoder('utf8');
        let text = truncated ? decoder.write(buffer) : buffer.toString('utf8');
        if (index === 0 && text.charCodeAt(0) === 0xfeff) text = text.slice(1);
        if (!truncated) text = text.replace(/\r?\n$/, '');
        return { text, bytes: length, truncated };
    }

    async rows(start: number, count: number): Promise<{ index: number; preview: string }[]> {
        if (!Number.isInteger(start) || start < 0 || !Number.isInteger(count) || count < 0) throw new Error('Invalid row range.');
        const end = Math.min(this.count, start + Math.min(count, 160));
        return Promise.all(Array.from({ length: Math.max(0, end - start) }, async (_, i) => {
            const index = start + i;
            const row = await this.read(index, 320);
            const preview = row.text.replace(/\s+/g, ' ').trim();
            return { index, preview: preview ? preview + (row.truncated ? '…' : '') : '(empty line)' };
        }));
    }

    async row(index: number, maxBytes: number) {
        const { length } = this.bounds(index);
        if (length > maxBytes) return {
            index, bytes: length, text: '', kind: 'tooLarge',
            error: `This row exceeds the ${Math.round(maxBytes / 1024 / 1024)} MiB row limit. Increase Record Explorer: Max Row Size MB in Settings.`,
        };
        const row = await this.read(index, maxBytes);
        return { index, bytes: row.bytes, ...formatRow(row.text) };
    }

    async close(): Promise<void> { await this.handle?.close(); }
}
