import * as vscode from 'vscode';
import { Worker } from 'node:worker_threads';
import { randomBytes } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import * as path from 'node:path';
import type { Metadata } from './indexed-file';

const VIEW_TYPE = 'jsonlViewer.viewer';
type Row = { index: number; bytes: number; text: string; kind: string; error?: string };
type Preview = { index: number; preview: string };

class WorkerClient implements vscode.Disposable {
    private worker: Worker;
    private nextId = 0;
    private pending = new Map<number, { resolve: (value: unknown) => void; reject: (error: Error) => void }>();
    private disposed = false;

    constructor(filePath: string, onMeta: (meta: Metadata) => void) {
        this.worker = new Worker(path.join(__dirname, 'file-worker.cjs'), { workerData: { path: filePath } });
        this.worker.on('message', message => {
            if (this.disposed) return;
            if (message.type === 'meta') { onMeta(message.meta); return; }
            const request = this.pending.get(message.id);
            if (!request) return;
            this.pending.delete(message.id);
            if (message.error) request.reject(new Error(message.error));
            else request.resolve(message.result);
        });
        this.worker.on('error', value => {
            if (this.disposed) return;
            const error = value instanceof Error ? value : new Error(String(value));
            this.rejectPending(error);
            onMeta({ count: 0, size: 0, scanned: 0, indexing: false, error: error.message });
        });
        this.worker.on('exit', code => {
            if (!this.disposed) {
                const error = new Error(`The file worker stopped (code ${code}). Refresh to try again.`);
                this.rejectPending(error);
                onMeta({ count: 0, size: 0, scanned: 0, indexing: false, error: error.message });
            }
        });
    }

    request<T>(type: string, data: object): Promise<T> {
        if (this.disposed) return Promise.reject(new Error('The viewer was closed or refreshed.'));
        const id = ++this.nextId;
        return new Promise((resolve, reject) => {
            this.pending.set(id, { resolve: value => resolve(value as T), reject });
            this.worker.postMessage({ id, type, ...data });
        });
    }

    private rejectPending(error: Error): void {
        for (const request of this.pending.values()) request.reject(error);
        this.pending.clear();
    }

    dispose(): void {
        this.disposed = true;
        this.rejectPending(new Error('The viewer was closed or refreshed.'));
        void this.worker.terminate();
    }
}

class JsonlDocument implements vscode.CustomDocument {
    private emitter = new vscode.EventEmitter<void>();
    readonly onDidChange = this.emitter.event;
    private worker!: WorkerClient;
    private watcher: vscode.FileSystemWatcher;
    private refreshTimer?: NodeJS.Timeout;
    meta: Metadata = { count: 0, size: 0, scanned: 0, indexing: true };
    generation = 0;

    constructor(readonly uri: vscode.Uri) {
        this.reload();
        this.watcher = vscode.workspace.createFileSystemWatcher(new vscode.RelativePattern(path.dirname(uri.fsPath), '*'));
        const changed = (file: vscode.Uri) => {
            if (file.toString() !== uri.toString()) return;
            clearTimeout(this.refreshTimer);
            this.refreshTimer = setTimeout(() => this.reload(), 200);
        };
        this.watcher.onDidChange(changed);
        this.watcher.onDidCreate(changed);
        this.watcher.onDidDelete(changed);
    }

    reload(): void {
        clearTimeout(this.refreshTimer);
        this.worker?.dispose();
        this.generation++;
        this.meta = { count: 0, size: 0, scanned: 0, indexing: true };
        this.worker = new WorkerClient(this.uri.fsPath, meta => { this.meta = meta; this.emitter.fire(); });
        this.emitter.fire();
    }

    rows(start: number, count: number): Promise<Preview[]> { return this.worker.request('rows', { start, count }); }

    row(index: number): Promise<Row> {
        const size = vscode.workspace.getConfiguration('jsonlViewer', this.uri).get<number>('maxRowSizeMB', 8);
        return this.worker.request('row', { index, maxBytes: Math.max(1, Math.min(128, size)) * 1024 * 1024 });
    }

    dispose(): void {
        clearTimeout(this.refreshTimer);
        this.watcher.dispose();
        this.worker.dispose();
        this.emitter.dispose();
    }
}

class JsonlEditorProvider implements vscode.CustomReadonlyEditorProvider<JsonlDocument> {
    constructor(private context: vscode.ExtensionContext) {}

    openCustomDocument(uri: vscode.Uri): JsonlDocument {
        if (uri.scheme !== 'file') throw new Error('JSONL Viewer currently supports files on disk.');
        return new JsonlDocument(uri);
    }

    async resolveCustomEditor(document: JsonlDocument, panel: vscode.WebviewPanel): Promise<void> {
        const media = vscode.Uri.joinPath(this.context.extensionUri, 'media');
        panel.webview.options = { enableScripts: true, localResourceRoots: [media] };
        const nonce = randomBytes(16).toString('hex');
        let html = await readFile(vscode.Uri.joinPath(media, 'viewer.html').fsPath, 'utf8');
        const replacements: Record<string, string> = {
            '{{cspSource}}': panel.webview.cspSource,
            '{{nonce}}': nonce,
            '{{script}}': panel.webview.asWebviewUri(vscode.Uri.joinPath(media, 'build', 'viewer.js')).toString(),
            '{{style}}': panel.webview.asWebviewUri(vscode.Uri.joinPath(media, 'viewer.css')).toString(),
            '{{editorStyle}}': panel.webview.asWebviewUri(vscode.Uri.joinPath(media, 'build', 'viewer.css')).toString(),
            '{{editorWorker}}': panel.webview.asWebviewUri(vscode.Uri.joinPath(media, 'build', 'editor.worker.js')).toString(),
            '{{jsonWorker}}': panel.webview.asWebviewUri(vscode.Uri.joinPath(media, 'build', 'json.worker.js')).toString(),
        };
        for (const [key, value] of Object.entries(replacements)) html = html.replaceAll(key, value);
        panel.webview.html = html;
        let alive = true;
        let selected: Row | undefined;
        let selectedGeneration = -1;
        let selectionRequest = 0;
        const post = (message: object) => { if (alive) void panel.webview.postMessage(message); };
        const sendMeta = () => post({ type: 'meta', generation: document.generation, name: path.basename(document.uri.fsPath),
            ...document.meta, format: document.meta.format ?? (/\.parquet$/i.test(document.uri.fsPath) ? 'parquet' : 'jsonl') });
        const changeListener = document.onDidChange(sendMeta);
        const messageListener = panel.webview.onDidReceiveMessage(async message => {
            const generation = document.generation;
            try {
                if (message.type === 'ready') { sendMeta(); return; }
                if (message.type === 'refresh') { document.reload(); return; }
                if (message.generation !== generation) return;
                if (message.type === 'rows') {
                    const rows = await document.rows(message.start, message.count);
                    if (generation === document.generation) post({ type: 'rows', generation, request: message.request, rows });
                } else if (message.type === 'select') {
                    const request = ++selectionRequest;
                    const row = await document.row(message.index);
                    if (request !== selectionRequest || generation !== document.generation) return;
                    selected = row;
                    selectedGeneration = generation;
                    post({ type: 'row', generation, request: message.request, ...row });
                } else if (message.type === 'copy' && selected && selected.index === message.index && selectedGeneration === generation) {
                    await vscode.env.clipboard.writeText(selected.text);
                    post({ type: 'copied', generation });
                } else if (message.type === 'copyText' && selected && selected.index === message.index && selectedGeneration === generation
                    && typeof message.text === 'string' && message.text.length <= selected.text.length) {
                    await vscode.env.clipboard.writeText(message.text);
                    post({ type: 'textCopied', generation, request: message.request });
                } else if (message.type === 'openText') {
                    await vscode.commands.executeCommand('vscode.openWith', document.uri, 'default');
                    const editor = vscode.window.activeTextEditor;
                    if (editor?.document.uri.toString() === document.uri.toString() && Number.isInteger(message.index)) {
                        const line = Math.max(0, Math.min(editor.document.lineCount - 1, message.index));
                        editor.selection = new vscode.Selection(line, 0, line, 0);
                        editor.revealRange(new vscode.Range(line, 0, line, 0), vscode.TextEditorRevealType.InCenter);
                    }
                }
            } catch (error) {
                if (generation === document.generation) post({
                    type: 'error', generation, request: message.request, operation: message.type,
                    error: error instanceof Error ? error.message : String(error),
                });
            }
        });
        panel.onDidDispose(() => { alive = false; changeListener.dispose(); messageListener.dispose(); });
    }
}

export function activate(context: vscode.ExtensionContext): void {
    context.subscriptions.push(
        vscode.window.registerCustomEditorProvider(VIEW_TYPE, new JsonlEditorProvider(context), {
            webviewOptions: { retainContextWhenHidden: false }, supportsMultipleEditorsPerDocument: true,
        }),
        vscode.commands.registerCommand('jsonlViewer.open', async (uri?: vscode.Uri) => {
            uri ??= vscode.window.activeTextEditor?.document.uri;
            if (!uri) uri = (await vscode.window.showOpenDialog({ filters: { 'JSON Lines and Parquet': ['jsonl', 'ndjson', 'parquet'], 'All files': ['*'] } }))?.[0];
            if (uri) await vscode.commands.executeCommand('vscode.openWith', uri, VIEW_TYPE);
        }),
    );
}
