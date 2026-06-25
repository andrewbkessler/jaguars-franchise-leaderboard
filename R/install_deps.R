#!/usr/bin/env Rscript

required_packages <- c(
  "nflreadr",
  "dplyr",
  "arrow",
  "lubridate",
  "jsonlite",
  "yaml",
  "cli",
  "glue",
  "tibble"
)

missing <- required_packages[
  !vapply(required_packages, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))
]

if (length(missing) > 0) {
  install.packages(missing, repos = "https://cloud.r-project.org")
}
