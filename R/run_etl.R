if (file.exists("config/stats.yaml")) {
  root <- normalizePath(getwd())
} else {
  root <- Sys.getenv("JAGS_RECORDS_ROOT", unset = NA_character_)
}

if (is.na(root) || !file.exists(file.path(root, "config", "stats.yaml"))) {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    script_path <- sub("^--file=", "", file_arg[1])
    candidate <- normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
    if (file.exists(file.path(candidate, "config", "stats.yaml"))) {
      root <- candidate
    }
  }
}

if (is.na(root) || !dir.exists(root)) {
  fallback <- normalizePath("~/jags-records", mustWork = FALSE)
  if (file.exists(file.path(fallback, "config", "stats.yaml"))) {
    root <- fallback
  }
}

if (is.na(root) || !file.exists(file.path(root, "config", "stats.yaml"))) {
  stop("Run from the jags-records directory or set JAGS_RECORDS_ROOT.")
}

setwd(root)

source("R/00_utils.R")
set_project_root()

source("R/01_ingest_nflverse.R")
source("R/02_ingest_pfr_legacy.R")
source("R/03_build_player_game.R")
source("R/04_validate.R")

cli_h1("Jaguars Records ETL")

df <- build_player_game_stats()
write_fact_table(df)
copy_processed_to_web()

cli_alert_success("Wrote {nrow(df)} rows to data/processed/player_game_stats.parquet")
validate_qb_passing_yards(df)
