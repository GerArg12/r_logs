library(plumber)
library(jsonlite)

source("R/log_store.R")
source("R/process_logs.R")
source("R/parser.R")
source("R/analytics.R")

#* Health check
#* @get /health
function() {
  list(status = "ok", service = "r-log-backend")
}

#* Preview log file without storing
#* @post /logs/preview
function(req) {
  content <- req$postBody
  parse_log_content(content)
}

#* Internal helper to append and process logs
append_and_process <- function(valid_logs, type = "upload") {
  filename <- if(type == "streaming") "logs_streaming" else "logs_upload"
  existing <- get_processed_data(type)
  combined <- if(is.null(existing)) valid_logs else bind_rows(existing, valid_logs)
  write_processed_outputs(combined, filename)
  return(nrow(valid_logs))
}

#* Upload and process log file
#* @post /logs/upload
function(req, res) {
  content <- req$postBody
  parsed_results <- parse_log_content(content)
  
  if (nrow(parsed_results$valid) == 0) {
    res$status <- 400
    return(list(status = "error", message = "No valid logs found in content"))
  }
  
  count <- append_and_process(parsed_results$valid, "upload")
  
  res$status <- 201
  list(
    status = "ok",
    records_parsed = count,
    errors = nrow(parsed_results$invalid)
  )
}

#* Receive batch of logs from local monitoring
#* @post /logs/batch
function(req, res) {
  body <- fromJSON(req$postBody, simplifyVector = TRUE)
  
  if (is.null(body$logs) || length(body$logs) == 0) {
    return(list(status = "ignored", message = "No logs in batch"))
  }
  
  all_content <- paste(body$logs, collapse = "\n")
  parsed_results <- parse_log_content(all_content)
  
  count <- append_and_process(parsed_results$valid, "streaming")
  
  res$status <- 201
  list(
    status = "ok",
    records_parsed = count,
    errors = nrow(parsed_results$invalid),
    source = body$source
  )
}

#* Analytics: Top IPs
#* @get /analytics/top-ips
function(type = "upload") {
  get_top_ips(source_type = type)
}

#* Analytics: Requests over time
#* @get /analytics/requests-over-time
function(type = "upload") {
  get_requests_over_time(source_type = type)
}

#* Analytics: Top Resources
#* @get /analytics/top-resources
function(type = "upload") {
  get_top_resources(source_type = type)
}

#* Receive one application log and process the dataset
#* @post /log
function(req, res) {
  body <- fromJSON(req$postBody, simplifyVector = TRUE)

  stored_file <- store_log(body)
  result <- process_logs()

  res$status <- 201
  list(
    status = "ok",
    stored_file = basename(stored_file),
    records_processed = result$records_processed,
    outputs = result$outputs
  )
}

#* Return processed logs as JSON
#* @get /logs
function(res) {
  output_file <- file.path(get_output_dir(), "logs_procesados.json")

  if (!file.exists(output_file)) {
    res$status <- 404
    return(list(status = "not_found", message = "No processed logs available"))
  }

  fromJSON(output_file, simplifyVector = FALSE)
}
