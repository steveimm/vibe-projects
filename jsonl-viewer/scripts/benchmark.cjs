const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { Worker } = require('node:worker_threads');
const { performance } = require('node:perf_hooks');
const assert = require('node:assert/strict');

async function benchmark() {
    const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'jsonl-viewer-benchmark-'));
    let worker;
    try {
        const parquet = process.argv.includes('--parquet');
        const filePath = path.join(directory, parquet ? 'million.parquet' : 'million.jsonl');
        const record = '{"id":123,"name":"Sample record","nested":{"ok":true,"values":[1,2,3]},"text":"Unicode 안녕"}\n';
        if (parquet) {
            const { ByteWriter, parquetWriteRows } = await import('hyparquet-writer');
            const writer = new ByteWriter();
            function* records() {
                for (let id = 0; id < 1000000; id++) yield { id, payload: { name: 'Sample record', text: 'First\nSecond', ok: true } };
            }
            await parquetWriteRows({ writer, rows: records(), rowGroupSize: 10000, pageSize: 65536,
                columns: [{ name: 'id', type: 'INT32' }, { name: 'payload', type: 'JSON' }] });
            await fs.writeFile(filePath, writer.getBytes());
        } else {
            const handle = await fs.open(filePath, 'w');
            try {
                const chunk = record.repeat(10000);
                for (let i = 0; i < 100; i++) await handle.write(chunk);
            } finally { await handle.close(); }
        }

        const started = performance.now();
        worker = new Worker(path.join(__dirname, '../dist/file-worker.cjs'), { workerData: { path: filePath } });
        const pending = new Map();
        let nextId = 0;
        let firstRowsMs = 0;
        const request = (type, data) => new Promise((resolve, reject) => {
            const id = ++nextId;
            pending.set(id, { resolve, reject });
            worker.postMessage({ id, type, ...data });
        });
        const meta = await new Promise((resolve, reject) => {
            worker.on('error', reject);
            worker.on('message', message => {
                if (message.type === 'meta') {
                    if (message.meta.error) reject(new Error(message.meta.error));
                    if (message.meta.count && !firstRowsMs) firstRowsMs = performance.now() - started;
                    if (!message.meta.indexing) resolve(message.meta);
                } else {
                    const callback = pending.get(message.id);
                    pending.delete(message.id);
                    if (message.error) callback.reject(new Error(message.error));
                    else callback.resolve(message.result);
                }
            });
        });
        const indexMs = performance.now() - started;
        const times = [];
        for (let i = 0; i < 20; i++) {
            const start = performance.now();
            const index = i % 2 ? meta.count - 1 : 0;
            const row = await request('row', { index, maxBytes: 8388608 });
            assert.equal(row.kind, 'json');
            if (parquet) assert.equal(JSON.parse(row.text).id, index);
            times.push(performance.now() - start);
        }
        console.log(JSON.stringify({
            format: parquet ? 'parquet' : 'jsonl', rows: meta.count, fileBytes: meta.size,
            firstRowsMs: Math.round(firstRowsMs), indexMs: Math.round(indexMs),
            selectMeanMs: +(times.reduce((a, b) => a + b, 0) / times.length).toFixed(2),
            selectMaxMs: +Math.max(...times).toFixed(2),
            note: 'Generated file with small records and a warm filesystem cache. Parquet indexing reads metadata only. Selection measures worker replies, excluding UI rendering.',
        }, null, 2));
    } finally {
        await worker?.terminate();
        await fs.rm(directory, { recursive: true, force: true });
    }
}

benchmark().catch(error => { console.error(error); process.exitCode = 1; });
