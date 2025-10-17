library(targets)

tar_source(list.files("R", pattern = "\\.R$", full.names = TRUE))

if (file.exists(".env")) {
  dotenv::load_dot_env(".env")
}

# sets GCS_AUTH_FILE to tempfile using GCS_AUTH_JSON=$(cat service-account.json | base64)
init_gcs_auth()

tar_option_set(
  packages = c(
    "tidyverse",
    "glue",
    "janitor",
    "sf",
    "httr2",
    "jsonlite",
    "logger"
  ),
  repository = "gcp",
  repository_meta = "gcp",
  resources = tar_resources(
    gcp = tar_resources_gcp(
      bucket = Sys.getenv("GCS_BUCKET"),
      prefix = "targets",
      predefined_acl = "bucketLevel",
      verbose = FALSE
    )
  )
)

if (interactive()) {
  sapply(tar_option_get("packages"), require, character.only = TRUE)
}

mkdirp <- function(x) {
  dir.create(x, recursive = TRUE, showWarnings = FALSE)
  x
}

logger::log_threshold(Sys.getenv("LOG_LEVEL", unset = "INFO"))

# Define pipeline
list(
  tar_target(data_dir, "data"),
  tar_target(gis_dir, mkdirp(file.path(data_dir, "gis"))),
  tar_target(era5_dir, mkdirp(file.path(data_dir, "era5"))),
  tar_target(output_dir, mkdirp(file.path(data_dir, "output"))),

  tar_target(
    wbd_file,
    file.path(gis_dir, "WBD_19_HU2_GDB", "WBD_19_HU2_GDB.gdb")
  ),
  tar_target(wbd, load_wbd(wbd_file)),
  
  tar_target(usgs_freeze_start_date, "1950-01-01"),
  tar_target(usgs_freeze_end_date, "2024-12-31"),
  tar_target(usgs_new_start_date, as.character(lubridate::ymd(usgs_freeze_end_date) + 1)),
  tar_target(usgs_stations, collect_usgs_stations()),
  tar_target(usgs_raw_data_freeze, {
    usgs_stations <- collect_usgs_stations()
    collect_usgs_raw_data(
      usgs_stations,
      start_date = usgs_freeze_start_date,
      end_date = usgs_freeze_end_date
    )
  }),
  tar_target(usgs_raw_data_new, collect_usgs_raw_data(usgs_stations, start_date = usgs_new_start_date)),
  tar_target(usgs_data_freeze, transform_usgs_data(usgs_raw_data_freeze)),
  tar_target(usgs_data_new, transform_usgs_data(usgs_raw_data_new)),
  tar_target(usgs_data, merge_usgs_data(usgs_stations, usgs_data_freeze, usgs_data_new)),

  tar_target(nps_freeze_start_date, "2008-01-01"),
  tar_target(nps_freeze_end_date, usgs_freeze_end_date),
  tar_target(nps_new_start_date, as.character(lubridate::ymd(nps_freeze_end_date) + 1)),
  tar_target(
    nps_metrics,
    c(
      "Temp",
      "Stream_Water",
      "Stream_Water_A",
      "Water_Temperature",
      "continuous_wq_temp"
    )
  ),
  tar_target(nps_datasets, collect_nps_datasets(nps_metrics)),
  tar_target(nps_stations, transform_nps_datasets(nps_datasets)),
  tar_target(nps_raw_data, collect_nps_raw_data(nps_datasets), error = "continue"),
  tar_target(nps_data, transform_nps_data(nps_stations, nps_raw_data)),

  tar_target(aktemp_raw_data, collect_aktemp_raw_data()),
  tar_target(aktemp_data, transform_aktemp_data(aktemp_raw_data)),

  # water temperature dataset
  tar_target(wtemp_data, combine_wtemp(usgs_data, nps_data, aktemp_data)),
  tar_target(wtemp_manifest, generate_wtemp_manifest(wtemp_data)),

  # air temperature dataset
  tar_target(era5_data, fetch_era5_data(wtemp_manifest)),

  # paired datasets
  tar_target(paired_data, pair_wtemp_atemp(wtemp_data, era5_data)),
  tar_target(station_wbd, extract_station_wbd(paired_data, wbd)),

  # output files
  tar_target(output_data, transform_output_data(paired_data, station_wbd)),
  tar_target(
    output_stations_file,
    export_stations_file(output_data, output_dir)
  ),
  tar_target(
    output_data_files,
    export_data_files(output_data, output_dir)
  ),
  tar_target(
    output_config,
    list(
      era5_last_date = as.character(era5_data$last_date),
      last_updated = format_ISO8601(
        with_tz(Sys.time(), tzone = "America/Anchorage"),
        usetz = TRUE
      )
    )
  ),
  tar_target(
    output_config_file,
    export_config_file(output_config, output_dir)
  ),
  tar_target(
    output_wbd_files,
    export_wbd_files(wbd, output_dir)
  )
)
