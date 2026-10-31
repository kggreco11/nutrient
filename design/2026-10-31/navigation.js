// Same palette, three different navigation and page structures.
iconPaths.menu = "M4 6h16 M4 12h16 M4 18h16";
Object.assign(dirs.clear, {
  name: "Journal",
  title: "Journal / the whole day",
  desc: "Scan and Quick log at the top. Progress, nutrient gaps and the food log share one page. Chat is a logging sheet; past days, Trends and Library are secondary destinations.",
  recommend: "Recommended: one daily home, no bottom tabs.",
  principles: [
    "Capture from the top of Today in one tap.",
    "Read and edit the food log on the same screen.",
    "Use the menu for trends, saved meals and settings.",
  ],
});
Object.assign(dirs.pace, {
  name: "Capture",
  title: "Capture / start with the meal",
  desc: "A large meal input leads the screen. Progress is a compact readout below it. Barcode and Quick log stay pinned at the bottom as actions, not navigation tabs.",
  recommend: "For frequent, fast logging.",
  principles: [
    "The meal input is the focal point.",
    "A two-action dock stays reachable while scrolling.",
    "Progress and recent entries follow the capture area.",
  ],
});
Object.assign(dirs.table, {
  name: "Meals",
  title: "Meals / build the day",
  desc: "A meal timeline leads, with ingredients and add actions inside each meal. A compact progress summary stays above it. Scan or Quick log can start the next meal immediately.",
  recommend: "For thinking in meals and their ingredients.",
  principles: [
    "Meals and their components form the main structure.",
    "Scan another ingredient into an existing meal.",
    "Use the date to review another day without a separate Diary tab.",
  ],
});
function capturePair(cls = "capture-pair") {
  return (
    '<div class="' +
    cls +
    '">' +
    btn("Scan barcode", "scan", "secondary", "scan") +
    btn("Quick log", "chat", "primary", "plus") +
    "</div>"
  );
}
function progressStrip() {
  return '<div class="progress-strip"><button data-screen="nutrients"><b>76%</b><span>Coverage · 21 / 31</span></button><button data-screen="nutrient"><b>2,480</b><span>of 3,500 kcal</span></button></div>';
}
function mealTimeline() {
  return (
    '<section class="meal-timeline">' +
    head("Food log", "", '<button data-screen="select">Select foods</button>') +
    '<div class="timeline-meal"><div class="meal-heading"><h3>Lunch</h3><span>12:40</span></div>' +
    row("Grilled cheese", "3 ingredients", "347 kcal", "recipe") +
    foods.map(([n, p, e]) => row(n, p, e, "entry")).join("") +
    '<button class="plain-button" data-screen="scan">+ Add ingredient</button></div><div class="timeline-meal"><div class="meal-heading"><h3>Breakfast</h3><span>08:15</span></div>' +
    row("Oats & Greek yogurt", "1 saved meal", "620 kcal", "entry") +
    "</div></section>"
  );
}
function smallGaps() {
  return (
    '<section class="small-gaps">' +
    head(
      "Still to go",
      "",
      '<button data-screen="nutrients">View all</button>',
    ) +
    row("Vitamin C", "", "49 mg left", "nutrient") +
    row("Fiber", "", "8 g left", "nutrient") +
    "</section>"
  );
}
function journalHome() {
  return (
    capturePair() +
    '<section class="journal-summary"><div class="rings">' +
    ring("76%", "Coverage", "21 of 31 met", 76) +
    ring("2,480", "Calories", "1,020 kcal left", 71, true) +
    "</div>" +
    macros() +
    "</section>" +
    smallGaps() +
    mealTimeline()
  );
}
function captureHome() {
  return (
    '<section class="capture-hero"><span class="small muted">Saturday, October 31</span><h3>What did you eat?</h3><button class="meal-input" data-screen="chat"><span>Describe a meal…</span>' +
    icon("mic") +
    '</button><div class="capture-shortcuts">' +
    btn("Saved meals", "library", "secondary", "library") +
    btn("Label photo", "label", "secondary", "camera") +
    "</div></section>" +
    progressStrip() +
    "<section>" +
    macros() +
    "</section>" +
    smallGaps() +
    "<section>" +
    head(
      "Recently logged",
      "",
      '<button data-screen="diary">Full food log</button>',
    ) +
    row("Grilled cheese", "Lunch · 12:40", "347 kcal", "entry") +
    "</section>"
  );
}
function mealsHome() {
  return (
    '<div class="date-strip"><button aria-label="Previous day">' +
    icon("back") +
    '</button><strong>Saturday, Oct 31</strong><button aria-label="Next day">' +
    icon("chevron") +
    "</button></div>" +
    capturePair("meal-capture") +
    progressStrip() +
    '<button class="remaining-strip" data-screen="nutrients"><strong>10 targets still to go</strong><span>Vitamin C · fiber · magnesium</span></button>' +
    mealTimeline() +
    btn("Start another meal", "chat", "secondary", "plus")
  );
}
const priorPhone = phone;
phone = function (screen, d) {
  if (screen !== "today") {
    let html = priorPhone(screen, "clear").replace(
      /<nav class="bottom-nav"[\s\S]*?<\/nav>/,
      "",
    );
    if (
      [
        "diary",
        "chat",
        "trends",
        "library",
        "select",
        "empty",
        "error",
      ].includes(screen)
    )
      html = html.replace(
        '<header class="nav">',
        '<header class="nav">' + ib("back", "today", "Back to Today"),
      );
    return html;
  }
  const menu = state.navMenu
    ? '<div class="navigation-menu">' +
      btn("Food log & past days", "diary", "secondary", "diary") +
      btn("Trends", "trends", "secondary", "trends") +
      btn("Library", "library", "secondary", "library") +
      btn("Settings", "settings", "secondary", "settings") +
      "</div>"
    : "";
  return (
    '<article class="phone clear ' +
    state.appearance +
    " layout-" +
    d +
    (state.scale >= 1.8 ? " size-large" : "") +
    '" style="--font-scale:' +
    state.scale +
    ";--phone-width:" +
    state.width +
    'px" aria-label="' +
    dirs[d].name +
    ' home"><div class="island"></div><div class="status"><span>9:41</span><span>◔ ▰</span></div><header class="nav"><button class="icon-button" data-nav-menu aria-label="Open navigation menu">' +
    icon("menu") +
    '</button><div class="nav-title"><h2>' +
    (d === "table" ? "My day" : "Today") +
    "</h2>" +
    (d === "clear" ? "<p>Saturday, October 31</p>" : "") +
    "</div>" +
    ib("clock", "diary", "Past days") +
    "</header>" +
    menu +
    '<div class="screen-body">' +
    { clear: journalHome, pace: captureHome, table: mealsHome }[d]() +
    "</div>" +
    (d === "pace"
      ? '<div class="capture-dock">' + capturePair() + "</div>"
      : "") +
    '<div class="home-indicator"></div></article>'
  );
};
const priorRender = render;
render = function () {
  priorRender();
  document.querySelectorAll("[data-screen]").forEach((el) =>
    el.addEventListener(
      "click",
      () => {
        state.navMenu = false;
      },
      { capture: true },
    ),
  );
  document.querySelectorAll("[data-nav-menu]").forEach(
    (el) =>
      (el.onclick = () => {
        state.navMenu = !state.navMenu;
        render();
      }),
  );
  document.querySelectorAll("[data-dir]").forEach(
    (el) =>
      (el.onclick = () => {
        state.dir = el.dataset.dir;
        state.appearance = "light";
        state.navMenu = false;
        render();
      }),
  );
};
state.dir = "clear";
state.screen = "today";
state.appearance = "light";
state.board = false;
render();
