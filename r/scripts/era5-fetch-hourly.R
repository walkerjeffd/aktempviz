# fetch ERA5-Land hourly data aggregated to daily values based on UTC-9 (AK Standard Time)
# for given stations and date range. Stations outside image coverage are filled with nearest pixel.

# Load required packages --------------------------------------------------
library(rgee)
library(sf)
library(tidyverse)
library(lubridate)
library(googleCloudStorageR)
source("_targets.R")

# Initialize Google Earth Engine ------------------------------------------
tar_load(gee_config)
gee <- init_gee(gee_config$email, gee_config$key_file)
gcs_auth(json_file = gee_config$key_file)

# Setup test data ---------------------------------------------------------
stations <- tar_read(wtemp_manifest) |> 
  distinct(dataset, provider_station_code, latitude, longitude) |> 
  filter(str_starts(provider_station_code, "CIK:")) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |> 
  print()

cat("Testing time zone effects at", nrow(stations), "locations:\n")
print(stations)

# Define date range -------------------------------------------------------
start_date <- "2023-01-01"
end_date <- "2023-12-31"

# Convert stations to Earth Engine ----------------------------------------
stations_ee <- sf_as_ee(stations)

# Define GEE task ---------------------------------------------------------
era5_hourly <- ee$ImageCollection("ECMWF/ERA5_LAND/HOURLY")$
  filterDate(start_date, as.character(as.Date(end_date) + 1))$
  select('temperature_2m')
cat(sprintf("Found %d hourly images\n\n", era5_hourly$size()$getInfo()))

aggregate_hourly_images <- function(date_str) {
  # Alaska day starts at 09:00 UTC of the same calendar date
  # and ends at 09:00 UTC of the next calendar date
  day_start <- ee$Date(date_str)$advance(9, 'hour')
  day_end <- day_start$advance(24, 'hour')
  
  # Filter hourly images for this Alaska day
  day_images <- era5_hourly$filterDate(day_start, day_end)
  
  # Calculate daily mean
  daily_mean <- day_images$mean()$
    set('system:time_start', ee$Date(date_str)$millis())$  # Label with local date
    set('date', date_str)
  
  return(daily_mean)
}
date_strs <- as.character(seq(as.Date(start_date), as.Date(end_date), by = "day"))
era5_daily <- ee$ImageCollection(
  ee$List(date_strs)$map(ee_utils_pyfunc(aggregate_hourly_images))
)
cat(sprintf("Aggregated to %d daily images\n\n", era5_daily$size()$getInfo()))

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
    reducer = ee$Reducer$first(),
    scale = 9000
  )$map(function(feature) {
    feature$set('date', ee$Date(image$get('system:time_start'))$format('YYYY-MM-dd'))
  })
  return(extracted)
})$flatten()

# Execute task and download results -----------------------------

# run task, save output to GCS
task <- ee_table_to_gcs(era5_extracted, bucket = "walkerenvres-aktempviz")
task$start()
ee_monitoring(task)

# download from GCS
local_file <- tempfile(fileext = ".csv")
gcs_get_object(
  object_name = paste0(task$config$fileExportOptions$cloudStorageDestination$filenamePrefix, ".csv"),
  bucket = task$config$fileExportOptions$cloudStorageDestination$bucket,
  saveToDisk = local_file,  # Save to a temporary file
)
out <- read_csv(local_file) |> 
  select(-`system:index`, -`.geo`) |> 
  rename(value = first)

stopifnot(all(!is.na(out$value)))

out |> 
  ggplot(aes(date, value)) +
  geom_line(aes(group = provider_station_code), alpha = 0.5) +
  theme_bw()
