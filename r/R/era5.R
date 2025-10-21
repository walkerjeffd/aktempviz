# ERA5-Land Air Temperature Data Functions
# Retrieves daily mean 2m air temperature from Google Earth Engine
# Dataset: ECMWF/ERA5_LAND/HOURLY

init_gee <- function(email = "", key_file = "") {
  gee <- reticulate::import("ee")

  # Authenticate with service account
  credentials <- gee$ServiceAccountCredentials(
    email = Sys.getenv("GEE_SERVICE_ACCOUNT_EMAIL", unset = email),
    key_file = Sys.getenv("GEE_SERVICE_ACCOUNT_KEY_FILE", unset = key_file)
  )

  # Initialize with service account email
  gee$Initialize(credentials = credentials)

  gee
}

find_era5_last_date <- function(gee_config) {
  log_info("Finding last available date in ERA5-Land dataset...")

  gee <- init_gee(
    email = gee_config$email,
    key_file = gee_config$key_file
  )

  tryCatch(
    {
      era5 <- gee$ImageCollection("ECMWF/ERA5_LAND/DAILY_AGGR")

      # Get the most recent image
      latest <- era5$sort("system:time_start", FALSE)$first()

      # Convert from milliseconds to date
      last_date <- lubridate::ymd(latest$get("system:index")$getInfo())

      log_info("ERA5-Land last available date: {last_date}")
      last_date
    },
    error = function(e) {
      log_error("Failed to query ERA5-Land last date: {conditionMessage(e)}")
      # Return a conservative fallback (5 days ago)
      fallback_date <- Sys.Date() - 5
      log_warn("Using fallback date: {fallback_date}")
      fallback_date
    }
  )
}

fetch_era5_last_date <- function(gee) {
  era5_hourly <- gee$ImageCollection("ECMWF/ERA5/HOURLY")$
    filterDate(as.character(today() - days(90)), as.character(today()))$
    select('temperature_2m')

  last_timestamp_str <- era5_hourly$sort('system:time_start', FALSE)$first()$get('system:index')$getInfo()
  last_timestamp_utc <- ymd_h(last_timestamp_str, tz = "UTC")
  last_timestamp_ak <- last_timestamp_utc - hours(9)
  as.Date(last_timestamp_ak) - 1
}

fetch_era5_stations_period <- function(
  stations,
  start_date,
  end_date,
  last_full_date,
  gee,
  bucket = NULL
) {
  if (is.null(bucket)) {
    bucket <- Sys.getenv("GCS_BUCKET")
  }
  stations_ee <- rgee::sf_as_ee(stations, quiet = TRUE)

  era5_hourly <- gee$ImageCollection("ECMWF/ERA5/HOURLY")$
    filterDate(start_date, as.character(as.Date(end_date) + 2))$
    select('temperature_2m')

  if (as.Date(end_date) > last_full_date) {
    log_warn("Requested end_date {end_date} is after last full available date {last_full_date}, adjusting end_date")
    end_date <- as.character(last_full_date)
  }

  if (as.Date(start_date) > as.Date(end_date)) {
    log_warn("start_date {start_date} is after adjusted end_date {end_date}, no data to fetch")
    return(NULL)
  }

  aggregate_hourly_images <- function(date_str) {
    # Alaska day starts at 09:00 UTC of the same calendar date
    # and ends at 09:00 UTC of the next calendar date
    day_start <- gee$Date(date_str)$advance(9, 'hour')
    day_end <- day_start$advance(24, 'hour')
    
    # Filter hourly images for this Alaska day
    day_images <- era5_hourly$filterDate(day_start, day_end)
    
    # Calculate daily mean
    daily_mean <- day_images$mean()$
      set('system:time_start', gee$Date(date_str)$millis())$  # Label with local date
      set('date', date_str)
    
    return(daily_mean)
  }
  date_strs <- as.character(seq(as.Date(start_date), as.Date(end_date), by = "day"))
  era5_daily <- gee$ImageCollection(
    gee$List(date_strs)$map(rgee::ee_utils_pyfunc(aggregate_hourly_images))
  )

  # fill gaps using nearest valid pixels
  fill_with_nearest <- function(image, radius_m = 50000) {
    # Original image (with mask intact)
    original <- image$subtract(273.15)
    
    # Create filled version using focal_mean within radius
    # This will average nearby valid pixels to fill masked areas
    filled <- original$focal_mean(
      radius = radius_m,
      kernelType = 'circle',
      units = 'meters'
    )
    
    # Blend: use original where valid, use filled where originally masked
    # unmask() replaces masked pixels with the filled values
    result <- original$unmask(filled)
    
    return(result)
  }
  era5_filled <- era5_daily$map(function(image) {
    return(fill_with_nearest(image, radius_m = 50000)$set('system:time_start', image$get('system:time_start')))
  })

  # extract values at stations
  era5_extracted <- era5_filled$map(function(image) {
    extracted <- image$reduceRegions(
      collection = stations_ee,
      reducer = gee$Reducer$first(),
      scale = 9000
    )$map(function(feature) {
      feature$set('date', gee$Date(image$get('system:time_start'))$format('YYYY-MM-dd'))
    })
    return(extracted)
  })$flatten()

  # run task, save output to GCS
  log_info("ERA5 fetch: submitting task to GEE")
  task <- rgee::ee_table_to_gcs(
    era5_extracted,
    description = "fetch_era5",
    bucket = bucket,
    fileNamePrefix = "tasks/fetch_era5",
    selectors = c("dataset", "provider_station_code", "date", "first")
  )
  task$start()
  rgee::ee_monitoring(task)
  Sys.sleep(5)

  # download from GCS
  bucket <- task$config$fileExportOptions$cloudStorageDestination$bucket
  prefix <- paste0(task$config$fileExportOptions$cloudStorageDestination$filenamePrefix, ".csv")
  local_file <- tempfile(fileext = ".csv")
  log_info("ERA5 fetch: downloading table from GCS (gs://{bucket}/{prefix}) to local file ({local_file})")
  download_from_gcs(
    bucket = bucket,
    prefix = prefix,
    local_file = local_file
  )

  # parse results
  log_info("ERA5 fetch: parsingresults from local file")
  read_csv(local_file, col_types = cols(.default = col_character(), date = col_date(), first = col_double())) |> 
    rename(mean_airtemp_c = first)
}

download_from_gcs <- function(bucket, prefix, local_file, max_retries = 10, initial_wait = 5, max_wait = 300) {
  attempt <- 1
  
  while (attempt <= max_retries) {
    tryCatch(
      {
        googleCloudStorageR::gcs_get_object(
          object_name = prefix,
          bucket = bucket,
          saveToDisk = local_file,
          overwrite = TRUE
        )
        return(invisible(NULL))  # Success - exit function
      },
      error = function(e) {
        if (grepl("404", conditionMessage(e), ignore.case = TRUE)) {
          if (attempt < max_retries) {
            wait_seconds <- min(initial_wait * (2 ^ (attempt - 1)), max_wait)
            log_warn("Object not found (attempt {attempt}/{max_retries}), retrying in {wait_seconds}s...")
            Sys.sleep(wait_seconds)
            attempt <<- attempt + 1
          } else {
            log_error("Object not found after {max_retries} attempts")
            stop(e)
          }
        } else {
          # Non-404 error - don't retry
          stop(e)
        }
      }
    )
  }
}



fetch_era5_data <- function(wtemp_manifest) {
  log_info("era5: initializing GEE")
  gee <- init_gee()

  cache <- gcs_load_cache(prefix = "cache/era5.rds")

  last_full_date <- fetch_era5_last_date(gee)

  if (is.null(cache[["data"]])) {
    fetch_manifest <- wtemp_manifest
    log_info("era5: fetching all {nrow(fetch_manifest)} station-years")
  } else {
    cache_drop <- cache[["data"]] |> 
      anti_join(wtemp_manifest, by = names(wtemp_manifest))

    cache_existing <- cache[["data"]] |> 
      semi_join(wtemp_manifest, by = names(wtemp_manifest))

    fetch_manifest <- wtemp_manifest |> 
      anti_join(cache[["data"]], by = names(wtemp_manifest))

    log_info("era5: updating dataset (drop={nrow(cache_drop)}, keep={nrow(cache_existing)}, fetch={nrow(fetch_manifest)})")
  }
  
  fetch_data <- fetch_manifest |> 
    nest_by(year, .key = "data") |>
    ungroup() |> 
    mutate(
      data = pmap(list(data, year), function(stations, year) {
        log_info("era5: fetching year={year}, n_stations={nrow(stations)}")
        x <- tryCatch({
          stations |> 
            st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |> 
            select(dataset, provider_station_code) |> 
            fetch_era5_stations_period(
              start_date = as.character(min(stations$start_date)),
              end_date = as.character(max(stations$end_date)),
              last_full_date = last_full_date,
              gee = gee
            ) |> 
            nest_by(dataset, provider_station_code) |> 
            ungroup()
        }, error = function(e) {
          log_error("era5: {e$message}")
          NULL
        })
        if (is.null(x)) {
          log_warn("era5: failed for year={year}")
          return(NULL)
        }
        stations |> 
          left_join(x, by = c("dataset", "provider_station_code"))
      }, .progress = TRUE)
    ) |> 
    unnest(data)

  out_data <- bind_rows(cache_existing, fetch_data) |> 
    arrange(dataset, provider_station_code, year)
  log_info("era5: total {nrow(out_data)} station-years after update")

  out <- list(
    updated_at = format_ISO8601(now(), usetz = TRUE),
    last_date = last_full_date,
    data = out_data
  )
  
  gcs_save_cache(out, prefix = "cache/era5.rds")

  out
}
