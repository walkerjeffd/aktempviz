# gis data

library(tidyverse)
library(sf)

wbd_gdb <- "data/gis/WBD_19_HU2_GDB/WBD_19_HU2_GDB.gdb"


# wbd: load ---------------------------------------------------------------

huc4 <- st_read(wbd_gdb, layer = "WBDHU4") %>%
  st_transform("EPSG:4326")
huc6 <- st_read(wbd_gdb, layer = "WBDHU6") %>%
  st_transform("EPSG:4326")
huc8 <- st_read(wbd_gdb, layer = "WBDHU8") %>%
  st_transform("EPSG:4326")

mapview::mapview(huc4)
mapview::mapview(huc6)
mapview::mapview(huc8)


# wbd: export -------------------------------------------------------------

list(huc4 = huc4, huc6 = huc6, huc8 = huc8) |> 
  write_rds("data/wbd.rds")

export_wbd_json <- function(x, id_field) {
  filepath <- file.path(glue("../public/data/gis/wbd_{id_field}.geojson"))
  if (file.exists(filepath)) {
    unlink(filepath)
  }
  x %>%
    st_simplify(dTolerance = 100) %>%
    st_write(filepath, layer_options = c(
      "COORDINATE_PRECISION=6",
      glue("ID_FIELD={id_field}")
    ), append=FALSE)
  filepath
}

export_wbd_json(huc4, "huc4")
export_wbd_json(huc6, "huc6")
export_wbd_json(huc8, "huc8")
