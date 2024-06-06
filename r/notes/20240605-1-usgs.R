# USGS NWIS dataset

library(tidyverse)
library(janitor)
library(jsonlite)
library(glue)
library(config)
library(sf)
library(mapview)
library(dataRetrieval)


nwis_download_temp <- function (station_id, startDate = "1980-01-01", endDate = as.character(today())) {
  cat("download: ", station_id, "\n")
  Sys.sleep(2)
  dataRetrieval::readNWISuv(
    siteNumbers = station_id,
    parameterCd = "00010",
    startDate = startDate,
    endDate = endDate
  ) |>
    as_tibble()
}

nwis_temp_stn_raw <- whatNWISsites(
  stateCd = "ak",
  parameterCd = "00010",
  hasDataTypeCd = "iv"
) |>
  as_tibble()

nwis_temp_stn <- nwis_temp_stn_raw |>
  filter(site_tp_cd %in% c("ST")) |>
  transmute(
    station_id = site_no,
    name = station_nm,
    type = fct_recode(site_tp_cd, stream = "ST"),
    latitude = dec_lat_va,
    longitude = dec_long_va
  )

nwis_temp_stn_sf <- nwis_temp_stn |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

mapview(nwis_temp_stn_sf)

nwis_temp_data_raw <- nwis_temp_stn |> 
  select(station_id) |> 
  mutate(
    data = map(station_id, nwis_download_temp)
  )
write_rds(nwis_temp_data_raw, "data/usgs-raw.rds")

nwis_temp_data_raw$data[[1]]

nwis_temp_data <- nwis_temp_data_raw |>
  rowwise() |> 
  mutate(
    data = list({
      data |> 
        dataRetrieval::renameNWISColumns() |> 
        mutate(dateTime = with_tz(dateTime, tzone = "US/Alaska")) |> 
        select(
          datetime = dateTime,
          temp_c = Wtemp_Inst,
          code = Wtemp_Inst_cd
        ) |> 
        filter(!is.na(temp_c))
    })
  )

nwis_temp <- nwis_temp_stn |> 
  inner_join(
    nwis_temp_data,
    by = c("station_id")
  )

write_rds(nwis_temp, "data/usgs.rds")
