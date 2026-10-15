export class ParquetJson {
    constructor(readonly text: string) {}
}

export function serializeParquetValue(value: unknown): string {
    if (value === null || value === undefined) return 'null';
    if (value instanceof ParquetJson) return value.text;
    if (typeof value === 'bigint') return value.toString();
    if (typeof value === 'number') return Number.isFinite(value) ? String(value) : JSON.stringify(String(value));
    if (typeof value === 'string' || typeof value === 'boolean') return JSON.stringify(value);
    if (value instanceof Date) return JSON.stringify(value.toISOString());
    if (value instanceof Uint8Array) return JSON.stringify({ encoding: 'base64', data: Buffer.from(value).toString('base64') });
    if (Array.isArray(value)) return '[' + value.map(serializeParquetValue).join(',') + ']';
    const entries = value instanceof Map ? Array.from(value.entries()) : Object.entries(value as object);
    return '{' + entries.map(([key, item]) => JSON.stringify(String(key)) + ':' + serializeParquetValue(item)).join(',') + '}';
}

export function parseParquetJson(bytes: Uint8Array): ParquetJson | string {
    const text = new TextDecoder().decode(bytes);
    try { JSON.parse(text); return new ParquetJson(text); }
    catch { return text; }
}
