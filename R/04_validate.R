# Known PFR franchise career passing yards (approximate) for validation.
# Source: https://www.pro-football-reference.com/teams/jax/index.htm
PFR_CAREER_PASSING_YARDS <- c(
  "Mark Brunell" = 25698L,
  "Blake Bortles" = 19044L,
  "Trevor Lawrence" = 14000L, # lower bound; updated by ETL
  "David Garrard" = 16203L,
  "Gardner Minshew" = 5927L
)

validate_qb_passing_yards <- function(df) {
  career <- df |>
    filter(.data$position_group == "QB") |>
    group_by(.data$player_display_name) |>
    summarise(yards = sum(.data$passing_yards, na.rm = TRUE), .groups = "drop") |>
    arrange(desc(.data$yards)) |>
    slice_head(n = 10)

  cli_h2("Top 10 JAX career passing yards (computed)")
  print(career)

  for (player_name in names(PFR_CAREER_PASSING_YARDS)) {
    computed <- career$yards[career$player_display_name == player_name]
    if (length(computed) == 0) {
      next
    }

    expected <- PFR_CAREER_PASSING_YARDS[[player_name]]
    diff <- abs(computed - expected)

    if (player_name == "Trevor Lawrence") {
      if (computed < expected) {
        cli_alert_info(
          "{player_name}: computed {computed} (PFR minimum check {expected})"
        )
      } else {
        cli_alert_success("{player_name}: computed {computed}")
      }
      next
    }

    if (diff > 50) {
      cli_alert_warning(
        "{player_name}: computed {computed}, expected ~{expected} (diff {diff})"
      )
    } else {
      cli_alert_success(
        "{player_name}: computed {computed}, expected ~{expected}"
      )
    }
  }

  invisible(career)
}
