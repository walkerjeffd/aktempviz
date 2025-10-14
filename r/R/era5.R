# ERA5-Land Air Temperature Data Functions
# Retrieves daily mean 2m air temperature from Google Earth Engine
# Dataset: ECMWF/ERA5_LAND/DAILY_AGGR

# Initialize Google Earth Engine ----
init_gee <- function(email, key_file) {
  ee <- import("ee")

  # Authenticate with service account
  credentials <- ee$ServiceAccountCredentials(
    email = email,
    key_file = key_file
  )

  # Initialize with service account email
  ee$Initialize(credentials = credentials)

  ee
}

# Find last available date in ERA5-Land dataset ----
find_era5_last_date <- function(ee) {
  log_info("Finding last available date in ERA5-Land dataset...")

  tryCatch({
    era5 <- ee$ImageCollection("ECMWF/ERA5_LAND/DAILY_AGGR")

    # Get the most recent image
    latest <- era5$sort("system:time_start", FALSE)$first()

    # Convert from milliseconds to date
    last_date <- lubridate::ymd(latest$get("system:index")$getInfo())

    log_info("ERA5-Land last available date: {last_date}")
    last_date
  }, error = function(e) {
    log_error("Failed to query ERA5-Land last date: {conditionMessage(e)}")
    # Return a conservative fallback (5 days ago)
    fallback_date <- Sys.Date() - 5
    log_warn("Using fallback date: {fallback_date}")
    fallback_date
  })
}

# S3 Cache Management ----

get_s3_cache_uri <- function() {
  bucket <- Sys.getenv("AWS_S3_BUCKET")
  prefix <- Sys.getenv("AWS_S3_PREFIX")

  if (bucket == "" || prefix == "") {
    log_error("AWS_S3_BUCKET and AWS_S3_PREFIX environment variables must be set")
    stop("Missing AWS S3 configuration")
  }

  glue("s3://{bucket}/{prefix}/cache/era5_cache.csv")
}

read_era5_cache <- function(era5_dir) {
  s3_uri <- get_s3_cache_uri()
  local_cache_file <- file.path(era5_dir, "era5_cache.csv")

  log_info("Reading ERA5 cache from S3: {s3_uri}")

  tryCatch({
    # Download from S3 using AWS CLI
    result <- system2(
      "aws",
      args = c("s3", "cp", s3_uri, local_cache_file),
      stdout = FALSE,
      stderr = FALSE
    )

    if (result == 0 && file.exists(local_cache_file)) {
      cache <- read_csv(
        local_cache_file,
        col_types = cols(
          station_id = col_character(),
          latitude = col_double(),
          longitude = col_double(),
          date = col_date(),
          mean_airtemp_c = col_double()
        )
      )
      log_info("Loaded {nrow(cache)} rows from ERA5 cache")
      return(cache)
    } else {
      log_warn("ERA5 cache not found in S3, starting with empty cache")
      return(tibble(
        station_id = character(),
        latitude = double(),
        longitude = double(),
        date = as.Date(character()),
        mean_airtemp_c = double()
      ))
    }
  }, error = function(e) {
    log_warn("Failed to read ERA5 cache from S3: {conditionMessage(e)}")
    log_info("Starting with empty cache")
    return(tibble(
      station_id = character(),
      latitude = double(),
      longitude = double(),
      date = as.Date(character()),
      mean_airtemp_c = double()
    ))
  })
}

write_era5_cache <- function(cache, era5_dir) {
  s3_uri <- get_s3_cache_uri()
  local_cache_file <- file.path(era5_dir, "era5_cache.csv")

  log_info("Writing ERA5 cache ({nrow(cache)} rows) to S3: {s3_uri}")

  tryCatch({
    # Write to local file
    write_csv(cache, local_cache_file)

    # Upload to S3 using AWS CLI
    result <- system2(
      "aws",
      args = c("s3", "cp", local_cache_file, s3_uri),
      stdout = FALSE,
      stderr = FALSE
    )

    if (result == 0) {
      log_success("ERA5 cache uploaded to S3 successfully")
    } else {
      log_error("Failed to upload ERA5 cache to S3")
    }

    cache
  }, error = function(e) {
    log_error("Failed to write ERA5 cache: {conditionMessage(e)}")
    cache
  })
}

# Determine what data needs to be fetched ----
determine_era5_fetch_plan <- function(combined_data, era5_dir, era5_last_date) {
  log_info("Determining ERA5 fetch plan...")

  # Read existing cache
  cache <- read_era5_cache(era5_dir)

  # Extract station date ranges
  station_ranges <- combined_data |>
    select(dataset, station_id, latitude, longitude, data) |>
    mutate(
      provider_station_code = glue("{dataset}:{station_id}"),
      start_date = map_chr(data, ~ as.character(min(.x$date))),
      end_date = map_chr(data, ~ as.character(min(max(.x$date), era5_last_date)))
    ) |>
    select(provider_station_code, station_id, latitude, longitude, start_date, end_date) |>
    mutate(
      start_date = as.Date(start_date),
      end_date = as.Date(end_date)
    )

  # For each station, determine missing dates
  fetch_plan <- station_ranges |>
    rowwise() |>
    mutate(
      cached_dates = list({
        if (nrow(cache) == 0) {
          as.Date(character())
        } else {
          cache |>
            filter(station_id == .env$station_id) |>
            pull(date)
        }
      }),
      needed_dates = list({
        all_dates <- seq.Date(start_date, end_date, by = "day")
        setdiff(all_dates, cached_dates)
      }),
      n_needed = length(needed_dates),
      fetch_start_date = if (n_needed > 0) min(needed_dates) else as.Date(NA),
      fetch_end_date = if (n_needed > 0) max(needed_dates) else as.Date(NA)
    ) |>
    ungroup() |>
    select(provider_station_code, station_id, latitude, longitude, fetch_start_date, fetch_end_date, n_needed) |>
    filter(!is.na(fetch_start_date))

  log_info("Fetch plan: {nrow(fetch_plan)} stations need data, {sum(fetch_plan$n_needed)} total dates")

  fetch_plan
}

# Fetch ERA5 data for a single station ----
fetch_era5_station <- function(station_id, latitude, longitude, start_date, end_date, ee) {
  log_debug("Fetching ERA5 for station {station_id}: {start_date} to {end_date}")

  # Create point geometry
  point <- ee$Geometry$Point(c(longitude, latitude), proj = "EPSG:4326")

  # Filter ERA5 collection to date range
  era5 <- ee$ImageCollection("ECMWF/ERA5_LAND/DAILY_AGGR")$
    filterDate(as.character(start_date), as.character(as.Date(end_date) + 1))$
    select("temperature_2m_mean")

  point_sf <- sf::st_point(c(longitude, latitude)) |>
    sf::st_sfc(crs = 4326)

  # Extract time series at point
  values <- ee_extract(
    x = era5$first(),
    y = point_sf,
    fun = ee$Reducer$mean()
    # scale = 9000  # 9km resolution
  )

  # Process results
  if (nrow(values) == 0) {
    log_warn("No ERA5 data returned for station {station_id}")
    return(tibble(
      station_id = character(),
      latitude = double(),
      longitude = double(),
      date = as.Date(character()),
      mean_airtemp_c = double()
    ))
  }

  result <- values |>
    as_tibble() |>
    transmute(
      station_id = station_id,
      latitude = latitude,
      longitude = longitude,
      date = as.Date(id, format = "%Y%m%d"),
      mean_airtemp_c = temperature_2m_mean - 273.15  # Convert Kelvin to Celsius
    ) |>
    filter(!is.na(mean_airtemp_c))

  log_debug("Fetched {nrow(result)} days for station {station_id}")

  # Rate limiting
  Sys.sleep(0.5)

  result
}

# Collect ERA5 data for all stations in fetch plan ----
collect_era5_data <- function(fetch_plan, era5_dir, gee_init) {
  log_info("Collecting ERA5 data for {nrow(fetch_plan)} stations...")

  # Read existing cache
  cache <- read_era5_cache(era5_dir)

  if (nrow(fetch_plan) == 0) {
    log_info("No new data to fetch")
    return(cache)
  }

  # Wrapper for error handling
  possibly_fetch <- possibly(fetch_era5_station, otherwise = NULL)

  # Fetch data for each station
  for (i in seq_len(nrow(fetch_plan))) {
    station <- fetch_plan[i, ]

    log_info("Fetching station {i}/{nrow(fetch_plan)}: {station$provider_station_code} ({station$n_needed} days)")

    new_data <- possibly_fetch(
      station_id = station$station_id,
      latitude = station$latitude,
      longitude = station$longitude,
      start_date = station$fetch_start_date,
      end_date = station$fetch_end_date
    )

    if (!is.null(new_data) && nrow(new_data) > 0) {
      # Append to cache
      cache <- bind_rows(cache, new_data) |>
        distinct(station_id, date, .keep_all = TRUE) |>
        arrange(station_id, date)

      # Upload to S3 incrementally (every 10 stations or last station)
      if (i %% 10 == 0 || i == nrow(fetch_plan)) {
        write_era5_cache(cache, era5_dir)
      }
    } else {
      log_warn("Failed to fetch data for station {station$provider_station_code}")
    }
  }

  # Final upload
  write_era5_cache(cache, era5_dir)

  log_success("ERA5 data collection complete: {nrow(cache)} total rows in cache")

  cache
}

# Merge ERA5 air temperature to station data ----
merge_era5_to_stations <- function(combined_data, era5_cache) {
  log_info("Merging ERA5 air temperature to station data...")

  combined_data |>
    rowwise() |>
    mutate(
      data = list({
        # Get air temp data for this station
        airtemp <- era5_cache |>
          filter(station_id == .env$station_id) |>
          select(date, mean_airtemp_c)

        # Join air temp to water temp data
        # Complete date range to fill gaps
        data |>
          complete(date = seq.Date(min(date), max(date), by = "day")) |>
          left_join(airtemp, by = "date") |>
          mutate(
            min_airtemp_c = NA_real_,
            max_airtemp_c = NA_real_
          )
      })
    ) |>
    ungroup()

  log_success("ERA5 air temperature merged successfully")
}
