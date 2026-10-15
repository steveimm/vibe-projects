const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const { writeFileSync } = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Worker } = require('node:worker_threads');
const { IndexedFile } = require('../dist/indexed-file');
const { formatRow } = require('../dist/format');

async function fixture(t, text) {
    const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'jsonl-viewer-test-'));
    const filePath = path.join(directory, 'records.jsonl');
    await fs.writeFile(filePath, text);
    const file = new IndexedFile();
    t.after(async () => { await file.close(); await fs.rm(directory, { recursive: true, force: true }); });
    return { file, filePath };
}

test('physical lines remain selectable across BOM, CRLF, blanks, invalid JSON and an unterminated final line', async t => {
    const { file, filePath } = await fixture(t, '\ufeff{"name":"안녕"}\r\n\r\n{broken}\r\nnull\r\n[1,{},[],false]');
    await file.index(filePath, () => {});
    assert.equal(file.count, 5);
    assert.deepEqual(JSON.parse((await file.row(0, 1024)).text), { name: '안녕' });
    assert.equal((await file.row(1, 1024)).kind, 'empty');
    assert.equal((await file.row(2, 1024)).kind, 'invalid');
    assert.equal((await file.row(3, 1024)).text, 'null');
    assert.deepEqual(JSON.parse((await file.row(4, 1024)).text), [1, {}, [], false]);
    assert.deepEqual((await file.rows(0, 20)).map(row => row.index), [0, 1, 2, 3, 4]);
    await assert.rejects(file.row(5, 1024), /outside/);
});

test('empty files and trailing newlines have the expected row counts', async t => {
    for (const [text, count] of [['', 0], ['{}', 1], ['{}\n', 1], ['{}\n\n', 2], ['\n', 1], ['\n\n', 2]]) {
        const { file, filePath } = await fixture(t, text);
        await file.index(filePath, () => {});
        assert.equal(file.count, count, JSON.stringify(text));
    }
});

test('formatting preserves numeric spelling, duplicate keys, escaped strings and nested empty containers', () => {
    const raw = '{"big":9007199254740993,"decimal":1.2300,"exponent":1e+30,"same":1,"same":2,"escaped":"a\\\"b\\nc","list":[{},[],true,null]}';
    const row = formatRow(raw);
    assert.equal(row.kind, 'json');
    assert(row.text.includes('9007199254740993'));
    assert(row.text.includes('1.2300'));
    assert(row.text.includes('1e+30'));
    assert.equal((row.text.match(/"same":/g) || []).length, 2);
    assert.deepEqual(JSON.parse(row.text), JSON.parse(raw));
    assert(row.text.includes('\n'));
    const fallback = formatRow(raw, 10);
    assert.equal(fallback.text, raw);
    assert(fallback.error.includes('too large'));
});

test('chunk boundaries, large-row limits and preview UTF-8 boundaries do not lose subsequent rows', async t => {
    const text = '{"data":"' + 'a'.repeat(1024 * 1024 - 11) + '"}\n{"last":true}\n' + 'a'.repeat(319) + '안녕';
    const { file, filePath } = await fixture(t, text);
    await file.index(filePath, () => {});
    assert.equal(file.count, 3);
    assert.equal((await file.row(0, 100)).kind, 'tooLarge');
    assert.deepEqual(JSON.parse((await file.row(1, 1024)).text), { last: true });
    assert(!(await file.rows(2, 1))[0].preview.includes('\ufffd'));
});

test('file truncation during indexing is detected', async t => {
    const { file, filePath } = await fixture(t, '{}\n'.repeat(100));
    await assert.rejects(file.index(filePath, meta => {
        if (meta.scanned === 0) writeFileSync(filePath, '');
    }), /changed/);
});

test('worker indexes across offset pages and serves arbitrary rows and preview ranges', async t => {
    const { filePath } = await fixture(t, '{"ok":true}\n'.repeat(200000));
    const worker = new Worker(path.join(__dirname, '../dist/index-worker.js'), { workerData: { path: filePath } });
    t.after(() => worker.terminate());
    const pending = new Map();
    let nextId = 0;
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
                if (!message.meta.indexing) resolve(message.meta);
            } else {
                const callback = pending.get(message.id);
                pending.delete(message.id);
                if (message.error) callback.reject(new Error(message.error));
                else callback.resolve(message.result);
            }
        });
    });
    assert.equal(meta.count, 200000);
    for (const index of [0, 65535, 65536, 131072, 199999]) {
        const row = await request('row', { index, maxBytes: 1024 });
        assert.equal(row.index, index);
        assert.deepEqual(JSON.parse(row.text), { ok: true });
    }
    assert.equal((await request('rows', { start: 199980, count: 100 })).length, 20);
});
