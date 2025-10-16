download_usgs_station_data <- function(
  station_ids,
  start_date = "1950-01-01",
  end_date = as.character(today())
) {
  Sys.sleep(1)
  dataRetrieval::read_waterdata_daily(
    monitoring_location_id = paste0("USGS-", station_ids),
    parameter_code = "00010", # water temperature, degrees C
    statistic_id = "00003", # mean
    skipGeometry = TRUE,
    properties = c("monitoring_location_id", "time", "value", "qualifier", "approval_status", "last_modified"),
    limit = NA,
    time = glue("{start_date}/{end_date}")
  )
}

collect_usgs_stations <- function() {
  # fetch locations
  api_locations <- dataRetrieval::read_waterdata_monitoring_location(
    agency_code = "USGS",
    state_code = "02",
    site_type_code = "ST"
  )

  # extract bbox
  bbox <- st_bbox(api_locations)

  # fetch timeseries metadata within bbox for daily mean water temp (C)
  # NOTE: IV data no longer available in waterdata API (only latest continuous)
  api_ts <- dataRetrieval::read_waterdata_ts_meta(
    parameter_code = "00010", # water temperature, degrees C
    statistic_id = c("00003"), # mean
    bbox = bbox
  )
  # mapview::mapview(api_ts, zcol = "statistic_id")

  api_locations |>
    mutate(
      latitude = st_coordinates(geometry)[, 2],
      longitude = st_coordinates(geometry)[, 1],
    ) |> 
    st_drop_geometry() |>
    filter(monitoring_location_id %in% api_ts$monitoring_location_id) |>
    transmute(
      provider_station_code = glue("USGS:{monitoring_location_number}"),
      station_id = monitoring_location_number,
      station_code = monitoring_location_number,
      station_description = monitoring_location_name,
      waterbody_name = monitoring_location_name,
      latitude,
      longitude,
      provider_code = "USGS",
      provider_name = "U.S. Geological Survey",
      url = glue(
        "https://waterdata.usgs.gov/monitoring-location/{monitoring_location_id}"
      )
    )
}

collect_usgs_raw_data <- function(usgs_stations, start_date = "1950-01-01", end_date = as.character(today())) {
  n_per_group <- 10
  group_stations <- split(usgs_stations$station_id, (seq_along(usgs_stations$station_id) - 1) %/% n_per_group)
  group_data <- map(group_stations, function(station_ids) {
    download_usgs_station_data(station_ids, start_date = start_date, end_date = end_date)
  }, .progress = TRUE)
  bind_rows(group_data)
}

transform_usgs_data <- function(usgs_raw_data) {
  usgs_raw_data |> 
    transmute(
      station_id = str_remove(monitoring_location_id, "USGS-"),
      date = time,
      mean_temp_c = value
    ) |> 
    nest_by(station_id) |> 
    ungroup()
}

merge_usgs_data <- function(usgs_stations, usgs_data_freeze, usgs_data_new) {
  data <- bind_rows(
    usgs_data_freeze,
    usgs_data_new
  ) |> 
    nest_by(station_id) |> 
    mutate(data = map(data, bind_rows)) |> 
    ungroup()
  usgs_stations |>
    inner_join(
      data,
      by = c("station_id")
    )
}