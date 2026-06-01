library(jsonlite)

get_log_dir <- function() {
  Sys.getenv("LOG_STORAGE_DIR", unset = "logs")
}

get_output_dir <- function() {
  Sys.getenv("LOG_OUTPUT_DIR", unset = "output")
}

ensure_storage_dirs <- function() {
  dir.create(get_log_dir(), recursive = TRUE, showWarnings = FALSE)
  dir.create(get_output_dir(), recursive = TRUE, showWarnings = FALSE)
}

store_log <- function(log_entry) {
  ensure_storage_dirs()

  file_name <- sprintf(
    "log_%s_%s.json",
    format(Sys.time(), "%Y%m%d%H%M%S"),
    sample(100000:999999, 1)
  )
  file_path <- file.path(get_log_dir(), file_name)

  writeLines(toJSON(log_entry, auto_unbox = TRUE, pretty = TRUE), file_path)
  file_path
}
