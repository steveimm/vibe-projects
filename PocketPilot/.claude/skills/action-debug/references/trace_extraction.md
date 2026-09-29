# Action trace extraction

Read `trace.jsonl` chronologically. A `tool_call` event identifies the tool and call ID. Its `tool_call_args` artifact contains arguments. The matching `tool_result` event contains the transport result and a post-action observation. The preceding `screen_captured` event supplies the screenshot used to choose the target.

Examples:

```json
{"point":[500,750]}
```

This `tap` call maps to approximately `(540,1799)` on a 1080×2400 display, regardless of the JPEG's resized dimensions.

```json
{"start":[500,800],"end":[500,300],"duration_ms":400}
```

This `swipe` moves the finger upward. Convert each axis to physical pixels before reproducing it with ADB.

`type_text` has one `text` parameter. It replaces the currently focused field. Screenshots before and after the preceding tap establish whether focus was correct.

Native reasoning is stored in `llm_reasoning` artifacts. Native final answers are `llm_response_text` artifacts on an `llm_response` event with `is_complete=true`. A `finished` summary is a terminal response, not a verified success verdict.
