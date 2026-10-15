import { createJsonEditor } from './json-editor.js';
import { createTextPreview } from './text-preview.js';

(() => {
    'use strict';
    const vscode = acquireVsCodeApi();
    const get = id => document.getElementById(id);
    const list = get('row-list');
    const rowCanvas = get('row-canvas');
    const rowSpacer = get('row-spacer');
    const codeView = get('code-view');
    const state = vscode.getState() || {};
    const ROW_HEIGHT = 48;
    const MAX_SCROLL_HEIGHT = 8000000;
    let generation = -1;
    let count = 0;
    let selected = Number.isInteger(state.selected) ? Math.max(0, state.selected) : 0;
    let loaded = -1;
    let indexing = true;
    let cache = new Map();
    let hasText = false;
    let rowKind = 'json';
    let rowRequest = 0;
    let rangeRequest = 0;
    let pendingRange = '';
    let frame = 0;
    let selectionTimer;
    let pendingRestore = true;
    let wordWrap = state.wordWrap === true;
    const jsonEditor = createJsonEditor(codeView, { wordWrap, onPreviewValue: value => textPreview.open(value) });

    const send = message => vscode.postMessage({ generation, ...message });
    const persist = () => vscode.setState({ ...state, selected, sidebarWidth: state.sidebarWidth, wordWrap });
    const number = value => value.toLocaleString();
    const bytes = value => value < 1024 ? `${value} B` : value < 1048576 ? `${(value / 1024).toFixed(1)} KiB` : `${(value / 1048576).toFixed(1)} MiB`;
    const notice = text => { get('notice').textContent = text || ''; get('notice').hidden = !text; };
    const textPreview = createTextPreview({ state, onStateChange: persist, onClose: () => jsonEditor.focus(),
        onCopy: (text, request) => send({ type: 'copyText', index: selected, text, request }) });

    function windowFor(view, total, height) {
        const physical = Math.min(MAX_SCROLL_HEIGHT, total * height);
        const visible = Math.max(1, Math.ceil(view.clientHeight / height));
        const scaled = total * height > MAX_SCROLL_HEIGHT;
        const first = scaled
            ? Math.floor(view.scrollTop / Math.max(1, physical - view.clientHeight) * Math.max(0, total - visible))
            : Math.floor(view.scrollTop / height);
        const start = Math.max(0, first - 3);
        return {
            start, end: Math.min(total, first + visible + 4), physical,
            top: scaled ? view.scrollTop + (start - first) * height : start * height,
        };
    }

    function scrollToRow(index) {
        const visible = Math.max(1, Math.ceil(list.clientHeight / ROW_HEIGHT));
        const current = windowFor(list, count, ROW_HEIGHT);
        if (index >= current.start + 3 && index < current.end - 4) return;
        const first = Math.max(0, Math.min(count - visible, index - Math.floor(visible / 2)));
        list.scrollTop = count * ROW_HEIGHT > MAX_SCROLL_HEIGHT
            ? first / Math.max(1, count - visible) * (MAX_SCROLL_HEIGHT - list.clientHeight)
            : first * ROW_HEIGHT;
    }

    function renderRows() {
        const window = windowFor(list, count, ROW_HEIGHT);
        rowSpacer.style.height = `${window.physical}px`;
        rowCanvas.style.top = `${window.top}px`;
        const fragment = document.createDocumentFragment();
        let missing = false;
        for (let index = window.start; index < window.end; index++) {
            const row = document.createElement('div');
            row.className = 'row-option';
            row.id = `row-${index}`;
            row.dataset.index = String(index);
            row.setAttribute('role', 'option');
            row.setAttribute('aria-selected', String(index === selected));
            row.setAttribute('aria-posinset', String(index + 1));
            row.setAttribute('aria-setsize', String(count));
            const label = document.createElement('div');
            label.className = 'row-label';
            label.textContent = `Row ${number(index + 1)}`;
            const preview = document.createElement('div');
            preview.className = 'row-preview';
            preview.textContent = cache.get(index) ?? 'Loading…';
            if (!cache.has(index)) missing = true;
            row.append(label, preview);
            fragment.append(row);
        }
        rowCanvas.replaceChildren(fragment);
        if (get(`row-${selected}`)) list.setAttribute('aria-activedescendant', `row-${selected}`);
        else list.removeAttribute('aria-activedescendant');
        const range = `${window.start}:${window.end}`;
        if (missing && pendingRange !== range) {
            pendingRange = range;
            send({ type: 'rows', start: window.start, count: window.end - window.start, request: ++rangeRequest });
        }
    }

    function scheduleRender() {
        if (frame) return;
        frame = requestAnimationFrame(() => { frame = 0; renderRows(); });
    }

    function updateControls() {
        get('previous').disabled = !count || selected === 0;
        get('next').disabled = !count || selected >= count - 1;
        get('jump').disabled = !count;
        get('jump').max = String(count);
        get('jump').value = String(selected + 1);
        get('total').textContent = `/ ${number(count)}`;
        get('copy').disabled = loaded !== selected || !hasText;
        get('fold-all').disabled = get('unfold-all').disabled = loaded !== selected || !hasText || rowKind !== 'json';
    }

    function select(index, reveal = true, immediate = false) {
        if (!count) return;
        selected = Math.max(0, Math.min(count - 1, index));
        persist();
        clearTimeout(selectionTimer);
        const request = ++rowRequest;
        loaded = -1;
        hasText = false;
        jsonEditor.clear();
        textPreview.loading();
        notice('');
        get('row-heading').textContent = `ROW ${number(selected + 1)}`;
        get('row-info').textContent = 'Loading…';
        get('empty-state').hidden = true;
        codeView.setAttribute('aria-busy', 'true');
        if (reveal) scrollToRow(selected);
        updateControls();
        scheduleRender();
        const requestRow = () => send({ type: 'select', index: selected, request });
        if (immediate) requestRow();
        else selectionTimer = setTimeout(requestRow, 35);
    }

    window.addEventListener('message', event => {
        const message = event.data;
        if (message.type === 'meta') {
            if (generation !== message.generation) {
                generation = message.generation;
                cache = new Map();
                pendingRange = '';
                loaded = -1;
                hasText = false;
                jsonEditor.clear();
                textPreview.loading();
                count = 0;
                pendingRestore = true;
                clearTimeout(selectionTimer);
                rowRequest++;
                rangeRequest++;
                notice('');
            }
            count = message.count;
            indexing = message.indexing;
            get('file-name').textContent = message.name;
            get('row-count').textContent = number(count);
            list.setAttribute('aria-busy', String(indexing));
            get('status').textContent = message.error || (indexing
                ? `Indexing ${message.size ? Math.floor(message.scanned / message.size * 100) : 0}% · ${number(count)} rows`
                : `${number(count)} rows · ${bytes(message.size)}`);
            if (message.error) notice(message.error);
            if (count && pendingRestore && (selected < count || !indexing)) {
                pendingRestore = false;
                select(selected, true, true);
            }
            if (!count && !indexing) {
                get('empty-state').hidden = false;
                get('empty-state').querySelector('strong').textContent = message.error ? 'Unable to open file' : 'This file is empty';
                get('empty-state').querySelector('span:last-child').textContent = message.error || 'Add JSON records, one per line, to get started.';
                get('row-heading').textContent = 'NO ROWS';
                get('row-info').textContent = '';
                codeView.setAttribute('aria-busy', 'false');
                textPreview.loading(message.error ? 'Unable to load this row.' : 'This file is empty.');
            }
            updateControls();
            scheduleRender();
            return;
        }
        if (message.generation !== generation) return;
        if (message.type === 'rows') {
            for (const row of message.rows) cache.set(row.index, row.preview);
            if (cache.size > 1200) {
                const window = windowFor(list, count, ROW_HEIGHT);
                for (const index of cache.keys()) if (index < window.start - 150 || index > window.end + 150) cache.delete(index);
            }
            if (message.request === rangeRequest) pendingRange = '';
            scheduleRender();
        } else if (message.type === 'row' && message.request === rowRequest && message.index === selected) {
            loaded = selected;
            rowKind = message.kind;
            hasText = message.text.length > 0;
            jsonEditor.setValue(message.text, message.kind);
            textPreview.update(jsonEditor);
            get('row-info').textContent = `${message.kind === 'json' ? 'JSON' : message.kind === 'empty' ? 'EMPTY' : message.kind === 'invalid' ? 'INVALID JSON' : 'ROW TOO LARGE'} · ${bytes(message.bytes)}`;
            notice(message.error);
            codeView.setAttribute('aria-busy', 'false');
            updateControls();
            scheduleRender();
        } else if (message.type === 'textCopied') {
            textPreview.copied(message.request);
        } else if (message.type === 'copied') {
            get('copy').textContent = 'Copied';
            setTimeout(() => { get('copy').textContent = 'Copy JSON'; }, 1500);
        } else if (message.type === 'error') {
            if (message.operation === 'select' && message.request !== rowRequest) return;
            if (message.operation === 'rows' && message.request !== rangeRequest) return;
            notice(message.error);
            if (message.operation === 'rows') pendingRange = '';
            if (message.operation === 'select') {
                get('row-info').textContent = 'Unable to load row';
                textPreview.loading('Unable to load this row.');
                codeView.setAttribute('aria-busy', 'false');
            }
        }
    });

    list.addEventListener('click', event => {
        const row = event.target.closest('[data-index]');
        if (row) { list.focus(); select(Number(row.dataset.index), false, true); }
    });
    list.addEventListener('keydown', event => {
        const keys = {
            ArrowUp: selected - 1, ArrowDown: selected + 1, Home: 0, End: count - 1,
            PageUp: selected - Math.max(1, Math.floor(list.clientHeight / ROW_HEIGHT)),
            PageDown: selected + Math.max(1, Math.floor(list.clientHeight / ROW_HEIGHT)),
        };
        if (event.key in keys) { event.preventDefault(); select(keys[event.key]); }
    });
    document.addEventListener('keydown', event => {
        if (event.altKey && ['ArrowUp', 'ArrowDown'].includes(event.key)) {
            event.preventDefault();
            select(selected + (event.key === 'ArrowUp' ? -1 : 1));
        }
    });
    get('previous').addEventListener('click', () => select(selected - 1, true, true));
    get('next').addEventListener('click', () => select(selected + 1, true, true));
    function updateWordWrap() {
        jsonEditor.setWordWrap(wordWrap);
        get('word-wrap').setAttribute('aria-pressed', String(wordWrap));
    }
    updateWordWrap();
    get('word-wrap').addEventListener('click', () => {
        wordWrap = !wordWrap;
        updateWordWrap();
        persist();
        scheduleRender();
    });
    get('jump-form').addEventListener('submit', event => {
        event.preventDefault();
        const index = Number(get('jump').value) - 1;
        if (Number.isInteger(index)) select(index, true, true);
    });
    get('fold-all').addEventListener('click', () => jsonEditor.foldAll());
    get('unfold-all').addEventListener('click', () => jsonEditor.unfoldAll());
    get('copy').addEventListener('click', () => send({ type: 'copy', index: selected }));
    get('open-text').addEventListener('click', () => send({ type: 'openText', index: selected }));
    get('refresh').addEventListener('click', () => send({ type: 'refresh' }));
    list.addEventListener('scroll', scheduleRender, { passive: true });
    new ResizeObserver(scheduleRender).observe(list);

    const divider = get('divider');
    function resize(width) {
        state.sidebarWidth = Math.max(220, Math.min(620, Math.floor(window.innerWidth * .65), width));
        document.documentElement.style.setProperty('--sidebar-width', `${state.sidebarWidth}px`);
        divider.setAttribute('aria-valuenow', String(state.sidebarWidth));
        persist();
        scheduleRender();
    }
    if (state.sidebarWidth) resize(state.sidebarWidth);
    divider.addEventListener('pointerdown', event => {
        divider.setPointerCapture(event.pointerId);
        divider.dataset.dragging = 'true';
    });
    divider.addEventListener('pointermove', event => {
        if (divider.dataset.dragging) resize(window.innerWidth - event.clientX);
    });
    divider.addEventListener('pointerup', () => { delete divider.dataset.dragging; });
    divider.addEventListener('lostpointercapture', () => { delete divider.dataset.dragging; });
    divider.addEventListener('keydown', event => {
        if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
            event.preventDefault();
            resize((state.sidebarWidth || 320) + (event.key === 'ArrowLeft' ? 20 : -20));
        }
    });
    send({ type: 'ready' });
})();
