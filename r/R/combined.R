extract_station_tile_years <- function(combined_data) {
  combined_data |>
    select(dataset, station_id, latitude, longitude, data) |>
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |>
    st_join(
      daymetr::tile_outlines |>
        select(TileID)
    ) |>
    st_drop_geometry() |>
    clean_names() |>
    mutate(
      data = map(data, \(x) {
        x |>
          arrange(date) |>
          distinct(year = year(date))
      })
    ) |>
    unnest(data)
}

merge_data_airtemp <- function(combined_data, airtemp) {
  combined_data |>
    left_join(
      airtemp |>
        select(dataset, station_id, daymet),
      by = c("dataset", "station_id")
    ) |>
    rowwise() |>
    mutate(
      data = list({
        x <- data |>
          complete(date = seq.Date(min(date), max(date), by = "day"))
        if (is.null(daymet) | nrow(daymet) == 0) {
          x <- x |>
            mutate(
              min_airtemp_c = NA_real_,
              max_airtemp_c = NA_real_,
              mean_airtemp_c = NA_real_
            )
        } else {
          x <- x |>
            left_join(
              daymet,
              by = "date"
            )
        }
        x
      })
    ) |>
    ungroup() |>
    select(-daymet)
}
