const { test } = require('node:test');
const assert = require('node:assert/strict');
const values = import('../media/json-values.mjs');

test('hovering a value decodes newlines, tabs, quotes and Unicode exactly once', async () => {
    const { stringValueAt, stringValueAtPath } = await values;
    const decoded = 'First line\nSecond line\n\t"quoted" 안녕 😀';
    const source = JSON.stringify({ messages: [{ content: decoded }], literal: String.raw`literal \n` });
    const found = stringValueAt(source, source.indexOf('First'));
    assert.deepEqual(found.path, ['messages', 0, 'content']);
    assert.equal(found.value, decoded);
    assert.equal(stringValueAtPath(source, ['literal']).value, String.raw`literal \n`);
});

test('property keys, numbers and whitespace do not expose a string value action', async () => {
    const { stringTokenAt, stringValueAt } = await values;
    const source = '{ "key": "value", "count": 42 }';
    for (const offset of [1, source.indexOf('key'), source.indexOf('42')]) {
        assert.equal(stringTokenAt(source, offset), null);
        assert.equal(stringValueAt(source, offset), null);
    }
    assert(stringTokenAt(source, source.indexOf('value')));
});

test('empty and root strings, array positions and unusual property names have accurate paths', async () => {
    const { stringValueAt, stringValueAtPath, formatJsonPath } = await values;
    assert.deepEqual(stringValueAt('"root\\nvalue"', 2).path, []);
    assert.equal(stringValueAt('"root\\nvalue"', 2).value, 'root\nvalue');
    const source = '{"a.b":["first", ""], "__proto__":{"value":"safe"}}';
    assert.equal(stringValueAtPath(source, ['a.b', 1]).value, '');
    assert.equal(stringValueAtPath(source, ['__proto__', 'value']).value, 'safe');
    assert.equal(formatJsonPath(['a.b', 1]), '$["a.b"][1]');
    assert.equal(formatJsonPath([]), '$');
});

test('tracking a field distinguishes missing values from non-string values', async () => {
    const { stringValueAtPath } = await values;
    const source = '{"content":null,"count":12,"object":{},"array":[],"active":true}';
    for (const key of ['content', 'count', 'object', 'array', 'active']) {
        assert.equal(stringValueAtPath(source, [key]).kind, 'notString');
    }
    assert.equal(stringValueAtPath(source, ['missing']).kind, 'missing');
});

test('duplicate keys preview the string under the pointer without rewriting adjacent numbers', async () => {
    const { stringValueAt } = await values;
    const source = '{"text":"first","large":9007199254740993,"text":"second"}';
    assert.equal(stringValueAt(source, source.indexOf('first')).value, 'first');
    assert.equal(stringValueAt(source, source.indexOf('second')).value, 'second');
    assert(source.includes('9007199254740993'));
});
