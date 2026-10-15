(() => {
    'use strict';
    const vscode = acquireVsCodeApi();
    const get = id => document.getElementById(id);
    const list = get('row-list');
    const rowCanvas = get('row-canvas');
    const rowSpacer = get('row-spacer');
    const codeView = get('code-view');
    const codeCanvas = get('code-canvas');
    const codeSpacer = get('code-spacer');
    const state = vscode.getState() || {};
    const ROW_HEIGHT = 48;
    const LINE_HEIGHT = 22;
    const MAX_SCROLL_HEIGHT = 8000000;
    let generation = -1;
    let count = 0;
    let selected = Number.isInteger(state.selected) ? Math.max(0, state.selected) : 0;
    let loaded = -1;
    let indexing = true;
    let cache = new Map();
    let lines = [];
    let rowKind = 'json';
    let rowRequest = 0;
    let rangeRequest = 0;
    let pendingRange = '';
    let frame = 0;
    let selectionTimer;
    let rowWidth = 0;
    let pendingRestore = true;
    let wordWrap = state.wordWrap === true;
    let codeLayout = { lines: [], total: 0, offsets: null };
    const textMeasure = document.createElement('canvas').getContext('2d');

    const send = message => vscode.postMessage({ generation, ...message });
    const persist = () => vscode.setState({ selected, sidebarWidth: state.sidebarWidth, wordWrap });
    const number = value => value.toLocaleString();
    const bytes = value => value < 1024 ? `${value} B` : value < 1048576 ? `${(value / 1024).toFixed(1)} KiB` : `${(value / 1048576).toFixed(1)} MiB`;
    const notice = text => { get('notice').textContent = text || ''; get('notice').hidden = !text; };

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

    function highlight(text, node) {
        if (rowKind !== 'json') { node.textContent = text; return; }
        const regex = /"(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null/g;
        let last = 0;
        for (const token of text.matchAll(regex)) {
            if (token.index > last) node.append(document.createTextNode(text.slice(last, token.index)));
            const span = document.createElement('span');
            span.className = token[0][0] === '"'
                ? (/^\s*:/.test(text.slice(token.index + token[0].length)) ? 'token-key' : 'token-string')
                : (/^(true|false|null)$/.test(token[0]) ? 'token-literal' : 'token-number');
            span.textContent = token[0];
            node.append(span);
            last = token.index + token[0].length;
        }
        if (last < text.length) node.append(document.createTextNode(text.slice(last)));
    }

    const lineOffset = (layout, index) => layout.offsets ? layout.offsets[index] : index * LINE_HEIGHT;

    function codePosition(layout) {
        const physical = Math.min(MAX_SCROLL_HEIGHT, layout.total);
        return layout.total > MAX_SCROLL_HEIGHT
            ? codeView.scrollTop / Math.max(1, physical - codeView.clientHeight) * Math.max(0, layout.total - codeView.clientHeight)
            : codeView.scrollTop;
    }

    function lineAt(layout, position) {
        if (!layout.offsets) return Math.min(Math.max(0, layout.lines.length - 1), Math.floor(position / LINE_HEIGHT));
        let low = 0;
        let high = layout.lines.length;
        while (low < high) {
            const middle = Math.floor((low + high) / 2);
            if (layout.offsets[middle + 1] <= position) low = middle + 1;
            else high = middle;
        }
        return Math.min(low, Math.max(0, layout.lines.length - 1));
    }

    function codeAnchor(layout) {
        const position = codePosition(layout);
        const index = lineAt(layout, position);
        const height = lineOffset(layout, index + 1) - lineOffset(layout, index);
        return {
            index, fraction: height > 0 ? (position - lineOffset(layout, index)) / height : 0,
            atEnd: position > 0 && position >= layout.total - codeView.clientHeight - 1,
        };
    }

    function restoreCodeAnchor(layout, anchor) {
        const height = lineOffset(layout, anchor.index + 1) - lineOffset(layout, anchor.index);
        const maxPosition = Math.max(0, layout.total - codeView.clientHeight);
        const position = anchor.atEnd ? maxPosition : Math.max(0, Math.min(maxPosition,
            lineOffset(layout, anchor.index) + anchor.fraction * height));
        codeView.scrollTop = layout.total > MAX_SCROLL_HEIGHT
            ? position / Math.max(1, maxPosition) * (MAX_SCROLL_HEIGHT - codeView.clientHeight)
            : position;
    }

    function ensureCodeLayout() {
        const width = codeView.clientWidth;
        const font = getComputedStyle(codeView).font;
        if (codeLayout.lines === lines && codeLayout.width === width && codeLayout.font === font && codeLayout.wrap === wordWrap) return;
        const anchor = codeLayout.lines === lines && lines.length ? codeAnchor(codeLayout) : null;
        textMeasure.font = font;
        const characterWidth = Math.max(1, textMeasure.measureText('M').width);
        const gutter = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--gutter-width'));
        const columns = Math.max(1, Math.floor((width - gutter - 24) / characterWidth));
        const heights = wordWrap ? new Float64Array(lines.length) : null;
        const offsets = wordWrap ? new Float64Array(lines.length + 1) : null;
        let maxLength = 0;
        for (let i = 0; i < lines.length; i++) {
            maxLength = Math.max(maxLength, lines[i].length);
            if (wordWrap) {
                heights[i] = Math.max(1, Math.ceil(lines[i].length / columns)) * LINE_HEIGHT;
                offsets[i + 1] = offsets[i] + heights[i];
            }
        }
        rowWidth = 100 + maxLength * characterWidth;
        codeLayout = { lines, width, font, wrap: wordWrap, heights, offsets, total: offsets ? offsets[lines.length] : lines.length * LINE_HEIGHT };
        codeSpacer.style.height = `${Math.min(MAX_SCROLL_HEIGHT, codeLayout.total)}px`;
        codeSpacer.style.width = wordWrap ? '100%' : `${Math.max(width, rowWidth)}px`;
        if (anchor) restoreCodeAnchor(codeLayout, anchor);
    }

    function renderCode() {
        ensureCodeLayout();
        const position = codePosition(codeLayout);
        const start = Math.max(0, lineAt(codeLayout, position) - 3);
        const end = Math.min(lines.length, lineAt(codeLayout, position + codeView.clientHeight) + 4);
        codeCanvas.style.top = `${codeView.scrollTop + lineOffset(codeLayout, start) - position}px`;
        const fragment = document.createDocumentFragment();
        for (let i = start; i < end; i++) {
            const line = document.createElement('div');
            line.className = 'code-line';
            const gutter = document.createElement('span');
            gutter.className = 'line-number';
            gutter.textContent = String(i + 1);
            gutter.setAttribute('aria-hidden', 'true');
            const text = document.createElement('span');
            text.className = 'line-text';
            highlight(lines[i], text);
            line.append(gutter, text);
            fragment.append(line);
        }
        codeCanvas.replaceChildren(fragment);
        if (wordWrap) {
            const anchor = codeAnchor(codeLayout);
            let changed = lines.length;
            for (let i = 0; i < codeCanvas.children.length; i++) {
                const index = start + i;
                const height = Math.max(LINE_HEIGHT, codeCanvas.children[i].getBoundingClientRect().height);
                if (codeLayout.heights[index] !== height) {
                    codeLayout.heights[index] = height;
                    changed = Math.min(changed, index);
                }
            }
            if (changed < lines.length) {
                for (let i = changed; i < lines.length; i++) codeLayout.offsets[i + 1] = codeLayout.offsets[i] + codeLayout.heights[i];
                codeLayout.total = codeLayout.offsets[lines.length];
                codeSpacer.style.height = `${Math.min(MAX_SCROLL_HEIGHT, codeLayout.total)}px`;
                restoreCodeAnchor(codeLayout, anchor);
                scheduleRender();
            }
        }
    }

    function scheduleRender() {
        if (frame) return;
        frame = requestAnimationFrame(() => { frame = 0; renderRows(); renderCode(); });
    }

    function updateControls() {
        get('previous').disabled = !count || selected === 0;
        get('next').disabled = !count || selected >= count - 1;
        get('jump').disabled = !count;
        get('jump').max = String(count);
        get('jump').value = String(selected + 1);
        get('total').textContent = `/ ${number(count)}`;
        get('copy').disabled = loaded !== selected || !lines.length;
    }

    function select(index, reveal = true, immediate = false) {
        if (!count) return;
        selected = Math.max(0, Math.min(count - 1, index));
        persist();
        clearTimeout(selectionTimer);
        const request = ++rowRequest;
        loaded = -1;
        lines = [];
        notice('');
        get('row-heading').textContent = `ROW ${number(selected + 1)}`;
        get('row-info').textContent = 'Loading…';
        get('empty-state').hidden = true;
        codeView.setAttribute('aria-busy', 'true');
        codeView.scrollTop = 0;
        codeView.scrollLeft = 0;
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
                lines = [];
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
            lines = message.text ? message.text.split('\n') : [];
            get('row-info').textContent = `${message.kind === 'json' ? 'JSON' : message.kind === 'empty' ? 'EMPTY' : message.kind === 'invalid' ? 'INVALID JSON' : 'ROW TOO LARGE'} · ${bytes(message.bytes)}`;
            notice(message.error);
            codeView.setAttribute('aria-busy', 'false');
            updateControls();
            scheduleRender();
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
        codeView.classList.toggle('word-wrap', wordWrap);
        get('word-wrap').setAttribute('aria-pressed', String(wordWrap));
    }
    updateWordWrap();
    get('word-wrap').addEventListener('click', () => {
        wordWrap = !wordWrap;
        updateWordWrap();
        codeView.scrollLeft = 0;
        persist();
        scheduleRender();
    });
    get('jump-form').addEventListener('submit', event => {
        event.preventDefault();
        const index = Number(get('jump').value) - 1;
        if (Number.isInteger(index)) select(index, true, true);
    });
    get('copy').addEventListener('click', () => send({ type: 'copy', index: selected }));
    get('open-text').addEventListener('click', () => send({ type: 'openText', index: selected }));
    get('refresh').addEventListener('click', () => send({ type: 'refresh' }));
    list.addEventListener('scroll', scheduleRender, { passive: true });
    codeView.addEventListener('scroll', scheduleRender, { passive: true });
    new ResizeObserver(scheduleRender).observe(codeView);
    new MutationObserver(scheduleRender).observe(document.body, { attributes: true, attributeFilter: ['class', 'style'] });

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
