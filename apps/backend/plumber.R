library(plumber)
library(jsonlite)

source("R/log_store.R")
source("R/process_logs.R")
source("R/parser.R")
source("R/analytics.R")

last_preview <- NULL

get_request_filename <- function(req, fallback = NA_character_) {
  header_value <- req$HTTP_X_LOG_FILENAME
  query_value <- req$args$filename

  if (!is.null(header_value) && nzchar(header_value)) {
    return(basename(header_value))
  }
  if (!is.null(query_value) && nzchar(query_value)) {
    return(basename(query_value))
  }

  fallback
}

set_last_preview <- function(preview) {
  last_preview <<- preview
  preview
}

as_positive_integer <- function(value, default = 1L) {
  if (is.null(value) || length(value) == 0) {
    return(default)
  }

  parsed <- suppressWarnings(as.integer(value[[1]]))
  if (is.na(parsed) || parsed < 1L) {
    return(default)
  }

  parsed
}

make_log_dedupe_key <- function(logs) {
  if (is.null(logs) || nrow(logs) == 0) {
    return(character())
  }

  archivo <- if ("archivo" %in% names(logs)) logs$archivo else NA_character_
  linea <- if ("linea" %in% names(logs)) logs$linea else NA_integer_
  raw <- if ("raw" %in% names(logs)) logs$raw else NA_character_

  paste(archivo, linea, raw, sep = "\r")
}

shift_parsed_line_numbers <- function(parsed_results, line_start) {
  offset <- line_start - 1L

  if (nrow(parsed_results$valid) > 0 && "linea" %in% names(parsed_results$valid)) {
    parsed_results$valid$linea <- parsed_results$valid$linea + offset
  }
  if (nrow(parsed_results$invalid) > 0 && "linea" %in% names(parsed_results$invalid)) {
    parsed_results$invalid$linea <- parsed_results$invalid$linea + offset
  }

  parsed_results
}

split_new_streaming_logs <- function(valid_logs) {
  if (nrow(valid_logs) == 0) {
    return(list(accepted = valid_logs, duplicated = valid_logs))
  }

  valid_logs$dedupe_key <- make_log_dedupe_key(valid_logs)

  existing <- get_processed_data("streaming")
  existing_keys <- if (is.null(existing) || nrow(existing) == 0) {
    character()
  } else if ("dedupe_key" %in% names(existing)) {
    existing$dedupe_key
  } else {
    make_log_dedupe_key(existing)
  }

  duplicated <- valid_logs$dedupe_key %in% existing_keys

  list(
    accepted = valid_logs[!duplicated, , drop = FALSE],
    duplicated = valid_logs[duplicated, , drop = FALSE]
  )
}

#* Health check
#* @get /health
function() {
  list(status = "ok", service = "r-log-backend")
}

#* Return last parsed preview and errors
#* @get /logs/preview
function(res) {
  if (is.null(last_preview)) {
    res$status <- 404
    return(list(status = "not_found", message = "No preview available"))
  }

  last_preview
}

#* Preview log file without storing
#* @post /logs/preview
function(req) {
  content <- req$postBody
  filename <- get_request_filename(req)

  set_last_preview(parse_log_content(
    content,
    fuente = "upload",
    archivo = filename,
    preview_limit = 50
  ))
}

#* Internal helper to append and process logs
append_and_process <- function(valid_logs, type = "upload") {
  if (nrow(valid_logs) == 0) {
    return(list(records_processed = 0L, outputs = list()))
  }

  filename <- if(type == "streaming") "logs_streaming" else "logs_upload"
  existing <- get_processed_data(type)
  combined <- if(is.null(existing)) valid_logs else bind_rows(existing, valid_logs)
  write_processed_outputs(combined, filename)
}

#* Upload and process log file
#* @post /logs/upload
function(req, res) {
  content <- req$postBody
  filename <- get_request_filename(req)
  parsed_results <- parse_log_content(
    content,
    fuente = "upload",
    archivo = filename,
    preview_limit = .Machine$integer.max
  )
  set_last_preview(parsed_results)
  
  if (nrow(parsed_results$valid) == 0) {
    res$status <- 400
    return(list(
      status = "error",
      message = "No valid logs found in content",
      summary = parsed_results$summary,
      errors = parsed_results$invalid
    ))
  }
  
  result <- append_and_process(parsed_results$valid, "upload")
  
  res$status <- 201
  list(
    status = "ok",
    records_accepted = nrow(parsed_results$valid),
    records_rejected = nrow(parsed_results$invalid),
    summary = parsed_results$summary,
    errors = parsed_results$invalid,
    outputs = result$outputs
  )
}

#* Receive batch of logs from local monitoring
#* @post /logs/batch
function(req, res) {
  body <- fromJSON(req$postBody, simplifyVector = TRUE)
  
  if (is.null(body$logs) || length(body$logs) == 0) {
    return(list(status = "ignored", message = "No logs in batch"))
  }
  
  source_file <- if (is.null(body$source)) NA_character_ else basename(body$source)
  line_start <- as_positive_integer(body$line_start, default = 1L)
  all_content <- paste(body$logs, collapse = "\n")
  parsed_results <- parse_log_content(
    all_content,
    fuente = "streaming",
    archivo = source_file,
    preview_limit = .Machine$integer.max
  )
  parsed_results <- shift_parsed_line_numbers(parsed_results, line_start)
  deduped <- split_new_streaming_logs(parsed_results$valid)
  
  result <- append_and_process(deduped$accepted, "streaming")
  
  res$status <- if (nrow(deduped$accepted) > 0) 201 else 200
  list(
    status = "ok",
    records_accepted = nrow(deduped$accepted),
    records_duplicated = nrow(deduped$duplicated),
    records_rejected = nrow(parsed_results$invalid),
    errors = parsed_results$invalid,
    source = source_file,
    line_start = line_start,
    line_end = line_start + length(body$logs) - 1L,
    outputs = result$outputs
  )
}

#* Process stored logs and regenerate analytics CSV/JSON outputs
#* @post /logs/process
function(type = "all", res) {
  result <- tryCatch(
    process_analytics(source_type = type),
    error = function(e) {
      res$status <- 500
      list(status = "error", message = e$message)
    }
  )

  result
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
