library(tidyverse)
library(logger)
library(reticulate)
library(rgee)
library(sf)

source("R/era5.R")

# Initialize GEE
cat("Initializing GEE...\n")
ee <- init_gee(
  email = 'aktempviz@aktemp-walkerenvres.iam.gserviceaccount.com',
  key_file = 'service-account.json'
)
cat("GEE initialized successfully!\n\n")

# Find most recent ERA5 data
cat("Finding most recent ERA5 data...\n")
era5_last_date <- find_era5_last_date(ee)
cat("ERA5 last date:", as.character(era5_last_date), "\n\n")

# Create test stations (just 2-3 stations for testing)
stations <- tibble(
  station_id = c("test_station_1", "test_station_2", "test_station_3"),
  latitude = c(61.217, 64.844, 60.492),
  longitude = c(-149.863, -147.723, -151.051)
) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

# mapview::mapview(stations)

out <- fetch_era5_stations(
  stations = stations,
  start_date = "2024-07-01",
  end_date = "2024-07-31",
  variable = "temperature_2m",
  scale = 9000,
  ee = ee
) |> 
  mutate(value = value - 273.15)

if (interactive()) {
  out |> 
    ggplot(aes(date, value, color = station_id)) +
    geom_line() +
    geom_point() +
    scale_color_brewer(palette = "Set1") +
    facet_wrap(vars(variable), scales = "free_y")
}

cat("Test data fetched successfully! Rows:", nrow(out), "\n")
out |> 
  summarise(
    start = min(date),
    end = max(date),
    n = n(),
    min = min(value, na.rm = TRUE),
    mean = mean(value, na.rm = TRUE),
    max = max(value, na.rm = TRUE),
    .by = c(variable, station_id)
  )
