#!/usr/bin/env Rscript

library(logger)

log_appender(appender_stdout)
log_level <- toupper(Sys.getenv("LOG_LEVEL", unset = "INFO"))
log_threshold(log_level)

tryCatch({
  library(targets)
  
  log_info("Running pipeline...")
  tar_invalidate(c(
    "usgs_stations", "usgs_raw_data",
    "nps_datasets", "nps_raw_data",
    "aktemp_raw_data",
    "config"
  ))
  tar_make()

  log_success("Pipeline completed successfully")
}, error = function(e) {
  log_error("Pipeline failed: {conditionMessage(e)}")
  quit(status = 1)
})

tryCatch({
  # Upload to S3 using AWS CLI
  bucket <- Sys.getenv("AWS_S3_BUCKET")
  prefix <- Sys.getenv("AWS_S3_PREFIX")
  output_dir <- tar_read(output_dir)

  # Use system2 to run aws s3 sync command
  log_info("Uploading to S3...")
  result <- system2(
    "aws", 
    args = c("s3", "sync", "--quiet", output_dir, paste0("s3://", bucket, "/", prefix)),
    stdout = FALSE,
    stderr = FALSE
  )
  
  if (result == 0) {
    log_success("S3 upload completed successfully")
  } else {
    log_error("S3 upload failed")
    quit(status = 1)
  }
}, error = function(e) {
  log_error("S3 upload failed: {conditionMessage(e)}")
  quit(status = 1)
})
