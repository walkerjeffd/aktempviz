# ERA5-Land Time Zone Comparison Script
# Compares three aggregation methods:
# 1. Pre-aggregated daily (UTC days)
# 2. Hourly aggregated to UTC days
# 3. Hourly aggregated to Alaska Standard Time days

# Load required packages --------------------------------------------------
library(rgee)        # R interface to Google Earth Engine
library(sf)          # Spatial features
library(tidyverse)   # Data manipulation and visualization
library(lubridate)   # Date handling
library(reticulate)

# Initialize Google Earth Engine ------------------------------------------
ee <- import("ee")
credentials <- ee$ServiceAccountCredentials(
  email = "aktempviz@aktemp-walkerenvres.iam.gserviceaccount.com",
  key_file = "service-account.json"
)
ee$Initialize(credentials = credentials)
ee_Initialize(user = "aktempviz", email = "aktempviz@aktemp-walkerenvres.iam.gserviceaccount.com")

# Define test locations ---------------------------------------------------
# Three representative Alaska locations across different regions

test_sites <- data.frame(
  site_id = c("interior_fairbanks", "southeast_juneau", "northslope_barrow"),
  site_name = c("Interior (Fairbanks)", "Southeast (Juneau)", "North Slope (Barrow)"),
  longitude = c(-147.72, -134.42, -156.79),
  latitude = c(64.84, 58.30, 71.29),
  elevation = c(138, 4, 5)
)

cat("Testing time zone effects at 3 locations:\n")
print(test_sites[, c("site_id", "site_name", "longitude", "latitude")])

# Define test period ------------------------------------------------------
# Using one year to keep processing time reasonable
start_date <- '2023-01-01'
end_date <- '2023-12-31'

cat(sprintf("\nTest period: %s to %s\n", start_date, end_date))
cat("Alaska Standard Time offset: UTC-9 (no daylight saving adjustment)\n\n")

# Convert sites to Earth Engine -------------------------------------------
sites_sf <- st_as_sf(test_sites, coords = c("longitude", "latitude"), crs = 4326)
sites_ee <- sf_as_ee(sites_sf)

# Method 1: Pre-aggregated daily data (UTC days) -------------------------
cat("METHOD 1: Pre-aggregated daily (UTC days)\n")

start_time_1 <- Sys.time()

era5_daily <- ee$ImageCollection("ECMWF/ERA5_LAND/DAILY_AGGR")$
  filterDate(start_date, end_date)$
  select('temperature_2m')

# Extract at points
extract_daily <- function(image) {
  image_celsius <- image$subtract(273.15)
  
  extracted <- image_celsius$reduceRegions(
    collection = sites_ee,
    reducer = ee$Reducer$mean(),
    scale = 9000
  )$map(function(feature) {
    feature$set('date', ee$Date(image$get('system:time_start'))$format('YYYY-MM-dd'))
  })
  
  return(extracted)
}

daily_extracted <- era5_daily$map(extract_daily)$flatten()

# Download results
cat("Downloading Method 1 results...\n")
method1_sf <- ee_as_sf(daily_extracted)
method1_df <- st_drop_geometry(method1_sf) %>%
  as_tibble() %>%
  rename(temp_C = mean) %>%
  mutate(
    date = as.Date(date)
  ) %>%
  select(site_id, site_name, date, temp_C)

end_time_1 <- Sys.time()
time_1 <- as.numeric(difftime(end_time_1, start_time_1, units = "secs"))

cat(sprintf("Method 1 complete: %.1f seconds\n", time_1))
cat(sprintf("Retrieved %d daily values\n\n", nrow(method1_df)))

# Method 2: Hourly aggregated to UTC days --------------------------------
cat("METHOD 2: Hourly → UTC daily aggregation\n")

start_time_2 <- Sys.time()

era5_hourly <- ee$ImageCollection("ECMWF/ERA5_LAND/HOURLY")$
  filterDate(start_date, as.character(as.Date(end_date) + 1))$
  select('temperature_2m')

# Create list of UTC dates
date_list <- seq(as.Date(start_date), as.Date(end_date), by = "day")
date_strings <- format(date_list, "%Y-%m-%d")
cat(sprintf("Processing %d days of hourly data...\n", length(date_strings)))

# Function to aggregate one UTC day from hourly data
aggregate_utc_day <- function(date_str) {
  # Define UTC day boundaries
  day_start <- ee$Date(date_str)
  day_end <- day_start$advance(1, 'day')
  
  # Filter hourly images for this UTC day
  day_images <- era5_hourly$filterDate(day_start, day_end)
  
  # Calculate daily mean
  daily_mean <- day_images$mean()$
    set('system:time_start', day_start$millis())$
    set('date', date_str)
  
  return(daily_mean)
}

# Create ImageCollection of UTC daily means
cat("Aggregating hourly to UTC days in GEE...\n")
utc_daily_images <- ee$ImageCollection(
  ee$List(date_strings)$map(ee_utils_pyfunc(aggregate_utc_day))
)

# Extract at points
utc_daily_extracted <- utc_daily_images$map(extract_daily)$flatten()

# Download results
cat("Downloading Method 2 results...\n")
method2_sf <- ee_as_sf(utc_daily_extracted)
method2_df <- st_drop_geometry(method2_sf) %>%
  as_tibble() %>%
  rename(temp_C = mean) %>%
  mutate(
    date = as.Date(date)
  ) %>%
  select(site_id, site_name, date, temp_C)

end_time_2 <- Sys.time()
time_2 <- as.numeric(difftime(end_time_2, start_time_2, units = "secs"))

cat(sprintf("Method 2 complete: %.1f seconds\n", time_2))
cat(sprintf("Retrieved %d daily values\n\n", nrow(method2_df)))

# Method 3: Hourly aggregated to Alaska Standard Time days ---------------
cat("METHOD 3: Hourly → Alaska Standard Time daily aggregation\n")

start_time_3 <- Sys.time()

# Alaska Standard Time = UTC - 9 hours
# Alaska day 2023-01-01 AKST = 2023-01-01 09:00 UTC to 2023-01-02 09:00 UTC
alaska_offset_hours <- 9

cat(sprintf("Alaska offset: UTC-%d hours\n", alaska_offset_hours))
cat(sprintf("Processing %d days of hourly data...\n", length(date_strings)))

# Function to aggregate one Alaska day from hourly data
aggregate_alaska_day <- function(date_str) {
  # Alaska day starts at 09:00 UTC of the same calendar date
  # and ends at 09:00 UTC of the next calendar date
  alaska_day_start <- ee$Date(date_str)$advance(alaska_offset_hours, 'hour')
  alaska_day_end <- alaska_day_start$advance(24, 'hour')
  
  # Filter hourly images for this Alaska day
  day_images <- era5_hourly$filterDate(alaska_day_start, alaska_day_end)
  
  # Calculate daily mean
  daily_mean <- day_images$mean()$
    set('system:time_start', ee$Date(date_str)$millis())$  # Label with Alaska date
    set('date', date_str)
  
  return(daily_mean)
}

# Create ImageCollection of Alaska daily means
cat("Aggregating hourly to Alaska days in GEE...\n")
alaska_daily_images <- ee$ImageCollection(
  ee$List(date_strings)$map(ee_utils_pyfunc(aggregate_alaska_day))
)

# Extract at points
alaska_daily_extracted <- alaska_daily_images$map(extract_daily)$flatten()

# Download results
cat("Downloading Method 3 results...\n")
method3_sf <- ee_as_sf(alaska_daily_extracted)
method3_df <- st_drop_geometry(method3_sf) %>%
  as_tibble() %>%
  rename(temp_C = mean) %>%
  mutate(
    date = as.Date(date)
  ) %>%
  select(site_id, site_name, date, temp_C)

end_time_3 <- Sys.time()
time_3 <- as.numeric(difftime(end_time_3, start_time_3, units = "secs"))

cat(sprintf("Method 3 complete: %.1f seconds\n", time_3))
cat(sprintf("Retrieved %d daily values\n\n", nrow(method3_df)))

# Performance summary -----------------------------------------------------
cat("\n")
cat("PERFORMANCE SUMMARY\n")
cat(sprintf("Method 1 (Pre-aggregated UTC):  %.1f seconds (%.1fx baseline)\n", 
            time_1, 1.0))
cat(sprintf("Method 2 (Hourly→UTC):          %.1f seconds (%.1fx slower)\n", 
            time_2, time_2/time_1))
cat(sprintf("Method 3 (Hourly→Alaska):       %.1f seconds (%.1fx slower)\n", 
            time_3, time_3/time_1))

# Combine all methods -----------------------------------------------------
all_data <- bind_rows(
  day_utc = method1_df,
  hr_utc = method2_df,
  hr_lst = method3_df,
  .id = "method"
) %>%
  arrange(method, site_id, date)

# Statistical comparison --------------------------------------------------
cat("\n")
cat("STATISTICAL COMPARISON\n")

# Pivot to wide format for comparison
comparison <- all_data %>%
  pivot_wider(
    id_cols = c(site_id, site_name, date),
    names_from = method,
    values_from = temp_C
  ) %>%
  mutate(
    diff_day_utc_vs_hr_utc = day_utc - hr_utc,
    diff_day_utc_vs_method3 = day_utc - hr_lst,
    diff_hr_utc_vs_lst = hr_utc - hr_lst
  )

# Summary statistics by site
cat("\nDifference: Pre-aggregated UTC vs Hourly→UTC (should be ~0)\n")
cat("(This validates our hourly aggregation method)\n")
summary_1v2 <- comparison %>%
  group_by(site_id, site_name) %>%
  summarise(
    mean_diff = mean(diff_day_utc_vs_hr_utc, na.rm = TRUE),
    sd_diff = sd(diff_day_utc_vs_hr_utc, na.rm = TRUE),
    max_abs_diff = max(abs(diff_day_utc_vs_hr_utc), na.rm = TRUE),
    rmse = sqrt(mean(diff_day_utc_vs_hr_utc^2, na.rm = TRUE)),
    .groups = 'drop'
  )
print(summary_1v2)

cat("\n\nDifference: UTC vs Alaska Standard Time daily binning\n")
cat("(This is the key comparison for your decision)\n")
summary_utc_ak <- comparison %>%
  group_by(site_id, site_name) %>%
  summarise(
    mean_diff = mean(diff_hr_utc_vs_lst, na.rm = TRUE),
    sd_diff = sd(diff_hr_utc_vs_lst, na.rm = TRUE),
    max_abs_diff = max(abs(diff_hr_utc_vs_lst), na.rm = TRUE),
    rmse = sqrt(mean(diff_hr_utc_vs_lst^2, na.rm = TRUE)),
    correlation = cor(hr_utc, hr_lst, use = "complete.obs"),
    .groups = 'drop'
  )
print(summary_utc_ak)

# Overall statistics
cat("\n\nOVERALL STATISTICS (all sites combined):\n")
overall <- comparison %>%
  summarise(
    mean_temp_hr_utc = mean(hr_utc, na.rm = TRUE),
    mean_temp_hr_lst = mean(hr_lst, na.rm = TRUE),
    mean_diff = mean(diff_hr_utc_vs_lst, na.rm = TRUE),
    sd_diff = sd(diff_hr_utc_vs_lst, na.rm = TRUE),
    max_abs_diff = max(abs(diff_hr_utc_vs_lst), na.rm = TRUE),
    pct_diff_gt_1C = sum(abs(diff_hr_utc_vs_lst) > 1, na.rm = TRUE) / n() * 100,
    pct_diff_gt_2C = sum(abs(diff_hr_utc_vs_lst) > 2, na.rm = TRUE) / n() * 100
  )
print(overall)

# Seasonal analysis -------------------------------------------------------
cat("\n\nSEASONAL ANALYSIS:\n")

comparison <- comparison %>%
  mutate(
    month = month(date),
    season = case_when(
      month %in% c(12, 1, 2) ~ "Winter",
      month %in% c(3, 4, 5) ~ "Spring",
      month %in% c(6, 7, 8) ~ "Summer",
      month %in% c(9, 10, 11) ~ "Fall"
    )
  )

seasonal_summary <- comparison %>%
  group_by(season, site_name) %>%
  summarise(
    mean_diff = mean(diff_hr_utc_vs_lst, na.rm = TRUE),
    sd_diff = sd(diff_hr_utc_vs_lst, na.rm = TRUE),
    max_abs_diff = max(abs(diff_hr_utc_vs_lst), na.rm = TRUE),
    n = n(),
    .groups = 'drop'
  )

print(seasonal_summary)

# Save results ------------------------------------------------------------
# cat("\n\nSaving results...\n")

# # Save full comparison
# write_csv(comparison, "timezone_comparison_full.csv")
# cat("Full comparison saved to: timezone_comparison_full.csv\n")

# # Save long format
# write_csv(all_data, "timezone_comparison_long.csv")
# cat("Long format saved to: timezone_comparison_long.csv\n")

# Create visualizations ---------------------------------------------------
cat("\nCreating visualizations...\n")

# Plot 1: Time series comparison
all_data |> 
  ggplot(aes(x = date, y = temp_C, color = method)) +
  geom_line(alpha = 0.7, linewidth = 0.5) +
  scale_color_brewer(palette = "Set1") +
  facet_wrap(vars(site_name), ncol = 1) +
  theme_bw()

comparison |> 
  ggplot(aes(x = date, y = diff_hr_utc_vs_lst)) +
  geom_line(alpha = 0.7, linewidth = 0.5) +
  facet_wrap(vars(site_name), ncol = 1) +
  labs(y = "Daily Difference\nUTC - Alaska (°C)", title = "Daily Temperature Difference: UTC vs Alaska Standard Time") +
  theme_bw()

# Plot 2: Difference distributions by site
comparison %>%
  select(site_name, date, diff_hr_utc_vs_lst) |> 
  ggplot(aes(x = diff_hr_utc_vs_lst, fill = site_name)) +
  geom_histogram(bins = 50, alpha = 0.7, position = "identity") +
  facet_wrap(~site_name, ncol = 1, scales = "free_y") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "black") +
  scale_fill_brewer(palette = "Set1") +
  labs(title = "Distribution of Temperature Differences",
       subtitle = "UTC daily bins vs Alaska Standard Time daily bins",
       x = "Temperature Difference (°C): UTC - Alaska",
       y = "Count") +
  theme_minimal() +
  theme(legend.position = "none")

# Plot 3: Seasonal boxplots
comparison |>
  ggplot(aes(x = season, y = abs(diff_hr_utc_vs_lst), fill = season)) +
  geom_boxplot(alpha = 0.7) +
  facet_wrap(~site_name, ncol = 3) +
  scale_fill_brewer(palette = "Set2") +
  labs(title = "Absolute Temperature Differences by Season",
       subtitle = "UTC daily - Alaska daily binning",
       x = "Season", y = "Absolute Temperature Difference (°C)") +
  theme_minimal() +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 45, hjust = 1))

# Plot 4: Scatter plot UTC vs Alaska
all_data |> 
  pivot_wider(names_from = "method", values_from = "temp_C") |> 
  ggplot(aes(x = hr_utc, y = hr_lst)) +
  geom_point(alpha = 0.5, size = 2) +
  geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed", linewidth = 1) +
  geom_smooth(method = "lm", color = "blue", se = TRUE) +
  coord_fixed() +
  labs(x = "UTC Daily Mean (°C)", y = "Alaska Daily Mean (°C)") +
  theme_minimal()

# Plot 5: Scatter plot pre-agg vs hr-agg UTC (very similar)
all_data |> 
  pivot_wider(names_from = "method", values_from = "temp_C") |> 
  ggplot(aes(x = day_utc, y = hr_utc)) +
  geom_point(alpha = 0.5, size = 2) +
  geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed", linewidth = 1) +
  geom_smooth(method = "lm", color = "blue", se = TRUE) +
  coord_fixed() +
  labs(x = "Pre-agg UTC Daily Mean (°C)", y = "Hourly UTC Daily Mean (°C)") +
  theme_minimal()
