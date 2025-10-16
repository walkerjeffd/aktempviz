# compare daily values for ERA5 vs ERA5-Land
source("_targets.R")

tar_load(gee_config)

stations <- data.frame(
    site_id = c("interior_fairbanks", "southeast_juneau", "northslope_barrow"),
    site_name = c("Interior (Fairbanks)", "Southeast (Juneau)", "North Slope (Barrow)"),
    longitude = c(-147.72, -134.42, -156.79),
    latitude = c(64.84, 58.30, 71.29),
    elevation = c(138, 4, 5)
  ) |> 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |> 
  print()

gee <- init_gee(gee_config$email, gee_config$key_file)
ee_Initialize(user = "aktempviz", email = "aktempviz@aktemp-walkerenvres.iam.gserviceaccount.com")

era5_land <- stations |> 
  fetch_era5_stations(
    start_date = "2019-01-01",
    end_date = "2019-12-31",
    variable = "temperature_2m",
    gee = gee,
    scale = 9000,
    collection = "ECMWF/ERA5_LAND/DAILY_AGGR"
  ) |> 
  mutate(
    missing = is.na(value)
  )
era5_standard <- stations |> 
  fetch_era5_stations(
    start_date = "2019-01-01",
    end_date = "2019-12-31",
    variable = "mean_2m_air_temperature",
    gee = gee,
    scale = 9000,
    collection = "ECMWF/ERA5/DAILY"
  ) |> 
  mutate(
    missing = is.na(value)
  )

all_data <- bind_rows(
  era5_land = era5_land,
  era5 = era5_standard,
  .id = "collection"
) |> 
  mutate(value = value - 273.15)

all_data |> 
  ggplot(aes(date, value)) +
  geom_line(aes(color = collection)) +
  scale_color_brewer(palette = "Set1") +
  facet_wrap(vars(site_name), ncol = 1) +
  labs(y = "temp_c") +
  theme_bw()

all_data |> 
  select(site_name, date, collection, value) |> 
  pivot_wider(names_from = collection, values_from = value) |>
  ggplot(aes(era5, era5_land)) +
  geom_abline() +
  geom_point(aes(color = month(date))) +
  geom_blank(aes(era5_land, era5)) +
  scale_color_viridis_c() +
  facet_wrap(vars(site_name)) +
  theme_bw() +
  theme(aspect.ratio = 1)
