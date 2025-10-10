download_usgs_station_data <- function(
  station_id,
  start_date = "1980-01-01",
  end_date = as.character(today())
) {
  Sys.sleep(2)
  dataRetrieval::readNWISuv(
    siteNumbers = station_id,
    parameterCd = "00010",
    startDate = start_date,
    endDate = end_date
  ) |>
    as_tibble()
}

collect_usgs_stations <- function() {
  raw <- dataRetrieval::whatNWISsites(
    stateCd = "ak",
    parameterCd = "00010",
    hasDataTypeCd = "iv"
  ) |>
    as_tibble()

  raw |>
    filter(site_tp_cd %in% c("ST")) |>
    transmute(
      provider_station_code = glue("USGS:{site_no}"),
      station_id = site_no,
      station_code = station_id,
      station_description = station_nm,
      waterbody_name = station_nm,
      latitude = dec_lat_va,
      longitude = dec_long_va,
      provider_code = "USGS",
      provider_name = "U.S. Geological Survey",
      url = glue(
        "https://waterdata.usgs.gov/nwis/inventory/?site_no={station_id}&agency_cd=USGS"
      )
    )
}

collect_usgs_raw_data <- function(usgs_stations, start_date = "1980-01-01", end_date = as.character(today())) {
  usgs_stations |>
    select(station_id) |>
    mutate(
      data = map(station_id, ~ download_usgs_station_data(.x, start_date = start_date, end_date = end_date))
    )
}

transform_usgs_data <- function(usgs_raw_data) {
  usgs_raw_data |>
    mutate(
      data = map(data, function (data) {
        if (nrow(data) == 0) {
          return(tibble())
        }
        data |>
          dataRetrieval::renameNWISColumns() |>
          rename_at(vars(starts_with("Primary_")), ~ str_remove_all(., "Primary_")) |> 
          mutate(dateTime = with_tz(dateTime, tzone = "America/Anchorage")) |>
          select(
            datetime = dateTime,
            temp_c = Wtemp_Inst,
            code = Wtemp_Inst_cd
          ) |>
          filter(!is.na(temp_c)) |>
          group_by(date = as_date(datetime)) |>
          summarise(
            min_temp_c = min(temp_c),
            mean_temp_c = mean(temp_c),
            max_temp_c = max(temp_c)
          )
      })
    )
}
