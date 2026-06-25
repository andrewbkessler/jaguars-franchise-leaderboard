export function formatStatValue(value, format) {
  if (value === null || value === undefined) {
    return "—";
  }

  if (format === "decimal") {
    return Number(value).toFixed(1);
  }

  return Number(value).toLocaleString();
}

export function renderTable(rows, scope, statFormat) {
  const thead = document.querySelector("#leaderboard thead");
  const tbody = document.querySelector("#leaderboard tbody");

  const scopeHeaders =
    scope === "season"
      ? "<th>Season</th>"
      : scope === "game"
        ? "<th>Game Date</th>"
        : "";

  thead.innerHTML = `
    <tr>
      <th>Rank</th>
      <th>Player</th>
      <th>Value</th>
      <th>Games</th>
      ${scopeHeaders}
    </tr>
  `;

  if (!rows.length) {
    tbody.innerHTML = `<tr><td colspan="5">No results for this filter combination.</td></tr>`;
    return;
  }

  tbody.innerHTML = rows
    .map((row, index) => {
      const scopeCell =
        scope === "season"
          ? `<td>${row.season ?? "—"}</td>`
          : scope === "game"
            ? `<td>${row.game_date ?? "—"}</td>`
            : "";

      return `
        <tr>
          <td>${index + 1}</td>
          <td>${row.player_display_name}</td>
          <td>${formatStatValue(row.stat_value, statFormat)}</td>
          <td>${row.games ?? "—"}</td>
          ${scopeCell}
        </tr>
      `;
    })
    .join("");
}

export function setStatus(message, isError = false) {
  const status = document.getElementById("status");
  status.textContent = message;
  status.className = isError ? "status error" : "status";
}
