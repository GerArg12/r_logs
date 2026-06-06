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

#* Upload and process log file
#* @post /logs/upload
function(req, res) {
  content <- req$postBody
  parsed_results <- parse_log_content(content)
  
  if (nrow(parsed_results$valid) == 0) {
    res$status <- 400
    return(list(status = "error", message = "No valid logs found in content"))
  }
  
  # For Phase 3: We need to ensure this data is "processed" so analytics work.
  # We simulate a store and global process update for this demo.
  write_processed_outputs(parsed_results$valid)
  
  res$status <- 201
  list(
    status = "ok",
    records_parsed = nrow(parsed_results$valid),
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
  
  # Append to existing processed data for Phase 3 demo
  existing <- get_processed_data()
  combined <- if(is.null(existing)) parsed_results$valid else bind_rows(existing, parsed_results$valid)
  write_processed_outputs(combined)
  
  res$status <- 201
  list(
    status = "ok",
    records_parsed = nrow(parsed_results$valid),
    errors = nrow(parsed_results$invalid),
    source = body$source
  )
}

#* Analytics: Top IPs
#* @get /analytics/top-ips
function() {
  get_top_ips()
}

#* Analytics: Requests over time
#* @get /analytics/requests-over-time
function() {
  get_requests_over_time()
}

#* Analytics: Top Resources
#* @get /analytics/top-resources
function() {
  get_top_resources()
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
