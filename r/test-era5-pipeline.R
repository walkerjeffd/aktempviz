library(tidyverse)
library(logger)
library(reticulate)
library(rgee)
library(sf)

# Point reticulate to your conda environment
use_python("/opt/homebrew/Caskroom/miniconda/base/envs/aktempviz/bin/python", required = TRUE)

# Source ERA5 functions
source("R/era5.R")

# Initialize GEE
cat("Initializing GEE...\n")
ee <- init_gee(
  email = 'gee-aktempviz@aktemp-walkerenvres.iam.gserviceaccount.com',
  key_file = '/Users/jeff/git/aktempviz/r/gee-service-account.json'
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

mapview::mapview(stations)

y <- stations
start_date <- "2024-05-01"
end_date <- "2024-05-05"
scale <- 9000  # 9km resolution
fun <- ee$Reducer$mean()

x <- ee$ImageCollection("ECMWF/ERA5_LAND/DAILY_AGGR")$
  filterDate(start_date, end_date)$
  select("temperature_2m")

x <- ee$ImageCollection$toBands(x)
oauth_func_path <- system.file("python/ee_extract.py", package = "rgee")
extract_py <- rgee:::ee_source_python(oauth_func_path)

sf_y <- y
ee_y <- sf_as_ee(y[[attr(y, "sf_column")]], quiet = TRUE)

ee_add_rows <- function(f) {
  f_prop <- ee$Feature$get(f, "system:index")
  ee$Feature(ee$Feature$set(f, "ee_ID", f_prop))
}
ee_y <- ee$FeatureCollection(ee_y) %>%
  ee$FeatureCollection$map(ee_add_rows)
fun_name <- gsub("Reducer.", "", (ee$Reducer$getInfo(fun))[["type"]]) # mean
x_ic <- rgee:::bands_to_image_collection(x)
create_tripplets <- function(img) {
  img_reduce_regions <- img$reduceRegions(
    collection = ee_y,
    reducer = fun,
    scale = scale
  )
  ee$FeatureCollection$map(img_reduce_regions, function(f) {
    ee$Feature$set(f, "imageId", ee$Image$get(img, "system:index"))
  })
}
triplets <- x_ic %>%
  ee$ImageCollection$map(create_tripplets) %>% 
  ee$ImageCollection$flatten()
table <- extract_py$table_format(triplets, "ee_ID", "imageId", fun_name)$
  map(function(feature) {
    ee$Feature$setGeometry(feature, NULL)
  })

table_geojson <- table %>%
  ee$FeatureCollection$getInfo() %>% 
  ee_utils_py_to_r()
class(table_geojson) <- "geo_list"
table_sf <- geojsonio::geojson_sf(table_geojson) |> 
  st_drop_geometry() |> 
  select(-id, -ee_ID)

out <- y %>%
  sf::st_drop_geometry() %>% 
  cbind(table_sf) |> 
  pivot_longer(
    cols = starts_with("X"),
    names_to = c("date"),
    names_pattern = "X(.*)_temperature_2m"
  ) |> 
  mutate(
    value = value - 273.15,
    date = ymd(date)
  ) |> 
  arrange(station_id, date)

# Test cache directory
cache_dir <- "data/era5_test"
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

# Test fetching data for a single station
cat("Testing single station fetch (station 1)...\n")
station_1 <- test_stations %>% slice(1)
era5_1 <- fetch_era5_station(
  station_id = station_1$station_id,
  latitude = station_1$latitude,
  longitude = station_1$longitude,
  start_date = station_1$start_date,
  end_date = station_1$end_date,
  ee = ee
)
cat("Fetched", nrow(era5_1), "rows for station 1\n")
print(head(era5_1))
cat("\n")

# Test cache write
cat("Testing cache write...\n")
cache_file <- file.path(cache_dir, "era5_cache.csv")
write_era5_cache(era5_1, cache_file)
cat("Cache written to:", cache_file, "\n\n")

# Test cache read
cat("Testing cache read...\n")
cache_data <- read_era5_cache(cache_file)
cat("Cache read successfully, rows:", nrow(cache_data), "\n")
print(head(cache_data))
cat("\n")

# Test determine fetch plan
cat("Testing determine_era5_fetch_plan...\n")
fetch_plan <- determine_era5_fetch_plan(test_stations, cache_dir, era5_last_date)
cat("Fetch plan created with", nrow(fetch_plan), "stations to fetch\n")
print(fetch_plan %>% select(station_id, latitude, longitude, n_dates))
cat("\n")

# Test batch collection
cat("Testing collect_era5_data (batch fetch with incremental caching)...\n")
era5_cache <- collect_era5_data(fetch_plan, cache_dir, gee_init)
cat("Batch collection complete! Total rows in cache:", nrow(era5_cache), "\n")
print(era5_cache %>% group_by(station_id) %>% summarise(n = n(), .groups = "drop"))
cat("\n")

# Test merge to stations
cat("Testing merge_era5_to_stations...\n")
stations_with_airtemp <- merge_era5_to_stations(test_stations, era5_cache)
cat("Merge complete!\n")
print(stations_with_airtemp %>% select(station_id, latitude, longitude))
cat("\n")

# Check merged data
cat("Checking merged data for station 1...\n")
station_1_merged <- stations_with_airtemp %>%
  filter(station_id == "test_station_1") %>%
  unnest(data)
print(head(station_1_merged, 10))
cat("\n")

cat("✓ All tests passed!\n")
cat("\nNext step: Run tar_make() with a subset of real stations\n")