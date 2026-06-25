library(dplyr)
library(lubridate)
library(yaml)
library(glue)
library(cli)

TEAM <- "JAX"
TEAM_ABBREVS <- c("JAX", "JAC")

normalize_team <- function(team) {
  dplyr::if_else(team %in% TEAM_ABBREVS, TEAM, team)
}

filter_jax_team <- function(data) {
  data |>
    filter(.data$team %in% TEAM_ABBREVS) |>
    mutate(team = TEAM)
}

read_site_config <- function() {
  yaml::read_yaml("config/site.yaml")
}

read_stats_config <- function() {
  yaml::read_yaml("config/stats.yaml")
}

calc_age_at_game <- function(birth_date, game_date) {
  as.numeric(difftime(game_date, birth_date, units = "days")) / 365.25
}

stat_columns_for <- function(stats_config, position_group) {
  stats_config$position_groups[[position_group]]$stats |>
    names()
}

has_project_root <- function(path) {
  file.exists(file.path(path, "config", "stats.yaml"))
}

project_root <- function() {
  root <- Sys.getenv("JAGS_RECORDS_ROOT", unset = NA_character_)
  if (!is.na(root) && has_project_root(root)) {
    return(normalizePath(root))
  }

  frame_files <- vapply(sys.frames(), function(env) {
    if (!is.null(env$ofile)) env$ofile else ""
  }, character(1))
  script_path <- frame_files[nzchar(frame_files)][1]
  if (!is.na(script_path) && nzchar(script_path)) {
    candidate <- normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
    if (has_project_root(candidate)) {
      return(candidate)
    }
  }

  candidates <- c(
    getwd(),
    normalizePath(file.path(getwd(), ".."), mustWork = FALSE),
    normalizePath("~/jags-records", mustWork = FALSE)
  )

  for (path in unique(candidates)) {
    if (has_project_root(path)) {
      return(normalizePath(path))
    }
  }

  stop(
    "Could not locate project root. Set JAGS_RECORDS_ROOT or run from the jags-records directory."
  )
}

set_project_root <- function() {
  root <- project_root()
  if (getwd() != root) {
    setwd(root)
  }
  invisible(root)
}
