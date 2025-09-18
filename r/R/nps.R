extract_dataset_metric <- function(x) {
  # dataset_identifier = "Water Temp.Annual Max Temp@DENA-001"
  y <- x |>
    str_remove_all("Water Temp.") |>
    str_split("@") |>
    flatten_chr()
  y[1]
}

collect_nps_datasets <- function(metrics) {
  response <- request("https://irma.nps.gov/AQWebPortal/Data/Data_List") |>
    req_method("POST") |>
    req_body_raw(
      "sort=Sequence-desc&page=1&pageSize=10000&group=&filter=&dataFilters=Location-Latitude~gt~50&spatialFilterRings=&spatialFilterWkid=&interval=Latest&date=2024-06-05&endDate=&parameters%5B0%5D=119&value=Location_4&type=Location&subValue=&subValueType=&refPeriod=&calendar=1&legend=-12&legendFilter%5B0%5D=-1&utcOffset=240&folder="
    ) |>
    req_headers("Content-Type" = "application/x-www-form-urlencoded") |>
    # req_dry_run() |>
    req_perform() |>
    resp_body_json(simplifyVector = TRUE)

  response[["Data"]] |>
    as_tibble() |>
    clean_names() |>
    mutate(
      metric = map_chr(dataset_identifier, extract_dataset_metric)
    ) |>
    filter(
      location_folder !=
        "National Park Service.Water Resources Division.Reflected USGS Gage",
      loc_type != "Lake",
      (metric %in% metrics | str_starts(metric, "Temp, °C "))
    )
}

transform_nps_datasets <- function(nps_datasets) {
  nps_datasets |>
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
      url = glue(
        "https://irma.nps.gov/AQWebPortal/Data/Location/Summary/Location/{location_identifier}"
      ),
    )
}

download_nps_dataset_data <- function(dataset) {
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

parse_nps_dataset_data <- function(raw_data) {
  read_csv(
    raw_data,
    col_names = c("start", "end", "mean_temp_c"),
    col_types = cols(
      .default = col_character(),
      start = col_datetime(),
      end = col_datetime(),
      mean_temp_c = col_double()
    ),
    skip = 5
  ) |>
    transmute(
      date = as_date(start),
      mean_temp_c
    ) |>
    filter(!is.na(mean_temp_c)) |>
    arrange(date)
}

collect_nps_dataset_data <- function(dataset) {
  raw_data <- download_nps_dataset_data(dataset)
  parse_nps_dataset_data(raw_data)
}

collect_nps_raw_data <- function(datasets) {
  datasets |>
    mutate(
      data = map(dataset_identifier, collect_nps_dataset_data)
    ) |>
    select(location_identifier, data)
}

transform_nps_data <- function(nps_stations, nps_datasets) {
  nps_stations |>
    left_join(
      nps_datasets,
      by = c("station_id" = "location_identifier")
    )
}
