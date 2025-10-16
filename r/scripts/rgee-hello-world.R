library(rgee)
library(reticulate)

# Point reticulate to virtual environment
# use_virtualenv("./.venv", required = TRUE)
print(py_config())

# Get the Earth Engine Python module
ee <- import("ee")

# Authenticate with service account
credentials <- ee$ServiceAccountCredentials(
  email = 'aktempviz@aktemp-walkerenvres.iam.gserviceaccount.com',
  key_file = 'service-account.json'
)

# Initialize with service account email
ee$Initialize(credentials = credentials)

image <- ee$Image('USGS/SRTMGL1_003')
print(image$getInfo())
