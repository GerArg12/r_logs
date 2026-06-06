library(jsonlite)
library(dplyr)
library(purrr)
library(readr)
library(tibble)

read_log_file <- function(file_path) {
  fromJSON(file_path, simplifyVector = TRUE) |>
    as_tibble()
}

process_logs <- function() {
  ensure_storage_dirs()

  files <- list.files(get_log_dir(), pattern = "\\.json$", full.names = TRUE)

  if (length(files) == 0) {
    empty_logs <- tibble(
      ip = character(),
      evento = character(),
      usuario = character(),
      timestamp = as.POSIXct(character())
    )

    return(write_processed_outputs(empty_logs))
  }

  logs <- files |>
    map_dfr(read_log_file)

  logs_limpios <- logs |>
    mutate(
      timestamp = as.POSIXct(timestamp, tz = "UTC"),
      evento = as.factor(evento)
    ) |>
    arrange(desc(timestamp))

  write_processed_outputs(logs_limpios)
}

write_processed_outputs <- function(logs_limpios, filename = "logs_procesados") {
  csv_path <- file.path(get_output_dir(), paste0(filename, ".csv"))
  json_path <- file.path(get_output_dir(), paste0(filename, ".json"))

  write_csv(logs_limpios, csv_path)
  write_json(logs_limpios, json_path, pretty = TRUE, auto_unbox = TRUE)

  list(
    records_processed = nrow(logs_limpios),
    outputs = list(
      csv = csv_path,
      json = json_path
    )
  )
}
