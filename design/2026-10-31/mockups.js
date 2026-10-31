const iconPaths = {
  home: "M3 11 12 3l9 8v10h-6v-7H9v7H3z",
  diary: "M5 3h14v18H5z M8 7h8 M8 11h8 M8 15h5",
  chat: "M4 4h16v13H9l-5 4z",
  trends: "M3 4v16h18 M6 15l4-5 4 3 6-8",
  library: "M4 4h4v17H4z M10 4h4v17h-4z M16 5l4-1 3 16-4 1z",
  plus: "M12 5v14 M5 12h14",
  chevron: "M9 5l7 7-7 7",
  back: "M15 5l-7 7 7 7",
  search: "M10 3a7 7 0 1 0 0 14 7 7 0 0 0 0-14 M15 15l6 6",
  scan: "M4 8V4h4 M16 4h4v4 M20 16v4h-4 M8 20H4v-4 M8 8v8 M11 8v8 M14 8v8 M17 8v8",
  camera: "M3 7h5l2-3h4l2 3h5v13H3z M12 10a4 4 0 1 0 0 8 4 4 0 0 0 0-8",
  mic: "M9 4a3 3 0 0 1 6 0v8a3 3 0 0 1-6 0z M5 10v2a7 7 0 0 0 14 0v-2 M12 19v3 M8 22h8",
  send: "M12 20V4 M5 11l7-7 7 7",
  check: "M5 12l4 4L19 6",
  settings: "M4 7h16 M4 17h16 M9 4v6 M15 14v6",
  food: "M4 3v7a3 3 0 0 0 6 0V3 M7 3v19 M17 3v19 M17 3c5 4 5 9 0 9",
  leaf: "M20 3C8 2 2 8 5 15c4 8 16 3 15-12 M5 20 16 8",
  pill: "M6 18a5 5 0 0 1 0-7l5-5a5 5 0 0 1 7 7l-5 5a5 5 0 0 1-7 0 M8 9l7 7",
  edit: "M4 20l1-6L16 3l5 5L10 19z M13 6l5 5",
  close: "M5 5l14 14 M19 5 5 19",
  clock: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18 M12 7v6l4 2",
  sun: "M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10 M12 1v2 M12 21v2 M1 12h2 M21 12h2 M4 4l2 2 M18 18l2 2 M20 4l-2 2 M6 18l-2 2",
  bolt: "m13 2-8 12h7l-1 8 8-12h-7z",
};
function icon(name) {
  return `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"><path d="${iconPaths[name] || iconPaths.food}"/></svg>`;
}
const dirs = {
  clear: {
    name: "Field",
    title: "Field / a personal field journal",
    desc: "Inspired by your misty landscapes, moss-covered ridges, and the quiet typography of kevingreco.me. Chalk surfaces, fern ink, and measured spacing make the daily numbers feel collected and considered.",
    recommend:
      "My recommendation: your landscape palette with a clean native iOS structure.",
    principles: [
      "Pale sky backgrounds and deep fern accents echo the landscape collection.",
      "A restrained serif title connects to your personal site; food amounts stay in readable system type.",
      "Fine rules and clear sections borrow the precision of your scientific illustrations.",
    ],
  },
  pace: {
    name: "Slate",
    title: "Slate / light against structure",
    desc: "Drawn from your monochrome upward-looking architecture and gray coastal scenes. Graphite, silver-blue, and spare structural lines give trends and meal components a precise rhythm.",
    recommend: "For the strongest data focus, especially in dark mode.",
    principles: [
      "Use architectural alignment and fine dividers instead of extra containers.",
      "Keep bright silver-blue accents readable against graphite surfaces.",
      "Give nutrient trends the same clear framing as your city compositions.",
    ],
  },
  table: {
    name: "Golden",
    title: "Golden / the last light",
    desc: "Inspired by the warm light between buildings and the muted gold of your wildlife landscapes. Pale stone, dark umber, and restrained ochre bring warmth to a food journal.",
    recommend:
      "For the warmest, most journal-like interpretation of your photography.",
    principles: [
      "Use warm light as a small accent around progress, never behind body text.",
      "Open meal lists and generous margins echo the breathing room in your photographs.",
      "Pair short serif headings with system text for quantities and controls.",
    ],
  },
};
const screens = {
  today: "Today",
  diary: "Diary",
  chat: "Chat",
  trends: "Trends",
  library: "Library",
  add: "Add food",
  review: "Review meal",
  scan: "Scan another ingredient",
  label: "Scan nutrition label",
  custom: "Review scanned label",
  select: "Select diary entries",
  save: "Save selected meal",
  recipe: "Saved meal",
  builder: "Build a meal",
  entry: "Edit diary entry",
  units: "Measurement conversion",
  supplements: "Supplements",
  nutrient: "Nutrient contributions",
  nutrients: "All nutrients",
  settings: "Settings & targets",
  empty: "Empty day",
  error: "Chat error",
};
const selectedFoods = new Set([0, 1, 2]);
const state = {
  dir: "clear",
  screen: "today",
  appearance: "light",
  scale: 1,
  width: 393,
  board: false,
  period: "Daily",
  selected: 3,
  logged: false,
};
const params = new URLSearchParams(location.search);
for (const k of ["dir", "screen", "appearance"])
  if (params.has(k)) state[k] = params.get(k);
state.board = params.get("board") === "1";
const btn = (text, screen, cls = "primary", ico = "") =>
  `<button class="${cls}" data-screen="${screen}">${ico ? icon(ico) : ""}${text}</button>`;
const ib = (name, screen, label) =>
  `<button class="icon-button" data-screen="${screen}" aria-label="${label}">${icon(name)}</button>`;
function row(title, sub, value, screen = "") {
  return `<${screen ? "button" : "div"} class="row" ${screen ? `data-screen="${screen}" style="width:100%;border-left:0;border-right:0;border-bottom:0;background:none;text-align:left;color:inherit;padding:8px 0"` : ""}><div><strong>${title}</strong>${sub ? `<p>${sub}</p>` : ""}</div><span class="amount">${value}</span></${screen ? "button" : "div"}>`;
}
const head = (title, sub = "", action = "") =>
  `<div class="section-head"><h3>${title}</h3>${action}</div>${sub ? `<p class="muted small">${sub}</p>` : ""}`;
function ring(value, label, sub, percent, second = false) {
  return `<div class="ring-wrap"><div class="label">${label}</div><div class="ring" style="--progress:${percent};${second ? "--ring-color:var(--ring2)" : ""}"><svg viewBox="0 0 116 116"><circle cx="58" cy="58" r="50"/><circle class="arc" cx="58" cy="58" r="50"/></svg><div class="ring-value"><strong>${value}</strong><span>${label === "Calories" ? "of 3,500 kcal" : "nutrient score"}</span></div></div><span>${sub}</span></div>`;
}
function macros() {
  return [
    ["Protein", "128 / 160 g", 80],
    ["Carbs", "342 / 500 g", 68],
    ["Fat", "67 / 95 g", 71],
  ]
    .map(
      ([name, value, p]) =>
        `<div class="macro" data-screen="nutrient" role="button" tabindex="0" aria-label="${name} contributing foods"><div class="row"><strong>${name}</strong><span class="muted">${value}</span></div><div class="macro-track" style="--value:${p}%"><i></i></div></div>`,
    )
    .join("");
}
const foods = [
  ["Bread", "2 slices / 64 g", "170 kcal", "B"],
  ["Cheddar", "35 g", "141 kcal", "C"],
  ["Butter", "5 g", "36 kcal", "B"],
];
function foodRows(selection = false) {
  return foods
    .map(
      ([name, portion, energy, initial], i) =>
        `<${selection ? "button" : "div"} class="food-row" ${selection ? `data-select="${i}" style="border-left:0;border-right:0;border-bottom:0;background:none;width:100%;text-align:left;color:inherit"` : ""}>${selection ? `<span class="check ${selectedFoods.has(i) ? "selected" : ""}">${selectedFoods.has(i) ? icon("check") : ""}</span>` : `<span class="food-initial">${initial}</span>`}<div class="food-copy"><strong>${name}</strong><p>${portion}</p></div><span class="food-energy">${energy}</span></${selection ? "button" : "div"}>`,
    )
    .join("");
}
function gapRows() {
  return [
    ["Vitamin C", "49 mg left", "41 / 90 mg"],
    ["Fiber", "8 g left", "30 / 38 g"],
    ["Magnesium", "84 mg left", "336 / 420 mg"],
  ]
    .map(
      ([n, left, v]) =>
        `<div class="gap" data-screen="nutrient" role="button" tabindex="0"><i class="mini-bar"></i><div class="grow"><b>${n}</b><br><span>${v}</span></div><strong class="label">${left}</strong>${icon("chevron")}</div>`,
    )
    .join("");
}
function today(d) {
  const summary = `<section class="card summary"><div class="rings">${ring("76%", "Coverage", "21 of 31 targets met", 76)}${ring("2,480", "Calories", "1,020 kcal left", 71, true)}</div>${macros()}</section>`;
  const gaps = `<section>${head("Still to go", "", `<button data-screen="nutrients">All nutrients</button>`)}<div class="${d === "table" ? "" : "card"}" style="padding-top:0;padding-bottom:0">${gapRows()}</div>${btn("Find foods for these gaps", "chat", "secondary", "chat")}</section>`;
  const meal = `<section>${head("Recent meal", "", `<button data-screen="diary">Diary</button>`)}<div class="card line-list">${row("Grilled cheese", "Lunch / 12:40", "347 kcal", "recipe")}</div></section>`;
  return summary + gaps + meal;
}
function diary(d, selection = false) {
  return `<div class="date-strip"><button aria-label="Previous day">${icon("back")}</button><strong>Today, Oct 31</strong><button aria-label="Next day">${icon("chevron")}</button></div>${!selection ? `<div class="card" style="padding:12px 16px">${row("2,480 kcal", "76% nutrient coverage", `<span class="pill">21 targets met</span>`)}</div>` : ""}<div class="meal-heading"><h3>Lunch</h3><span class="muted small">347 kcal</span></div>${d === "table" && !selection ? `<div class="card"><div class="row"><span class="food-initial">${icon("food")}</span><div style="flex:1"><strong>Grilled cheese</strong><p>Bread, cheddar, butter</p></div><button class="plain-button" data-screen="entry">${icon("edit")}</button></div>${foodRows()}</div>` : `<section class="card line-list">${foodRows(selection)}</section>`}${selection ? "" : `<div class="meal-heading"><h3>Breakfast</h3><span class="muted small">620 kcal</span></div><section class="card line-list">${row("Oats & Greek yogurt", "1 saved meal", "620 kcal", "entry")}</section>${btn("Add food", "add", "secondary", "plus")}`}`;
}
function chat(d, error = false) {
  return `<div class="chat-time">Today, 12:40</div><div class="message user">I ate a grilled cheese: 2 slices of bread, 35 g cheddar, and 5 g butter.</div>${error ? `<div class="alert-box"><strong>Couldn’t reach the assistant</strong><div class="muted">Your message is saved. Try sending it again.</div>${btn("Retry", "chat", "secondary")}</div>` : `<div class="message assistant">Here’s your grilled cheese. You can change any amount before logging it.</div><div class="chat-proposal"><h3>Grilled cheese</h3>${foods.map(([n, p, e]) => row(n, p, e)).join("")}<div class="row"><strong>Total</strong><strong>347 kcal</strong></div>${btn("Review & log", "review", "primary")}</div><div class="message assistant muted small">You can also scan another ingredient into this meal.</div>`}`;
}
function chart(d) {
  const vals =
    state.period === "Weekly"
      ? [59, 66, 71, 76, 74, 80, 76]
      : state.period === "Monthly"
        ? [48, 54, 59, 66, 69, 76, 76]
        : [62, 75, 81, 73, 84, 81, 76];
  let art = "";
  if (d === "pace")
    art = vals
      .map(
        (v, i) =>
          `<rect x="${16 + i * 41}" y="${145 - v * 1.15}" width="24" height="${v * 1.15}" rx="4" fill="currentColor" opacity="${i === 6 ? 1 : 0.5}"/>`,
      )
      .join("");
  else {
    const p = vals.map((v, i) => `${20 + i * 42},${145 - v * 1.15}`).join(" ");
    art = `<polygon class="area" points="20,145 ${p} 272,145"/><polyline class="trend-line" points="${p}"/>${vals.map((v, i) => `<circle cx="${20 + i * 42}" cy="${145 - v * 1.15}" r="${i === 6 ? 5 : 3}" fill="currentColor"/>`).join("")}`;
  }
  return `<div class="chart"><svg viewBox="0 0 310 170" role="img" aria-label="Daily nutrient scores: 62, 75, 81, 73, 84, 81, 76 percent"><path class="grid" d="M8 145h278 M8 88h278"/><path class="goal" d="M8 30h278"/><text x="285" y="34">100</text><text x="290" y="92">50</text><text x="296" y="149">0</text>${art}</svg><div class="chart-labels">${(state.period === "Daily" ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] : state.period === "Weekly" ? ["Sep 14", "21", "28", "Oct 5", "12", "19", "26"] : ["Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct"]).map((x) => `<span>${x}</span>`).join("")}</div></div>`;
}
function trends(d) {
  return `<div class="segmented">${["Daily", "Weekly", "Monthly"].map((p) => `<button data-period="${p}" class="${state.period === p ? "active" : ""}">${p}</button>`).join("")}</div><div class="row" style="min-height:44px;margin-bottom:16px"><strong>Nutrient score</strong><span class="muted small">${state.period === "Daily" ? "Last 7 days" : state.period === "Weekly" ? "Last 8 weeks" : "Last 6 months"}</span></div><section class="card"><div class="metric-summary"><div><div class="muted small">${state.period === "Daily" ? "Daily average" : state.period === "Weekly" ? "Weekly average" : "Monthly average"}</div><span class="big-number">76<span style="font-size:.5em">%</span></span></div><span class="pill">+8 pts</span></div>${chart(d)}<div class="muted small">Dashed line: 100% target</div></section>${d === "table" ? `<section>${head("This week")}<div class="calendar-row">${["S", "M", "T", "W", "T", "F", "S"].map((x, i) => `<span class="calendar-day">${x}<b class="${i > 1 ? "hit" : ""}">${[62, 75, 81, 73, 84, 81, 76][i]}</b></span>`).join("")}</div></section>` : ""}<section>${head(state.period === "Daily" ? "By day" : state.period === "Weekly" ? "By week" : "By month")}<div class="card line-list">${row(state.period === "Daily" ? "Today" : state.period === "Weekly" ? "Oct 26–31" : "October", "", "76%")}${row(state.period === "Daily" ? "Fri, Oct 30" : state.period === "Weekly" ? "Oct 19–25" : "September", "", "81%")}${row(state.period === "Daily" ? "Thu, Oct 29" : state.period === "Weekly" ? "Oct 12–18" : "August", "", "84%")}</div></section><section>${head("Recurring shortfalls")}<div class="card line-list">${row("Fiber", "Average 30 of 38 g", "79%", "nutrient")}${row("Magnesium", "Average 336 of 420 mg", "80%", "nutrient")}</div></section>`;
}
function library(d) {
  return `<div class="search-field">${icon("search")}<input aria-label="Search saved foods" placeholder="Search your library"></div><div class="segmented"><button class="active">Meals</button><button>Foods</button><button data-screen="supplements">Supplements</button></div>${d === "table" ? head("Your regulars") : ""}${[
    ["Grilled cheese", "3 ingredients / 347 kcal", "food"],
    ["Oats & Greek yogurt", "4 ingredients / 620 kcal", "sun"],
    ["Chicken rice bowl", "5 ingredients / 710 kcal", "food"],
  ]
    .map(
      ([n, s, i]) =>
        `<div class="recipe" data-screen="recipe" role="button" tabindex="0"><div class="tile">${icon(i)}</div><div><h3>${n}</h3><p>${s}</p></div>${icon("chevron")}</div>`,
    )
    .join(
      "",
    )}<section style="margin-top:20px">${btn("Build a meal", "builder", "secondary", "plus")}</section>`;
}
function add() {
  return `<div class="search-field">${icon("search")}<input placeholder="Food, product, or brand" aria-label="Find food"></div><div class="action-row" style="margin-bottom:20px">${btn("Barcode", "scan", "secondary", "scan")}${btn("Label photo", "label", "secondary", "camera")}</div>${btn("Describe what you ate", "chat", "primary", "mic")}<section style="margin-top:22px">${head("Recent foods")}<div class="card line-list">${row("Whole-grain bread", "1 slice / 32 g", "85 kcal", "review")}${row("Cheddar", "35 g", "141 kcal", "review")}${row("Butter", "5 g", "36 kcal", "review")}${row("Greek yogurt", "170 g", "100 kcal", "review")}</div></section>${btn("Create custom food", "custom", "secondary", "plus")}`;
}
function review(d) {
  return `<div class="field"><label for="meal-name-${d}">Meal name</label><input id="meal-name-${d}" value="Grilled cheese"></div><section class="card line-list">${foods.map(([n, p, e], i) => `<div class="food-row"><div class="food-copy"><strong>${n}</strong><p>${p}</p></div><span class="food-energy">${e}</span><button class="plain-button" data-screen="units" aria-label="Edit ${n} amount">${icon("edit")}</button></div>`).join("")}</section><div class="action-row" style="margin-bottom:18px">${btn("Scan next", "scan", "secondary", "scan")}${btn("Add food", "add", "secondary", "plus")}</div><section class="card line-list">${row("Total energy", "", "347 kcal")}${row("Log as one meal", "Keep ingredient breakdown", '<span class="toggle"></span>')}${row("Meal", "", "Lunch")}${row("Date", "", "Today")}</section><div class="row"><span>Save to Library</span><span class="toggle"></span></div>`;
}
function scan() {
  return `<div class="scan-frame"><div class="scan-guides"></div><div class="barcode"></div><span class="scan-caption">Hold the barcode inside the frame</span></div><section>${head("Your meal", "", `<span class="pill">3 ingredients</span>`)}<div class="card line-list">${foods.map(([n, p]) => row(n, p, icon("check"))).join("")}</div></section>${btn("Enter barcode", "add", "secondary")}<p class="small muted">Each scan adds an ingredient to the same meal.</p>`;
}
function label() {
  return `<div class="scan-frame label-frame"><div class="scan-guides"></div><div class="label-paper"><h3>Nutrition Facts</h3><div>Serving size <b>1 slice (32 g)</b></div><div>Calories <b>85</b></div><div>Total Fat <b>1 g</b></div><div>Carbohydrate <b>16 g</b></div><div>Protein <b>4 g</b></div></div></div><p style="margin:0 0 20px">Fit the full Nutrition Facts panel in the frame.</p><div class="action-row">${btn("Take photo", "custom", "primary", "camera")}${btn("Choose photo", "custom", "secondary")}</div>`;
}
function custom() {
  return `<div class="pill" style="display:inline-flex;align-items:center;gap:6px;margin-bottom:20px">${icon("check")} Label ready to review</div><div class="field"><label>Food name</label><input value="Whole-grain bread"></div><div class="field-grid"><div class="field"><label>Serving</label><input value="1 slice"></div><div class="field"><label>Weight in grams</label><input value="32" inputmode="decimal"></div></div><section class="card line-list">${row("Calories", "", "85 kcal")}${row("Protein", "", "4 g")}${row("Carbs", "", "16 g")}${row("Fat", "", "1 g")}${row("Fiber", "", "3 g")}</section><button class="plain-button" data-screen="nutrients">More nutrients</button>`;
}
function save() {
  return `<div class="field"><label>Meal name</label><input value="Grilled cheese"></div><section>${head("Selected ingredients")}<div class="card line-list">${foodRows()}</div></section><div class="card line-list">${row("Saved serving", "", "1 meal")}${row("Total energy", "", "347 kcal")}</div>`;
}
function recipe() {
  return `<div class="nutrient-total"><span>Saved meal</span><h2 style="font-size:30px;margin:8px 0">Grilled cheese</h2><span>3 ingredients / 347 kcal per meal</span></div><div class="card line-list">${foodRows()}</div><section style="margin-top:20px">${head("Nutrition per meal")}<div class="card line-list">${row("Protein", "", "16 g", "nutrient")}${row("Carbs", "", "35 g", "nutrient")}${row("Fat", "", "16 g", "nutrient")}</div></section>${btn("Edit ingredients", "builder", "secondary", "edit")}`;
}
function units() {
  return `<h3 style="font-size:20px;margin:4px 0 20px">Cheddar</h3><div class="field-grid"><div class="field"><label>Amount</label><input value="1.25" inputmode="decimal"></div><div class="field"><label>Unit</label><select aria-label="Measurement unit"><option>Ounces (oz)</option><option>Grams</option><option>Servings</option></select></div></div><div class="card"><span class="muted label">Converted weight</span><div class="big-number" style="margin:10px 0">35.44 <span style="font-size:22px">g</span></div><div class="small muted">Per 100 g source serving</div></div><div class="card line-list" style="margin-top:20px">${row("Energy", "", "143 kcal")}${row("Protein", "", "8.9 g")}${row("Fat", "", "11.7 g")}</div>`;
}
function nutrient() {
  return `<div class="nutrient-total"><span>Today / target 160 g</span><span class="big-number">128 <span style="font-size:25px">g</span></span><div class="macro-track" style="--value:80%"><i></i></div><p class="muted small">32 g left</p></div><section>${head("Contributing foods")}<div class="card line-list">${[
    ["Chicken", "150 g", "46 g"],
    ["Milk", "2 cups", "16 g"],
    ["Grilled cheese", "1 meal", "18 g"],
    ["Oats", "100 g", "12 g"],
    ["Other foods", "4 entries", "36 g"],
  ]
    .map(([n, p, v]) =>
      row(n, p, v, n === "Grilled cheese" ? "recipe" : "entry"),
    )
    .join(
      "",
    )}</div></section>${btn("Find foods with protein", "chat", "secondary", "chat")}`;
}
function nutrients() {
  return `<div class="segmented"><button class="active">Still to go</button><button>All</button><button>Met</button></div><section class="card line-list">${row("Vitamin C", "41 of 90 mg", "49 mg left", "nutrient")}${row("Fiber", "30 of 38 g", "8 g left", "nutrient")}${row("Magnesium", "336 of 420 mg", "84 mg left", "nutrient")}${row("Protein", "128 of 160 g", "32 g left", "nutrient")}${row("Calcium", "840 of 1,000 mg", "160 mg left", "nutrient")}</section><div class="row"><strong>Not reported</strong><span class="muted">4 nutrients</span></div><p class="small muted">Chromium, iodine, biotin, molybdenum</p>`;
}
function settings() {
  return `<section>${head("Daily targets")}<div class="card settings-group">${[
    ["Energy", "3500", "kcal"],
    ["Protein", "160", "g"],
    ["Carbs", "500", "g"],
    ["Fat", "95", "g"],
  ]
    .map(
      ([n, v, u]) =>
        `<div class="row"><label>${n}</label><div><input value="${v}" aria-label="${n} target"> <span class="muted small">${u}</span></div></div>`,
    )
    .join(
      "",
    )}</div></section><section class="card line-list">${row("Nutrient targets", "", "34", "nutrients")}${row("Appearance", "", "System")}${row("Chat connection", "", "Connected")}${row("Export diary", "", "JSON")}${row("Import backup", "", "")}</section>`;
}
function entry() {
  return `<h3 style="margin:4px 0 18px">Whole-grain bread</h3><div class="field-grid"><div class="field"><label>Amount</label><input value="2"></div><div class="field"><label>Unit</label><select><option>Slices (32 g)</option><option>Grams</option></select></div></div><div class="card line-list">${row("Converted weight", "", "64 g")}${row("Energy", "", "170 kcal")}${row("Meal", "", "Lunch")}${row("Date", "", "Today")}</div><button class="plain-button" style="margin-top:18px;color:var(--warn)">Remove entry</button>`;
}
function empty() {
  return `<section class="card summary"><div class="rings">${ring("0%", "Coverage", "No foods logged", 0)}${ring("0", "Calories", "3,500 kcal left", 0, true)}</div>${[
    ["Protein", "0 / 160 g"],
    ["Carbs", "0 / 500 g"],
    ["Fat", "0 / 95 g"],
  ]
    .map(
      ([n, v]) =>
        `<div class="macro"><div class="row"><strong>${n}</strong><span class="muted">${v}</span></div><div class="macro-track"></div></div>`,
    )
    .join(
      "",
    )}</section>${btn("Log your first food", "add", "primary", "plus")}`;
}
function builder() {
  return `<div class="field"><label>Meal name</label><input value="Grilled cheese"></div><div class="card line-list">${foodRows()}</div><div class="action-row" style="margin:20px 0">${btn("Scan item", "scan", "secondary", "scan")}${btn("Add food", "add", "secondary", "plus")}</div><div class="card line-list">${row("Recipe total", "", "347 kcal")}${row("Makes", "", "1 meal")}</div>`;
}
function supplements() {
  return `<div class="search-field">${icon("search")}<input placeholder="Find a supplement" aria-label="Find supplement"></div><div class="card line-list">${row("Vitamin D3 + K2", "1 capsule", "25 μg D", "review")}${row("Omega-3", "1 softgel", "640 mg", "review")}</div>${btn("Scan supplement label", "label", "secondary", "camera")}`;
}
function content(screen, d) {
  return (
    {
      today: () => today(d),
      diary: () => diary(d),
      chat: () => chat(d),
      error: () => chat(d, true),
      trends: () => trends(d),
      library: () => library(d),
      add,
      review: () => review(d),
      scan,
      label,
      custom,
      select: () => diary(d, true),
      save,
      recipe,
      builder,
      entry,
      units,
      nutrient,
      nutrients,
      settings,
      supplements,
      empty,
    }[screen] || (() => today(d))
  )();
}
const modalScreens = [
  "add",
  "review",
  "scan",
  "label",
  "custom",
  "save",
  "builder",
  "entry",
  "units",
];
const titleMap = {
  today: "Today",
  diary: "Diary",
  chat: "Chat",
  trends: "Trends",
  library: "Library",
  add: "Add food",
  review: "Review meal",
  scan: "Scan ingredient",
  label: "Nutrition label",
  custom: "New food",
  select: "Select foods",
  save: "Save to Library",
  recipe: "Meal",
  builder: "Build a meal",
  entry: "Edit entry",
  units: "Amount",
  nutrient: "Protein",
  nutrients: "Nutrients",
  settings: "Settings",
  supplements: "Supplements",
  empty: "Today",
  error: "Chat",
};
function phone(screen, d) {
  const modal = modalScreens.includes(screen);
  const current = ["select", "save", "entry"].includes(screen)
    ? "diary"
    : ["recipe", "builder", "custom", "supplements"].includes(screen)
      ? "library"
      : screen === "error"
        ? "chat"
        : screen;
  const tabs = [
    ["home", "Today", "today"],
    ["diary", "Diary", "diary"],
    ["chat", "Chat", "chat"],
    ["trends", "Trends", "trends"],
    ["library", "Library", "library"],
  ];
  const navAction = modal
    ? ""
    : screen === "diary"
      ? `<button class="plain-button" data-screen="select">Select</button>`
      : screen === "select"
        ? `<button class="plain-button" data-select-all>Select all</button>`
        : screen === "today" || screen === "empty"
          ? ib("plus", "add", "Log food")
          : screen === "library"
            ? ib("plus", "builder", "Create a meal")
            : screen === "chat" || screen === "error"
              ? ""
              : screen === "settings"
                ? ""
                : screen === "recipe"
                  ? ib("edit", "builder", "Edit recipe")
                  : ib("settings", "settings", "Open settings");
  const back = modal
    ? `<button class="plain-button" data-screen="${screen === "save" ? "select" : "diary"}">Cancel</button>`
    : ["nutrient", "nutrients", "recipe", "settings", "supplements"].includes(
          screen,
        )
      ? ib("back", screen === "nutrient" ? "today" : "library", "Back")
      : "";
  const sub =
    screen === "today"
      ? d === "pace"
        ? "Saturday, Oct 31"
        : "Saturday, October 31"
      : "";
  let sticky = "";
  if (screen === "review")
    sticky = btn("Confirm & log meal", "diary", "primary", "check");
  if (screen === "scan")
    sticky = btn("Review 3 ingredients", "review", "primary");
  if (screen === "custom") sticky = btn("Save food", "library", "primary");
  if (screen === "select")
    sticky = btn(`Save as meal (${state.selected})`, "save", "primary");
  if (screen === "save" || screen === "builder")
    sticky = btn("Save meal", "library", "primary");
  if (screen === "recipe")
    sticky = btn("Log this meal", "review", "primary", "plus");
  if (screen === "entry" || screen === "units")
    sticky = btn("Save changes", "review", "primary");
  return `<article class="phone ${d} ${state.appearance} ${modal ? "sheet" : ""} ${state.scale >= 1.8 ? "size-large" : ""}" style="--font-scale:${state.scale};--phone-width:${state.width}px" aria-label="${dirs[d].name} ${titleMap[screen]}"><div class="island"></div><div class="status"><span>9:41</span><svg viewBox="0 0 53 15" aria-hidden="true"><path d="M1 12h3v-3H1zm5 0h3V6H6zm5 0h3V3h-3z" fill="currentColor"/><path d="M19 5q7-6 14 0 M22 8q4-4 8 0 M25 11h2" fill="none" stroke="currentColor" stroke-width="1.6"/><rect x="37" y="3" width="13" height="9" rx="2" fill="none" stroke="currentColor"/><rect x="39" y="5" width="9" height="5" rx="1" fill="currentColor"/></svg></div>${modal ? '<div class="sheet-handle"></div>' : ""}<header class="nav">${back}<div class="nav-title"><h2>${titleMap[screen]}</h2>${sub ? `<p>${sub}</p>` : ""}</div>${navAction}</header><div class="screen-body ${screen === "chat" || screen === "error" ? "chat-body" : ""}">${content(screen, d)}</div>${screen === "chat" || screen === "error" ? `<div class="composer"><button data-screen="scan" aria-label="Scan an ingredient">${icon("plus")}</button><div class="entry"><input placeholder="Message" aria-label="Message"><button aria-label="Dictate message">${icon("mic")}</button></div><button class="send" data-screen="review" aria-label="Send message">${icon("send")}</button></div>` : ""}${sticky ? `<div class="sticky-action">${sticky}</div>` : ""}${!modal ? `<nav class="bottom-nav" aria-label="Main navigation">${tabs.map(([i, n, k]) => `<button data-screen="${k}" class="${current === k ? "active" : ""}" ${current === k ? 'aria-current="page"' : ""}>${icon(i)}<span>${n}</span></button>`).join("")}</nav>` : ""}<div class="home-indicator"></div></article>`;
}
function render() {
  document.body.classList.toggle(
    "board-mode",
    state.board || new URLSearchParams(location.search).has("compare"),
  );
  document.getElementById("directions").innerHTML = Object.entries(dirs)
    .map(
      ([id, d]) =>
        `<button data-dir="${id}" aria-pressed="${state.dir === id}">${d.name}</button>`,
    )
    .join("");
  document.getElementById("screen").innerHTML = Object.entries(screens)
    .map(
      ([id, n]) =>
        `<option value="${id}" ${state.screen === id ? "selected" : ""}>${n}</option>`,
    )
    .join("");
  document.getElementById("appearance").value = state.appearance;
  document.getElementById("direction-copy").innerHTML =
    `<h2>${dirs[state.dir].title}</h2><p>${dirs[state.dir].desc}</p><div class="inspiration"><span class="palette ${state.dir}" aria-hidden="true"><i></i><i></i><i></i><i></i></span><a href="https://kevingreco.me/photography/${state.dir === "pace" ? "cities" : "landscapes"}" target="_blank" rel="noreferrer">Photography reference ↗</a></div>`;
  document.getElementById("canvas").innerHTML = state.board
    ? ["today", "diary", "chat", "trends", "library", "review"]
        .map(
          (s) =>
            `<section class="board-item"><h3>${titleMap[s]}</h3>${phone(s, state.dir)}</section>`,
        )
        .join("")
    : phone(state.screen, state.dir) +
      `<aside class="supporting"><h3>${dirs[state.dir].recommend}</h3><ul>${dirs[state.dir].principles.map((s) => `<li>${s}</li>`).join("")}</ul><h3>Explore the flows</h3><p>Tap the phone’s tabs and buttons, or use the screen menu above. Includes label capture, ingredient scanning, measurement conversion, diary selection, meal saving, nutrient sources, and settings.</p><h3>Mobile contract</h3><p>17 pt body type, 44 pt controls, labeled persistent tabs, safe-area insets, and light/dark token pairs. Larger text is a design stress test; final VoiceOver and Dynamic Type verification belongs in SwiftUI.</p><button class="secondary" id="landscape" style="color:#34465e;background:white;border-color:#bec7d2">Toggle landscape preview</button></aside>`;
  if (new URLSearchParams(location.search).has("compare"))
    document.getElementById("canvas").innerHTML = Object.entries(dirs)
      .map(
        ([d, v]) =>
          `<section class="board-item"><h3>${v.name}</h3>${phone("today", d).replace("phone pace light", "phone pace dark")}</section>`,
      )
      .join("");
  document.querySelectorAll("[data-screen]").forEach((el) =>
    el.addEventListener("click", () => {
      state.screen = el.dataset.screen;
      state.board = false;
      render();
    }),
  );
  document.querySelectorAll("[data-dir]").forEach(
    (el) =>
      (el.onclick = () => {
        state.dir = el.dataset.dir;
        state.appearance = state.dir === "pace" ? "dark" : "light";
        render();
      }),
  );
  document.querySelectorAll("[data-period]").forEach(
    (el) =>
      (el.onclick = () => {
        state.period = el.dataset.period;
        render();
      }),
  );
  document.querySelectorAll("[data-select]").forEach(
    (el) =>
      (el.onclick = () => {
        const id = Number(el.dataset.select);
        selectedFoods.has(id)
          ? selectedFoods.delete(id)
          : selectedFoods.add(id);
        state.selected = selectedFoods.size;
        render();
      }),
  );
  document.querySelectorAll("[data-select-all]").forEach(
    (el) =>
      (el.onclick = () => {
        selectedFoods.clear();
        [0, 1, 2].forEach((i) => selectedFoods.add(i));
        state.selected = 3;
        render();
      }),
  );
  document.querySelectorAll(".phone .field").forEach((field, i) => {
    const label = field.querySelector("label"),
      control = field.querySelector("input,select");
    if (label && control) {
      control.id = control.id || `field-${i}`;
      label.htmlFor = control.id;
    }
  });
  document
    .getElementById("landscape")
    ?.addEventListener("click", () =>
      document.querySelector(".phone").classList.toggle("landscape"),
    );
}
document.getElementById("screen").onchange = (e) => {
  state.screen = e.target.value;
  state.board = false;
  render();
};
document.getElementById("appearance").onchange = (e) => {
  state.appearance = e.target.value;
  render();
};
document.getElementById("text-size").onchange = (e) => {
  state.scale = Number(e.target.value);
  render();
};
document.getElementById("phone-width").onchange = (e) => {
  state.width = Number(e.target.value);
  render();
};
document.getElementById("board").onclick = () => {
  state.board = !state.board;
  state.scale = 1;
  state.width = 393;
  render();
};
render();
