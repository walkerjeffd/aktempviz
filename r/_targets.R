library(targets)

tar_source(list.files("R", pattern = "\\.R$", full.names = TRUE))

tar_option_set(
  packages = c(
    "tidyverse", "glue", "janitor", "sf", "httr2", "jsonlite", "logger"
  )
)

mkdirp <- function (x) {
  dir.create(x, recursive = TRUE, showWarnings = FALSE)
  x
}

logger::log_threshold(Sys.getenv("LOG_LEVEL", unset = "INFO"))

# Define pipeline
list(
  tar_target(data_dir, Sys.getenv("AKTEMPVIZ_DATA_DIR", unset = "data"), cue = tar_cue("always")),
  tar_target(gis_dir, mkdirp(file.path(data_dir, "gis"))),
  tar_target(daymet_dir, mkdirp(file.path(data_dir, "daymet"))),
  tar_target(output_dir, mkdirp(file.path(data_dir, "output"))),
  
  tar_target(
    wbd_file, 
    file.path(gis_dir, "WBD_19_HU2_GDB", "WBD_19_HU2_GDB.gdb"),
    format = "file"
  ),
  tar_target(wbd, load_wbd(wbd_file)),
  
  tar_target(usgs_stations, collect_usgs_stations()),
  tar_target(usgs_raw_data, collect_usgs_raw_data(usgs_stations)),
  tar_target(usgs_data, transform_usgs_data(usgs_stations, usgs_raw_data)),
  
  tar_target(
    nps_metrics,
    c("Temp", "Stream_Water", "Stream_Water_A", "Water_Temperature", "continuous_wq_temp")
  ),
  tar_target(nps_datasets, collect_nps_datasets(nps_metrics)),
  tar_target(nps_stations, transform_nps_datasets(nps_datasets)),
  tar_target(nps_raw_data, collect_nps_raw_data(nps_datasets)),
  tar_target(nps_data, transform_nps_data(nps_stations, nps_raw_data)),
  
  tar_target(aktemp_raw_data, collect_aktemp_raw_data()),
  tar_target(aktemp_data, transform_aktemp_data(aktemp_raw_data)),
  
  tar_target(combined_data, bind_rows(
    USGS = usgs_data,
    NPS = nps_data,
    AKTEMP = aktemp_data,
    .id = "dataset"
  )),
  tar_target(
    combined_station_tile_years, 
    extract_station_tile_years(combined_data)
  ),
  tar_target(
    daymet_last_year,
    find_daymet_last_year()
  ),
  tar_target(
    daymet_tile_years, 
    extract_daymet_tile_years(combined_station_tile_years, daymet_last_year)
  ),
  tar_target(
    daymet_tile_files, 
    collect_daymet_tile_files(daymet_tile_years, daymet_dir)
  ),
  tar_target(
    airtemp,
    extract_airtemp(combined_station_tile_years, daymet_tile_files)
  ),
  
  tar_target(combined_data_airtemp, merge_data_airtemp(combined_data, airtemp)),
  tar_target(station_wbd, extract_station_wbd(combined_data, wbd)),
  tar_target(output_data, transform_output_data(combined_data_airtemp, station_wbd)),
  tar_target(
    output_stations_file, 
    export_stations_file(output_data, output_dir),
    format = "file"
  ),
  tar_target(
    output_data_files,
    export_data_files(output_data, output_dir),
    format = "file"
  ),
  tar_target(config, list(
    daymet_last_year = daymet_last_year,
    last_updated = format_ISO8601(with_tz(Sys.time(), tzone = "America/Anchorage"), usetz = TRUE)
  )),
  tar_target(
    output_config_file,
    export_config_file(config, output_dir),
    format = "file"
  ),
  tar_target(
    output_wbd_files,
    export_wbd_files(wbd, output_dir),
    format = "file"
  )
)
