
download_usgs_station_data <- function (station_id, startDate = "1980-01-01", endDate = as.character(today())) {
  Sys.sleep(2)
  dataRetrieval::readNWISuv(
    siteNumbers = station_id,
    parameterCd = "00010",
    startDate = startDate,
    endDate = endDate
  ) |>
    as_tibble()
}

collect_usgs_stations <- function () {
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
      url = glue("https://waterdata.usgs.gov/nwis/inventory/?site_no={station_id}&agency_cd=USGS")
    )
}

collect_usgs_raw_data <- function (usgs_stations) {
  usgs_stations |>
    select(station_id) |>
    mutate(
      data = map(station_id, download_usgs_station_data)
    )
}

transform_usgs_data <- function (usgs_stations, usgs_raw_data) {
  daily_data <- usgs_raw_data |>
    rowwise() |>
    mutate(
      data = list({
        data |>
          dataRetrieval::renameNWISColumns() |>
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

  usgs_stations |>
    inner_join(
      daily_data,
      by = c("station_id")
    )
}
