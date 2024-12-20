load_wbd <- function (gdb_file) {
  huc4 <- st_read(gdb_file, layer = "WBDHU4", quiet = TRUE) %>%
    st_transform("EPSG:4326")
  huc6 <- st_read(gdb_file, layer = "WBDHU6", quiet = TRUE) %>%
    st_transform("EPSG:4326")
  huc8 <- st_read(gdb_file, layer = "WBDHU8", quiet = TRUE) %>%
    st_transform("EPSG:4326")
  
  list(
    huc4 = huc4,
    huc6 = huc6,
    huc8 = huc8
  )
}

extract_station_wbd <- function (combined_data, wbd) {
  stn_sf <- combined_data |> 
    select(dataset, station_id, latitude, longitude) |> 
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
  
  stn_sf |> 
    st_join(
      select(wbd$huc4, huc4)
    ) |> 
    st_join(
      select(wbd$huc6, huc6)
    ) |> 
    st_join(
      select(wbd$huc8, huc8)
    ) |> 
    st_drop_geometry() |> 
    select(dataset, station_id, huc4, huc6, huc8)
}