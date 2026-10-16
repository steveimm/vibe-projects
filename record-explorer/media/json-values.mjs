import { createScanner, getLocation, SyntaxKind, visit } from 'jsonc-parser';

export function stringTokenAt(text, offset) {
    const scanner = createScanner(text, true);
    for (let token = scanner.scan(); token !== SyntaxKind.EOF; token = scanner.scan()) {
        const start = scanner.getTokenOffset();
        const end = start + scanner.getTokenLength();
        if (start > offset) return null;
        if (offset >= start && offset < end) {
            if (token !== SyntaxKind.StringLiteral || scanner.scan() === SyntaxKind.ColonToken) return null;
            return { start, end };
        }
    }
    return null;
}

export function stringValueAt(text, offset) {
    const location = getLocation(text, offset + 1);
    const node = location.previousNode;
    if (location.isAtPropertyKey || node?.type !== 'string' || offset < node.offset || offset >= node.offset + node.length) return null;
    return { path: location.path, value: node.value, offset: node.offset, end: node.offset + node.length };
}

export function stringValueAtPath(text, path) {
    const found = {};
    let result = { kind: 'missing' };
    const match = (candidate, value) => {
        if (candidate.length !== path.length || candidate.some((part, index) => part !== path[index])) return;
        result = typeof value === 'string' ? { kind: 'string', value } : { kind: 'notString' };
        throw found;
    };
    try {
        visit(text, {
            onLiteralValue: (value, _offset, _length, _line, _column, getPath) => match(getPath(), value),
            onObjectBegin: (_offset, _length, _line, _column, getPath) => match(getPath(), null),
            onArrayBegin: (_offset, _length, _line, _column, getPath) => match(getPath(), null),
        });
    } catch (error) { if (error !== found) throw error; }
    return result;
}

export function formatJsonPath(path) {
    return path.reduce((label, part) => typeof part === 'number' ? `${label}[${part}]`
        : /^[A-Za-z_$][\w$]*$/.test(part) ? `${label}.${part}` : `${label}[${JSON.stringify(part)}]`, '$');
}
