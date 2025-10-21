# Function to send SNS notification
send_sns_notification <- function(subject, message) {
  sns_topic_arn <- Sys.getenv("AWS_SNS_TOPIC_ARN")

  if (sns_topic_arn == "") {
    log_warn("AWS_SNS_TOPIC_ARN not set, skipping SNS notification")
    return(invisible(NULL))
  }

  log_info("Sending SNS notification to {sns_topic_arn}")
  log_info("Subject: {subject}")

  tryCatch(
    {
      result <- system2(
        "aws",
        args = c(
          "sns",
          "publish",
          "--topic-arn",
          sns_topic_arn,
          "--subject",
          shQuote(subject),
          "--message",
          shQuote(message)
        ),
        stdout = TRUE,
        stderr = TRUE
      )

      if (attr(result, "status") %||% 0 == 0) {
        log_debug("SNS notification sent successfully")
      } else {
        log_warn("Failed to send SNS notification")
      }
    },
    error = function(e) {
      log_warn("Error sending SNS notification: {conditionMessage(e)}")
    }
  )
}

# Function to sync output to S3
sync_output_to_s3 <- function() {
  bucket <- Sys.getenv("AWS_S3_BUCKET")
  prefix <- Sys.getenv("AWS_S3_PREFIX")
  output_dir <- "data/output"

  if (bucket == "") {
    log_warn("AWS_S3_BUCKET not set, skipping S3 upload")
    return(invisible(NULL))
  }

  log_info("Uploading {output_dir} to s3://{bucket}/{prefix}")

  result <- system2(
    "aws",
    args = c(
      "s3",
      "sync",
      "--quiet",
      "--cache-control",
      "'max-age=86400, public'",
      output_dir,
      paste0("s3://", bucket, "/", prefix)
    ),
    stdout = FALSE,
    stderr = FALSE
  )

  if (result != 0) {
    stop("S3 upload failed with exit code ", result)
  }

  log_success("S3 upload completed successfully")

  list(bucket = bucket, prefix = prefix)
}
