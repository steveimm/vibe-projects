import { parentPort, workerData } from 'node:worker_threads';
import { IndexedFile } from './indexed-file';

const file = new IndexedFile();
const port = parentPort!;
let failure: string | undefined;

port.on('message', async (message: { id: number; type: string; start: number; count: number; index: number; maxBytes: number }) => {
    try {
        if (failure) throw new Error(failure);
        const result = message.type === 'rows'
            ? await file.rows(message.start, message.count)
            : await file.row(message.index, message.maxBytes);
        port.postMessage({ id: message.id, result });
    } catch (error) {
        port.postMessage({ id: message.id, error: error instanceof Error ? error.message : String(error) });
    }
});

void file.index(workerData.path, meta => port.postMessage({ type: 'meta', meta })).catch(error => {
    failure = error instanceof Error ? error.message : String(error);
    port.postMessage({ type: 'meta', meta: { ...file.metadata, indexing: false, error: failure } });
});
