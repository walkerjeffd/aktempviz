# AKTEMPVIZ dataset

library(tidyverse)
library(janitor)
library(jsonlite)
library(glue)
library(config)
library(sf)
library(mapview)

cfg <- config::get("aktemp")

con <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname = cfg$dbname,
  host = cfg$host,
  port = cfg$port,
  user = cfg$user,
  password = cfg$password
)

DBI::dbListTables(con)



# -------------------------------------------------------------------------

db_providers <- tbl(con, "providers") |> 
  select(provider_id = id, provider_code = code, provider_name = name)

db_stn <- tbl(con, "stations") |> 
  left_join(
    db_providers,
    by = c("provider_id")
  ) |> 
  filter(
    !private,
    waterbody_type == "STREAM"
  ) |> 
  semi_join(tbl(con, "series"), by = c("id" = "station_id")) |> 
  select(
    station_id = id, provider_code, provider_name,
    station_code = code, station_description = description,
    longitude, latitude, placement,
    waterbody_name, waterbody_type, mixed
  )

db_series <- tbl(con, "series") |> 
  semi_join(db_stn, by = c("station_id")) |> 
  filter(interval == "CONTINUOUS") |> 
  select(
    series_id = id, station_id,
    depth_m, depth_category,
    start_datetime, end_datetime, n_values,
    interval, frequency, reviewed, accuracy
  )

stn <- collect(db_stn)
series <- collect(db_series)

tabyl(stn, provider_code, placement)

stn_sf <- stn |> 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

mapview(stn_sf, zcol = "provider_code")
mapview(stn_sf, zcol = "placement")

stn_series <- stn |> 
  left_join(
    series |> 
      nest_by(station_id),
    by = c("station_id")
  ) |> 
  mutate(
    n_series = map_int(data, \(x) nrow(x))
  )

stn_series |> 
  tabyl(n_series)

stn_series |> 
  filter(n_series > 2) |> 
  unnest(data) |> 
  arrange()

db_series_flags <- tbl(con, "series_flags") |> 
  semi_join(db_series, by = c("series_id")) |> 
  select(
    flag_id = id, series_id, start_datetime, end_datetime,
    flag_type_id, flag_type_other
  )
db_series_daily <- tbl(con, "series_daily") |> 
  semi_join(db_series, by = c("series_id")) |> 
  select(
    series_id, date, n_values, min_temp_c, mean_temp_c, max_temp_c
  )

series_flags <- collect(db_series_flags) |> 
  rowwise() |> 
  mutate(
    flag_data = list({
      start_date <- as_date(with_tz(start_datetime, "America/Anchorage"))
      end_date <- as_date(with_tz(end_datetime, "America/Anchorage"))
      tibble(
        date = seq.Date(start_date, end_date, by = "day"),
        flag = flag_type_id
      )
    })
  ) |> 
  select(series_id, flag_id, flag_data) |> 
  nest_by(series_id, .key = "flags") |> 
  mutate(
    flags = list({
      bind_rows(flags) |> 
        select(flag_data) |> 
        unnest(flag_data) |> 
        group_by(date) |> 
        summarise(
          flag = str_c(sort(unique(flag)), collapse = ","),
          .groups = "drop"
        )
    })
  )

series_daily <- collect(db_series_daily)

series_data <- series |> 
  left_join(
    series_daily |> 
      nest_by(series_id),
    by = c("series_id")
  ) |> 
  left_join(
    series_flags,
    by = c("series_id")
  ) |> 
  rowwise() |> 
  mutate(
    data = list({
      if (is.null(flags)) {
        data$flag <- NA_character_
      } else {
        data <- data |> 
          left_join(flags, by = "date")
      }
      data
    }),
    n_daily_values = nrow(data)
  ) |> 
  select(-flags)

series_data |>
  select(series_id, data) |> 
  unnest(data) |> 
  filter(is.na(flag)) |> 
  ggplot(aes(yday(date), mean_temp_c)) +
  geom_hex(bins = 100) +
  scale_fill_viridis_c()

tabyl(series_data, depth_category)
tabyl(series_data, depth_m)
tabyl(series_data, reviewed)
tabyl(series_data, accuracy)

stn_data <- series_data |> 
  nest_by(station_id, .key = "series") |> 
  mutate(
    n_dates = {
      series |> 
        select(data) |> 
        unnest(data) |> 
        pull(date) |> 
        n_distinct()
    },
    n_dates_overlapping = {
      series |> 
        select(data) |> 
        unnest(data) |> 
        count(date) |> 
        filter(n > 1) |>
        nrow()
    },
    n_series = nrow(series)
  ) |> 
  ungroup()

stn_data |> 
  tabyl(n_series)

stn_data_overlapping <- stn_data |> 
  filter(n_dates_overlapping > 10)

stn_data <- stn_data |> 
  filter(n_dates_overlapping <= 10)

stn_data |> 
  select(station_id, series) |> 
  unnest(series) |> 
  select(station_id, series_id, data) |>
  unnest(data) |> 
  ggplot(aes(yday(date), mean_temp_c)) +
  geom_hex(bins = 100) +
  scale_fill_viridis_c()

stn_daily <- stn_data |> 
  select(station_id, series) |> 
  unnest(series) |> 
  select(station_id, data) |> 
  unnest(data) |> 
  filter(is.na(flag)) |> 
  group_by(station_id, date) |> 
  summarise(
    min_temp_c = min(min_temp_c, na.rm = TRUE),
    mean_temp_c = mean(mean_temp_c, na.rm = TRUE),
    max_temp_c = max(max_temp_c, na.rm = TRUE),
    .groups = "drop"
  ) |> 
  nest_by(station_id, .key = "daily") |> 
  ungroup() |> 
  print()


# export ------------------------------------------------------------------

out <- stn |> 
  mutate(
    url = glue("https://aktemp.uaa.alaska.edu/#/explorer/stations/{station_id}"),
  ) |> 
  inner_join(
    stn_daily,
    by = c("station_id")
  ) |> 
  transmute(
    provider_station_code = glue("{provider_code}:{station_code}"),
    station_id = as.character(station_id),
    station_code,
    station_description,
    waterbody_name,
    latitude, longitude,
    provider_code,
    provider_name,
    url,
    data = daily
  )
write_rds(out, "data/aktemp.rds")
