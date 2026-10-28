import "./style.css";
import { marked } from "marked";
import DOMPurify from "dompurify";
import { sendChat } from "./chat-client.js";
import {
  migratePersonalTargets,
  personalSupplements,
} from "./personal-plan.js";
import { migrateReferenceTargets } from "./targets.js";
import { nutrients, foods, meals, initialState, localDate } from "./data.js";
import { totals, coverage, score, status, validState } from "./model.js";
import { startDictation, stopDictation } from "./dictation.js";
import { Preferences } from "@capacitor/preferences";
import { lookupBarcode } from "./open-food-facts.js";
import { loadFoodDatabase, searchDatabase } from "./food-database.js";
import { combineFoods, foodKind, sourceLabel } from "./library.js";
import { trendBuckets, monthlyNutrients, nutrientPatterns } from "./trends.js";

import {
  isNative,
  scanNative,
  startWebScanner,
  cameraError,
} from "./scanner.js";
const icons = {
  mic: '<rect x="9" y="2" width="6" height="13" rx="3"/><path d="M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8"/>',
  camera:
    '<rect x="3" y="6" width="18" height="15" rx="3"/><circle cx="12" cy="13" r="4"/><path d="m7 6 2-3h6l2 3"/>',
  chat: '<path d="M21 11a9 9 0 0 1-9 9H4l-2 2V11a9 9 0 0 1 19 0Z"/><path d="M7 10h10M7 14h6"/>',
  library: '<path d="M4 3h5v18H4zM12 3h4v18h-4zM18 5l3-1 4 16-3 1z"/>',
  leaf: '<path d="M20 4C10 3 3 7 5 15c2 8 14 6 15-11Z"/><path d="m5 20 10-10"/>',
  dashboard:
    '<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
  diary: '<path d="M5 3h14v18H5zM9 3v18M12 8h4M12 12h4"/>',
  nutrients: '<path d="M4 20V9m5 11V4m6 16v-7m5 7V7"/>',
  trends: '<path d="M3 17 9 11l4 4 8-10M16 5h5v5"/>',
  settings:
    '<path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="3"/><circle cx="15" cy="17" r="3"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  arrow: '<path d="m9 5 7 7-7 7"/>',
  back: '<path d="m15 5-7 7 7 7"/>',
  search: '<circle cx="10" cy="10" r="6"/><path d="m15 15 5 5"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  close: '<path d="m6 6 12 12M6 18 18 6"/>',
  drop: '<path d="M12 3C9 8 5 11 5 15a7 7 0 0 0 14 0c0-4-4-7-7-12Z"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l2 2m10 10 2 2M5 19l2-2M17 7l2-2"/>',
  download: '<path d="M12 3v12m-4-4 4 4 4-4M4 17v4h16v-4"/>',
  trash: '<path d="M3 6h18M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7m4-7v7"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10v1"/>',
  calendar:
    '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 3v4m10-4v4M3 11h18"/>',
};
const icon = (name, cls = "") =>
  `<svg class="icon ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name] || icons.leaf}</svg>`;
const esc = (s) =>
  String(s).replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const safeUrl = (s) => {
  try {
    const u = new URL(s);
    return ["https:", "http:"].includes(u.protocol) ? u.href : "";
  } catch {
    return "";
  }
};
const fmt = (n) =>
  Number(n.toFixed(n < 1 ? 2 : n < 10 ? 1 : 0)).toLocaleString();
let state,
  storageError = false,
  migrationChanged = false;
try {
  const raw = isNative()
    ? (await Preferences.get({ key: "nutrient-v1" })).value
    : localStorage.getItem("nutrient-v1");
  state = raw ? JSON.parse(raw) : initialState();
  migrationChanged = migrateReferenceTargets(state);
  migrationChanged =
    migratePersonalTargets(state, personalSupplements(nutrients)) ||
    migrationChanged;
  if (!validState(state)) throw Error("invalid");
} catch {
  state = initialState();
  storageError = true;
}
const referenceTargetsMigrated =
  migrationChanged || migrateReferenceTargets(state);
let scannerSession = null,
  scanGeneration = 0,
  database = [],
  databaseError = "",
  libraryFilter = "All",
  libraryQuery = "",
  trendMonths = 6,
  trendMetric = "score",
  builderItems = [],
  chatHistory = Array.isArray(state.chatHistory)
    ? state.chatHistory
        .filter(
          (m) =>
            ["user", "assistant"].includes(m.role) &&
            typeof m.content === "string",
        )
        .slice(-100)
    : [],
  agentReply = "",
  agentSources = [],
  agentTrace = [],
  agentAvailable = false,
  chatItems = [],
  chatText = "",
  chatError = "",
  chatStage = "idle",
  editingFood = null;
let selectedDate = localDate(),
  view = "Overview",
  filter = "All nutrients",
  search = "",
  meal = "Breakfast",
  selectedFood = null;
const modal = document.querySelector("#modal");
if (referenceTargetsMigrated) persist();
const catalog = () => [...foods, ...state.customFoods];
const day = () => state.days[selectedDate] || { entries: [], water: 0 };
const ensureDay = () =>
  (state.days[selectedDate] ??= { entries: [], water: 0 });
const values = () => totals(day().entries, catalog());
function toast(message) {
  const el = document.querySelector("#toast");
  el.textContent = message;
  el.classList.add("show");
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => el.classList.remove("show"), 3500);
}
function persist() {
  try {
    localStorage.setItem("nutrient-v1", JSON.stringify(state));
    if (isNative())
      Preferences.set({
        key: "nutrient-v1",
        value: JSON.stringify(state),
      }).catch(() => toast("Unable to save device data. Export a backup."));
  } catch {
    toast("Browser storage is unavailable. Export your data to keep a backup.");
  }
}
function stopScanner() {
  scanGeneration++;
  scannerSession?.stop();
  scannerSession = null;
}
function closeModal() {
  stopScanner();
  modal.close();
  modal.innerHTML = "";
}
function showModal(html) {
  stopScanner();
  modal.innerHTML = `<button class="icon-button modal-close" data-action="close" aria-label="Close dialog">${icon("close")}</button>${html}`;
  if (!modal.open) modal.showModal();
}
function ring(value, size = 148, cls = "") {
  return `<div class="score-ring ${cls}" style="--score:${value};--size:${size}px"><div><strong>${value}<span>/100</span></strong><small>NUTRIENT SCORE</small></div></div>`;
}
function dateLabel() {
  const d = new Date(selectedDate + "T12:00:00");
  return d.toLocaleDateString("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric",
  });
}
function shell() {
  stopDictation();
  document.body.dataset.view = view;
  const nav = [
    "Overview",
    "Food diary",
    "Chat",
    "Library",
    "Nutrients",
    "Trends",
  ];
  document.querySelector("#app").innerHTML = `
<aside class="sidebar"><a class="brand" href="#overview" aria-label="Nutrient home"><span class="brand-mark">${icon("leaf")}</span>nutrient<span class="brand-dot">.</span></a><nav class="desktop-nav" aria-label="Main navigation">${nav.map((n, i) => `<button class="nav-item ${view === n ? "active" : ""}" data-view="${n}">${icon(["dashboard", "diary", "chat", "library", "nutrients", "trends"][i])}<span>${n}</span>${view === n ? '<span class="nav-dot"></span>' : ""}</button>`).join("")}</nav><nav class="mobile-nav" aria-label="Main navigation">${[
    ["Overview", "Today", "dashboard"],
    ["Food diary", "Diary", "diary"],
    ["Chat", "Chat", "chat"],
    ["Trends", "Trends", "trends"],
  ]
    .map(
      ([target, label, glyph]) =>
        `<button class="nav-item ${view === target ? "active" : ""}" data-view="${target}" ${view === target ? 'aria-current="page"' : ""}>${icon(glyph)}<span>${label}</span></button>`,
    )
    .join(
      "",
    )}<button class="nav-item ${["Library", "Nutrients", "Settings"].includes(view) ? "active" : ""}" data-action="more" aria-haspopup="dialog"><span class="more-glyph" aria-hidden="true">•••</span><span>More</span></button></nav><div class="sidebar-bottom"><button class="nav-item ${view === "Settings" ? "active" : ""}" data-view="Settings">${icon("settings")} Targets & settings</button></div></aside>
<div class="main-shell ${view === "Chat" ? "chat-shell" : ""}"><main id="content">${view !== "Chat" ? `<div class="page-heading"><h1>${{ Overview: "Today", "Food diary": "Diary", Nutrients: "Nutrients", Trends: "Trends", Settings: "Settings", Library: "Library" }[view]}</h1>${view !== "Settings" ? '<button class="button primary" data-action="add">' + icon("plus") + " Log food</button>" : ""}</div>` : ""}
${!["Settings", "Chat"].includes(view) ? `<div class="day-toolbar"><div class="date-control"><button class="icon-button" data-action="prev" aria-label="Previous day">${icon("back")}</button><label class="date-picker">${icon("calendar")}<strong>${dateLabel()}</strong><input type="date" id="date" value="${selectedDate}" aria-label="Choose diary date"></label><button class="icon-button" data-action="next" aria-label="Next day">${icon("arrow")}</button>${selectedDate === localDate() ? '<span class="today-tag">Today</span>' : '<button class="text-button" data-action="today">Today</button>'}</div><div class="day-meta">${day().demo ? '<span class="demo-badge">Sample day</span><button class="text-button" data-action="clear-demo">Start fresh ' + icon("arrow") + "</button>" : `<span>${day().entries.length} foods logged</span>`}</div></div>` : ""}
<div id="view-content"></div></main></div>`;
  const area = document.querySelector("#view-content");
  area.innerHTML =
    view === "Overview"
      ? overview()
      : view === "Food diary"
        ? diary()
        : view === "Nutrients"
          ? nutrientPage()
          : view === "Trends"
            ? trends()
            : view === "Library"
              ? libraryPage()
              : view === "Chat"
                ? chatPage()
                : settings();
  if (view === "Chat") {
    const conversation = document.querySelector(".conversation");
    conversation.scrollTop = conversation.scrollHeight;
  }
}
function overview() {
  const v = values(),
    s = score(v, state.targets),
    met = nutrients.filter(
      (n) => n.group !== "Macros" && v[n.id] >= state.targets[n.id],
    ).length;
  const low = nutrients
    .filter((n) => n.group !== "Macros")
    .sort(
      (a, b) =>
        coverage(v[a.id], state.targets[a.id]) -
        coverage(v[b.id], state.targets[b.id]),
    )
    .slice(0, 3);
  return `
<section class="overview-grid"><article class="card score-card"><div class="card-kicker">NUTRIENT SCORE <button class="icon-button small" data-action="method" aria-label="About nutrient scores">${icon("info")}</button></div><div class="score-content">${ring(s, 174)}<div class="score-copy"><h2>${met} of ${nutrients.filter((n) => n.group !== "Macros").length} targets met</h2><button class="text-button" data-view="Nutrients">Explore your nutrients ${icon("arrow")}</button></div></div><div class="score-source-note">Food only: ${score(
    totals(
      day().entries.filter(
        (e) =>
          foodKind(catalog().find((f) => f.id === e.foodId)) !== "supplement",
      ),
      catalog(),
    ),
    state.targets,
  )}/100 · ${day().entries.filter((e) => foodKind(catalog().find((f) => f.id === e.foodId)) === "supplement").length} supplements logged</div><div class="score-card-foot"><span><i class="dot olive"></i>Daily coverage</span><span>${nutrients.filter((n) => n.group !== "Macros").length} nutrients · equally weighted</span></div></article>
<article class="card energy-card"><div class="card-kicker">ENERGY <span class="quiet">kcal</span></div><div class="energy-number">${fmt(v.calories)} <small>/ ${fmt(state.calorieTarget)}</small></div><div class="energy-track"><span style="width:${Math.min(100, (v.calories / state.calorieTarget) * 100)}%"></span></div><p class="energy-caption">${v.calories <= state.calorieTarget ? fmt(state.calorieTarget - v.calories) + " kcal to your target" : fmt(v.calories - state.calorieTarget) + " kcal above your target"}</p><div class="macro-list">${[
    "protein",
    "carbs",
    "fat",
  ]
    .map((id, i) => {
      let n = nutrients.find((x) => x.id === id);
      return `<div><span><i class="dot macro-${i}"></i>${id === "carbs" ? "Carbs" : n.name}</span><strong>${fmt(v[id])}<small> / ${state.targets[id]} g</small></strong><div class="tiny-track"><i class="macro-${i}" style="width:${coverage(v[id], state.targets[id])}%"></i></div></div>`;
    })
    .join("")}</div></article></section>
<div class="section-heading"><div><h2>Nutrients</h2></div><button class="text-button" data-view="Nutrients">See all nutrients ${icon("arrow")}</button></div><section class="category-grid">${categoryCard("Vitamins", "10 essential vitamins", "sun", v)}${categoryCard("Minerals", "6 everyday essentials", "nutrients", v)}${categoryCard("Other", "Fiber & omega-3", "leaf", v)}</section>
<section class="lower-grid"><article class="card diary-preview"><div class="section-heading compact"><h2>On your plate</h2><button class="text-button" data-view="Food diary">Open diary ${icon("arrow")}</button></div>${mealSummary()}<button class="add-line" data-action="add">${icon("plus")} Add food</button></article><div class="right-stack"><article class="opportunity-card"><div class="card-kicker">LOWEST RECORDED INTAKE ${icon("leaf")}</div><h2>Below target</h2><p>Your lowest coverage today. Tap a nutrient to see which foods contribute.</p><div class="gap-list">${low.map((n) => `<button data-nutrient="${n.id}"><span>${n.name}</span><strong>${Math.round(coverage(v[n.id], state.targets[n.id]))}% ${icon("arrow")}</strong></button>`).join("")}</div></article><article class="card water-card"><div><h3>${icon("drop")} Water</h3><p><strong>${day().water}</strong> / ${state.waterTarget} glasses <span>· 250 mL each</span></p></div><div class="water-actions"><button class="icon-button" data-action="water-minus" aria-label="Remove a glass of water" ${day().water === 0 ? "disabled" : ""}>−</button><button class="icon-button water-plus" data-action="water-plus" aria-label="Add a glass of water" ${day().water >= 30 ? "disabled" : ""}>${icon("plus")}</button></div></article></div></section>`;
}
function categoryCard(group, label, ico, v) {
  const s = score(v, state.targets, group),
    list = nutrients.filter((n) => n.group === group),
    met = list.filter((n) => v[n.id] >= state.targets[n.id]).length;
  return `<button class="card category-card" data-group="${group}"><div class="category-top"><span class="category-icon ${group.toLowerCase()}">${icon(ico)}</span><span class="mini-ring" style="--score:${s}">${s}<small>%</small></span></div><h3>${group === "Other" ? "Beyond the essentials" : group}</h3><p>${label}</p><div class="category-foot"><span>${met} of ${list.length} targets met</span>${icon("arrow")}</div></button>`;
}
function mealSummary() {
  return meals
    .map((m, i) => {
      const entries = day().entries.filter((e) => e.meal === m),
        t = totals(entries, catalog());
      return `<button class="meal-summary" data-meal-view="${m}"><span class="meal-icon">${["☀", "◒", "☾", "◈", "✧"][i]}</span><span class="meal-text"><strong>${m}</strong><small>${entries.length ? entries.map((e) => esc(catalog().find((f) => f.id === e.foodId)?.name || "Unknown food")).join(", ") : "No entries"}</small></span><span class="meal-kcal">${fmt(t.calories)}<small>kcal</small></span>${icon("arrow")}</button>`;
    })
    .join("");
}
function diary() {
  return `<div class="diary-layout"><div>${meals
    .map((m, i) => {
      const entries = day().entries.filter((e) => e.meal === m);
      return `<section class="card meal-section" id="meal-${m}"><div class="section-heading compact"><h2><span class="meal-symbol">${["☀", "◒", "☾", "◈", "✧"][i]}</span>${m}</h2><span class="quiet">${fmt(totals(entries, catalog()).calories)} kcal</span></div>${
        entries.length
          ? entries
              .map((e) => {
                const f = catalog().find((f) => f.id === e.foodId);
                return `<div class="food-row"><span class="food-emoji">${esc(f.emoji || "◈")}</span><button class="food-info" data-edit="${esc(e.id)}"><strong>${esc(f.name)}</strong><small>${e.quantity} × ${esc(f.serving)} · ${esc(sourceLabel(f))}</small></button><span class="food-calories">${fmt(f.calories * e.quantity)} <small>kcal</small></span><button class="icon-button delete-food" data-delete="${esc(e.id)}" aria-label="Remove ${esc(f.name)}">${icon("trash")}</button></div>`;
              })
              .join("")
          : '<p class="empty-meal">Nothing here yet. What’s on your plate?</p>'
      }<button class="add-line" data-add-meal="${m}">${icon("plus")} Add food to ${m.toLowerCase()}</button></section>`;
    })
    .join(
      "",
    )}</div><aside><article class="card diary-score">${ring(score(values(), state.targets), 150)}<h3>Your day, coming together.</h3><p>Every logged food adds to your nutrient picture.</p><button class="button secondary" data-view="Nutrients">View nutrient breakdown ${icon("arrow")}</button></article><p class="data-note">${icon("info")} Built-in foods use illustrative values. Add custom label data or look up a package barcode with Open Food Facts for real food entries.</p></aside></div>`;
}
function nutrientPage() {
  return `<div class="nutrient-header"><div class="tabs" role="group" aria-label="Nutrient group">${["All nutrients", "Vitamins", "Minerals", "Macros", "Other"].map((g) => `<button aria-pressed="${g === filter}" class="${g === filter ? "selected" : ""}" data-filter="${g}">${g}</button>`).join("")}</div><label class="search-input compact-search">${icon("search")}<input id="nutrient-search" placeholder="Find a nutrient" value="${esc(search)}" aria-label="Find a nutrient"></label></div><div class="card nutrient-table"><div class="table-head"><span>NUTRIENT</span><span>DAILY INTAKE / TARGET</span><span>COVERAGE</span><span>STATUS</span></div><div id="nutrient-rows">${nutrientRows()}</div></div><p class="data-note">${icon("info")} Scores measure progress toward your targets. Coverage is capped at 100% and does not assess excess intake or safety limits. Unknown food values contribute zero, so incomplete data may understate coverage.</p>`;
}
function nutrientRows() {
  const v = values();
  const list = nutrients.filter(
    (n) =>
      (filter === "All nutrients" || n.group === filter) &&
      n.name.toLowerCase().includes(search.toLowerCase()),
  );
  return list.length
    ? list
        .map((n) => {
          const raw = (v[n.id] / state.targets[n.id]) * 100,
            pct = Math.round(coverage(v[n.id], state.targets[n.id]));
          return `<button class="nutrient-row" data-nutrient="${n.id}"><span class="nutrient-name"><span class="element-icon">${n.icon}</span><span><strong>${n.name}</strong><small>${n.group}</small></span></span><span class="nutrient-amount"><strong>${fmt(v[n.id])}</strong> / ${fmt(state.targets[n.id])} ${n.unit}</span><span class="coverage-cell"><span class="coverage-track"><i class="${pct >= 100 ? "complete" : pct >= 70 ? "progress" : "low"}" style="width:${pct}%"></i></span><strong>${Math.round(raw)}%</strong></span><span class="status-label ${pct >= 100 ? "complete" : pct >= 70 ? "progress" : "low"}">${pct >= 100 ? icon("check") : ""}${status(pct)}</span></button>`;
        })
        .join("")
    : '<div class="empty-state"><h3>No nutrients found</h3><p>Try another name or choose a different group.</p></div>';
}
function trends() {
  const buckets = trendBuckets(
      state,
      catalog(),
      selectedDate,
      trendMonths,
      trendMetric,
    ),
    logged = buckets.reduce((sum, b) => sum + b.loggedDays, 0),
    avg = logged
      ? buckets.reduce((sum, b) => sum + (b.average || 0) * b.loggedDays, 0) /
        logged
      : 0,
    unit =
      trendMetric === "calories"
        ? "kcal"
        : trendMetric === "score"
          ? "/100"
          : "%";
  const firstMonth = buckets.findIndex((b) => b.loggedDays > 0);
  const plottedBuckets = buckets.slice(firstMonth < 0 ? -1 : firstMonth);
  const max =
    trendMetric === "calories"
      ? Math.max(state.calorieTarget, ...buckets.map((b) => b.average || 0))
      : Math.max(100, ...buckets.map((b) => b.average || 0));
  const patterns = nutrientPatterns(
    state,
    catalog(),
    selectedDate,
    trendMonths,
  );
  return `<div class="trend-controls"><div class="tabs" aria-label="Trend range">${[3, 6, 12].map((n) => `<button data-months="${n}" aria-pressed="${trendMonths === n}" class="${trendMonths === n ? "selected" : ""}">${n} months</button>`).join("")}</div><label>Show<select id="trend-metric"><option value="score">Nutrient score</option><option value="calories" ${trendMetric === "calories" ? "selected" : ""}>Energy</option>${nutrients.map((n) => `<option value="${n.id}" ${trendMetric === n.id ? "selected" : ""}>${n.name} coverage</option>`).join("")}</select></label></div>${intakeSummary(patterns)}<article class="card trend-chart"><div class="section-heading compact"><div><h2>${trendMetric === "score" ? "Nutrient score" : trendMetric === "calories" ? "Energy" : nutrients.find((n) => n.id === trendMetric).name + " coverage"} by month</h2><p>Monthly averages through ${dateLabel()}</p></div><span class="pill">${trendMonths} months</span></div><div class="monthly-chart"><div class="monthly-grid"><span>${Math.round(max)}</span><span>${Math.round(max / 2)}</span><span>0</span></div><div class="monthly-bars"><div class="monthly-target-line" style="top:calc(var(--plot-height) * ${1 - (trendMetric === "calories" ? state.calorieTarget : 100) / max})"><span>Target ${trendMetric === "calories" ? state.calorieTarget + " kcal" : "100%"}</span></div>${plottedBuckets.map((b) => `<button class="month-column" data-month-detail="${b.key}" aria-label="${b.label} ${b.year}: ${b.average === null ? "no logged days" : Math.round(b.average) + " " + unit}"><div class="month-bar-slot"><span>${b.average === null ? "—" : Math.round(b.average)}</span><div class="month-bar" style="height:${b.average === null ? 0 : Math.min(100, (b.average / max) * 100)}%"><i style="height:${b.average ? Math.min(100, ((b.foodOnly || 0) / b.average) * 100) : 0}%"></i></div></div><strong>${b.label}</strong><small>${b.year}</small><small>${b.loggedDays} days</small></button>`).join("")}</div></div><div class="chart-legend"><span><i class="dot olive"></i> Food contribution</span><span><i class="dot supplement-color"></i> With supplements</span></div></article><div class="section-heading"><div><h2>Coverage across nutrients</h2><p>Monthly average as a percentage of your target.</p></div></div><div class="card heatmap-card"><div class="heatmap-heading"><span>NUTRIENT</span>${buckets.map((b) => `<span>${b.label}</span>`).join("")}</div>${monthlyNutrients(
    state,
    catalog(),
    selectedDate,
    trendMonths,
  )
    .map(
      (n) =>
        `<div class="heatmap-row"><strong>${n.name}</strong>${n.months.map((b) => `<span class="heatmap-cell ${b.average === null ? "no-data" : ""}" style="--coverage:${b.average === null ? 0 : Math.min(1, Math.max(0.12, b.average / 100))}" title="${n.name}, ${b.label} ${b.year}: ${b.average === null ? "no data" : Math.round(b.average) + "%"}">${b.average === null ? "—" : Math.round(b.average)}</span>`).join("")}</div>`,
    )
    .join("")}</div>`;
}
function intakeSummary(patterns) {
  const rows = [...patterns.records].sort((a, b) => a.average - b.average);
  const row = (n) => {
    const actual = (state.targets[n.id] * n.average) / 100;
    const gap = Math.max(0, state.targets[n.id] - actual);
    const partial = n.completeDays < n.knownDays;
    return `<div class="intake-line"><span>${n.name}${partial ? "<small>Partial data</small>" : ""}</span><span><strong>${fmt(actual)} ${n.unit}</strong><small>Target ${fmt(state.targets[n.id])} ${n.unit}</small></span><span><strong>${gap > 0 ? fmt(gap) + " " + n.unit : "Met"}</strong><small>${Math.round(n.average)}% of target</small></span></div>`;
  };
  return `<section class="card intake-summary"><header><h2>Average intake</h2><span>${patterns.loggedDays} ${patterns.loggedDays === 1 ? "day" : "days"} logged · ${trendMonths} months</span></header>${rows.length ? `<div class="intake-line labels"><span>Nutrient</span><span>Daily average</span><span>Recorded gap</span></div>${rows.slice(0, 6).map(row).join("")}${rows.length > 6 ? `<details><summary>All nutrients</summary>${rows.slice(6).map(row).join("")}</details>` : ""}` : "<p>Log meals to see your averages and gaps.</p>"}</section>`;
}
function settings() {
  return `<section class="settings-grid"><article class="card settings-card"><p class="eyebrow">YOUR DAILY BASELINE</p><h2>Nutrition targets</h2><p class="subtitle">Micronutrient references: male, age 19–30 (RDA/AI). Custom targets stay editable. These are intake references, not deficiency-treatment doses.</p><form id="targets-form"><div class="target-fields"><label>Energy <span>kcal</span><input name="calorieTarget" type="number" min="1" max="20000" required value="${state.calorieTarget}"></label><label>Water <span>glasses</span><input name="waterTarget" type="number" min="1" max="30" step="1" required value="${state.waterTarget}"></label>${nutrients.map((n) => `<label>${n.name}<span>${n.unit}</span><input type="number" name="${n.id}" value="${state.targets[n.id]}" min="0.01" max="100000" step="any" required></label>`).join("")}</div><button class="button primary" type="submit">${icon("check")} Save targets</button></form></article><div class="right-stack"><article class="card settings-card"><p class="eyebrow">YOUR ASSISTANT</p><h2>Chat connection</h2><details><summary>Advanced connection</summary><form id="connection-form"><label class="field-label">Backend URL<input name="base" type="url" value="${esc(apiBase())}" placeholder="Same origin on web"></label><label class="field-label">App access token (optional)<input name="token" type="password" autocomplete="off" placeholder="Connection token"></label><button class="button secondary">Save connection</button></form></details></article><article class="card settings-card"><p class="eyebrow">ALWAYS YOURS</p><h2>Your data belongs to you.</h2><p>Food logs, targets, and your food library stay in this browser. Barcode lookups send only the product code to Open Food Facts. Export a backup to keep them safe or move them to another device.</p><button class="button secondary full" data-action="export">${icon("download")} Export all data</button><label class="button secondary full import-label">${icon("plus")} Import backup<input id="import-file" type="file" accept="application/json,.json"></label><p class="quiet small-copy">Import replaces this browser’s data after confirmation.</p></article><article class="card settings-card"><h2>A note on the numbers</h2><p>This is an independent, free tracker. Built-in foods contain illustrative values and are labeled as samples. Custom foods let you enter label values. Barcode lookup uses community data from <a href="https://world.openfoodfacts.org" target="_blank" rel="noopener noreferrer">Open Food Facts</a> (ODbL). Check imported values against the package; missing nutrients remain unknown.</p><p>The score tracks coverage, not clinical health, nutrient balance, or safe upper limits. Micronutrient defaults use male age 19–30 reference intakes. A vitamin D intake percentage does not measure your blood vitamin D status or replace a prescribed treatment target. <a href="https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables/reference-values-vitamins.html" target="_blank" rel="noopener noreferrer">Vitamin references</a> · <a href="https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables/reference-values-elements.html" target="_blank" rel="noopener noreferrer">Mineral references</a>.</p><button class="text-button" data-action="method">Read the scoring method ${icon("arrow")}</button></article><article class="card settings-card"><h2>Your food library</h2><p>${foods.length} sample foods · ${state.customFoods.length} saved foods</p><button class="button secondary" data-action="custom">${icon("plus")} Create a custom food</button></article></div></section>`;
}
function addDialog(m = "Breakfast") {
  meal = m;
  selectedFood = null;
  showModal(
    `<p class="eyebrow">SOMETHING NOURISHING</p><h2 id="modal-title">Add to your day.</h2><p class="modal-subtitle">Scan a package, search a database, or describe your meal.</p><div class="logging-shortcuts"><button class="button primary" data-action="scan">${icon("camera")} Scan barcode</button><button class="button secondary" data-action="open-chat">${icon("chat")} Describe a meal</button></div><label class="search-input">${icon("search")}<input id="food-search" placeholder="Search foods, e.g. avocado" aria-label="Search foods" autofocus></label><div class="meal-select"><label for="meal-select">Add to</label><select id="meal-select">${meals.map((x) => `<option ${x === m ? "selected" : ""}>${x}</option>`).join("")}</select><button class="text-button" data-action="custom">Create food ${icon("plus")}</button></div><details class="barcode-details"><summary>Have a package? Look up a barcode</summary><form id="barcode-form"><label for="barcode">Package barcode</label><div><input id="barcode" name="barcode" inputmode="numeric" pattern="[0-9]{8,14}" minlength="8" maxlength="14" placeholder="8–14 digits" required><button class="button secondary" type="submit">Look up</button></div><p>Lookup sends only the barcode to Open Food Facts. Community-supplied values may be incomplete.</p><p id="barcode-status" role="status"></p></form></details><p class="list-label">YOUR FOOD LIBRARY <span>Sample values · editable with custom foods</span></p><div id="food-results">${foodResults("")}</div><button class="button secondary full" data-action="database-search">Search USDA food database</button><div id="food-selection"></div>`,
  );
}
function foodResults(q) {
  const list = catalog().filter(
    (f) => !f.archived && f.name.toLowerCase().includes(q.toLowerCase()),
  );
  return list.length
    ? list
        .map(
          (f) =>
            `<button class="food-result ${selectedFood === f.id ? "chosen" : ""}" data-food="${esc(f.id)}"><span class="food-emoji">${esc(f.emoji || "◈")}</span><span><strong>${esc(f.name)}</strong><small>${esc(f.serving)} · ${esc(sourceLabel(f))}</small></span><span class="result-kcal">${fmt(f.calories)}<small>kcal</small></span>${icon("plus")}</button>`,
        )
        .join("")
    : '<div class="empty-state"><h3>No matches yet</h3><p>Create a custom food using your label.</p><button class="button secondary" data-action="custom">Create food</button></div>';
}
function selectFood(id) {
  selectedFood = id;
  const f = catalog().find((x) => x.id === id);
  document
    .querySelectorAll(".food-result")
    .forEach((el) => el.classList.toggle("chosen", el.dataset.food === id));
  document.querySelector("#food-selection").innerHTML =
    `<form id="add-form" class="selection-panel"><div><strong>${esc(f.name)}</strong><small>${esc(f.serving)} per serving</small></div><label>Servings<input type="number" name="quantity" min="0.01" max="100" step="any" value="1" required></label><button class="button primary">${icon("plus")} Log food</button></form>`;
}
function customDialog(kind = "food", food = null) {
  editingFood = food?.id || null;
  showModal(
    `<p class="eyebrow">YOUR LIBRARY</p><h2 id="modal-title">${food ? "Update this item." : kind === "supplement" ? "Add a supplement." : "Make it your own."}</h2><p class="modal-subtitle">Enter amounts per serving from the label or a sourced nutrition page. Leave unknown values blank. ${food ? "Updates create a new version so earlier logs keep their original values." : ""}</p><form id="custom-form"><input type="hidden" name="kind" value="${kind}"><div class="custom-basics"><label>${kind === "supplement" ? "Supplement" : "Food"} name<input name="name" maxlength="100" required value="${esc(food?.name || "")}" placeholder="${kind === "supplement" ? "e.g. Vitamin D3 · my brand" : "e.g. My breakfast smoothie"}"></label><label>Serving description<input name="serving" maxlength="100" required value="${esc(food?.serving || "")}" placeholder="${kind === "supplement" ? "e.g. 1 capsule" : "e.g. 1 glass · 300 mL"}"></label><label>Calories (kcal)<input name="calories" type="number" min="0" max="100000" step="any" required value="${food?.calories ?? (kind === "supplement" ? 0 : "")}"></label><label>Source URL (optional)<input name="sourceUrl" type="url" pattern="https?://.+" value="${esc(food?.sourceUrl || "")}" placeholder="https://manufacturer.com/nutrition"></label></div><details open><summary>Nutrients per serving · use the units shown</summary><div class="target-fields">${nutrients.map((n) => `<label>${n.name}<span>${n.unit}</span><input name="${n.id}" type="number" min="0" max="100000" step="any" placeholder="Unknown" value="${food?.values[n.id] ?? ""}"></label>`).join("")}</div></details><p class="data-note">${kind === "supplement" ? "Enter the actual nutrient amount, not the % Daily Value. Convert IU to the displayed units using the product label. This logs what you took; it does not recommend a dose." : "Values stay tied to this serving and source."}</p><button class="button primary full">${icon("check")} Save ${kind === "supplement" ? "supplement" : "food"}</button></form>`,
  );
}
function detailDialog(id) {
  const n = nutrients.find((x) => x.id === id),
    v = values(),
    pct = Math.round((v[id] / state.targets[id]) * 100);
  const contributions = day()
    .entries.map((e) => {
      const f = catalog().find((x) => x.id === e.foodId);
      return {
        name: f.name,
        value: (f.values[id] ?? 0) * e.quantity,
        known: f.values[id] != null,
        partial: f.partialNutrients?.includes(id),
        source: sourceLabel(f),
      };
    })
    .sort((a, b) => b.value - a.value);
  showModal(
    `<p class="eyebrow">YOUR NUTRIENT PICTURE</p><h2 id="modal-title">${n.name}</h2><div class="detail-total"><strong>${fmt(v[id])}<small> ${n.unit}</small></strong><span>of ${fmt(state.targets[id])} ${n.unit} target · ${pct}%</span></div><div class="detail-progress"><i style="width:${Math.min(pct, 100)}%"></i></div><h3>What’s contributing</h3><div class="contribution-list">${contributions.length ? contributions.map((f) => `<div><span>${esc(f.name)}<small class="contribution-source">${esc(f.source)}</small></span><strong>${f.known ? (f.partial ? "≥ " : "") + fmt(f.value) + " " + n.unit : "Unknown"}</strong></div>`).join("") : "<p>Log a food to see its contribution here.</p>"}</div><p class="data-note">Coverage is capped at 100% in your score. ${n.group === "Macros" ? "Macros are shown separately and excluded from the nutrient score." : "Each of the 18 scored nutrients has equal weight."}</p><button class="button secondary" data-action="target-settings">Edit your targets ${icon("arrow")}</button>`,
  );
}
function editEntry(id) {
  const e = day().entries.find((x) => x.id === id),
    f = catalog().find((x) => x.id === e.foodId);
  showModal(
    `<p class="eyebrow">FOOD DIARY</p><h2 id="modal-title">${esc(f.name)}</h2><p class="modal-subtitle">${esc(f.serving)} per serving</p><form id="edit-form" data-id="${esc(id)}" class="edit-form"><label>Servings<input name="quantity" type="number" min="0.01" max="100" step="any" value="${e.quantity}" required></label><label for="edit-meal">Meal</label><select id="edit-meal" name="meal">${meals.map((m) => `<option ${e.meal === m ? "selected" : ""}>${m}</option>`).join("")}</select><button class="button primary">Save changes</button></form>`,
  );
}
function method() {
  showModal(
    `<p class="eyebrow">A SCORE YOU CAN UNDERSTAND</p><h2 id="modal-title">Coverage, made clear.</h2><div class="method-formula">Daily score = average of 18 nutrient coverage percentages</div><p>For each vitamin, mineral, fiber, and omega-3, we divide your logged intake by your target and cap it at 100%. We average these 18 percentages and round to the nearest whole number.</p><p>All 18 nutrients have equal weight. Protein, carbohydrates, fat, and calories are tracked separately, so extra calories or protein cannot inflate this score.</p><p><strong>A coverage score is not a health score.</strong> It does not flag upper limits, excess intake, absorption, or nutrient interactions. Reaching 100% is not a reason to eat more of a nutrient.</p><p>Food entries are only as accurate as their data. Built-in foods use illustrative values. Unknown values count as zero contribution; check your labels or a verified food database.</p><button class="button primary full" data-action="close">Got it</button>`,
  );
}
function libraryPage() {
  const list = state.customFoods.filter(
    (f) =>
      !f.archived &&
      (libraryFilter === "All" || foodKind(f) === libraryFilter) &&
      f.name.toLowerCase().includes(libraryQuery.toLowerCase()),
  );
  return `<div class="library-toolbar"><div class="tabs">${[
    ["All", "All saved"],
    ["meal", "Meals"],
    ["food", "Foods"],
    ["supplement", "Supplements"],
  ]
    .map(
      ([id, label]) =>
        `<button data-library-filter="${id}" class="${libraryFilter === id ? "selected" : ""}" aria-pressed="${libraryFilter === id}">${label}</button>`,
    )
    .join(
      "",
    )}</div><div class="library-actions"><button class="button secondary" data-action="supplement">Add supplement</button><button class="button primary" data-action="new-meal">${icon("plus")} Create meal</button></div></div><label class="search-input library-search">${icon("search")}<input id="library-search" value="${esc(libraryQuery)}" placeholder="Find something you’ve saved" aria-label="Search saved library"></label><div id="library-results" class="library-grid">${libraryCards(list)}</div><article class="card database-callout"><div><p class="eyebrow">MORE THAN YOUR LIBRARY</p><h2>Start with a food database.</h2><p>Search 7,793 USDA foods, including 312 historical fast-food entries, or scan a package. Save matches once and reuse them.</p></div><button class="button secondary" data-action="database-search">Search foods ${icon("search")}</button></article>`;
}
function libraryCards(list) {
  return list.length
    ? list
        .map(
          (f) =>
            `<article class="card library-card"><div class="library-card-top"><span class="element-icon">${foodKind(f) === "supplement" ? "✧" : foodKind(f) === "meal" ? "◈" : "↟"}</span><span class="pill">${foodKind(f)}</span></div><h3>${esc(f.name)}</h3><p>${esc(f.serving)} · ${fmt(f.calories)} kcal</p><p class="quiet">${esc(sourceLabel(f))}${f.components ? " · " + f.components.length + " components" : ""}</p><div class="library-card-actions"><button class="button primary" data-library-log="${esc(f.id)}">${icon("plus")} Log</button>${foodKind(f) !== "meal" ? `<button class="icon-button" data-library-edit="${esc(f.id)}" aria-label="Edit ${esc(f.name)}">${icon("settings")}</button>` : `<button class="text-button" data-recipe-detail="${esc(f.id)}">Components</button>`}<button class="icon-button" data-library-archive="${esc(f.id)}" aria-label="Archive ${esc(f.name)}">${icon("trash")}</button></div></article>`,
        )
        .join("")
    : `<div class="empty-state card"><h3>A home for your usuals.</h3><p>Save a breakfast, add your supplement label, or find a food in the database. It will be here next time.</p><button class="button secondary" data-action="custom">Create your first item</button></div>`;
}
function databaseDialog() {
  const q = document.querySelector("#food-search")?.value || "";
  showModal(
    `<p class="eyebrow">DATABASE FIRST</p><h2 id="modal-title">Find the food.</h2><p class="modal-subtitle">USDA SR Legacy · 7,793 foods · per 100 g. This historical release is not a current restaurant menu.</p><label class="search-input">${icon("search")}<input id="database-query" value="${esc(q)}" placeholder="e.g. chicken breast cooked, Subway" aria-label="Search USDA database" autofocus></label><label class="checkbox-line"><input id="restaurant-only" type="checkbox"> Historical fast-food entries only</label><div id="database-results" class="database-results"></div><p class="data-note">Missing nutrients remain unknown. For an absent food or current restaurant order, describe it in chat to resolve its components.</p><button class="text-button" data-action="open-chat">Describe a meal ${icon("arrow")}</button>`,
  );
  renderDatabaseResults();
}
async function renderDatabaseResults() {
  const area = document.querySelector("#database-results");
  if (!area) return;
  if (!database.length) {
    area.innerHTML =
      '<p class="loading-copy">Loading the bundled USDA database…</p>';
    try {
      database = await loadFoodDatabase();
    } catch (e) {
      area.innerHTML = `<p class="data-note">${esc(e.message)}</p><button class="button secondary" data-action="retry-database">Retry</button>`;
      return;
    }
  }
  if (!area.isConnected) return;
  const q = document.querySelector("#database-query").value;
  const list = searchDatabase(database, q, {
    restaurantOnly: document.querySelector("#restaurant-only").checked,
  });
  area.innerHTML = list.length
    ? list
        .map(
          (f) =>
            `<button class="food-result" data-database-food="${f.id}"><span class="element-icon">U</span><span><strong>${esc(f.name)}</strong><small>USDA SR Legacy · 100 g · ${nutrients.filter((n) => f.values[n.id] != null).length}/${nutrients.length} nutrients reported</small></span><span class="result-kcal">${fmt(f.calories)}<small>kcal</small></span>${icon("plus")}</button>`,
        )
        .join("")
    : '<div class="empty-state"><h3>No matching food in this database.</h3><p>Try another description, or use chat to clarify the meal and its sources.</p><button class="button secondary" data-action="open-chat">Describe this food</button></div>';
}
function rememberFood(f) {
  if (!state.customFoods.some((x) => x.id === f.id))
    state.customFoods.push(structuredClone(f));
}
function chooseLibraryFood(f) {
  rememberFood(f);
  persist();
  addDialog(
    foodKind(f) === "supplement"
      ? "Supplements"
      : meal === "Supplements"
        ? "Breakfast"
        : meal,
  );
  document.querySelector("#food-search").value = f.name;
  document.querySelector("#food-results").innerHTML = foodResults(f.name);
  selectFood(f.id);
}
async function acceptBarcode(code) {
  if (!/^\d{8,14}$/.test(code))
    throw Error(
      "This is not a supported package barcode. Scan an EAN or UPC barcode.",
    );
  const f = await lookupBarcode(code);
  chooseLibraryFood(f);
  toast("Barcode found. Confirm your portion before logging.");
}
async function scanDialog() {
  showModal(
    `<p class="eyebrow">POINT. SCAN. NO TYPING.</p><h2 id="modal-title">Scan a package.</h2><p class="modal-subtitle">Center the UPC or EAN barcode. Only the decoded product code is sent to Open Food Facts; camera frames stay on your device.</p><div class="scanner-frame"><video id="scanner-video" playsinline muted aria-label="Live barcode camera preview"></video><div class="scan-guide"></div></div><p id="scanner-status" role="status">Starting your camera…</p><button class="button secondary full" data-action="manual-barcode">Enter barcode manually</button>`,
  );
  const generation = scanGeneration;
  const statusEl = document.querySelector("#scanner-status");
  const fail = (e) => {
    if (statusEl.isConnected) statusEl.textContent = cameraError(e);
  };
  const found = async (code) => {
    if (!statusEl.isConnected) return;
    statusEl.textContent = "Barcode detected. Finding its nutrition facts…";
    try {
      await acceptBarcode(code);
    } catch (e) {
      if (statusEl.isConnected) statusEl.textContent = e.message;
    }
  };
  if (isNative()) {
    try {
      const code = await scanNative();
      if (generation === scanGeneration && code) await found(code);
    } catch (e) {
      fail(e);
    }
    return;
  }
  try {
    const session = await startWebScanner(
      document.querySelector("#scanner-video"),
      found,
      fail,
    );
    if (generation !== scanGeneration) {
      session.stop();
      return;
    }
    scannerSession = session;
    await session.ready;
    if (
      statusEl.isConnected &&
      statusEl.textContent === "Starting your camera…"
    )
      statusEl.textContent = "Looking for a barcode. Hold the package steady.";
  } catch (e) {
    fail(e);
  }
}
function builderDialog() {
  builderItems = [];
  showModal(
    `<p class="eyebrow">A MEAL TO COME BACK TO</p><h2 id="modal-title">Build your usual.</h2><p class="modal-subtitle">Combine saved foods or database components. Quantities are multiples of each item’s listed serving.</p><form id="builder-form"><label class="field-label">Meal name<input name="name" required maxlength="100" placeholder="e.g. My weekday breakfast"></label><label class="search-input">${icon("search")}<input id="builder-search" placeholder="Find a component" aria-label="Search meal components"></label><div id="builder-matches" class="builder-matches"></div><div id="builder-items"></div><button class="button primary full">Save meal to library</button></form>`,
  );
  renderBuilderMatches("");
}
async function renderBuilderMatches(q) {
  const el = document.querySelector("#builder-matches");
  if (!el) return;
  try {
    if (!database.length) database = await loadFoodDatabase();
  } catch {}
  if (!el.isConnected) return;
  const list = [
    ...state.customFoods.filter(
      (f) =>
        !f.archived && foodKind(f) !== "supplement" && foodKind(f) !== "meal",
    ),
    ...database,
  ];
  const matches = searchDatabase(list, q, { limit: 8 });
  el.innerHTML =
    matches
      .map(
        (f) =>
          `<button type="button" class="food-result" data-builder-add="${esc(f.id)}"><span><strong>${esc(f.name)}</strong><small>${esc(f.serving)} · ${esc(sourceLabel(f))}</small></span>${icon("plus")}</button>`,
      )
      .join("") ||
    '<p class="data-note">No match. Create a custom food with label values first, then add it here.</p>';
}
function renderBuilderItems() {
  document.querySelector("#builder-items").innerHTML = builderItems
    .map(
      (x, i) =>
        `<div class="builder-item"><span><strong>${esc(x.food.name)}</strong><small>${esc(x.food.serving)} per serving</small></span><label>Servings<input type="number" min="0.01" max="100" step="any" value="${x.quantity}" data-builder-quantity="${i}" required></label><button class="icon-button" type="button" data-builder-remove="${i}" aria-label="Remove component">${icon("close")}</button></div>`,
    )
    .join("");
}
function chatPage() {
  const render = (text) =>
    DOMPurify.sanitize(marked.parse(text, { breaks: true }));
  return `<section class="chat-layout"><article class="chat-panel"><header class="chat-heading"><h1>Chat</h1><button class="icon-button" data-action="database-search" aria-label="Search foods">${icon("search")}</button></header><div class="conversation" role="log" aria-label="Conversation" aria-live="polite">${chatHistory.length ? chatHistory.map((m) => `<div class="chat-bubble ${m.role === "user" ? "user-bubble" : "assistant-bubble"}">${render(m.content)}</div>`).join("") : '<div class="chat-empty">What did you eat?</div>'}<div id="chat-step">${chatStep()}</div></div><form id="chat-form" class="chat-composer"><div class="composer-input"><button type="button" class="icon-button" data-action="scan" aria-label="Scan a barcode">${icon("camera")}</button><label class="sr-only" for="chat-input">Message</label><textarea id="chat-input" name="message" rows="1" required maxlength="6000" placeholder="Message…">${esc(chatText)}</textarea><button class="icon-button" type="button" data-action="dictate" aria-label="Dictate a meal">${icon("mic")}</button><button class="button primary send-button" type="submit" aria-label="Send message" ${chatStage === "loading" ? "disabled" : ""}>↑</button></div></form></article></section>`;
}
function chatStep() {
  if (chatError)
    return `<div class="chat-bubble assistant-bubble"><p>${esc(chatError)}</p><div class="fallback-actions"><button class="text-button" data-action="retry-chat">Retry</button><button class="text-button" data-view="Settings">Connection</button></div></div>`;
  if (chatStage === "loading")
    return '<div class="chat-bubble assistant-bubble chat-loading" role="status">Looking up your meal…</div>';
  if (chatStage === "complete")
    return '<div class="chat-bubble assistant-bubble"><p>Logged. Your diary and today’s progress are updated.</p><button class="text-button" data-view="Food diary">Open diary</button></div>';
  if (chatStage === "review") return chatReview();
  return "";
}
function chatReview() {
  const combined = combineFoods("Meal preview", chatItems, "preview");
  return `<div class="chat-bubble assistant-bubble"><h3>Review your meal.</h3><div class="review-items">${chatItems.map((x) => `<div><strong>${esc(x.food.name)}</strong><span>${fmt(x.quantity)} × ${esc(x.food.serving)}</span><small>${esc(sourceLabel(x.food))}${safeUrl(x.food.sourceUrl) ? ` · <a href="${esc(safeUrl(x.food.sourceUrl))}" target="_blank" rel="noopener noreferrer">View source ↗</a>` : ""}</small></div>`).join("")}</div><div class="review-total"><strong>${fmt(combined.calories)} kcal</strong><span>${fmt(combined.values.protein || 0)} g protein · ${fmt(combined.values.carbs || 0)} g carbs</span></div><p class="review-data-count">${nutrients.length - combined.partialNutrients.length}/${nutrients.length} nutrients fully reported</p><form id="chat-confirm"><label class="field-label">Log to<select name="meal">${meals.map((m) => `<option ${meal === m ? "selected" : ""}>${m}</option>`).join("")}</select></label><details class="save-meal-details"><summary>Save this meal</summary><label class="field-label">Meal name<input name="name" maxlength="100" placeholder="e.g. My usual breakfast"></label></details><p class="quiet">For ${dateLabel()}</p><button class="button primary full">Confirm & log meal</button></form></div>`;
}
function refreshChat() {
  const step = document.querySelector("#chat-step");
  if (step) step.innerHTML = chatStep();
}
function apiBase() {
  return (
    localStorage.getItem("nutrient-api-base") ||
    (isNative()
      ? "https://nutrient-kggreco11.blue-brush-8571.chatgpt.site"
      : "")
  );
}
async function beginChat(message, retry = false) {
  await stopDictation();
  if (chatStage === "loading") return;
  if (retry) {
    const index = chatHistory.findLastIndex((m) => m.role === "user");
    chatHistory = chatHistory.slice(0, index + 1);
  } else chatHistory.push({ role: "user", content: message });
  chatHistory = chatHistory.slice(-100);
  state.chatHistory = chatHistory;
  chatText = "";
  persist();
  chatItems = [];
  chatError = "";
  chatStage = "loading";
  shell();
  try {
    const result = await sendChat(
      {
        messages: chatHistory.slice(-12),
        savedFoods: state.customFoods.filter((f) => !f.archived),
      },
      {
        base: apiBase(),
        token: sessionStorage.getItem("nutrient-api-token") || "",
      },
    );
    agentSources = result.sources || [];
    agentTrace = result.trace || [];
    chatHistory.push({ role: "assistant", content: result.reply });
    state.chatHistory = chatHistory;
    persist();
    if (result.proposal?.length) {
      chatItems = result.proposal;
      chatStage = "review";
    } else chatStage = "idle";
  } catch (error) {
    chatError =
      error.name === "TimeoutError"
        ? "This lookup took too long. Try a smaller request or search the food database directly."
        : error.message;
    chatStage = "idle";
  }
  if (view === "Chat") shell();
}
function monthDetail(key) {
  const entries = Object.entries(state.days)
    .filter(
      ([date, d]) =>
        date.startsWith(key) &&
        date <= selectedDate &&
        d.entries.some((e) => !e.id.startsWith("sample-")),
    )
    .sort(([a], [b]) => a.localeCompare(b));
  showModal(
    `<p class="eyebrow">YOUR MONTH IN DETAIL</p><h2 id="modal-title">${new Date(key + "-01T12:00:00").toLocaleDateString("en-US", { month: "long", year: "numeric" })}</h2><p class="modal-subtitle">Choose a logged day to see its diary.</p>${
      entries
        .map(
          ([date, d]) =>
            `<button class="food-result" data-open-day="${date}"><span><strong>${date}</strong><small>${d.entries.filter((e) => !e.id.startsWith("sample-")).length} real entries</small></span><span>${score(
              totals(
                d.entries.filter((e) => !e.id.startsWith("sample-")),
                catalog(),
              ),
              state.targets,
            )}/100</span>${icon("arrow")}</button>`,
        )
        .join("") ||
      '<p class="empty-state">No real food or supplement entries this month.</p>'
    }`,
  );
}

document.addEventListener("click", (event) => {
  const el = event.target.closest("button,[data-view],a.brand");
  if (!el) return;
  if (el.matches("a.brand")) {
    event.preventDefault();
    view = "Overview";
    shell();
    return;
  }
  if (el.dataset.view) {
    if (modal.open) closeModal();
    view = el.dataset.view;
    shell();
    window.scrollTo(0, 0);
    return;
  }
  if (el.dataset.nutrient) {
    detailDialog(el.dataset.nutrient);
    return;
  }
  if (el.dataset.group) {
    view = "Nutrients";
    filter = el.dataset.group;
    search = "";
    shell();
    return;
  }
  if (el.dataset.filter) {
    filter = el.dataset.filter;
    shell();
    return;
  }
  if (el.dataset.food) {
    selectFood(el.dataset.food);
    return;
  }
  if (el.dataset.addMeal) {
    addDialog(el.dataset.addMeal);
    return;
  }
  if (el.dataset.mealView) {
    view = "Food diary";
    shell();
    document
      .getElementById("meal-" + el.dataset.mealView)
      ?.scrollIntoView({ block: "center" });
    return;
  }
  if (el.dataset.edit) {
    editEntry(el.dataset.edit);
    return;
  }
  if (el.dataset.delete) {
    ensureDay().entries = day().entries.filter(
      (e) => e.id !== el.dataset.delete,
    );
    persist();
    shell();
    toast("Food removed from your diary.");
    return;
  }
  if (el.dataset.date) {
    selectedDate = el.dataset.date;
    view = "Overview";
    shell();
    return;
  }
  const action = el.dataset.action;
  if (action === "close") closeModal();
  if (action === "add") addDialog();
  if (action === "retry-chat") {
    const last = chatHistory.filter((m) => m.role === "user").at(-1);
    if (last) beginChat(last.content, true);
  }
  if (action === "custom") customDialog();
  if (action === "supplement") customDialog("supplement");
  if (action === "scan") scanDialog();
  if (action === "database-search") databaseDialog();
  if (action === "open-chat") {
    closeModal();
    view = "Chat";
    shell();
  }
  if (action === "new-meal") builderDialog();
  if (action === "more")
    showModal(
      `<h2 id="modal-title">More</h2><nav class="more-menu" aria-label="More destinations"><button class="button secondary" data-view="Library">${icon("library")} Library ${icon("arrow")}</button><button class="button secondary" data-view="Nutrients">${icon("nutrients")} Nutrients ${icon("arrow")}</button><button class="button secondary" data-view="Settings">${icon("settings")} Targets & settings ${icon("arrow")}</button></nav>`,
    );
  if (action === "method") method();
  if (action === "target-settings") {
    closeModal();
    view = "Settings";
    shell();
  }
  if (action === "prev" || action === "next") {
    const d = new Date(selectedDate + "T12:00:00");
    d.setDate(d.getDate() + (action === "next" ? 1 : -1));
    selectedDate = localDate(d);
    shell();
  }
  if (action === "today") {
    selectedDate = localDate();
    shell();
  }
  if (action === "water-plus" || action === "water-minus") {
    const d = ensureDay();
    d.water = Math.max(
      0,
      Math.min(30, d.water + (action === "water-plus" ? 1 : -1)),
    );
    persist();
    shell();
  }
  if (action === "clear-demo")
    showModal(
      `<p class="eyebrow">A CLEAN PLATE</p><h2 id="modal-title">Start your own diary?</h2><p>This removes the sample entries and water for ${dateLabel()}. Your targets and custom foods stay with you.</p><div class="modal-actions"><button class="button secondary" data-action="close">Keep exploring</button><button class="button primary" data-action="confirm-clear">Start fresh</button></div>`,
    );
  if (action === "confirm-clear") {
    state.days[selectedDate] = { entries: [], water: 0 };
    persist();
    closeModal();
    shell();
    toast("A fresh start. Log your first food.");
  }
  if (action === "export") {
    const url = URL.createObjectURL(
      new Blob([JSON.stringify(state, null, 2)], { type: "application/json" }),
    );
    const a = document.createElement("a");
    a.href = url;
    a.download = `nutrient-backup-${localDate()}.json`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    toast("Your backup has been exported.");
  }
});
document.addEventListener("input", (e) => {
  if (e.target.id === "food-search")
    document.querySelector("#food-results").innerHTML = foodResults(
      e.target.value,
    );
  if (e.target.id === "nutrient-search") {
    search = e.target.value;
    document.querySelector("#nutrient-rows").innerHTML = nutrientRows();
  }
});
document.addEventListener("change", async (e) => {
  if (e.target.id === "date" && e.target.value) {
    selectedDate = e.target.value;
    shell();
  }
  if (e.target.id === "meal-select") meal = e.target.value;
  if (e.target.id === "import-file") {
    const file = e.target.files[0];
    if (!file) return;
    if (file.size > 5000000) {
      toast("Please choose a backup smaller than 5 MB.");
      return;
    }
    try {
      const imported = JSON.parse(await file.text());
      migrateReferenceTargets(imported);
      migratePersonalTargets(imported, personalSupplements(nutrients));
      if (!validState(imported)) throw Error();
      showModal(
        `<p class="eyebrow">YOUR DATA</p><h2 id="modal-title">Restore this backup?</h2><p>This will replace your current food diary, targets, and custom foods with ${Object.keys(imported.days).length} days from this backup.</p><div class="modal-actions"><button class="button secondary" data-action="close">Cancel</button><button id="confirm-import" class="button primary">Replace & restore</button></div>`,
      );
      document.querySelector("#confirm-import").onclick = () => {
        state = imported;
        migrateReferenceTargets(state);
        persist();
        closeModal();
        shell();
        toast("Your backup has been restored.");
      };
    } catch {
      toast(
        "This file is not a valid Nutrient backup. Your data was not changed.",
      );
    }
  }
});
document.addEventListener("submit", async (e) => {
  e.preventDefault();
  const form = e.target,
    data = new FormData(form);
  if (form.id === "barcode-form") {
    const button = form.querySelector("button"),
      statusEl = form.querySelector("#barcode-status");
    button.disabled = true;
    button.textContent = "Looking up…";
    statusEl.textContent = "";
    try {
      const f = await lookupBarcode(data.get("barcode").trim());
      if (!state.customFoods.some((x) => x.id === f.id))
        state.customFoods.push(f);
      persist();
      if (!form.isConnected) return;
      addDialog(meal);
      document.querySelector("#food-search").value = f.name;
      document.querySelector("#food-results").innerHTML = foodResults(f.name);
      selectFood(f.id);
      toast("Product found. Values are per 100 g. Check against your label.");
    } catch (error) {
      if (!form.isConnected) return;
      statusEl.textContent =
        error.name === "TimeoutError"
          ? "Lookup timed out. Please try again."
          : error instanceof TypeError
            ? "Unable to reach Open Food Facts. Check your connection or create a custom food."
            : error.message;
      button.disabled = false;
      button.textContent = "Look up";
    }
    return;
  }
  if (form.id === "add-form") {
    const q = Number(data.get("quantity"));
    if (!(q > 0 && q <= 100 && selectedFood)) return;
    ensureDay().entries.push({
      id: crypto.randomUUID(),
      foodId: selectedFood,
      meal,
      quantity: q,
    });
    persist();
    closeModal();
    shell();
    toast("Food added. Your nutrient picture is updated.");
  }
  if (form.id === "edit-form") {
    const entry = day().entries.find((x) => x.id === form.dataset.id);
    entry.quantity = Number(data.get("quantity"));
    entry.meal = data.get("meal");
    persist();
    closeModal();
    shell();
    toast("Food entry updated.");
  }
  if (form.id === "targets-form") {
    state.calorieTarget = Number(data.get("calorieTarget"));
    state.waterTarget = Number(data.get("waterTarget"));
    for (const n of nutrients) state.targets[n.id] = Number(data.get(n.id));
    persist();
    shell();
    toast("Targets saved. Your scores now reflect your goals.");
  }
  if (form.id === "custom-form") {
    const kind = data.get("kind") || "food";
    const f = {
      id: "custom-" + crypto.randomUUID(),
      kind,
      source:
        kind === "supplement"
          ? "Supplement label"
          : data.get("sourceUrl")
            ? "User-provided source"
            : "Custom label",
      sourceUrl: data.get("sourceUrl") || null,
      name: data.get("name").trim(),
      serving: data.get("serving").trim(),
      emoji: "◈",
      calories: Number(data.get("calories")),
      values: Object.fromEntries(
        nutrients.map((n) => [
          n.id,
          data.get(n.id) === "" ? null : Number(data.get(n.id)),
        ]),
      ),
    };
    if (!f.name || !f.serving) {
      toast("Enter a food name and serving description.");
      return;
    }
    if (editingFood) {
      const previous = state.customFoods.find((x) => x.id === editingFood);
      if (previous) previous.archived = true;
      editingFood = null;
    }
    state.customFoods.push(f);
    persist();
    addDialog(
      kind === "supplement"
        ? "Supplements"
        : meal === "Supplements"
          ? "Breakfast"
          : meal,
    );
    document.querySelector("#food-search").value = f.name;
    document.querySelector("#food-results").innerHTML = foodResults(f.name);
    selectFood(f.id);
    toast("Custom food saved. Choose your servings to log it.");
  }
});
modal.addEventListener("click", (e) => {
  if (e.target === modal) {
    const r = modal.getBoundingClientRect();
    if (
      e.clientX < r.left ||
      e.clientX > r.right ||
      e.clientY < r.top ||
      e.clientY > r.bottom
    )
      closeModal();
  }
});
document.addEventListener("click", async (event) => {
  const el = event.target.closest("button");
  if (!el) return;
  if (el.dataset.libraryFilter) {
    libraryFilter = el.dataset.libraryFilter;
    shell();
  }
  if (el.dataset.libraryLog) {
    chooseLibraryFood(catalog().find((f) => f.id === el.dataset.libraryLog));
  }
  if (el.dataset.libraryEdit) {
    const f = catalog().find((f) => f.id === el.dataset.libraryEdit);
    customDialog(foodKind(f), f);
  }
  if (el.dataset.libraryArchive) {
    const f = state.customFoods.find((f) => f.id === el.dataset.libraryArchive);
    f.archived = true;
    persist();
    shell();
    toast("Archived from your library. Previous diary entries are preserved.");
  }
  if (el.dataset.recipeDetail) {
    const f = catalog().find((f) => f.id === el.dataset.recipeDetail);
    showModal(
      `<p class="eyebrow">SAVED MEAL</p><h2 id="modal-title">${esc(f.name)}</h2><div class="review-items">${(f.components || []).map((c) => `<div><strong>${esc(c.name)}</strong><span>${fmt(c.quantity)} × ${esc(c.serving)}</span><small>${esc(c.source)}</small></div>`).join("")}</div><p class="data-note">Saved meals retain the nutrition values from the time they were created. ${f.partialNutrients?.length || 0} nutrient fields have incomplete source data.</p>`,
    );
  }
  if (el.dataset.databaseFood) {
    const f = database.find((f) => f.id === el.dataset.databaseFood);
    chooseLibraryFood(f);
  }
  if (el.dataset.builderAdd) {
    const f = [...catalog(), ...database].find(
      (f) => f.id === el.dataset.builderAdd,
    );
    builderItems.push({ food: f, quantity: 1 });
    renderBuilderItems();
  }
  if (el.dataset.builderRemove !== undefined) {
    builderItems.splice(Number(el.dataset.builderRemove), 1);
    renderBuilderItems();
  }
  if (el.dataset.months) {
    trendMonths = Number(el.dataset.months);
    shell();
  }
  if (el.dataset.monthDetail) monthDetail(el.dataset.monthDetail);
  if (el.dataset.openDay) {
    selectedDate = el.dataset.openDay;
    view = "Food diary";
    closeModal();
    shell();
  }
  const action = el.dataset.action;
  if (action === "dictate") {
    if (el.dataset.listening === "true") {
      await stopDictation();
      return;
    }
    try {
      await startDictation(
        (text) => {
          const input = document.querySelector("#chat-input");
          if (input) input.value = text;
          chatText = text;
        },
        (listening) => {
          el.dataset.listening = String(listening);
          el.textContent = listening ? "■" : "◉";
          el.setAttribute(
            "aria-label",
            listening ? "Stop dictation" : "Dictate a meal",
          );
        },
      );
    } catch (error) {
      toast(error.message);
    }
  }
  if (action === "manual-barcode") {
    addDialog(meal);
    document.querySelector(".barcode-details").open = true;
    document.querySelector("#barcode").focus();
  }
  if (action === "retry-database") renderDatabaseResults();
});
document.addEventListener("input", (e) => {
  if (e.target.id === "chat-input") {
    chatText = e.target.value;
    e.target.style.height = "auto";
    e.target.style.height = Math.min(e.target.scrollHeight, 160) + "px";
  }
  if (e.target.id === "database-query") renderDatabaseResults();
  if (e.target.id === "library-search") {
    libraryQuery = e.target.value;
    const list = state.customFoods.filter(
      (f) =>
        !f.archived &&
        (libraryFilter === "All" || foodKind(f) === libraryFilter) &&
        f.name.toLowerCase().includes(libraryQuery.toLowerCase()),
    );
    document.querySelector("#library-results").innerHTML = libraryCards(list);
  }
  if (e.target.id === "builder-search") renderBuilderMatches(e.target.value);
  if (e.target.dataset.builderQuantity !== undefined)
    builderItems[Number(e.target.dataset.builderQuantity)].quantity = Number(
      e.target.value,
    );
});
document.addEventListener("change", (e) => {
  if (e.target.id === "restaurant-only") renderDatabaseResults();
  if (e.target.id === "trend-metric") {
    trendMetric = e.target.value;
    shell();
  }
});
document.addEventListener("submit", async (e) => {
  const form = e.target,
    data = new FormData(form);
  if (form.id === "builder-form") {
    e.preventDefault();
    try {
      const food = combineFoods(
        data.get("name"),
        builderItems,
        "meal-" + crypto.randomUUID(),
      );
      state.customFoods.push(food);
      persist();
      closeModal();
      view = "Library";
      shell();
      toast("Meal saved. Ready for next time.");
    } catch (error) {
      toast(error.message);
    }
  }
  if (form.id === "connection-form") {
    e.preventDefault();
    const base = data.get("base").trim().replace(/\/$/, "");
    if (base && !/^https?:\/\//.test(base)) {
      toast("Enter an HTTPS backend address.");
      return;
    }
    localStorage.setItem("nutrient-api-base", base);
    if (data.get("token")) {
      sessionStorage.setItem("nutrient-api-token", data.get("token"));
    }
    toast("Connection saved. The provider key stays on the server.");
  }
  if (form.id === "chat-form") {
    e.preventDefault();
    const message = data.get("message").trim();
    if (message) await beginChat(message);
  }
  if (form.id === "chat-confirm") {
    if (chatStage !== "review") return;
    e.preventDefault();
    const selectedMeal = data.get("meal"),
      name = data.get("name").trim();
    const foodItems = chatItems.filter(
      (x) => foodKind(x.food) !== "supplement",
    );
    if (name && foodItems.length)
      state.customFoods.push(
        combineFoods(name, foodItems, "meal-" + crypto.randomUUID()),
      );
    for (const item of chatItems) {
      rememberFood(item.food);
      ensureDay().entries.push({
        id: crypto.randomUUID(),
        foodId: item.food.id,
        quantity: item.quantity,
        meal:
          foodKind(item.food) === "supplement" ? "Supplements" : selectedMeal,
      });
    }
    persist();
    chatStage = "complete";
    shell();
    toast("Meal logged. Your daily picture is updated.");
  }
});
modal.addEventListener("cancel", stopScanner);
modal.addEventListener("close", stopScanner);

shell();
if (storageError)
  toast("Saved data could not be loaded. The sample diary is shown.");

function fitChatViewport() {
  const viewport = window.visualViewport;
  document.documentElement.style.setProperty(
    "--app-height",
    `${viewport?.height || window.innerHeight}px`,
  );
  document.body.dataset.keyboard = String(
    !!viewport && viewport.height < window.innerHeight * 0.8,
  );
}
window.visualViewport?.addEventListener("resize", fitChatViewport);
window.addEventListener("resize", fitChatViewport);
fitChatViewport();

document.addEventListener("keydown", (event) => {
  if (
    event.target.id === "chat-input" &&
    event.key === "Enter" &&
    !event.shiftKey &&
    !event.isComposing &&
    window.innerWidth > 700
  ) {
    event.preventDefault();
    if (chatStage !== "loading")
      document.querySelector("#chat-form")?.requestSubmit();
  }
});
