# JSONL Viewer

A read-only VS Code extension for `.jsonl` and `.ndjson` files. The main pane shows one selected row as formatted, highlighted JSON. A list on the right shows every row with a short preview. Click a row, use the arrow keys, or enter a row number to change the selection.

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
code --install-extension jsonl-viewer-0.1.1.vsix
```

You can also use **Extensions: Install from VSIX** in VS Code. The extension requires VS Code 1.95 or newer.

## Controls

- Click a row in the right pane to select and highlight it.
- Focus the row list and use **Up**, **Down**, **Home**, **End**, **Page Up**, or **Page Down**.
- Use **Alt+Up** and **Alt+Down** from either pane for the previous or next row.
- Enter a number in **Row** and press **Enter** to jump directly to it.
- **Copy JSON** copies the entire selected row, including lines outside the visible area.
- **Word wrap** toggles wrapping in the main JSON pane. The viewer remembers the choice when switching rows or restoring the editor.
- **Open text** opens the source file at the selected line for editing.
- Drag the divider, or focus it and use **Left** and **Right**, to resize the list.
- **Refresh** reindexes the file. File changes on disk also trigger a refresh.

## Performance and file handling

The extension scans the file in 1 MiB chunks in a Node worker, storing only line offsets. The offset index takes about 8 bytes per row, plus small fixed allocations. It reads previews for visible rows and parses and formats only the selected row. Both panes render their visible lines with a small overscan. Large row counts use a scaled scrollbar so every row remains reachable past browser scroll height limits.

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

The runtime has no third-party dependencies. TypeScript and the VSIX packager are development tools. Source lives in `src/`, webview assets in `media/`, and generated JavaScript in `dist/`.

## Verification

The record tests cover physical line counts, invalid and blank lines, BOM and CRLF, UTF-8 and read-chunk boundaries, number preservation, size limits, file truncation, and worker requests across index pages. `npm run benchmark` creates and indexes one million small records in a temporary file, measures worker replies, and removes the file.

Initial checks also ran the actual VS Code extension host and a headless webview backed by the file worker. The webview checks covered selection, keyboard navigation to the millionth row, row jumping, full-row copying, resizing, refresh, stale replies, empty and invalid rows, script-like text, and scrolling a JSON array with 10,000 elements. Results and measurement conditions are recorded in [verification.json](verification.json).
