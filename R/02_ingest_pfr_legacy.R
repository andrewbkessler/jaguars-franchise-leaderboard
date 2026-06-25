ingest_pfr_legacy_qb <- function() {
  files <- list.files("data/raw/pfr", pattern = "jax_.*_passing\\.csv", full.names = TRUE)

  if (length(files) == 0) {
    cli_alert_warning("No PFR legacy passing CSVs found in data/raw/pfr/")
    return(tibble::tibble())
  }

  path <- download_nflverse_parquet("players", "players.parquet", "data/cache")
  players <- arrow::read_parquet(path) |>
    transmute(
      player_id = .data$gsis_id,
      pfr_id = .data$pfr_id,
      birth_date = lubridate::as_date(.data$birth_date),
      position = .data$position
    )

  raw <- lapply(files, read.csv, stringsAsFactors = FALSE) |>
    dplyr::bind_rows()

  raw |>
    left_join(players, by = "pfr_id") |>
    mutate(
      player_display_name = .data$player_name,
      team = TEAM,
      opponent_team = NA_character_,
      game_id = NA_character_,
      game_date = as.Date(paste0(.data$season, "-09-01")),
      week = NA_integer_,
      season_type = "REG",
      is_home = NA,
      position = dplyr::coalesce(.data$position, "QB"),
      age_at_game = calc_age_at_game(.data$birth_date, .data$game_date),
      source = "pfr_season",
      passing_epa = NA_real_,
      passing_air_yards = NA_real_,
      passing_yards_after_catch = NA_real_,
      passing_first_downs = NA_real_,
      sack_yards_lost = NA_integer_,
      passing_2pt_conversions = NA_integer_,
      sacks_suffered = dplyr::coalesce(.data$sacks_suffered, NA_integer_)
    )
}
