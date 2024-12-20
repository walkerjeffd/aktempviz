# NPS Dataset via Aquarius Web Portal

library(tidyverse)
library(janitor)
library(httr2)
library(jsonlite)
library(glue)
library(config)
library(sf)
library(mapview)


# functions ---------------------------------------------------------------

# dataset_identifier = "Water Temp.Annual Max Temp@DENA-001"
extract_dataset_metric <- function (x) {
  y <- x |> 
    str_remove_all("Water Temp.") |> 
    str_split("@") |> 
    flatten_chr()
  y[1]
}

# fetch: datasets ---------------------------------------------------------

datasets_response <- request("https://irma.nps.gov/AQWebPortal/Data/Data_List") |> 
  req_method("POST") |> 
  req_body_raw("sort=Sequence-desc&page=1&pageSize=10000&group=&filter=&dataFilters=Location-Latitude~gt~50&spatialFilterRings=&spatialFilterWkid=&interval=Latest&date=2024-06-05&endDate=&parameters%5B0%5D=119&value=Location_4&type=Location&subValue=&subValueType=&refPeriod=&calendar=1&legend=-12&legendFilter%5B0%5D=-1&utcOffset=240&folder=") |> 
  req_headers("Content-Type" = "application/x-www-form-urlencoded") |> 
  # req_dry_run() |> 
  req_perform() |> 
  resp_body_json(simplifyVector = TRUE)

datasets_all <- datasets_response$Data |> 
  as_tibble() |> 
  clean_names() |> 
  mutate(
    metric = map_chr(dataset_identifier, extract_dataset_metric)
  ) |> 
  print()

glimpse(datasets_all)
tabyl(datasets_all, loc_type)
tabyl(datasets_all, location_folder)
tabyl(datasets_all, metric)

datasets_all |> 
  st_as_sf(coords = c("loc_x", "loc_y"), crs = 4326) |> 
  mapview(zcol = "loc_type")

datasets_all |> 
  filter(loc_type != "Lake") |>
  st_as_sf(coords = c("loc_x", "loc_y"), crs = 4326) |> 
  mapview(zcol = "location_folder")

datasets_all |> 
  filter(location_folder == "National Park Service.Water Resources Division.Reflected USGS Gage") |> 
  tabyl(location_identifier)


# filter: datasets --------------------------------------------------------

# filter:
#   location_folder != "National Park Service.Water Resources Division.Reflected USGS Gage" (USGS gages, though not all are on NWIS)
#   loc_type != "Lake" (streams only)
#   metric IN (Daily Mean)

datasets_all |> 
  filter(
    location_folder != "National Park Service.Water Resources Division.Reflected USGS Gage",
    loc_type != "Lake"
  ) |> 
  tabyl(metric)

datasets <- datasets_all |> 
  filter(
    location_folder != "National Park Service.Water Resources Division.Reflected USGS Gage",
    loc_type != "Lake",
    (metric %in% c("Temp", "Stream_Water", "Stream_Water_A", "Water_Temperature", "continuous_wq_temp") | str_starts(metric, "Temp, °C "))
  )

tabyl(datasets, location_identifier)
tabyl(datasets, metric)

stopifnot(all(!duplicated(datasets$location_identifier)))

datasets |> 
  st_as_sf(coords = c("loc_x", "loc_y"), crs = 4326) |> 
  mapview(zcol = "location_folder", layer.name = "folder")

# fetch data --------------------------------------------------------------

download_nps_data_day <- function (dataset) {
  # https://irma.nps.gov/AQWebPortal/Export/DataSet?
  # DataSet=Water%20Temp.Stream_Water_A%40LACL_TLIKR_STREAM
  # &Calendar=CALENDARYEAR
  # &DateRange=EntirePeriodOfRecord
  # &UnitID=171
  # &Conversion=Aggregate
  # &IntervalPoints=Daily
  # &ApprovalLevels=False
  # &Qualifiers=False
  # &Step=1
  # &ExportFormat=csv
  # &Compressed=false
  # &RoundData=False
  # &GradeCodes=False
  # &InterpolationTypes=False
  # &Timezone=-8&_=1727886718067
  
  url <- url_parse("https://irma.nps.gov/AQWebPortal/Export/DataSet")
  url$query <- list(
    DataSet = dataset,
    DateRange = "EntirePeriodOfRecord",
    # UnitID = "171",
    Conversion = "Aggregate",
    IntervalPoints = "Daily",
    ApprovalLevels = "False",
    Qualifiers = "False",
    Step = "1",
    ExportFormat = "csv",
    Compressed = "false",
    RoundData = "False",
    GradeCodes = "False",
    InterpolationTypes = "False",
    Timezone = "0"
  )
  resp <- url_build(url) |> 
    request() |> 
    req_perform()
  Sys.sleep(2)
  resp_body_string(resp)
}

parse_nps_data_day <- function (x) {
  read_csv(
    x, 
    col_names = c("start", "end", "mean_temp_c"),
    col_types = cols(.default = col_character(), start = col_datetime(), end = col_datetime(), mean_temp_c = col_double()), 
    skip = 5
  ) |> 
    transmute(
      date = as_date(start),
      mean_temp_c
    ) |> 
    filter(!is.na(mean_temp_c)) |> 
    arrange(date)
}

download_nps_data_inst <- function (dataset) {
  # https://irma.nps.gov/AQWebPortal/Export/DataSet?DataSet=Water%20Temp.Temp%2C%20%C2%B0C%20(LGR%20S%2FN%3A%202003431%2C%20SEN%20S%2FN%3A%202003431)%40WRST-004&Calendar=CALENDARYEAR&UnitID=171&Conversion=Instantaneous&IntervalPoints=PointsAsRecorded&ApprovalLevels=True&Qualifiers=False&Step=1&ExportFormat=csv&Compressed=false&RoundData=False&GradeCodes=True&InterpolationTypes=False&Timezone=0&_=1717608481057
  # https://irma.nps.gov/AQWebPortal/Export/DataSet?
  #   DataSet=Water%20Temp.Stream_Water_A%40LACL_TLIKR_STREAM&
  #   Calendar=CALENDARYEAR&
  #   DateRange=EntirePeriodOfRecord&
  #   UnitID=171&
  #   Conversion=Instantaneous&
  #   IntervalPoints=PointsAsRecorded&
  #   ApprovalLevels=False&
  #   Qualifiers=False&
  #   Step=1&
  #   ExportFormat=csv&
  #   Compressed=false&
  #   RoundData=False&
  #   GradeCodes=False&
  #   InterpolationTypes=False&
  #   Timezone=-8&
  #   _=1727886157212
  
  # https://irma.nps.gov/AQWebPortal/Export/Dataset?Dataset=Water%20Temp.Stream_Water_A@LACL_TLIKR_STREAM&DateRange=EntirePeriodOfRecord&ExportFormat=csv
  url <- url_parse("https://irma.nps.gov/AQWebPortal/Export/DataSet")
  url$query <- list(
    DataSet = dataset,
    DateRange = "EntirePeriodOfRecord",
    # UnitID = "171",
    Conversion = "Instantaneous",
    IntervalPoints = "PointsAsRecorded",
    ApprovalLevels = "True",
    Qualifiers = "True",
    Step = "1",
    ExportFormat = "csv",
    Compressed = "false",
    RoundData = "False",
    GradeCodes = "True",
    InterpolationTypes = "False",
    Timezone = "0"
  )
  resp <- url_build(url) |> 
    request() |> 
    req_perform()
  Sys.sleep(2)
  resp_body_string(resp)
}

datasets_data_raw <- datasets |>
  mutate(
    data = map(dataset_identifier, download_nps_data_day, .progress = TRUE)
  )
write_rds(datasets_data_raw, "data/nps-raw.rds")

datasets_data_raw <- read_rds("data/nps-raw.rds")

datasets_data <- datasets_data_raw |> 
  mutate(data = map(data, parse_nps_data_day))

# datasets_grades <- datasets_data |>
#   rowwise() |> 
#   mutate(
#     grades = list({
#       tabyl(data, grade_code)
#     })
#   ) |> 
#   select(dataset_identifier, grades) |> 
#   unnest(grades)
# 
# datasets_approval <- datasets_data |>
#   rowwise() |> 
#   mutate(
#     data = list({
#       tabyl(data, approval_level)
#     })
#   ) |> 
#   select(dataset_identifier, data) |> 
#   unnest(data)

nps_data <- datasets_data |>
  transmute(
    provider_station_code = glue("NPS:{location_identifier}"),
    station_id = location_identifier,
    station_code = station_id,
    station_description = location,
    waterbody_name = location,
    latitude = loc_y,
    longitude = loc_x,
    provider_code = "NPS",
    provider_name = "National Park Service",
    url = glue("https://irma.nps.gov/AQWebPortal/Data/Location/Summary/Location/{location_identifier}"),
    data
  )

nps_data |> 
  select(station_id, data) |> 
  unnest(data) |>
  ggplot(aes(date, mean_temp_c)) +
  geom_line() +
  facet_wrap(vars(station_id)) +
  theme_bw()

nps_data |> 
  select(station_id, data) |> 
  unnest(data) |>
  ggplot(aes(ymd(20001231) + days(yday(date)), mean_temp_c)) +
  geom_line(aes(group = year(date))) +
  facet_wrap(vars(station_id)) +
  theme_bw()

nps_data |> 
  select(station_id, data) |> 
  unnest(data) |>
  ggplot(aes(ymd(20001231) + days(yday(date)), mean_temp_c)) +
  geom_hex(bins = 100) +
  scale_fill_viridis_c()

nps_data |> 
  write_rds("data/nps.rds")
