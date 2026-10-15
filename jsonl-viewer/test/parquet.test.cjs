const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { Worker } = require('node:worker_threads');
const { gzipSync, brotliCompressSync, zstdCompressSync } = require('node:zlib');
const { ParquetFile } = require('../dist/parquet-file');
const { parseParquetJson, serializeParquetValue } = require('../dist/parquet-json');

async function fixture(t, options) {
    const { parquetWriteBuffer } = await import('hyparquet-writer');
    const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'jsonl-viewer-parquet-'));
    const filePath = path.join(directory, 'records.parquet');
    await fs.writeFile(filePath, new Uint8Array(parquetWriteBuffer(options)));
    const file = new ParquetFile();
    t.after(async () => { await file.close(); await fs.rm(directory, { recursive: true, force: true }); });
    return { file, filePath };
}

test('Parquet JSON columns become nested dictionaries and retain string formatting', async t => {
    const input = { messages: [{ role: 'user', content: 'First line\n\t"quoted" 안녕 😀' }] };
    const { file, filePath } = await fixture(t, { columnData: [
        { name: 'id', type: 'STRING', data: ['a', 'b'] },
        { name: 'input', type: 'JSON', data: [input, null] },
        { name: 'output', type: 'JSON', data: [{ reasoning_content: 'One\nTwo', completion: '{"answer":true}' }, {}] },
    ] });
    const updates = [];
    await file.index(filePath, meta => updates.push(meta));
    assert.equal(file.metadata.count, 2);
    assert.equal(file.metadata.format, 'parquet');
    assert.equal(updates.at(-1).indexing, false);
    const row = await file.row(0, 8388608);
    assert.equal(row.kind, 'json');
    const decoded = JSON.parse(row.text);
    assert.deepEqual(decoded.input, input);
    assert.equal(decoded.output.reasoning_content, 'One\nTwo');
    assert.equal(decoded.output.completion, '{"answer":true}');
    assert.equal(JSON.parse((await file.row(1, 8388608)).text).input, null);
    assert.deepEqual((await file.rows(0, 10)).map(row => row.index), [0, 1]);
});

test('native Parquet structs and nullable fields render as JSON objects', async t => {
    const { file, filePath } = await fixture(t, {
        schema: [
            { name: 'root', num_children: 2 },
            { name: 'id', type: 'INT32', repetition_type: 'OPTIONAL' },
            { name: 'detail', num_children: 2, repetition_type: 'OPTIONAL' },
            { name: 'message', type: 'BYTE_ARRAY', converted_type: 'UTF8', repetition_type: 'OPTIONAL' },
            { name: 'active', type: 'BOOLEAN', repetition_type: 'OPTIONAL' },
        ],
        columnData: [{ name: 'id', data: [1, 2] }, { name: 'detail', data: [{ message: 'First\nSecond', active: true }, null] }],
    });
    await file.index(filePath, () => {});
    assert.deepEqual(JSON.parse((await file.row(0, 8388608)).text), { id: 1, detail: { message: 'First\nSecond', active: true } });
    assert.equal(JSON.parse((await file.row(1, 8388608)).text).detail, null);
});

test('Parquet INT64 values and JSON-typed integer literals retain their exact digits', async t => {
    const big = 9007199254740993n;
    const { file, filePath } = await fixture(t, { columnData: [{ name: 'large', type: 'INT64', data: [big, -big] }] });
    await file.index(filePath, () => {});
    assert((await file.row(0, 8388608)).text.includes('9007199254740993'));
    assert((await file.row(1, 8388608)).text.includes('-9007199254740993'));
    const raw = parseParquetJson(new TextEncoder().encode('{"value":9007199254740993,"decimal":1.2300}'));
    assert.equal(serializeParquetValue({ payload: raw }), '{"payload":{"value":9007199254740993,"decimal":1.2300}}');
});

test('Snappy, GZIP, Brotli and available ZSTD compressed Parquet files can be read', async t => {
    const codecs = ['SNAPPY', 'GZIP', 'BROTLI'];
    if (zstdCompressSync) codecs.push('ZSTD');
    for (const codec of codecs) {
        const compressors = codec === 'GZIP' ? { GZIP: gzipSync } : codec === 'BROTLI' ? { BROTLI: brotliCompressSync }
            : codec === 'ZSTD' ? { ZSTD: zstdCompressSync } : undefined;
        const { file, filePath } = await fixture(t, { codec, compressors,
            columnData: [{ name: 'message', type: 'STRING', data: ['First\nSecond', 'Next record'] }] });
        await file.index(filePath, () => {});
        assert.equal(JSON.parse((await file.row(0, 8388608)).text).message, 'First\nSecond', codec);
    }
});

test('empty Parquet, row limits, invalid ranges and corrupt input have clear results', async t => {
    const empty = await fixture(t, { columnData: [{ name: 'message', type: 'STRING', data: [] }] });
    await empty.file.index(empty.filePath, () => {});
    assert.equal(empty.file.metadata.count, 0);
    assert.deepEqual(await empty.file.rows(0, 10), []);
    const populated = await fixture(t, { columnData: [{ name: 'message', type: 'STRING', data: ['x'.repeat(1000)] }] });
    await populated.file.index(populated.filePath, () => {});
    assert.equal((await populated.file.row(0, 100)).kind, 'tooLarge');
    await assert.rejects(populated.file.row(1, 8388608), /outside/);
    await assert.rejects(populated.file.rows(-1, 10), /Invalid/);
    const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'jsonl-viewer-corrupt-'));
    const filePath = path.join(directory, 'broken.parquet');
    await fs.writeFile(filePath, 'not a parquet file');
    const file = new ParquetFile();
    try { await assert.rejects(file.index(filePath, () => {})); }
    finally { await file.close(); await fs.rm(directory, { recursive: true, force: true }); }
});

test('the packaged worker selects arbitrary Parquet records across row groups', async t => {
    const { filePath } = await fixture(t, { rowGroupSize: 37, pageSize: 256, columnData: [
        { name: 'index', type: 'INT32', data: Array.from({ length: 200 }, (_, index) => index) },
        { name: 'payload', type: 'JSON', data: Array.from({ length: 200 }, (_, index) => ({ message: `Record ${index}\nNext line` })) },
    ] });
    const worker = new Worker(path.join(__dirname, '../dist/file-worker.cjs'), { workerData: { path: filePath } });
    t.after(() => worker.terminate());
    let nextId = 0;
    const pending = new Map();
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
                else if (!message.meta.indexing) resolve(message.meta);
            } else {
                const callback = pending.get(message.id);
                pending.delete(message.id);
                if (message.error) callback.reject(new Error(message.error));
                else callback.resolve(message.result);
            }
        });
    });
    assert.equal(meta.count, 200);
    for (const index of [199, 0, 37, 38, 74, 150]) {
        const row = await request('row', { index, maxBytes: 8388608 });
        assert.equal(JSON.parse(row.text).index, index);
        assert.equal(JSON.parse(row.text).payload.message, `Record ${index}\nNext line`);
    }
    assert.equal((await request('rows', { start: 32, count: 20 })).length, 20);
});

