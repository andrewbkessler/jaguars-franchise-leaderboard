NFLVERSE_BASE <- "https://github.com/nflverse/nflverse-data/releases/download"

download_nflverse_parquet <- function(release, file_name, dest_dir = tempdir()) {
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(dest_dir, file_name)
  url <- paste0(NFLVERSE_BASE, "/", release, "/", file_name)

  if (!file.exists(dest)) {
    cli_alert_info("Downloading {file_name}")
    status <- tryCatch(
      {
        utils::download.file(url, dest, mode = "wb", quiet = TRUE)
        TRUE
      },
      error = function(error) {
        cli_alert_warning("Failed to download {file_name}: {error$message}")
        FALSE
      }
    )
    if (!status || !file.exists(dest) || file.info(dest)$size == 0) {
      if (file.exists(dest)) {
        unlink(dest)
      }
      return(NA_character_)
    }
  }

  dest
}

most_recent_nflverse_season <- function() {
  as.integer(format(Sys.Date(), "%Y")) - 1L
}

load_players_arrow <- function(cache_dir = "data/cache") {
  path <- download_nflverse_parquet("players", "players.parquet", cache_dir)
  arrow::read_parquet(path) |>
    transmute(
      player_id = .data$gsis_id,
      pfr_id = .data$pfr_id,
      birth_date = lubridate::as_date(.data$birth_date),
      position = .data$position,
      position_group = .data$position_group
    )
}

load_schedules_arrow <- function(seasons, cache_dir = "data/cache") {
  path <- download_nflverse_parquet("schedules", "games.parquet", cache_dir)
  arrow::read_parquet(path) |>
    transmute(
      game_id = .data$game_id,
      game_date = lubridate::as_date(.data$gameday),
      home_team = .data$home_team,
      away_team = .data$away_team,
      season = .data$season,
      week = .data$week,
      season_type = ifelse(.data$game_type == "REG", "REG", "POST")
    ) |>
    filter(.data$season %in% seasons)
}

load_player_stats_week_arrow <- function(seasons, cache_dir = "data/cache") {
  paths <- vapply(seasons, function(season) {
    file_name <- paste0("stats_player_week_", season, ".parquet")
    download_nflverse_parquet("stats_player", file_name, cache_dir)
  }, character(1))

  paths <- paths[!is.na(paths)]

  if (length(paths) == 0) {
    stop("No weekly player stat files could be downloaded.")
  }

  arrow::open_dataset(paths, format = "parquet") |>
    dplyr::collect()
}

join_game_context <- function(stats, schedules) {
  games <- schedules |>
    filter(.data$home_team %in% TEAM_ABBREVS | .data$away_team %in% TEAM_ABBREVS) |>
    transmute(
      game_id = .data$game_id,
      game_date = .data$game_date,
      home_team = normalize_team(.data$home_team),
      away_team = normalize_team(.data$away_team),
      season = .data$season,
      week = .data$week,
      season_type = .data$season_type,
      team = TEAM,
      opponent_team = dplyr::if_else(.data$home_team %in% TEAM_ABBREVS, .data$away_team, .data$home_team),
      is_home = .data$home_team %in% TEAM_ABBREVS
    ) |>
    mutate(opponent_team = normalize_team(.data$opponent_team))

  if ("game_id" %in% names(stats)) {
    stats <- stats |>
      select(-dplyr::any_of(c(
        "game_date", "home_team", "away_team", "is_home"
      )))
  }

  stats |>
    select(-dplyr::any_of(c("game_id", "game_date", "is_home"))) |>
    left_join(
      games,
      by = c("season", "week", "season_type", "team", "opponent_team")
    )
}

ingest_nflverse_qb_nflreadr <- function(seasons = 1999:nflreadr::most_recent_season()) {
  players <- nflreadr::load_players() |>
    transmute(
      player_id = .data$gsis_id,
      pfr_id = .data$pfr_id,
      birth_date = lubridate::as_date(.data$birth_date),
      position = .data$position,
      position_group = .data$position_group
    )

  schedules <- nflreadr::load_schedules(seasons = seasons) |>
    transmute(
      game_id = .data$game_id,
      game_date = lubridate::as_date(.data$gameday),
      home_team = .data$home_team,
      away_team = .data$away_team,
      season = .data$season,
      week = .data$week,
      season_type = ifelse(.data$game_type == "REG", "REG", "POST")
    )

  qb_positions <- yaml::read_yaml("config/stats.yaml")$position_groups$QB$positions

  stats <- nflreadr::load_player_stats(seasons = seasons, summary_level = "week") |>
    filter_jax_team() |>
    filter(.data$position %in% qb_positions) |>
    filter(.data$attempts > 0 | .data$passing_yards != 0)

  stats |>
    join_game_context(schedules) |>
    left_join(players, by = "player_id", suffix = c("", "_ref")) |>
    mutate(
      age_at_game = calc_age_at_game(.data$birth_date, .data$game_date),
      source = "nflverse"
    )
}

ingest_nflverse_qb_arrow <- function(seasons = 1999:most_recent_nflverse_season()) {
  seasons <- seasons[seasons <= most_recent_nflverse_season()]

  players <- load_players_arrow()
  schedules <- load_schedules_arrow(seasons)
  qb_positions <- yaml::read_yaml("config/stats.yaml")$position_groups$QB$positions

  stats <- load_player_stats_week_arrow(seasons) |>
    filter_jax_team() |>
    filter(.data$position %in% qb_positions) |>
    filter(.data$attempts > 0 | .data$passing_yards != 0)

  stats |>
    join_game_context(schedules) |>
    left_join(players, by = "player_id", suffix = c("", "_ref")) |>
    mutate(
      age_at_game = calc_age_at_game(.data$birth_date, .data$game_date),
      source = "nflverse"
    )
}

ingest_nflverse_qb <- function(seasons = 1999:most_recent_nflverse_season()) {
  use_nflreadr <- isTRUE(as.logical(Sys.getenv("JAGS_USE_NFLREADR", "FALSE")))

  if (use_nflreadr && "nflreadr" %in% rownames(utils::installed.packages())) {
    result <- tryCatch(
      ingest_nflverse_qb_nflreadr(seasons = seasons),
      error = function(error) {
        cli_alert_warning(
          "nflreadr ingest failed ({error$message}); falling back to arrow downloads."
        )
        NULL
      }
    )
    if (!is.null(result)) {
      return(result)
    }
  } else if (!use_nflreadr) {
    cli_alert_info("Using nflverse parquet downloads (set JAGS_USE_NFLREADR=TRUE for nflreadr).")
  }

  ingest_nflverse_qb_arrow(seasons = seasons)
}
