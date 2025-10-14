library(rgee)
library(reticulate)

# Point reticulate to your conda environment
use_python("/opt/homebrew/Caskroom/miniconda/base/envs/aktempviz/bin/python", required = TRUE)

# Get the Earth Engine Python module
ee <- import("ee")

# Authenticate with service account
credentials <- ee$ServiceAccountCredentials(
  email = 'gee-aktempviz@aktemp-walkerenvres.iam.gserviceaccount.com',
  key_file = '/Users/jeff/git/aktempviz/r/gee-service-account.json'
)

# Initialize with service account email
ee$Initialize(credentials = credentials)

image <- ee$Image('USGS/SRTMGL1_003')
print(image$getInfo())
