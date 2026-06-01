library(plumber)
library(jsonlite)

source("R/log_store.R")
source("R/process_logs.R")

#* Health check
#* @get /health
function() {
  list(status = "ok", service = "r-log-backend")
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
