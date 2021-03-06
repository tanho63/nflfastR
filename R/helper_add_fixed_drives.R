################################################################################
# Author: Sebastian Carl, Ben Baldwin
# Purpose: Function to add drive variables
# Code Style Guide: styler::tidyverse_style()
################################################################################

## fixed_drive =
##  starts at 1, each new drive, numbers shared across both teams
## fixed_drive_result =
##  result of  given drive

#' @import dplyr
#' @importFrom rlang .data
#' @importFrom stats na.omit
add_drive_results <- function(d) {
  drive_df <- d %>%
    dplyr::group_by(.data$game_id, .data$game_half) %>%
    dplyr::mutate(
      row = 1:dplyr::n(),
      new_drive = dplyr::if_else(
        # change in posteam
        .data$posteam != dplyr::lag(.data$posteam) |
          # change in posteam in t-2 and na posteam in t-1
          (.data$posteam != dplyr::lag(.data$posteam, 2) & is.na(dplyr::lag(.data$posteam))) |
          # change in posteam in t-3 and na posteam in t-1 and t-2
          (.data$posteam != dplyr::lag(.data$posteam, 3) & is.na(dplyr::lag(.data$posteam, 2)) & is.na(dplyr::lag(.data$posteam))),
        1, 0
      ),
      # PAT after defensive TD is not a new drive
      new_drive = dplyr::if_else(
        dplyr::lag(.data$touchdown == 1) &
          (dplyr::lag(.data$posteam) != dplyr::lag(.data$td_team))
          # this last part is needed because otherwise it was overwriting
          # the existing value of new_drive with NA on plays following timeouts
          & !is.na(dplyr::lag(.data$posteam)),
        0,
        .data$new_drive),
      # if same team has the ball as prior play, but prior play was a punt with lost fumble, it's a new drive
      new_drive = dplyr::if_else(
        # this line is to prevent it from overwriting already-defined new drives with NA
        # when there's a timeout on prior line
        .data$new_drive != 1 &
          # same team has ball after lost fumble on punt
          .data$posteam == dplyr::lag(.data$posteam) & dplyr::lag(.data$fumble_lost == 1) & dplyr::lag(.data$play_type) == "punt",
        1, .data$new_drive
      ),
      # first observation of a half is also a new drive
      new_drive = dplyr::if_else(.data$row == 1, 1, .data$new_drive),
      # if there's a missing, make it not a new drive (0)
      new_drive = dplyr::if_else(is.na(.data$new_drive), 0, .data$new_drive)
    ) %>%
    dplyr::group_by(.data$game_id) %>%
    dplyr::mutate(
      fixed_drive = cumsum(.data$new_drive),
      tmp_result = dplyr::case_when(
        .data$touchdown == 1 & .data$posteam == .data$td_team ~ "Touchdown",
        .data$touchdown == 1 & .data$posteam != .data$td_team ~ "Opp touchdown",
        .data$field_goal_result == "made" ~ "Field goal",
        .data$field_goal_result %in% c("blocked", "missed") ~ "Missed field goal",
        .data$safety == 1 ~ "Safety",
        .data$play_type == "punt" | .data$punt_attempt == 1 ~ "Punt",
        .data$interception == 1 | .data$fumble_lost == 1 ~ "Turnover",
        .data$down == 4 & .data$yards_gained < .data$ydstogo & .data$play_type != "no_play" ~ "Turnover on downs",
        .data$desc %in% c("END GAME", "END QUARTER 2", "END QUARTER 4") ~ "End of half"
      )
    ) %>%
    dplyr::group_by(.data$game_id, .data$fixed_drive) %>%
    dplyr::mutate(
      fixed_drive_result =
        dplyr::if_else(
          # if it's end of half, take the first thing we see
          dplyr::last(stats::na.omit(.data$tmp_result)) == "End of half",
          dplyr::first(stats::na.omit(.data$tmp_result)),
          # otherwise take the last
          dplyr::last(stats::na.omit(.data$tmp_result))
        )
    ) %>%
    dplyr::ungroup() %>%
    dplyr::select(-"row", -"new_drive", -"tmp_result")

  usethis::ui_done("added fixed drive variables")
  return(drive_df)
}
