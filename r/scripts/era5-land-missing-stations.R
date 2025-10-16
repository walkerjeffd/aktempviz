# find stations where data not available in ERA5-Land
source("_targets.R")

tar_load(gee_config)

stations <- tar_read(wtemp_manifest) |> 
  distinct(dataset, provider_station_code, latitude, longitude) |> 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |> 
  print()

gee <- init_gee(gee_config$email, gee_config$key_file)
ee_Initialize(user = "aktempviz", email = "aktempviz@aktemp-walkerenvres.iam.gserviceaccount.com")

era5_stations <- stations |> 
  fetch_era5_stations(
    start_date = "2020-06-01",
    end_date = "2020-06-01",
    variable = "temperature_2m",
    gee = gee,
    scale = 9000,
    collection = "ECMWF/ERA5_LAND/DAILY_AGGR"
  ) |> 
  mutate(
    missing = is.na(value)
  )

era5_img <- gee$ImageCollection("ECMWF/ERA5_LAND/DAILY_AGGR") |> 
    gee$ImageCollection$filterDate("2020-06-01") |> 
    gee$ImageCollection$select("temperature_2m")

ee_stn <- era5_stations |> 
  filter(missing) |> 
  select(dataset, provider_station_code, latitude, longitude) |> 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |>
  sf_as_ee()

Map$setCenter(-150, 64, 4)
Map$addLayer(era5_img$first(), list(min = 240, max = 310)) + Map$addLayer(ee_stn, list(color = "red"), "missing stations")
