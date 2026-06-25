FACT_COLUMNS <- c(
  "player_id",
  "pfr_id",
  "player_name",
  "player_display_name",
  "team",
  "game_id",
  "game_date",
  "season",
  "week",
  "season_type",
  "opponent_team",
  "is_home",
  "age_at_game",
  "position",
  "position_group",
  "source",
  "completions",
  "attempts",
  "passing_yards",
  "passing_tds",
  "passing_interceptions",
  "sacks_suffered",
  "sack_yards_lost",
  "passing_air_yards",
  "passing_yards_after_catch",
  "passing_first_downs",
  "passing_epa",
  "passing_2pt_conversions"
)

build_player_game_stats <- function() {
  nflverse <- ingest_nflverse_qb()
  legacy <- ingest_pfr_legacy_qb()

  dplyr::bind_rows(nflverse, legacy) |>
    mutate(
      player_display_name = dplyr::coalesce(.data$player_display_name, .data$player_name),
      position_group = "QB"
    ) |>
    select(dplyr::any_of(FACT_COLUMNS)) |>
    arrange(.data$season, .data$week, .data$player_id)
}

write_fact_table <- function(df, out_dir = "data/processed") {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  arrow::write_parquet(
    df,
    file.path(out_dir, "player_game_stats.parquet"),
    compression = "zstd"
  )

  manifest <- list(
    updated_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    row_count = nrow(df),
    seasons = sort(unique(df$season)),
    position_groups = unique(df$position_group),
    parquet_url = "/data/player_game_stats.parquet",
    stats_config = yaml::read_yaml("config/stats.yaml")
  )

  jsonlite::write_json(
    manifest,
    file.path(out_dir, "manifest.json"),
    auto_unbox = TRUE,
    pretty = TRUE
  )

  jsonlite::write_json(
    yaml::read_yaml("config/stats.yaml"),
    file.path(out_dir, "stats.json"),
    auto_unbox = TRUE,
    pretty = TRUE
  )
}

copy_processed_to_web <- function(
  processed_dir = "data/processed",
  web_dir = "web/public/data"
) {
  dir.create(web_dir, recursive = TRUE, showWarnings = FALSE)

  files <- c(
    "player_game_stats.parquet",
    "manifest.json",
    "stats.json"
  )

  for (file_name in files) {
    src <- file.path(processed_dir, file_name)
    if (file.exists(src)) {
      file.copy(src, file.path(web_dir, file_name), overwrite = TRUE)
    }
  }
}
