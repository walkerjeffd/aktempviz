# use focal_mean to get nearest pixel values

# Test script for extracting ERA5-Land data at coastal stations
# Uses focal_mean() to fill gaps with nearest valid pixels

# Load required packages --------------------------------------------------
library(rgee)
library(sf)
library(tidyverse)
library(lubridate)
source("_targets.R")

# Initialize Google Earth Engine ------------------------------------------
tar_load(gee_config)
gee <- init_gee(gee_config$email, gee_config$key_file)
ee_Initialize(user = "aktempviz", email = "aktempviz@aktemp-walkerenvres.iam.gserviceaccount.com")


# Setup test data ---------------------------------------------------------
# Example: Create test stations (replace with your actual stations sf object)
# stations <- st_read("your_stations.shp") 
# OR
# stations <- your_existing_sf_object

# For demonstration, create coastal test stations near Alaska
stations <- tar_read(wtemp_manifest) |> 
  distinct(dataset, provider_station_code, latitude, longitude) |> 
  filter(str_starts(provider_station_code, "CIK:")) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |> 
  print()

cat("Testing time zone effects at", nrow(stations), "locations:\n")
print(stations)

# Define date range -------------------------------------------------------
start_date <- "2019-01-01"
end_date <- "2019-01-07"  # Just one week for testing

cat("Testing extraction for:\n")
cat(sprintf("  Stations: %d\n", nrow(stations)))
cat(sprintf("  Date range: %s to %s\n", start_date, end_date))
cat(sprintf("  Total days: %d\n\n", as.numeric(difftime(as.Date(end_date), as.Date(start_date), units = "days")) + 1))

# Convert stations to Earth Engine ----------------------------------------
stations_ee <- sf_as_ee(stations)

# Load ERA5-Land daily data -----------------------------------------------
cat("Loading ERA5-Land data...\n")
era5_daily <- ee$ImageCollection("ECMWF/ERA5_LAND/DAILY_AGGR")$
  filterDate(start_date, end_date)$
  select('temperature_2m')

cat(sprintf("Found %d daily images\n\n", era5_daily$size()$getInfo()))

# Method 1: Standard extraction (will have missing data for coastal sites) -
cat("METHOD 1: Standard extraction (may have gaps)\n")

extract_standard <- function(image) {
  image_celsius <- image$subtract(273.15)
  
  extracted <- image_celsius$reduceRegions(
    collection = stations_ee,
    reducer = ee$Reducer$first(),
    scale = 11132
  )$map(function(feature) {
    feature$set('date', ee$Date(image$get('system:time_start'))$format('YYYY-MM-dd'))
  })
  
  return(extracted)
}

cat("Extracting with standard method...\n")
standard_extracted <- era5_daily$map(extract_standard)$flatten()
standard_sf <- ee_as_sf(standard_extracted)

standard_df <- st_drop_geometry(standard_sf) %>%
  as_tibble() %>%
  rename(temp_C = first) %>%
  mutate(
    date = as.Date(date),
  ) %>%
  select(dataset, provider_station_code, date, temp_C)

# Count missing values
n_missing_standard <- sum(is.na(standard_df$temp_C))
pct_missing_standard <- n_missing_standard / nrow(standard_df) * 100

cat(sprintf("Standard extraction complete\n"))
cat(sprintf("  Missing values: %d (%.1f%%)\n\n", n_missing_standard, pct_missing_standard))

# Method 2: Using focal_mean to fill gaps with nearest pixels ------------
cat("METHOD 2: Gap-filling with focal_mean (nearest pixels)\n")

# Function to fill gaps using nearest valid pixels
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

cat("Applying focal_mean gap-filling (50km radius)...\n")
era5_filled <- era5_daily$map(function(image) {
  return(fill_with_nearest(image, radius_m = 50000)$
           set('system:time_start', image$get('system:time_start')))
})

cat("Extracting from gap-filled dataset...\n")
filled_extracted <- era5_filled$map(function(image) {
  extracted <- image$reduceRegions(
    collection = stations_ee,
    reducer = ee$Reducer$first(),
    scale = 11132
  )$map(function(feature) {
    feature$set('date', ee$Date(image$get('system:time_start'))$format('YYYY-MM-dd'))
  })
  return(extracted)
})$flatten()

filled_sf <- ee_as_sf(filled_extracted)

filled_df <- st_drop_geometry(filled_sf) %>%
  as_tibble() %>%
  rename(temp_C = first) %>%
  mutate(
    date = as.Date(date)
  ) %>%
  select(dataset, provider_station_code, date, temp_C)

# Count missing values
n_missing_filled <- sum(is.na(filled_df$temp_C))
pct_missing_filled <- n_missing_filled / nrow(filled_df) * 100

cat(sprintf("Gap-filled extraction complete\n"))
cat(sprintf("  Missing values: %d (%.1f%%)\n\n", n_missing_filled, pct_missing_filled))

# Combine and compare results ---------------------------------------------
cat("COMPARISON\n")

all_data <- bind_rows(
  standard = standard_df, 
  filled = filled_df,
  .id = "method"
)

# Create comparison table
comparison <- all_data %>%
  pivot_wider(
    names_from = method,
    values_from = temp_C
  )

cat("\nSummary by station:\n")
summary_by_station <- comparison %>%
  group_by(dataset, provider_station_code) %>%
  summarise(
    n_days = n(),
    n_missing_standard = sum(is.na(standard)),
    n_missing_filled = sum(is.na(filled)),
    n_filled = sum(is.na(standard) & !is.na(filled)),
    mean_temp_standard = mean(standard, na.rm = TRUE),
    mean_temp_filled = mean(filled, na.rm = TRUE),
    .groups = 'drop'
  )

print(summary_by_station)

cat("\n\nOverall statistics:\n")
cat(sprintf("Total station-days: %d\n", nrow(comparison)))
cat(sprintf("Missing with standard method: %d (%.1f%%)\n", 
            n_missing_standard, pct_missing_standard))
cat(sprintf("Missing with focal_mean fill: %d (%.1f%%)\n", 
            n_missing_filled, pct_missing_filled))
cat(sprintf("Successfully filled: %d gaps\n", 
            sum(is.na(comparison$standard) & !is.na(comparison$filled))))

# Show specific examples of filled values
cat("\n\nExample filled values (where standard was NA):\n")
filled_examples <- comparison %>%
  filter(is.na(standard) & !is.na(filled)) %>%
  head(10)

if (nrow(filled_examples) > 0) {
  print(filled_examples)
} else {
  cat("No gaps were filled (all stations had valid data with standard extraction)\n")
  cat("This means your stations are likely not in coastal masked areas.\n")
}

# Visualize results -------------------------------------------------------
cat("\n\nCreating visualizations...\n")

# Plot 1: Time series comparison
ggplot(all_data, aes(x = date, y = temp_C, color = method, shape = method)) +
  geom_point(size = 3, alpha = 0.7) +
  geom_line(alpha = 0.5) +
  facet_wrap(~provider_station_code) +
  theme_minimal() +
  theme(legend.position = "bottom")

# Plot 2: Scatter plot showing filled vs standard (where both exist)
comparison |> 
  ggplot(aes(x = standard, y = filled)) +
  geom_point(alpha = 0.6, size = 3) +
  geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed") +
  geom_smooth(method = "lm", color = "blue", se = TRUE) +
  coord_fixed() +
  labs(title = "Standard vs Gap-Filled Temperatures",
        x = "Standard Extraction (°C)",
        y = "Gap-Filled Extraction (°C)") +
  theme_minimal()
