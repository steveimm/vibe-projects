import { createJsonEditor } from './json-editor.js';
import { formatJsonPath } from './json-values.mjs';

export function createTextPreview({ state, onStateChange, onCopy, onClose }) {
    const get = id => document.getElementById(id);
    const drawer = get('text-preview');
    const divider = get('preview-divider');
    const container = get('preview-editor');
    const detail = drawer.parentElement;
    let path = Array.isArray(state.previewPath) && state.previewPath.every(part => typeof part === 'string'
        || (Number.isInteger(part) && part >= 0)) ? state.previewPath : null;
    let wordWrap = state.previewWordWrap !== false;
    let editor;
    let text = null;
    let copyVersion = 0;
    let copyTimer;

    function setHeight(height, persist = false) {
        const header = detail.querySelector('.pane-heading').offsetHeight;
        const maximum = Math.max(80, detail.clientHeight - header - get('notice').offsetHeight - 125);
        const minimum = Math.min(140, maximum);
        height = Math.round(Math.max(minimum, Math.min(maximum, height)));
        drawer.style.height = `${height}px`;
        divider.setAttribute('aria-valuemin', String(minimum));
        divider.setAttribute('aria-valuemax', String(maximum));
        divider.setAttribute('aria-valuenow', String(height));
        if (persist) { state.previewHeight = height; onStateChange(); }
    }

    function show() {
        drawer.hidden = divider.hidden = false;
        get('preview-path').textContent = formatJsonPath(path);
        get('preview-path').title = formatJsonPath(path);
        const height = Number.isFinite(state.previewHeight) ? state.previewHeight : detail.clientHeight * .4;
        setHeight(height);
    }

    function resetCopy() {
        copyVersion++;
        clearTimeout(copyTimer);
        get('preview-copy').textContent = 'Copy text';
    }

    function status(message) {
        text = null;
        resetCopy();
        editor?.clear();
        container.hidden = true;
        get('preview-copy').disabled = true;
        get('preview-status').hidden = false;
        get('preview-status').textContent = message;
    }

    function display(value) {
        text = value;
        resetCopy();
        container.hidden = false;
        editor ??= createJsonEditor(container, { wordWrap, plainText: true });
        editor.setValue(value, 'text');
        get('preview-copy').disabled = false;
        get('preview-status').hidden = value.length > 0;
        get('preview-status').textContent = 'Empty string';
    }

    const api = {
        open(value) {
            path = value.path.slice();
            state.previewPath = path;
            show();
            display(value.value);
            onStateChange();
            editor.focus();
        },
        loading(message = 'Loading row…') { if (path) { show(); status(message); } },
        update(jsonEditor) {
            if (!path) return;
            show();
            const result = jsonEditor.stringAtPath(path);
            if (result.kind === 'string') display(result.value);
            else status(result.kind === 'missing' ? 'Field not present in this row.'
                : result.kind === 'notString' ? 'This field is not a string in this row.' : 'Select a row with valid JSON to preview this field.');
        },
        close() {
            path = null;
            state.previewPath = null;
            status('');
            drawer.hidden = divider.hidden = true;
            onStateChange();
            onClose();
        },
        copied(request) {
            if (request !== copyVersion) return;
            get('preview-copy').textContent = 'Copied';
            copyTimer = setTimeout(() => { get('preview-copy').textContent = 'Copy text'; }, 1500);
        },
    };
    get('preview-copy').addEventListener('click', () => { if (text !== null) onCopy(text, ++copyVersion); });
    get('preview-close').addEventListener('click', api.close);
    get('preview-wrap').setAttribute('aria-pressed', String(wordWrap));
    get('preview-wrap').addEventListener('click', () => {
        wordWrap = !wordWrap;
        state.previewWordWrap = wordWrap;
        get('preview-wrap').setAttribute('aria-pressed', String(wordWrap));
        editor?.setWordWrap(wordWrap);
        onStateChange();
    });
    let dragging = false;
    divider.addEventListener('pointerdown', event => { divider.setPointerCapture(event.pointerId); dragging = true; event.preventDefault(); });
    divider.addEventListener('pointermove', event => {
        if (dragging) setHeight(detail.getBoundingClientRect().bottom - event.clientY, true);
    });
    divider.addEventListener('pointerup', () => { dragging = false; });
    divider.addEventListener('lostpointercapture', () => { dragging = false; });
    divider.addEventListener('keydown', event => {
        if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
            event.preventDefault();
            setHeight(drawer.getBoundingClientRect().height + (event.key === 'ArrowUp' ? 20 : -20), true);
        }
    });
    new ResizeObserver(() => { if (!drawer.hidden) setHeight(Number.isFinite(state.previewHeight)
        ? state.previewHeight : detail.clientHeight * .4); }).observe(detail);
    document.addEventListener('keydown', event => {
        if (event.key === 'Escape' && !event.defaultPrevented && !drawer.hidden && drawer.contains(document.activeElement)) {
            event.preventDefault(); api.close();
        }
    });
    return api;
}
