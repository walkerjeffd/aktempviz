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

datasets_url <- "https://irma.nps.gov/AQWebPortal/Data/Data_List?sort=Sequence-desc&page=1&pageSize=10000&group=&filter=&dataFilters=Location-Latitude~gt~50&spatialFilterRings=&spatialFilterWkid=&interval=Latest&date=2024-06-05&endDate=&parameters%5B0%5D=119&value=Location_4&type=Location&subValue=&subValueType=&refPeriod=&calendar=1&legend=-12&legendFilter%5B0%5D=-1&utcOffset=240&folder="

datasets_response <- request(datasets_url) |> 
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
    (metric %in% c("Temp") | str_starts(metric, "Temp, °C "))
  )

tabyl(datasets, location_identifier)
tabyl(datasets, metric)


# fetch data --------------------------------------------------------------

download_nps_data <- function (dataset_id) {
  # https://irma.nps.gov/AQWebPortal/Export/DataSet?DataSet=Water%20Temp.Temp%2C%20%C2%B0C%20(LGR%20S%2FN%3A%202003431%2C%20SEN%20S%2FN%3A%202003431)%40WRST-004&Calendar=CALENDARYEAR&UnitID=171&Conversion=Instantaneous&IntervalPoints=PointsAsRecorded&ApprovalLevels=True&Qualifiers=False&Step=1&ExportFormat=csv&Compressed=false&RoundData=False&GradeCodes=True&InterpolationTypes=False&Timezone=0&_=1717608481057
  url <- url_parse("https://irma.nps.gov/AQWebPortal/Export/DataSet")
  url$query <- list(
    DataSet = dataset_id,
    UnitID = "171",
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
    data = map(dataset_identifier, download_nps_data, .progress = TRUE)
  )
write_rds(datasets_data_raw, "data/nps-raw.rds")

datasets_data <- datasets_data_raw |> 
  rowwise() |> 
  mutate(
    data = list({
      read_csv(
        data, 
        col_names = c("datetime", "temp_c", "grade_code", "approval_level", "qualifier"), 
        col_types = cols(.default = col_character(), datetime = col_datetime(), temp_c = col_double()), 
        skip = 5
      ) |> 
        mutate(
          datetime = with_tz(datetime, "US/Alaska")
        )
    })
  )

datasets_grades <- datasets_data |>
  rowwise() |> 
  mutate(
    grades = list({
      tabyl(data, grade_code)
    })
  ) |> 
  select(dataset_identifier, grades) |> 
  unnest(grades)

datasets_approval <- datasets_data |>
  rowwise() |> 
  mutate(
    data = list({
      tabyl(data, approval_level)
    })
  ) |> 
  select(dataset_identifier, data) |> 
  unnest(data)

nps_data <- datasets_data |>
  transmute(
    station_id = glue("NPS:{location_identifier}"),
    description = location,
    latitude = loc_y,
    longitude = loc_x,
    data_inst = list(data)
  ) |> 
  rowwise() |> 
  mutate(
    data_daily = list({
      data_inst |> 
        filter(!is.na(temp_c)) |> 
        group_by(date = as_date(datetime)) |> 
        summarise(
          n_values = n(),
          min_temp_c = min(temp_c),
          mean_temp_c = mean(temp_c),
          max_temp_c = max(temp_c)
        ) |> 
        arrange(date)
    })
  )

nps_data |> 
  select(station_id, data_daily) |> 
  unnest(data_daily) |>
  ggplot(aes(date, mean_temp_c)) +
  geom_ribbon(aes(ymin = min_temp_c, ymax = max_temp_c), alpha = 0.2) +
  geom_line() +
  facet_wrap(vars(station_id)) +
  theme_bw()

nps_data |> 
  select(station_id, data_daily) |> 
  unnest(data_daily) |>
  ggplot(aes(ymd(20001231) + days(yday(date)), mean_temp_c)) +
  geom_line(aes(group = year(date))) +
  facet_wrap(vars(station_id)) +
  theme_bw()

nps_data |> 
  select(station_id, data_daily) |> 
  unnest(data_daily) |>
  ggplot(aes(ymd(20001231) + days(yday(date)), mean_temp_c)) +
  geom_hex(bins = 100) +
  scale_fill_viridis_c()

nps_data |> 
  write_rds("data/nps.rds")
