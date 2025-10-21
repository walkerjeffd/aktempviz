gcs_load_cache <- function(prefix) {
  bucket <- Sys.getenv("GCS_BUCKET")
  cache_filename <- tempfile(fileext = ".rds")

  googleCloudStorageR::gcs_get_object(
    object_name = prefix,
    bucket = bucket,
    saveToDisk = cache_filename,
    overwrite = TRUE
  )

  log_info("gcs: loading cache from {cache_filename}")
  if (file.exists(cache_filename)) {
    cache <- read_rds(cache_filename)
    log_info("gcs: loaded {nrow(cache$data)} rows from existing cache")
  } else {
    log_info("gcs: no existing cache found, starting fresh")
    cache <- list(data = NULL)
  }

  cache
}

gcs_save_cache <- function(x, prefix) {
  bucket <- Sys.getenv("GCS_BUCKET")
  cache_filename <- tempfile(fileext = ".rds")

  write_rds(x, cache_filename, compress = "gz")

  log_info("cvs: saving cache {cache_filename} to gs://{bucket}/{prefix}")
  googleCloudStorageR::gcs_upload(
    file = cache_filename,
    bucket = bucket,
    name = prefix,
    predefinedAcl = "bucketLevel"
  )
}
