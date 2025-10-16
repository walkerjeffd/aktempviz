combine_wtemp <- function (usgs_data, nps_data, aktemp_data) {
  bind_rows(
    USGS = usgs_data,
    NPS = nps_data,
    AKTEMP = aktemp_data,
    .id = "dataset"
  ) |> 
    mutate(n = map_int(data, nrow)) |>
    filter(n > 0) |> 
    select(-n)
}

pair_wtemp_atemp <- function (wtemp_data, era5_data) {
  atemp_data <- era5_data[["data"]] |> 
    summarise(
      atemp_data = list(bind_rows(data)),
      .by = c("dataset", "provider_station_code")
    )
  wtemp_data |> 
    left_join(
      atemp_data,
      by = c("dataset", "provider_station_code")
    ) |> 
      mutate(
        data = map2(data, atemp_data, function(wtemp, atemp) {
          if (is.null(atemp) || nrow(atemp) == 0) {
            wtemp |> 
              mutate(mean_airtemp_c = NA_real_)
          } else {
            wtemp |> 
              left_join(atemp, by = "date")
          }
        })
      ) |> 
      select(-atemp_data)
}

generate_wtemp_manifest <- function (wtemp_data) {
  wtemp_data |>
    select(dataset, provider_station_code, latitude, longitude, data) |>
    mutate(
      data = map(data, function (data) {
        if (nrow(data) == 0) return(NULL)
        data |> 
          mutate(year = year(date)) |> 
          summarise(
            start_date = min(date),
            end_date = max(date),
            .by = year
          )
      })
    ) |> 
    unnest(data)
}