---
name: browser-use
description: Browser automation guidance and raw CDP examples.
allowed-tools:
  - browser_script
metadata:
  bundled: "true"
---

# Browser Use

Use `browser_script` when the task needs Chrome DevTools Protocol control over the user's real Android Chrome profile: navigation, reading page state, screenshots, input, or tab management.

`browser_script` runs JavaScript in PocketPilot's hidden script host. The only built-in browser primitive is:

```js
await cdp(method, params = {}, options = {})
```

## Raw CDP Examples

Read the current title:

```js
const response = await cdp("Runtime.evaluate", {
  expression: "document.title",
  returnByValue: true
});
return response.result.value;
```

Navigate and wait for the load event with raw polling:

```js
await cdp("Page.navigate", { url: "https://example.com" });
for (let i = 0; i < 50; i++) {
  const state = await cdp("Runtime.evaluate", {
    expression: "document.readyState",
    returnByValue: true
  });
  if (state.result.value === "complete") break;
  await new Promise(resolve => setTimeout(resolve, 300));
}
return { loaded: true };
```

## Operating Rules

- Keep scripts small and task-specific.
- `Target.*` and `Browser.*` are browser-level CDP methods. Most page domains route to the active page session unless you pass `options.targetId` or `options.sessionId`.
- Screenshots are device pixels. Input coordinates are CSS pixels. Convert by `window.devicePixelRatio` if you measure coordinates from a screenshot.
- After visible actions, verify by rereading page state or taking another screenshot.
- Android Chrome CDP support can differ from desktop Chrome. If a method is unsupported, use another raw CDP route or visible Android automation.
