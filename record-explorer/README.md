# Record Explorer

A read-only VS Code extension for `.jsonl`, `.ndjson`, and `.parquet` files. The main pane shows one selected record in [Monaco Editor](https://github.com/microsoft/monaco-editor), the editor component used by VS Code, with JSON syntax colors, collapsible objects and arrays, and word wrap. A list on the right shows every record with a short preview. Click a record, use the arrow keys, or enter a row number to change the selection.

## Run locally

```sh
cd record-explorer
npm ci
npm run compile
code .
```

Press **F5** to launch the Extension Development Host with the example file. Open any `.jsonl`, `.ndjson`, or `.parquet` file to use the viewer. For an existing editor, use **Reopen Editor With → Record Explorer**, or run **Record Explorer: Open File** from the command palette.

## Install

```sh
npm run package
code --install-extension record-explorer-0.4.1.vsix
```

If you installed JSONL Viewer, uninstall that extension before installing Record Explorer to avoid duplicate file handlers. Existing `jsonlViewer` setting keys, command IDs, and editor associations remain supported.

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
- **Open text** opens a JSONL/NDJSON source file at the selected line for editing. Parquet records are displayed as JSON in the viewer.
- Drag the divider, or focus it and use **Left** and **Right**, to resize the list.
- **Refresh** reindexes the file. File changes on disk also trigger a refresh.

## Performance and file handling

The extension scans the file in 1 MiB chunks in a Node worker, storing only line offsets. The offset index takes about 8 bytes per row, plus small fixed allocations. It reads previews for visible rows and parses and formats only the selected row. Monaco renders the selected JSON and computes JSON folding in a web worker. The right-hand row list renders only its visible rows. Large row counts use a scaled scrollbar so every row remains reachable past browser scroll height limits.

Rows appear while indexing. Blank lines remain selectable and show an empty-line message. Invalid JSON shows the original line and its parse error. LF, CRLF, UTF-8, an initial UTF-8 BOM, and a final line without a newline are supported. A trailing newline does not create an extra row. Row numbers match physical source lines.

Formatting preserves the original numbers and key order, including large integers, exponent notation, trailing decimal zeros, and duplicate keys. Formatting changes whitespace only. Text is rendered as text, so file contents cannot insert HTML or scripts into the viewer.

The default maximum selected row size is 8 MiB. Change **Record Explorer: Max Row Size MB** in Settings to allow up to 128 MiB. Very large individual rows take longer to parse and display. If formatting would exceed 32 million characters, the original JSON is shown with a message. The viewer supports files on disk and does not load virtual filesystem documents or unsaved text edits.

## Parquet

Each Parquet record becomes one selectable JSON object. A file with one record shows that dictionary, and a file with multiple records uses the same right-hand row list as JSONL. Native structs, maps and lists appear as nested dictionaries and arrays. Columns annotated as JSON are decoded into their JSON values, so fields such as `input`, `output` and `metadata` can be expanded and collapsed. Strings remain strings, including JSON-looking completion text, and support the same **View as text** drawer with exact decoded copying and field tracking across records.

The reader gets the record count from the file metadata, then reads requested row ranges in the background worker. It uses page indexes when available, shares pending reads, and keeps bounded caches of compressed bytes and decoded record text. It does not convert the whole file into JSON before opening it. Parquet compression support is bundled, including Snappy, GZIP, Brotli and ZSTD, with no Python installation or system codec required. The reader uses [hyparquet](https://github.com/hyparam/hyparquet) and [hyparquet-compressors](https://github.com/hyparam/hyparquet-compressors).

Plain 64-bit integer fields retain their exact digits in the JSON representation. JSON-typed columns retain the spelling of their original numbers. Dates and timestamps are shown as ISO strings. Unannotated binary values are represented with `encoding: "base64"` and `data`, and non-finite floating-point values use the strings `"NaN"`, `"Infinity"` and `"-Infinity"`.

## Development

```sh
npm run compile
npm run watch
npm run package
npm test
npm run benchmark
npm run benchmark -- --parquet
```

Monaco, its JSON support, fonts, and web workers are bundled into the VSIX. The viewer works offline and does not use a CDN. Syntax colors follow Monaco's light, dark, or high-contrast theme, with editor background and interface colors taken from VS Code. VS Code extensions that customize TextMate syntax colors are not loaded into the embedded editor.

Extension source lives in `src/`, webview source in `media/`, compiled extension JavaScript in `dist/`, and generated webview bundles in `media/build/`. `npm run compile` builds both parts. `npm run watch` watches both parts. Third-party licenses are included alongside the generated bundles.

## Verification

The record tests cover physical line counts, invalid and blank lines, BOM and CRLF, UTF-8 and read-chunk boundaries, number preservation, size limits, file truncation, and worker requests across index pages. `npm run benchmark` creates and indexes one million small records in a temporary file, measures worker replies, and removes the file.

Initial checks also ran the actual VS Code extension host and a headless webview backed by the file worker. The webview checks covered selection, keyboard navigation to the millionth row, row jumping, full-row copying, resizing, refresh, stale replies, empty and invalid rows, script-like text, and scrolling a JSON array with 10,000 elements. Results and measurement conditions are recorded in [verification.json](verification.json).

The Monaco integration was checked for JSON colors in light and dark themes, visible folding arrows, individual and nested key folding, collapse/expand all, complete copying while collapsed, word wrap and editor restoration, read-only behavior, and virtual rendering through the last element of a 10,000-element array. Its real JavaScript and JSON workers ran under the webview's content-security policy without console errors or warnings.

String-preview checks cover the hover action, decoded newlines, tabs, quotes and Unicode, literal backslashes, exact copying, drawer resizing, independent wrapping, field tracking across rows, missing and non-string fields, empty and root strings, array values, editor restoration, and virtual scrolling through a 10,000-line value. HTML-like string contents remain plain text. The browser check completed with no console errors or warnings.

Parquet checks cover JSON columns, native structs, nullable values, INT64 precision, compression, empty and corrupt files, row limits, and worker requests across row groups. The provided five-record ZSTD example was checked in the browser with the actual file worker, including dictionary folding, selecting records, jumping to the final record, whole-record copying, and hovering `output.reasoning_content` for exact text copying and tracking across records. The local example is excluded from Git and the VSIX.
