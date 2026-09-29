import { renderDetailPanel, renderSummary } from "./detail.js?v=7";

const debugRunSelect = document.getElementById("debugRunSelect");
const evalRunSelect = document.getElementById("evalRunSelect");
const evalTaskSelect = document.getElementById("evalTaskSelect");
const refreshBtn = document.getElementById("refreshBtn");
const treePanel = document.getElementById("treePanel");
const detailPanel = document.getElementById("detailPanel");
const stepSummaryPanel = document.getElementById("stepSummaryPanel");
const meta = document.getElementById("meta");
const stepCounter = document.getElementById("stepCounter");
const prevBtn = document.getElementById("prevBtn");
const nextBtn = document.getElementById("nextBtn");
const filterInput = document.getElementById("filterInput");
const clearFilterBtn = document.getElementById("clearFilterBtn");

let sessions = [];
let sessionById = new Map();
let stepById = new Map();
let steps = [];
let filteredSteps = [];
let selectedStepIndex = -1;
let selectedStepId = null;
let filterQuery = "";
let treeError = null;
let catalog = { debug_runs: [], eval_runs: [] };
let selectedDebugRunId = "";
let selectedEvalRunId = "";
let selectedEvalTaskId = "";
let currentTraceId = null;
let activeSource = "";

// Initial load
refreshCatalog();

refreshBtn.addEventListener("click", refreshCatalog);
debugRunSelect.addEventListener("change", () => {
  selectedDebugRunId = debugRunSelect.value || "";
  if (!selectedDebugRunId) {
    if (activeSource === "debug") {
      activeSource = "";
      currentTraceId = null;
      clearRunData("No trace selected.");
    }
    return;
  }
  activeSource = "debug";
  selectedEvalRunId = "";
  selectedEvalTaskId = "";
  evalRunSelect.value = "";
  populateEvalTaskSelect();
  loadDebugTrace();
});
evalRunSelect.addEventListener("change", () => {
  selectedEvalRunId = evalRunSelect.value || "";
  selectedEvalTaskId = "";
  populateEvalTaskSelect();
  if (!selectedEvalRunId) {
    if (activeSource === "eval") {
      activeSource = "";
      currentTraceId = null;
      clearRunData("No trace selected.");
    }
    return;
  }
  activeSource = "eval";
  selectedDebugRunId = "";
  debugRunSelect.value = "";
  loadEvalTrace();
});
evalTaskSelect.addEventListener("change", () => {
  selectedEvalTaskId = evalTaskSelect.value || "";
  if (!selectedEvalRunId || !selectedEvalTaskId) {
    if (activeSource === "eval") {
      currentTraceId = null;
      clearRunData("No eval task selected.");
    }
    return;
  }
  activeSource = "eval";
  selectedDebugRunId = "";
  debugRunSelect.value = "";
  loadEvalTrace();
});

prevBtn.addEventListener("click", () => moveSelection(-1));
nextBtn.addEventListener("click", () => moveSelection(1));
filterInput.addEventListener("input", () => {
  filterQuery = filterInput.value.trim().toLowerCase();
  applyFilters();
});
clearFilterBtn.addEventListener("click", () => {
  filterQuery = "";
  filterInput.value = "";
  applyFilters();
});

document.addEventListener("keydown", (event) => {
  if (event.key === "ArrowRight") {
    moveSelection(1);
  }
  if (event.key === "ArrowLeft") {
    moveSelection(-1);
  }
  if (event.key === "ArrowUp") {
    moveSelection(-1);
  }
  if (event.key === "ArrowDown") {
    moveSelection(1);
  }
});

function findDebugRun(runId) {
  return catalog.debug_runs.find((run) => run.id === runId) || null;
}

function findEvalRun(runId) {
  return catalog.eval_runs.find((run) => run.id === runId) || null;
}

function clearRunData(message) {
  sessions = [];
  sessionById = new Map();
  stepById = new Map();
  steps = [];
  filteredSteps = [];
  selectedStepIndex = -1;
  selectedStepId = null;
  filterQuery = "";
  filterInput.value = "";
  treeError = null;
  treePanel.innerHTML = `<div class="hint">${escapeHtml(message)}</div>`;
  detailPanel.textContent = "Select a step.";
  if (stepSummaryPanel) {
    stepSummaryPanel.innerHTML = "";
    stepSummaryPanel.style.display = "none";
  }
  updateCounter();
}

function populateDebugRunSelect() {
  debugRunSelect.innerHTML = "";
  const placeholder = document.createElement("option");
  placeholder.value = "";
  placeholder.textContent = "Debug Run...";
  debugRunSelect.appendChild(placeholder);

  catalog.debug_runs.forEach((run) => {
    const option = document.createElement("option");
    option.value = run.id;
    option.textContent = `${run.id} ${run.compiled ? "✓" : ""}`;
    debugRunSelect.appendChild(option);
  });

  debugRunSelect.disabled = catalog.debug_runs.length === 0;
  if (selectedDebugRunId && findDebugRun(selectedDebugRunId)) {
    debugRunSelect.value = selectedDebugRunId;
  } else {
    selectedDebugRunId = "";
    debugRunSelect.value = "";
  }
}

function populateEvalRunSelect() {
  evalRunSelect.innerHTML = "";
  const placeholder = document.createElement("option");
  placeholder.value = "";
  placeholder.textContent = "Eval Run...";
  evalRunSelect.appendChild(placeholder);

  catalog.eval_runs.forEach((run) => {
    const compiledCount = run.tasks.filter((task) => task.compiled).length;
    const option = document.createElement("option");
    option.value = run.id;
    option.textContent = `${run.id} (${compiledCount}/${run.tasks.length} compiled)`;
    evalRunSelect.appendChild(option);
  });

  evalRunSelect.disabled = catalog.eval_runs.length === 0;
  if (selectedEvalRunId && findEvalRun(selectedEvalRunId)) {
    evalRunSelect.value = selectedEvalRunId;
  } else {
    selectedEvalRunId = "";
    evalRunSelect.value = "";
  }
}

function populateEvalTaskSelect() {
  evalTaskSelect.innerHTML = "";
  const placeholder = document.createElement("option");
  placeholder.value = "";
  placeholder.textContent = "Eval Task...";
  evalTaskSelect.appendChild(placeholder);

  const evalRun = findEvalRun(selectedEvalRunId);
  if (!evalRun || evalRun.tasks.length === 0) {
    selectedEvalTaskId = "";
    evalTaskSelect.disabled = true;
    evalTaskSelect.value = "";
    return;
  }

  evalRun.tasks.forEach((task) => {
    const option = document.createElement("option");
    option.value = task.id;
    option.textContent = `${task.id} ${task.compiled ? "✓" : ""}`;
    evalTaskSelect.appendChild(option);
  });

  const keepCurrent = selectedEvalTaskId && evalRun.tasks.some((task) => task.id === selectedEvalTaskId);
  if (!keepCurrent) {
    selectedEvalTaskId = evalRun.tasks[0].id;
  }
  evalTaskSelect.disabled = false;
  evalTaskSelect.value = selectedEvalTaskId;
}

async function refreshCatalog() {
  try {
    const res = await fetch("/api/catalog");
    if (!res.ok) throw new Error("Failed to fetch run catalog");
    const payload = await res.json();
    catalog = {
      debug_runs: Array.isArray(payload.debug_runs) ? payload.debug_runs : [],
      eval_runs: Array.isArray(payload.eval_runs) ? payload.eval_runs : [],
    };

    populateDebugRunSelect();
    populateEvalRunSelect();
    populateEvalTaskSelect();

    const hasAnyRun = catalog.debug_runs.length > 0 || catalog.eval_runs.length > 0;
    if (!hasAnyRun) {
      selectedDebugRunId = "";
      selectedEvalRunId = "";
      selectedEvalTaskId = "";
      activeSource = "";
      currentTraceId = null;
      meta.textContent = "No trace runs found";
      clearRunData("No runs found.");
      return;
    }

    if (activeSource === "debug" && selectedDebugRunId && findDebugRun(selectedDebugRunId)) {
      await loadDebugTrace();
      return;
    }

    if (activeSource === "eval" && selectedEvalRunId && findEvalRun(selectedEvalRunId)) {
      populateEvalTaskSelect();
      if (selectedEvalTaskId) {
        await loadEvalTrace();
        return;
      }
    }

    if (catalog.debug_runs.length > 0) {
      selectedDebugRunId = catalog.debug_runs[0].id;
      debugRunSelect.value = selectedDebugRunId;
      selectedEvalRunId = "";
      selectedEvalTaskId = "";
      evalRunSelect.value = "";
      populateEvalTaskSelect();
      activeSource = "debug";
      await loadDebugTrace();
      return;
    }

    const firstEvalRun = catalog.eval_runs[0];
    selectedEvalRunId = firstEvalRun.id;
    evalRunSelect.value = selectedEvalRunId;
    selectedDebugRunId = "";
    debugRunSelect.value = "";
    populateEvalTaskSelect();
    activeSource = "eval";
    await loadEvalTrace();
  } catch (e) {
    console.error(e);
    meta.textContent = "Error fetching run catalog";
    clearRunData("Failed to load run catalog.");
  }
}

async function loadDebugTrace() {
  const run = findDebugRun(selectedDebugRunId);
  if (!run) {
    currentTraceId = null;
    clearRunData("No trace selected.");
    return;
  }
  await loadTraceByRef({ traceId: run.trace_id, label: run.id });
}

async function loadEvalTrace() {
  const evalRun = findEvalRun(selectedEvalRunId);
  if (!evalRun || evalRun.tasks.length === 0) {
    currentTraceId = null;
    clearRunData("No eval trace selected.");
    return;
  }

  let task = evalRun.tasks.find((item) => item.id === selectedEvalTaskId) || null;
  if (!task) {
    task = evalRun.tasks[0];
    selectedEvalTaskId = task.id;
    evalTaskSelect.value = selectedEvalTaskId;
  }
  await loadTraceByRef({ traceId: task.trace_id, label: `${evalRun.id} / ${task.id}` });
}

async function loadTraceByRef(traceRef) {
  currentTraceId = traceRef.traceId;
  const traceToken = encodeURIComponent(traceRef.traceId);
  meta.textContent = "Loading...";
  treePanel.innerHTML = '<div class="hint">Loading trace...</div>';

  try {
    const checkRes = await fetch(`/traces/${traceToken}/derived/steps.jsonl`, { method: "HEAD" });
    if (!checkRes.ok) {
      meta.textContent = "Compiling trace...";
      const compileRes = await fetch(`/api/traces/${traceToken}/compile`, { method: "POST" });
      if (!compileRes.ok) {
        throw new Error(`Compilation failed (${compileRes.status})`);
      }
    }

    const metaRes = await fetch(`/traces/${traceToken}/meta.json`);
    if (metaRes.ok) {
      const metaJson = await metaRes.json();
      meta.textContent = `${traceRef.label} | ${metaJson.appId || "app"} | sdk ${metaJson.deviceSdkInt || "?"}`;
    } else {
      meta.textContent = `${traceRef.label}`;
    }

    const treeRes = await fetch(`/traces/${traceToken}/derived/agent_tree.json`);
    const stepsRes = await fetch(`/traces/${traceToken}/derived/steps.jsonl`);
    
    if (!treeRes.ok || !stepsRes.ok) {
        throw new Error("Failed to load derived artifacts");
    }

    const derivedTree = await treeRes.json();
    const derivedStepsText = await stepsRes.text();

    if (!derivedTree || !Array.isArray(derivedTree.sessions)) {
        sessions = [];
        treeError = "Invalid agent_tree.json.";
    } else {
        sessions = derivedTree.sessions;
        treeError = null;
    }
    sessionById = new Map(sessions.map((node) => [node.session_id, node]));

    steps = parseJsonLines(derivedStepsText);
    stepById = new Map(steps.map((step) => [step.step_id, step]));
    filteredSteps = steps.slice();

    selectedStepIndex = -1;
    selectedStepId = null;
    filterQuery = "";
    filterInput.value = "";

    applyFilters();
    
    // Auto-select first step
    if (filteredSteps.length > 0) {
      selectStep(0);
    } else {
      detailPanel.textContent = "Select a step.";
    }

  } catch (e) {
    console.error(e);
    meta.textContent = `Error: ${e.message}`;
    treePanel.textContent = e.message;
  }
}

// Helpers for detail view to get file URL
function getFileUrl(path) {
    if (!currentTraceId || !path) return null;
    // path is relative to trace dir, e.g. "derived/..." or "artifacts/..."
    return `/traces/${encodeURIComponent(currentTraceId)}/${path}`;
}

// Re-export or pass getFileUrl to detail render
function getFile(path) {
    // This signature matches old getFile but returns URL/Fetchable
    // For detail.js, it expects something it can .text() or used as img src.
    // We need to adapt detail.js to work with URLs.
    // Here we just return the URL, and detail.js update will handle it.
    return getFileUrl(path); 
}

function parseJson(text) {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function parseJsonLines(text) {
  return text
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .map(parseJson)
    .filter(Boolean);
}

function renderTree() {
  if (treeError) {
    treePanel.textContent = treeError;
    return;
  }
  if (!sessions.length) {
    treePanel.textContent = "No session metadata.";
    return;
  }

  const stepsBySession = buildStepsBySession(steps);
  const roots = sessions;
  treePanel.innerHTML = "";

  const list = document.createElement("div");
  list.className = "tree-list";
  let rendered = false;
  roots.forEach((root) => {
    if (appendSessionNode(root.session_id, list, 0, stepsBySession)) {
      rendered = true;
    }
  });
  if (!rendered) {
    treePanel.textContent = filterQuery ? "No steps match the filter." : "No steps found.";
    return;
  }
  treePanel.appendChild(list);
}

function buildStepsBySession(allSteps) {
  const map = new Map();
  allSteps.forEach((step) => {
    if (!step.session_id) return;
    if (!map.has(step.session_id)) map.set(step.session_id, []);
    map.get(step.session_id).push(step);
  });
  for (const list of map.values()) {
    list.sort((a, b) => {
      const aTs = Number(a.ts_start_ms ?? 0);
      const bTs = Number(b.ts_start_ms ?? 0);
      if (aTs !== bTs) return aTs - bTs;
      return Number(a.turn_number ?? 0) - Number(b.turn_number ?? 0);
    });
  }
  return map;
}

function appendSessionNode(sessionId, parent, depth, stepsBySession) {
  const session = sessionById.get(sessionId);
  const sessionLabel = session
    ? session.session_id
    : `[?] ${sessionId}`;

  if (filterQuery && !sessionHasVisibleSteps(sessionId, stepsBySession)) {
    return false;
  }

  const sessionRow = document.createElement("div");
  sessionRow.className = "tree-session";
  sessionRow.style.marginLeft = `${depth * 14}px`;
  sessionRow.innerHTML = `
    <div class="tree-title">${escapeHtml(sessionLabel)}</div>
    <div class="tree-meta">${escapeHtml(session?.status || "running")}</div>
  `;
  parent.appendChild(sessionRow);

  const sessionSteps = stepsBySession.get(sessionId) || [];
  sessionSteps.forEach((step) => {
    if (!stepMatchesFilter(step)) return;
    parent.appendChild(createStepNode(step, depth + 1));
  });
  return true;
}

function createStepNode(step, depth) {
  const content = buildStepContent(step, depth, step.step_id === selectedStepId);
  content.addEventListener("click", () => selectStepById(step.step_id));
  return content;
}

function buildStepContent(step, depth, isActive) {
  const item = document.createElement("div");
  item.className = "tree-step";
  if (isActive) item.classList.add("active");
  item.style.marginLeft = `${depth * 14}px`;

  const types = Array.isArray(step.event_types) ? step.event_types.join(" -> ") : "";
  const turn = step.turn_number != null ? `turn ${step.turn_number}` : "turn ?";
  item.innerHTML = `
    <div class="tree-head">
      <span>${escapeHtml(turn)}</span>
      <span class="code" title="Seq Start: ${step.seq_start}">#${escapeHtml(String(step.seq_start ?? "?"))}</span>
    </div>
    <div class="tree-meta-line">${escapeHtml(getToolSummary(step))}</div>
  `;
  return item;
}

function applyFilters() {
  filteredSteps = filterQuery ? steps.filter((step) => stepMatchesFilter(step)) : steps.slice();
  selectedStepIndex = filteredSteps.findIndex((step) => step.step_id === selectedStepId);
  renderTree();
  updateCounter();
}

function updateCounter() {
  if (!filteredSteps.length) {
    stepCounter.textContent = "0 / 0";
    return;
  }
  if (selectedStepIndex >= 0) {
    stepCounter.textContent = `${selectedStepIndex + 1} / ${filteredSteps.length}`;
  } else {
    stepCounter.textContent = `0 / ${filteredSteps.length}`;
  }
}

function stepMatchesFilter(step) {
  if (!filterQuery) return true;
  const toolNames = (step.tool?.calls || [])
    .map((call) => call?.data?.name)
    .filter(Boolean)
    .join(" ");
  const parts = [
    step.step_id,
    step.session_id,
    step.agent_role,
    step.turn_number != null ? String(step.turn_number) : "",
    Array.isArray(step.event_types) ? step.event_types.join(" ") : "",
    toolNames,
  ];
  return parts.join(" ").toLowerCase().includes(filterQuery);
}

function sessionHasVisibleSteps(sessionId, stepsBySession) {
  return (stepsBySession.get(sessionId) || []).some(stepMatchesFilter);
}

function moveSelection(delta) {
  if (!filteredSteps.length) return;
  if (selectedStepIndex < 0) {
    const index = delta > 0 ? 0 : filteredSteps.length - 1;
    selectStep(index);
    return;
  }
  const nextIndex = Math.min(
    Math.max(selectedStepIndex + delta, 0),
    filteredSteps.length - 1
  );
  selectStep(nextIndex);
}

function selectStep(index) {
  if (!filteredSteps.length) return;
  if (index < 0 || index >= filteredSteps.length) return;

  const step = filteredSteps[index];
  selectedStepIndex = index;
  selectedStepId = step.step_id;
  renderTree();
  updateCounter();
  renderDetailPanel({
    container: detailPanel,
    step,
    getFileUrl: getFile, // Pass the function that returns URL
    escapeHtml,
  });

  // Render summary to sidebar
  if (stepSummaryPanel) {
    stepSummaryPanel.innerHTML = "";
    stepSummaryPanel.appendChild(renderSummary(step, escapeHtml));
    stepSummaryPanel.style.display = "block";
  }
}

function selectStepById(stepId) {
  if (!stepId) return;
  if (!stepById.has(stepId)) return;
  const index = filteredSteps.findIndex((step) => step.step_id === stepId);
  if (index >= 0) {
    selectStep(index);
    return;
  }
  selectedStepId = stepId;
  selectedStepIndex = -1;
  renderTree();
  updateCounter();
  renderDetailPanel({
    container: detailPanel,
    step: stepById.get(stepId),
    getFileUrl: getFile,
    escapeHtml,
  });
}

function clearFilter() {
  filterQuery = "";
  filterInput.value = "";
}

function escapeHtml(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}


function getToolSummary(step) {
  const calls = step.tool?.calls || [];
  if (calls.length > 0) {
    return calls.map(c => c.data?.name || "unknown").join(", ");
  }
  return Array.isArray(step.event_types) ? step.event_types.join(" -> ") : "";
}
