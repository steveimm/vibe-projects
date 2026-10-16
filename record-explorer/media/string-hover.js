import * as monaco from 'monaco-editor/editor/editor.api.js';
import { formatJsonPath, stringTokenAt, stringValueAt } from './json-values.mjs';

export function addStringHover(editor, onPreview, editorNode) {
    const button = document.createElement('button');
    button.className = 'string-preview-action';
    button.textContent = 'View as text';
    let position = null;
    let hovered = null;
    let cached = null;
    let source;
    let showTimer;
    let hideTimer;
    const canPreview = editor.createContextKey('jsonlStringValue', false);
    const valueAt = point => {
        const model = editor.getModel();
        if (!point || model?.getLanguageId() !== 'json') return null;
        const offset = model.getOffsetAt(point);
        if (cached && offset >= cached.offset && offset < cached.end) return cached;
        if (!stringTokenAt(model.getLineContent(point.lineNumber), point.column - 1)) return null;
        source ??= model.getValue();
        cached = stringValueAt(source, offset);
        return cached;
    };
    const widget = {
        getId: () => 'jsonl.stringPreview',
        getDomNode: () => button,
        getPosition: () => position && ({ position, preference: [
            monaco.editor.ContentWidgetPositionPreference.ABOVE,
            monaco.editor.ContentWidgetPositionPreference.BELOW,
        ] }),
        suppressMouseDown: true,
    };
    editor.addContentWidget(widget);
    const hide = () => {
        clearTimeout(showTimer);
        clearTimeout(hideTimer);
        position = null;
        hovered = null;
        editor.layoutContentWidget(widget);
    };
    const hideSoon = () => { clearTimeout(showTimer); clearTimeout(hideTimer); hideTimer = setTimeout(hide, 180); };
    editorNode.addEventListener('pointerleave', hideSoon);
    const listeners = [
        editor.onMouseMove(event => {
            if (button.contains(event.target.element)) { clearTimeout(hideTimer); return; }
            if (event.target.type !== monaco.editor.MouseTargetType.CONTENT_TEXT) { hideSoon(); return; }
            const value = valueAt(event.target.position);
            if (!value) { hideSoon(); return; }
            clearTimeout(hideTimer);
            if (hovered === value && position) return;
            clearTimeout(showTimer);
            showTimer = setTimeout(() => {
                hovered = value;
                position = event.target.position;
                button.title = `View ${formatJsonPath(value.path)} as text`;
                editor.layoutContentWidget(widget);
            }, 120);
        }),
        editor.onDidScrollChange(event => { if (event.scrollTopChanged || event.scrollLeftChanged) hide(); }),
        editor.onDidChangeModel(() => { hide(); source = undefined; cached = null; canPreview.set(false); }),
        editor.onDidChangeCursorPosition(event => canPreview.set(Boolean(valueAt(event.position)))),
        editor.addAction({
            id: 'jsonl.viewValueAsText', label: 'View value as text',
            precondition: 'jsonlStringValue', contextMenuGroupId: 'navigation', contextMenuOrder: 1,
            run: () => { const value = valueAt(editor.getPosition()); if (value) onPreview(value); },
        }),
    ];
    button.addEventListener('pointerenter', () => { clearTimeout(hideTimer); });
    button.addEventListener('pointerleave', hideSoon);
    button.addEventListener('click', () => { if (hovered) { const value = hovered; hide(); onPreview(value); } });
    return { dispose() {
        hide();
        editorNode.removeEventListener('pointerleave', hideSoon);
        for (const listener of listeners) listener.dispose();
        editor.removeContentWidget(widget);
    } };
}
