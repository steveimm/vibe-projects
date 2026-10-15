export type FormattedRow = { text: string; kind: 'json' | 'invalid' | 'empty'; error?: string };

export function formatRow(raw: string, maxOutputBytes = 32 * 1024 * 1024): FormattedRow {
    if (!raw.trim()) return { text: raw, kind: 'empty', error: 'This line is empty.' };
    try {
        JSON.parse(raw);
    } catch (error) {
        return { text: raw, kind: 'invalid', error: error instanceof Error ? error.message : String(error) };
    }

    const tokens = raw.match(/"(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null|[{}\[\],:]/g) ?? [];
    const output: string[] = [];
    let depth = 0;
    let size = 0;
    const append = (value: string) => {
        size += value.length;
        if (size > maxOutputBytes) throw new Error('Formatted row is too large. Showing the original JSON.');
        output.push(value);
    };
    const newline = () => append('\n' + '  '.repeat(depth));

    try {
        for (let i = 0; i < tokens.length; i++) {
            const token = tokens[i];
            if (token === '{' || token === '[') {
                append(token);
                if (tokens[i + 1] === (token === '{' ? '}' : ']')) append(tokens[++i]);
                else { depth++; newline(); }
            } else if (token === '}' || token === ']') {
                depth--;
                newline();
                append(token);
            } else if (token === ',') {
                append(token);
                newline();
            } else if (token === ':') append(': ');
            else append(token);
        }
        return { text: output.join(''), kind: 'json' };
    } catch (error) {
        return { text: raw, kind: 'json', error: error instanceof Error ? error.message : String(error) };
    }
}
