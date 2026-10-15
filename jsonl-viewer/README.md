# JSONL Viewer

A read-only VS Code extension for `.jsonl` and `.ndjson` files. The main pane shows one selected row in [Monaco Editor](https://github.com/microsoft/monaco-editor), the editor component used by VS Code, with JSON syntax colors, collapsible objects and arrays, and word wrap. A list on the right shows every row with a short preview. Click a row, use the arrow keys, or enter a row number to change the selection.

## Run locally

```sh
cd jsonl-viewer
npm ci
npm run compile
code .
```

Press **F5** to launch the Extension Development Host with the example file. Open any `.jsonl` or `.ndjson` file to use the viewer. For an existing text editor, use **Reopen Editor With → JSONL Viewer**, or run **JSONL Viewer: Open File** from the command palette.

## Install

```sh
npm run package
code --install-extension jsonl-viewer-0.3.0.vsix
```

You can also use **Extensions: Install from VSIX** in VS Code. The extension requires VS Code 1.95 or newer.

## Controls

- Click a row in the right pane to select and highlight it.
- Focus the row list and use **Up**, **Down**, **Home**, **End**, **Page Up**, or **Page Down**.
- Use **Alt+Up** and **Alt+Down** from either pane for the previous or next row.
- Enter a number in **Row** and press **Enter** to jump directly to it.
- **Copy JSON** copies the entire selected row, including lines outside the visible area.
- **Word wrap** toggles wrapping in the main JSON pane. The viewer remembers the choice when switching rows or restoring the editor.
- Click the arrow in the editor gutter next to an object or array key to collapse or expand it, including nested values.
- **Collapse all** and **Expand all** fold or unfold the selected row. **Copy JSON** still copies the complete row when parts are collapsed.
- Hover over a string value and click **View as text** to open a resizable drawer below the JSON. The drawer shows the field path and decoded text, with newlines, tabs, quotes, and Unicode escapes rendered as characters. Strings are decoded once, so a literal `\n` remains literal text. The context menu also offers **View value as text** when the cursor is inside a string value.
- The drawer follows the same field when you change rows. Missing fields and non-string values show a message. **Copy text** copies the complete decoded value, and the drawer has its own **Word wrap** and **Close** controls. Drag its divider, or focus it and use **Up/Down**, to resize it. The field path, drawer height, and wrap choice are restored with the editor.
- **Open text** opens the source file at the selected line for editing.
- Drag the divider, or focus it and use **Left** and **Right**, to resize the list.
- **Refresh** reindexes the file. File changes on disk also trigger a refresh.

## Performance and file handling

The extension scans the file in 1 MiB chunks in a Node worker, storing only line offsets. The offset index takes about 8 bytes per row, plus small fixed allocations. It reads previews for visible rows and parses and formats only the selected row. Monaco renders the selected JSON and computes JSON folding in a web worker. The right-hand row list renders only its visible rows. Large row counts use a scaled scrollbar so every row remains reachable past browser scroll height limits.

Rows appear while indexing. Blank lines remain selectable and show an empty-line message. Invalid JSON shows the original line and its parse error. LF, CRLF, UTF-8, an initial UTF-8 BOM, and a final line without a newline are supported. A trailing newline does not create an extra row. Row numbers match physical source lines.

Formatting preserves the original numbers and key order, including large integers, exponent notation, trailing decimal zeros, and duplicate keys. Formatting changes whitespace only. Text is rendered as text, so file contents cannot insert HTML or scripts into the viewer.

The default maximum selected row size is 8 MiB. Change **JSONL Viewer: Max Row Size MB** in Settings to allow up to 128 MiB. Very large individual rows take longer to parse and display. If formatting would exceed 32 million characters, the original JSON is shown with a message. The viewer supports files on disk and does not load virtual filesystem documents or unsaved text edits.

## Development

```sh
npm run compile
npm run watch
npm run package
npm test
npm run benchmark
```

Monaco, its JSON support, fonts, and web workers are bundled into the VSIX. The viewer works offline and does not use a CDN. Syntax colors follow Monaco's light, dark, or high-contrast theme, with editor background and interface colors taken from VS Code. VS Code extensions that customize TextMate syntax colors are not loaded into the embedded editor.

Extension source lives in `src/`, webview source in `media/`, compiled extension JavaScript in `dist/`, and generated webview bundles in `media/build/`. `npm run compile` builds both parts. `npm run watch` watches both parts. Third-party licenses are included alongside the generated bundles.

## Verification

The record tests cover physical line counts, invalid and blank lines, BOM and CRLF, UTF-8 and read-chunk boundaries, number preservation, size limits, file truncation, and worker requests across index pages. `npm run benchmark` creates and indexes one million small records in a temporary file, measures worker replies, and removes the file.

Initial checks also ran the actual VS Code extension host and a headless webview backed by the file worker. The webview checks covered selection, keyboard navigation to the millionth row, row jumping, full-row copying, resizing, refresh, stale replies, empty and invalid rows, script-like text, and scrolling a JSON array with 10,000 elements. Results and measurement conditions are recorded in [verification.json](verification.json).

The Monaco integration was checked for JSON colors in light and dark themes, visible folding arrows, individual and nested key folding, collapse/expand all, complete copying while collapsed, word wrap and editor restoration, read-only behavior, and virtual rendering through the last element of a 10,000-element array. Its real JavaScript and JSON workers ran under the webview's content-security policy without console errors or warnings.

String-preview checks cover the hover action, decoded newlines, tabs, quotes and Unicode, literal backslashes, exact copying, drawer resizing, independent wrapping, field tracking across rows, missing and non-string fields, empty and root strings, array values, editor restoration, and virtual scrolling through a 10,000-line value. HTML-like string contents remain plain text. The browser check completed with no console errors or warnings.
