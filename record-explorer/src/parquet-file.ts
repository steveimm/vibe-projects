import { open, type FileHandle } from 'node:fs/promises';
import type { Metadata } from './indexed-file';
import { formatRow } from './format';
import { parseParquetJson, serializeParquetValue } from './parquet-json';

async function loadParquet() {
    const [reader, { compressors }] = await Promise.all([import('hyparquet'), import('hyparquet-compressors')]);
    return { reader, compressors };
}

type Library = Awaited<ReturnType<typeof loadParquet>>;
type FileMetadata = Awaited<ReturnType<Library['reader']['parquetMetadataAsync']>>;
type AsyncFile = Parameters<Library['reader']['parquetMetadataAsync']>[0];
type RecordText = { text: string; bytes: number };
type Group = { start: number; end: number; pageSize: number };
const BYTE_CACHE_LIMIT = 32 * 1024 * 1024;
const ROW_CACHE_LIMIT = 16 * 1024 * 1024;

export class ParquetFile {
    private handle?: FileHandle;
    private library?: Library;
    private file?: AsyncFile;
    private schema?: FileMetadata;
    private groups: Group[] = [];
    private size = 0;
    private modified = 0;
    private ready = false;
    private rowCount = 0;
    private byteCache = new Map<string, { start: number; end: number; data: ArrayBuffer }>();
    private byteCost = 0;
    private rowCache = new Map<number, { rows: RecordText[]; cost: number }>();
    private rowCost = 0;
    private pendingPages = new Map<number, Promise<RecordText[]>>();
    private pendingBytes = new Map<string, Promise<ArrayBuffer>>();

    get metadata(): Metadata {
        return { count: this.rowCount, size: this.size, scanned: this.ready ? this.size : 0, indexing: !this.ready, format: 'parquet' };
    }

    async index(path: string, progress: (metadata: Metadata) => void): Promise<void> {
        this.handle = await open(path, 'r');
        const stat = await this.handle.stat();
        if (!stat.isFile()) throw new Error('Open a regular Parquet file.');
        this.size = stat.size;
        this.modified = stat.mtimeMs;
        progress(this.metadata);
        this.library = await loadParquet();
        this.file = { byteLength: this.size, slice: (start, end) => this.slice(start, end ?? this.size) };
        this.schema = await this.library.reader.parquetMetadataAsync(this.file, { parsers: { jsonFromBytes: parseParquetJson }, geoparquet: false });
        this.rowCount = Number(this.schema.num_rows);
        if (!Number.isSafeInteger(this.rowCount) || this.rowCount < 0) throw new Error('Parquet row count exceeds the supported integer range.');
        let start = 0;
        for (const group of this.schema.row_groups) {
            const rows = Number(group.num_rows);
            if (!Number.isSafeInteger(rows) || rows < 0) throw new Error('Invalid Parquet row group size.');
            if (rows) {
                const averageSize = Number(group.total_byte_size) / rows;
                const pageSize = Math.max(1, Math.min(32, Math.floor(1024 * 1024 / Math.max(1, averageSize))));
                this.groups.push({ start, end: start + rows, pageSize });
            }
            start += rows;
        }
        if (start !== this.rowCount) throw new Error('Parquet row groups do not match the file row count.');
        await this.assertUnchanged();
        this.ready = true;
        progress(this.metadata);
    }

    private async assertUnchanged(): Promise<void> {
        const stat = await this.handle!.stat();
        if (stat.size !== this.size || stat.mtimeMs !== this.modified) throw new Error('The file changed. Refresh to read it again.');
    }

    private slice(start: number, end: number): Promise<ArrayBuffer> {
        if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start < 0 || end < start || end > this.size) {
            return Promise.reject(new Error('Invalid byte range in Parquet file.'));
        }
        for (const [key, cached] of this.byteCache) {
            if (start >= cached.start && end <= cached.end) {
                this.byteCache.delete(key); this.byteCache.set(key, cached);
                return Promise.resolve(cached.data.slice(start - cached.start, end - cached.start));
            }
        }
        const key = `${start}:${end}`;
        const pending = this.pendingBytes.get(key);
        if (pending) return pending;
        const result = this.readBytes(start, end).finally(() => this.pendingBytes.delete(key));
        this.pendingBytes.set(key, result);
        return result;
    }

    private async readBytes(start: number, end: number): Promise<ArrayBuffer> {
        const bytes = new Uint8Array(end - start);
        let offset = 0;
        while (offset < bytes.length) {
            const { bytesRead } = await this.handle!.read(bytes, offset, bytes.length - offset, start + offset);
            if (!bytesRead) throw new Error('The Parquet file ended unexpectedly. Refresh to read it again.');
            offset += bytesRead;
        }
        if (bytes.byteLength <= BYTE_CACHE_LIMIT) {
            while ((this.byteCost + bytes.byteLength > BYTE_CACHE_LIMIT || this.byteCache.size >= 128) && this.byteCache.size) {
                const key = this.byteCache.keys().next().value!;
                this.byteCost -= this.byteCache.get(key)!.data.byteLength;
                this.byteCache.delete(key);
            }
            this.byteCache.set(`${start}:${end}`, { start, end, data: bytes.buffer });
            this.byteCost += bytes.byteLength;
        }
        return bytes.buffer;
    }

    private page(index: number): { start: number; end: number } {
        if (!this.ready || !Number.isInteger(index) || index < 0 || index >= this.rowCount) throw new Error('Row is outside the indexed file.');
        let low = 0;
        let high = this.groups.length - 1;
        while (low < high) {
            const middle = Math.floor((low + high) / 2);
            if (index < this.groups[middle].end) high = middle;
            else low = middle + 1;
        }
        const group = this.groups[low];
        const start = group.start + Math.floor((index - group.start) / group.pageSize) * group.pageSize;
        return { start, end: Math.min(start + group.pageSize, group.end) };
    }

    private async readPage(start: number, end: number): Promise<RecordText[]> {
        const cached = this.rowCache.get(start);
        if (cached) { this.rowCache.delete(start); this.rowCache.set(start, cached); return cached.rows; }
        const pending = this.pendingPages.get(start);
        if (pending) return pending;
        const request = this.decodePage(start, end).finally(() => this.pendingPages.delete(start));
        this.pendingPages.set(start, request);
        return request;
    }

    private async decodePage(start: number, end: number): Promise<RecordText[]> {
        await this.assertUnchanged();
        const records = await this.library!.reader.parquetReadObjects({
            file: this.file!, metadata: this.schema, compressors: this.library!.compressors,
            rowStart: start, rowEnd: end, useOffsetIndex: true, utf8: false, geoparquet: false,
            parsers: { jsonFromBytes: parseParquetJson },
        });
        await this.assertUnchanged();
        if (records.length !== end - start) throw new Error('Parquet decoding returned an unexpected number of records.');
        const rows = records.map(value => {
            const text = serializeParquetValue(value);
            return { text, bytes: Buffer.byteLength(text) };
        });
        const cost = rows.reduce((total, row) => total + row.text.length * 2, 0);
        if (cost <= ROW_CACHE_LIMIT) {
            while ((this.rowCost + cost > ROW_CACHE_LIMIT || this.rowCache.size >= 16) && this.rowCache.size) {
                const key = this.rowCache.keys().next().value!;
                this.rowCost -= this.rowCache.get(key)!.cost;
                this.rowCache.delete(key);
            }
            this.rowCache.set(start, { rows, cost });
            this.rowCost += cost;
        }
        return rows;
    }

    async rows(start: number, count: number): Promise<{ index: number; preview: string }[]> {
        if (!Number.isInteger(start) || start < 0 || !Number.isInteger(count) || count < 0) throw new Error('Invalid row range.');
        const end = Math.min(this.rowCount, start + Math.min(count, 160));
        const result = [];
        for (let index = start; index < end;) {
            const page = this.page(index);
            const rows = await this.readPage(page.start, page.end);
            for (; index < Math.min(end, page.end); index++) {
                const text = rows[index - page.start].text;
                const preview = text.slice(0, 320).replace(/[\uD800-\uDBFF]$/, '').replace(/\s+/g, ' ').trim();
                result.push({ index, preview: preview + (text.length > 320 ? '…' : '') });
            }
        }
        return result;
    }

    async row(index: number, maxBytes: number) {
        const page = this.page(index);
        const rows = await this.readPage(page.start, page.end);
        const { text, bytes } = rows[index - page.start];
        if (bytes > maxBytes) return {
            index, bytes, text: '', kind: 'tooLarge',
            error: `This record exceeds the ${Math.round(maxBytes / 1024 / 1024)} MiB row limit. Increase Record Explorer: Max Row Size MB in Settings.`,
        };
        return { index, bytes, ...formatRow(text) };
    }

    async close(): Promise<void> { await this.handle?.close(); }
}
