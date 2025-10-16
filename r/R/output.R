transform_output_data <- function(paired_data, station_wbd) {
  paired_data |>
    left_join(station_wbd, by = c("dataset", "station_id")) |>
    rowwise() |>
    mutate(
      data = list(select(
        data,
        date,
        temp_c = mean_temp_c,
        airtemp_c = mean_airtemp_c
      )),
      start = min(data$date),
      end = max(data$date),
      n = sum(!is.na(data$temp_c)),
      filename = glue(
        "{toupper(dataset)}_{toupper(snakecase::to_snake_case(station_id))}.json"
      )
    ) |>
    ungroup()
}

export_stations_file <- function(output_data, output_dir) {
  filename <- file.path(output_dir, "stations.json")
  output_data |>
    select(-data) |>
    write_json(filename, digits = 5)
  filename
}

export_data_files <- function(output_data, output_dir) {
  output_data_dir <- file.path(output_dir, "data")
  dir.create(output_data_dir, showWarnings = FALSE)

  map2_chr(
    output_data$filename,
    output_data$data,
    \(filename, data) {
      filename <- file.path(output_data_dir, filename)
      write_json(data, filename, digits = 5)
      filename
    }
  )
}

export_config_file <- function(config, output_dir) {
  filename <- file.path(output_dir, "config.json")
  write_json(config, filename, auto_unbox = TRUE)
  filename
}


export_wbd_json <- function(huc, id_field, output_gis_dir) {
  filepath <- file.path(output_gis_dir, glue("wbd_{id_field}.geojson"))
  if (file.exists(filepath)) {
    unlink(filepath)
  }
  huc %>%
    st_simplify(dTolerance = 100) %>%
    st_write(
      filepath,
      append = FALSE,
      quiet = TRUE,
      layer_options = c(
        "COORDINATE_PRECISION=6",
        glue("ID_FIELD={id_field}")
      )
    )
  filepath
}

export_wbd_files <- function(wbd, output_dir) {
  output_gis_dir <- file.path(output_dir, "gis")
  dir.create(output_gis_dir, showWarnings = FALSE)

  map_chr(names(wbd), \(key) export_wbd_json(wbd[[key]], key, output_gis_dir))
}
