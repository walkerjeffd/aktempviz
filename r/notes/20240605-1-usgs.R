# USGS NWIS dataset

library(tidyverse)
library(janitor)
library(jsonlite)
library(glue)
library(config)
library(sf)
library(mapview)
library(dataRetrieval)
library(nhdplusTools)


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

# waterbody names from gnis_name (doesn't work for AK)
get_gnis_name <- function (station_id, latitude, longitude) {
  cat(station_id, latitude, longitude, "\n")
  nldi_feature <- findNLDI(nwis = station_id)
  if (is.null(nldi_feature$comid) || nrow(nldi_feature) == 0) {
    cat('trying lat/lon\n')
    nldi_feature <- findNLDI(location = c(longitude, latitude))
  }
  if (is.null(nldi_feature$comid) || is.na(nldi_feature$comid[[1]])) {
    return(NA_character_)
  }
  comid <- nldi_feature$comid[[1]]
  flowline <- get_nhdplus(comid = comid, realization = "flowline")
  flowline$gnis_name
}

# nwis_temp_stn_gnis <- nwis_temp_stn |> 
#   rowwise() |> 
#   head() |> 
#   mutate(
#     gnis_name = get_gnis_name(station_id, latitude, longitude)
#   )

nwis_temp_data_day <- nwis_temp_data |> 
  rowwise() |> 
  mutate(
    data = list({
      data |> 
        filter(!is.na(temp_c)) |>
        group_by(date = as_date(datetime)) |> 
        summarise(
          min_temp_c = min(temp_c),
          mean_temp_c = mean(temp_c),
          max_temp_c = max(temp_c)
        )
    })
  )

nwis_temp <- nwis_temp_stn |> 
  transmute(
    provider_station_code = glue("USGS:{station_id}"),
    station_id,
    station_code = station_id,
    station_description = name,
    waterbody_name = name,
    latitude, longitude,
    provider_code = "USGS",
    provider_name = "U.S. Geological Survey",
    url = glue("https://waterdata.usgs.gov/nwis/inventory/?site_no={station_id}&agency_cd=USGS")
  ) |> 
  inner_join(
    nwis_temp_data_day,
    by = c("station_id")
  )

write_rds(nwis_temp, "data/usgs.rds")
