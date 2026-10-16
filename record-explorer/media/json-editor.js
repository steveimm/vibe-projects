import * as monaco from 'monaco-editor/editor/editor.api.js';
// Register shared services before creating the JSON and text editors.
import 'monaco-editor/internal/common/workers.js';
import 'monaco-editor/editor/contrib/folding/browser/folding.js';
import 'monaco-editor/editor/contrib/find/browser/findController.js';
import 'monaco-editor/editor/contrib/bracketMatching/browser/bracketMatching.js';
import 'monaco-editor/editor/contrib/clipboard/browser/clipboard.js';
import 'monaco-editor/editor/contrib/contextmenu/browser/contextmenu.js';
import 'monaco-editor/editor/contrib/wordOperations/browser/wordOperations.js';
import 'monaco-editor/base/browser/ui/codicons/codicon/codicon.css';
import { jsonDefaults } from 'monaco-editor/languages/features/json/register.js';
import { addStringHover } from './string-hover.js';
import { stringValueAtPath } from './json-values.mjs';

jsonDefaults.setModeConfiguration({ tokens: true, foldingRanges: true });
jsonDefaults.setDiagnosticsOptions({ validate: false, enableSchemaRequest: false });

const workerUrls = new Map();
globalThis.MonacoEnvironment = {
    async getWorker(_moduleId, label) {
        const kind = label === 'json' ? 'json' : 'editor';
        if (!workerUrls.has(kind)) {
            const source = document.getElementById('code-view').dataset[`${kind}Worker`];
            workerUrls.set(kind, fetch(source).then(response => {
                if (!response.ok) throw new Error(`Unable to load the ${kind} editor worker.`);
                return response.text();
            }).then(text => URL.createObjectURL(new Blob([text], { type: 'text/javascript' }))));
        }
        return new Worker(await workerUrls.get(kind), { name: `jsonl-${kind}` });
    },
};

export function createJsonEditor(container, { wordWrap, plainText = false, onPreviewValue }) {
    let editor;
    function applyTheme() {
        const style = getComputedStyle(document.body);
        const kind = document.body.dataset.vscodeThemeKind || document.body.className;
        const light = kind.includes('light');
        const contrast = kind.includes('high-contrast');
        const base = contrast ? (light ? 'hc-light' : 'hc-black') : (light ? 'vs' : 'vs-dark');
        const colors = {};
        const names = [
            'editor.background', 'editor.foreground', 'editorCursor.foreground',
            'editorLineNumber.foreground', 'editorLineNumber.activeForeground',
            'editor.selectionBackground', 'editor.inactiveSelectionBackground', 'editorGutter.background',
            'editorIndentGuide.background1', 'editorIndentGuide.activeBackground1', 'editorGutter.foldingControlForeground',
        ];
        for (const name of names) {
            const value = style.getPropertyValue(`--vscode-${name.replaceAll('.', '-')}`).trim();
            if (/^#[\da-f]{3,8}$/i.test(value)) colors[name] = value;
        }
        monaco.editor.defineTheme('record-explorer', { base, inherit: true, rules: [], colors });
        monaco.editor.setTheme('record-explorer');
        const fontSize = parseFloat(style.getPropertyValue('--vscode-editor-font-size')) || 13;
        editor?.updateOptions({
            fontFamily: style.getPropertyValue('--vscode-editor-font-family').trim() || 'monospace',
            fontSize, lineHeight: Math.max(22, Math.round(fontSize * 1.6)),
        });
    }
    applyTheme();
    const style = getComputedStyle(document.body);
    const fontSize = parseFloat(style.getPropertyValue('--vscode-editor-font-size')) || 13;
    editor = monaco.editor.create(container, {
        model: null,
        theme: 'record-explorer',
        readOnly: true,
        domReadOnly: true,
        automaticLayout: true,
        minimap: { enabled: false },
        stickyScroll: { enabled: false },
        fontFamily: style.getPropertyValue('--vscode-editor-font-family').trim() || 'monospace',
        fontSize,
        lineHeight: Math.max(22, Math.round(fontSize * 1.6)),
        wordWrap: wordWrap ? 'on' : 'off',
        wrappingIndent: plainText ? 'none' : 'same',
        folding: !plainText,
        foldingStrategy: 'auto',
        showFoldingControls: 'always',
        foldingHighlight: true,
        lineNumbers: plainText ? 'off' : 'on',
        lineNumbersMinChars: 4,
        scrollBeyondLastLine: false,
        stopRenderingLineAfter: -1,
        padding: { top: 8, bottom: 16 },
        renderLineHighlight: 'none',
        renderValidationDecorations: 'off',
        occurrencesHighlight: 'off',
        selectionHighlight: false,
        links: false,
        unicodeHighlight: { ambiguousCharacters: false, invisibleCharacters: false },
        bracketPairColorization: { enabled: true },
        guides: { indentation: !plainText, bracketPairs: !plainText },
        ariaLabel: plainText ? 'Decoded string value as plain text' : 'Selected row as formatted JSON',
    });
    const stringHover = onPreviewValue ? addStringHover(editor, onPreviewValue, container) : null;
    const themeObserver = new MutationObserver(applyTheme);
    themeObserver.observe(document.body, { attributes: true });

    const clear = () => {
        const model = editor.getModel();
        editor.setModel(null);
        model?.dispose();
    };
    const api = {
        clear,
        setValue(text, kind) {
            clear();
            const model = monaco.editor.createModel(text, kind === 'json' ? 'json' : 'plaintext');
            model.updateOptions({ tabSize: plainText ? 4 : 2, insertSpaces: true });
            editor.setModel(model);
            editor.setPosition({ lineNumber: 1, column: 1 });
            editor.setScrollPosition({ scrollTop: 0, scrollLeft: 0 });
        },
        setWordWrap(enabled) { editor.updateOptions({ wordWrap: enabled ? 'on' : 'off' }); },
        focus() { editor.focus(); },
        stringAtPath(path) {
            const model = editor.getModel();
            return model?.getLanguageId() === 'json' ? stringValueAtPath(model.getValue(), path) : { kind: 'invalid' };
        },
        foldAll() { return editor.getAction('editor.foldAll')?.run(); },
        unfoldAll() { return editor.getAction('editor.unfoldAll')?.run(); },
        dispose() { themeObserver.disconnect(); stringHover?.dispose(); clear(); editor.dispose(); },
    };
    window.addEventListener('pagehide', () => {
        api.dispose();
        for (const url of workerUrls.values()) void url.then(value => URL.revokeObjectURL(value));
    }, { once: true });
    return api;
}
