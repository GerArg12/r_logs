library(dplyr)
library(lubridate)
library(jsonlite)
library(readr)
library(tibble)

processed_filename <- function(source_type = "upload") {
  switch(
    source_type,
    upload = "logs_upload.json",
    streaming = "logs_streaming.json",
    all = NULL,
    "logs_upload.json"
  )
}

normalize_processed_logs <- function(df) {
  if (is.null(df) || nrow(df) == 0) {
    return(empty_processed_logs())
  }

  df <- as_tibble(df)

  if (!"timestamp" %in% names(df)) {
    df$timestamp <- as.POSIXct(character(), tz = "UTC")
  } else {
    df$timestamp <- as.POSIXct(df$timestamp, tz = "UTC")
  }

  if (!"ip" %in% names(df)) df$ip <- NA_character_
  if (!"recurso" %in% names(df)) df$recurso <- NA_character_
  if (!"fuente" %in% names(df)) df$fuente <- NA_character_

  df
}

empty_processed_logs <- function() {
  tibble(
    ip = character(),
    timestamp = as.POSIXct(character(), tz = "UTC"),
    metodo = character(),
    recurso = character(),
    status = integer(),
    bytes = integer(),
    fuente = character(),
    archivo = character(),
    raw = character(),
    linea = integer()
  )
}

read_processed_file <- function(filename) {
  json_path <- file.path(get_output_dir(), filename)
  if (!file.exists(json_path)) {
    return(empty_processed_logs())
  }

  normalize_processed_logs(fromJSON(json_path, simplifyVector = TRUE))
}

get_processed_data <- function(source_type = "upload") {
  if (identical(source_type, "all")) {
    return(bind_rows(
      read_processed_file("logs_upload.json"),
      read_processed_file("logs_streaming.json")
    ))
  }

  read_processed_file(processed_filename(source_type))
}

get_top_ips <- function(n = 10, source_type = "upload") {
  df <- get_processed_data(source_type)
  if (nrow(df) == 0) return(tibble(ip = character(), count = integer()))

  df |>
    filter(!is.na(ip), nzchar(ip)) |>
    count(ip, sort = TRUE, name = "count") |>
    head(n)
}

get_requests_over_time <- function(source_type = "upload") {
  df <- get_processed_data(source_type)
  if (nrow(df) == 0) {
    return(tibble(timestamp = as.POSIXct(character(), tz = "UTC"), count = integer()))
  }

  df |>
    filter(!is.na(timestamp)) |>
    mutate(timestamp = floor_date(timestamp, "hour")) |>
    count(timestamp, name = "count") |>
    arrange(timestamp)
}

get_top_resources <- function(n = 10, source_type = "upload") {
  df <- get_processed_data(source_type)
  if (nrow(df) == 0) return(tibble(recurso = character(), count = integer()))

  df |>
    filter(!is.na(recurso), nzchar(recurso)) |>
    count(recurso, sort = TRUE, name = "count") |>
    head(n)
}

write_metric_outputs <- function(metric_name, data) {
  output_dir <- get_output_dir()
  csv_path <- file.path(output_dir, paste0(metric_name, ".csv"))
  json_path <- file.path(output_dir, paste0(metric_name, ".json"))

  write_csv(data, csv_path)
  write_json(data, json_path, pretty = TRUE, auto_unbox = TRUE)

  list(csv = csv_path, json = json_path)
}

process_analytics <- function(source_type = "all") {
  ensure_storage_dirs()

  normalized_source <- if (source_type %in% c("upload", "streaming", "all")) source_type else "all"
  source_suffix <- normalized_source

  metrics <- list(
    top_ips = get_top_ips(source_type = normalized_source),
    requests_over_time = get_requests_over_time(source_type = normalized_source),
    top_resources = get_top_resources(source_type = normalized_source)
  )

  outputs <- list(
    top_ips = write_metric_outputs(paste0("analytics_", source_suffix, "_top_ips"), metrics$top_ips),
    requests_over_time = write_metric_outputs(paste0("analytics_", source_suffix, "_requests_over_time"), metrics$requests_over_time),
    top_resources = write_metric_outputs(paste0("analytics_", source_suffix, "_top_resources"), metrics$top_resources)
  )

  list(
    status = "ok",
    source_type = normalized_source,
    records_available = nrow(get_processed_data(normalized_source)),
    metrics = list(
      top_ips = nrow(metrics$top_ips),
      requests_over_time = nrow(metrics$requests_over_time),
      top_resources = nrow(metrics$top_resources)
    ),
    outputs = outputs
  )
}
