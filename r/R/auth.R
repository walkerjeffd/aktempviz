init_gcs_auth <- function () {
  if (Sys.getenv("GCS_AUTH_JSON") != "") {
    # Decode the base64 encoded JSON
    auth_json <- jsonlite::base64_dec(Sys.getenv("GCS_AUTH_JSON")) |> 
      rawToChar()

    # Parse the JSON
    auth_data <- jsonlite::fromJSON(auth_json)
    
    # Write the JSON to a temporary file
    temp_auth <- tempfile(fileext = ".json")
    writeLines(auth_json, temp_auth)

    # Set up Google Cloud Storage authentication for googleCloudStorageR
    Sys.setenv(GCS_AUTH_FILE = temp_auth)

    # Set up Google Earth Engine authentication variables for rgee
    Sys.setenv(GEE_SERVICE_ACCOUNT_EMAIL = auth_data$client_email, unset = "")
    Sys.setenv(GEE_SERVICE_ACCOUNT_KEY_FILE = temp_auth, unset = "")
  }
}