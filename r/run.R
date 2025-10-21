#!/usr/bin/env Rscript

library(targets)
library(logger)

log_appender(appender_stdout)
log_level <- toupper(Sys.getenv("LOG_LEVEL", unset = "INFO"))
log_threshold(log_level)

source("_targets.R")

tar_meta_download()

tryCatch(
  {
    log_info("Running pipeline...")
    tar_invalidate(c(
      "usgs_stations",
      "usgs_raw_data_new",
      "nps_datasets",
      "nps_raw_data",
      "aktemp_raw_data",
      "config",
    ))
    tar_make()

    log_success("Targets pipeline completed successfully")

    progress <- tar_progress()
    if (any(progress$progress == "errored")) {
      targets_errored <- paste0(progress$name[progress$progress == "errored"], collapse = ", ")
      log_warn("Some targets errored: {targets_errored}")
    } else {
      targets_errored <- "None"
    }

    # Upload to S3
    s3_info <- sync_output_to_s3()

    # Send success notification
    tar_load(output_config)
    success_msg <- sprintf(
      paste0(
        "The data processing pipeline completed successfully.\n\n",
        "Data uploaded to: s3://%s/%s\n\n",
        "Last updated at: %s\n",
        "Last ERA5-Land date: %s",
        "\n\n",
        "Targets errored (if any): %s"
      ),
      s3_info$bucket,
      s3_info$prefix,
      output_config$last_updated,
      output_config$era5_last_date,
      targets_errored
    )
    send_sns_notification(
      subject = "[AKTEMPVIZ] Pipeline Succeeded",
      message = success_msg
    )

    log_success("Pipeline finished successfully")
  },
  error = function(e) {
    error_msg <- conditionMessage(e)
    log_error("Pipeline failed: {error_msg}")

    send_sns_notification(
      subject = "[AKTEMPVIZ] Pipeline Failed",
      message = sprintf(
        "The data processing pipeline failed with error:\n\nTime: %s\n\n%s",
        lubridate::format_ISO8601(Sys.time(), usetz = TRUE),
        error_msg
      )
    )

    quit(status = 1)
  }
)
