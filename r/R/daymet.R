find_daymet_last_year <- function() {
  latitude <- 60
  longitude <- -150

  end_year <- year(today())
  start_year <- end_year - 2

  x <- daymetr::download_daymet(
    lat = latitude,
    lon = longitude,
    start = start_year,
    end = end_year,
    force = TRUE,
    silent = TRUE
  )
  last_year <- max(x$data$year)
  log_info("daymet last year: {last_year}")
  last_year
}

download_daymet_tile <- function(
  tile_id,
  year,
  param,
  daymet_dir,
  force = FALSE,
  timeout = 30
) {
  log_debug(
    "downloading daymet tile (id={tile_id}, year={year}, param={param})"
  )

  base_filename <- glue("{param}_{year}_{tile_id}")
  nc_filename <- glue("{base_filename}.nc")
  nc_filepath <- file.path(daymet_dir, nc_filename)

  tif_filename <- glue("{base_filename}.tif")
  tif_filepath <- file.path(daymet_dir, tif_filename)

  url <- glue(
    "https://thredds.daac.ornl.gov/thredds/fileServer/ornldaac/2129/tiles/{year}/{tile_id}_{year}/{param}.nc"
  )

  if (file.exists(tif_filepath)) {
    if (force) {
      log_debug("tif file ({tif_filename}) exists, deleting... (force=TRUE)")
      unlink(tif_filepath)
    } else {
      log_debug("tif file ({tif_filename}) exists, skipping...")
      return(tif_filepath)
    }
  }

  if (file.exists(nc_filepath)) {
    log_debug("nc file ({nc_filename}) exists, deleting...")
    unlink(nc_filepath)
  }

  log_info("downloading daymet tile ({nc_filename})")
  request(url) |>
    req_retry(max_tries = 5) |>
    req_timeout(timeout) |>
    req_perform(path = nc_filepath)

  if (!file.exists(nc_filepath)) {
    log_warn("failed to download nc file ({nc_filename}), skipping")
    return(NA_character_)
  }

  log_debug("converting nc file ({nc_filename}) to tif ({tif_filename})")
  daymetr::nc2tif(
    path = daymet_dir,
    files = nc_filepath,
    overwrite = TRUE,
    silent = TRUE
  )

  if (!file.exists(tif_filepath)) {
    log_error(
      "failed to convert nc file ({nc_filename}) to tif ({tif_filename})"
    )
    return(NA_character_)
  }

  log_debug("deleting nc file ({nc_filename})")
  unlink(nc_filepath)

  tif_filepath
}

collect_daymet_tile_files <- function(
  tile_years,
  daymet_dir = "data/daymet",
  params = c("tmin", "tmax")
) {
  possibly_download_daymet_tile <- possibly(
    download_daymet_tile,
    otherwise = NA_character_
  )
  tile_years |>
    crossing(param = params) |>
    rowwise() |>
    mutate(
      filename = possibly_download_daymet_tile(tile_id, year, param, daymet_dir)
    ) |>
    ungroup() |>
    pivot_wider(
      names_from = "param",
      names_glue = "{param}_filename",
      values_from = "filename"
    )
}

extract_daymet_tile_values <- function(
  filename,
  latitude,
  longitude,
  daymet_dir = "data/daymet"
) {
  param <- str_split_1(basename(filename), "_")[[1]]

  if (!file.exists(filename)) {
    return(NULL)
  }

  r <- terra::rast(filename)
  point <- terra::vect(cbind(longitude, latitude), crs = "EPSG:4326")
  values <- terra::extract(r, terra::project(point, r))

  x <- tibble(
    param = param,
    date = terra::time(r),
    value = as.numeric(values)[2:length(values)]
  )

  if (any(year(x$date) < 1980) | all(is.na(x$value))) {
    return(NULL)
  }

  if (day(last(x$date)) == 30) {
    # leap year
    x <- x |>
      add_row(
        param = param,
        date = last(x$date) + days(1),
        value = last(x$value)
      )
  }

  x
}

extract_daymet_airtemp <- function(
  tmin_filename,
  tmax_filename,
  latitude,
  longitude
) {
  # cat(tile_id, year, latitude, longitude, "\n")
  if (is.na(tmin_filename) | is.na(tmax_filename)) {
    return(NULL)
  }

  tmin <- extract_daymet_tile_values(tmin_filename, latitude, longitude)
  tmax <- extract_daymet_tile_values(tmax_filename, latitude, longitude)

  if (is.null(tmin) | is.null(tmax)) {
    return(NULL)
  }

  bind_rows(
    tmin,
    tmax
  ) |>
    pivot_wider(names_from = "param") |>
    mutate(tmean = (tmin + tmax) / 2) |>
    rename(min_airtemp_c = tmin, max_airtemp_c = tmax, mean_airtemp_c = tmean)
}

extract_airtemp <- function(station_years, daymet_tile_files) {
  possibly_extract_daymet_airtemp <- possibly(
    extract_daymet_airtemp,
    otherwise = NULL
  )
  station_years |>
    left_join(daymet_tile_files, by = c("tile_id", "year")) |>
    mutate(
      data = pmap(
        list(tmin_filename, tmax_filename, latitude, longitude),
        possibly_extract_daymet_airtemp
      )
    ) |>
    nest_by(dataset, station_id, .key = "daymet") |>
    mutate(
      daymet = list(bind_rows(daymet$data))
    ) |>
    ungroup()
}

extract_daymet_tile_years <- function(
  combined_station_tile_years,
  daymet_last_year
) {
  combined_station_tile_years |>
    filter(
      year >= 1980,
      year <= daymet_last_year
    ) |>
    distinct(tile_id, year)
}
