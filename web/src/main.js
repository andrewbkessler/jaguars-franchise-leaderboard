import { initDuckDB, runQuery } from "./duckdb.js";
import { buildLeaderboardSQL } from "./queryBuilder.js";
import { renderTable, setStatus } from "./render.js";

let statsConfig = null;
let manifest = null;

async function loadConfig() {
  const [statsRes, manifestRes] = await Promise.all([
    fetch("/data/stats.json"),
    fetch("/data/manifest.json"),
  ]);

  statsConfig = await statsRes.json();
  manifest = await manifestRes.json();

  const updated = document.getElementById("updated-at");
  if (updated && manifest?.updated_at) {
    updated.textContent = `Data updated: ${manifest.updated_at}`;
  }
}

function populateStatDropdown(positionGroup = "QB") {
  const pg = statsConfig.position_groups[positionGroup];
  const select = document.getElementById("stat-select");
  select.innerHTML = "";

  for (const [key, meta] of Object.entries(pg.stats)) {
    const opt = document.createElement("option");
    opt.value = key;
    opt.textContent = meta.label;
    opt.dataset.agg = meta.agg;
    opt.dataset.sort = meta.default_sort;
    opt.dataset.format = meta.format;
    select.appendChild(opt);
  }
}

function getFilters() {
  return {
    ageMin: document.getElementById("age-min").value,
    ageMax: document.getElementById("age-max").value,
    seasonType: document.getElementById("season-type").value,
    homeAway: document.getElementById("home-away").value,
    minGames: Number(document.getElementById("min-games").value) || 1,
  };
}

async function runLeaderboard() {
  const statSelect = document.getElementById("stat-select");
  const stat = statSelect.value;
  const selected = statSelect.selectedOptions[0];
  const agg = selected.dataset.agg;
  const sortDirection = selected.dataset.sort;
  const statFormat = selected.dataset.format;
  const scope = document.getElementById("scope-select").value;

  const sql = buildLeaderboardSQL({
    stat,
    agg,
    scope,
    positionGroup: "QB",
    filters: {
      ...getFilters(),
      sortDirection,
    },
  });

  document.getElementById("sql-debug").textContent = sql;
  setStatus("Running query...");

  try {
    const rows = await runQuery(sql);
    renderTable(rows, scope, statFormat);
    setStatus(`Showing ${rows.length} results.`);
  } catch (error) {
    console.error(error);
    setStatus(`Query failed: ${error.message}`, true);
  }
}

function applyUnder25Preset() {
  document.getElementById("age-min").value = "";
  document.getElementById("age-max").value = "25";
  runLeaderboard();
}

function wireEvents() {
  document.getElementById("run-btn").addEventListener("click", runLeaderboard);
  document.getElementById("under-25-btn").addEventListener("click", applyUnder25Preset);

  for (const id of [
    "stat-select",
    "scope-select",
    "season-type",
    "home-away",
    "min-games",
  ]) {
    document.getElementById(id).addEventListener("change", runLeaderboard);
  }
}

async function bootstrap() {
  wireEvents();
  await loadConfig();
  populateStatDropdown("QB");
  await initDuckDB();
  await runLeaderboard();
}

bootstrap().catch((error) => {
  console.error(error);
  setStatus(`Failed to initialize dashboard: ${error.message}`, true);
});
