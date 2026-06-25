const TABLE = "player_game";

const ALLOWED_STATS = new Set([
  "passing_yards",
  "passing_tds",
  "completions",
  "attempts",
  "passing_interceptions",
  "passing_epa",
  "passing_first_downs",
  "sacks_suffered",
  "passing_air_yards",
  "passing_yards_after_catch",
]);

const ALLOWED_AGGS = new Set(["sum", "max", "avg", "count"]);
const ALLOWED_SCOPES = new Set(["career", "season", "game"]);

export function buildLeaderboardSQL({
  stat,
  agg,
  scope,
  positionGroup,
  filters,
  limit = 10,
}) {
  if (!ALLOWED_STATS.has(stat)) {
    throw new Error(`Unsupported stat: ${stat}`);
  }
  if (!ALLOWED_AGGS.has(agg)) {
    throw new Error(`Unsupported aggregation: ${agg}`);
  }
  if (!ALLOWED_SCOPES.has(scope)) {
    throw new Error(`Unsupported scope: ${scope}`);
  }

  const statExpr =
    agg === "sum"
      ? `SUM(${stat})`
      : agg === "max"
        ? `MAX(${stat})`
        : agg === "avg"
          ? `AVG(${stat})`
          : agg === "count"
            ? `COUNT(${stat})`
            : `SUM(${stat})`;

  const groupCols =
    scope === "career"
      ? "player_id, player_display_name"
      : scope === "season"
        ? "player_id, player_display_name, season"
        : "player_id, player_display_name, game_id, game_date";

  const extraSelect =
    scope === "season" ? ", season" : scope === "game" ? ", game_id, game_date" : "";

  const extraGroup =
    scope === "season" ? ", season" : scope === "game" ? ", game_id, game_date" : "";

  const where = [`team = 'JAX'`, `position_group = '${positionGroup}'`];

  if (filters.ageMin !== null && filters.ageMin !== "") {
    where.push(`age_at_game >= ${Number(filters.ageMin)}`);
  }
  if (filters.ageMax !== null && filters.ageMax !== "") {
    where.push(`age_at_game < ${Number(filters.ageMax)}`);
  }

  if (filters.seasonType && filters.seasonType !== "ALL") {
    where.push(`season_type = '${filters.seasonType}'`);
  }

  if (filters.homeAway === "HOME") {
    where.push("is_home = true");
  }
  if (filters.homeAway === "AWAY") {
    where.push("is_home = false");
  }

  where.push(`${stat} IS NOT NULL`);

  const having =
    filters.minGames > 1
      ? `HAVING COUNT(DISTINCT game_id) >= ${Number(filters.minGames)}`
      : "";

  const sortDirection = filters.sortDirection === "asc" ? "ASC" : "DESC";

  return `
    SELECT
      ${groupCols}${extraSelect},
      ${statExpr} AS stat_value,
      COUNT(DISTINCT game_id) AS games
    FROM ${TABLE}
    WHERE ${where.join(" AND ")}
    GROUP BY ${groupCols}${extraGroup}
    ${having}
    ORDER BY stat_value ${sortDirection}
    LIMIT ${limit}
  `.trim();
}
