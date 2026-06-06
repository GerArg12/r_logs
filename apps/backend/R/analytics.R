library(dplyr)
library(lubridate)
library(jsonlite)

# Directorio de salida (mismo que process_logs.R)
get_output_dir <- function() {
  path <- "output"
  if (!dir.exists(path)) dir.create(path, recursive = TRUE)
  path
}

get_processed_data <- function(source_type = "upload") {
  filename <- if(source_type == "streaming") "logs_streaming.json" else "logs_upload.json"
  json_path <- file.path(get_output_dir(), filename)
  if (!file.exists(json_path)) return(NULL)
  
  df <- fromJSON(json_path) |> as_tibble()
  if (nrow(df) > 0 && "timestamp" %in% names(df)) {
    df$timestamp <- as.POSIXct(df$timestamp, tz = "UTC")
  }
  df
}

# 1. IP con más peticiones
get_top_ips <- function(n = 10, source_type = "upload") {
  df <- get_processed_data(source_type)
  if (is.null(df) || nrow(df) == 0) return(tibble(ip = character(), count = integer()))
  
  df |>
    count(ip, sort = TRUE, name = "count") |>
    head(n)
}

# 2. Cantidad de peticiones en el tiempo (por hora)
get_requests_over_time <- function(source_type = "upload") {
  df <- get_processed_data(source_type)
  if (is.null(df) || nrow(df) == 0) return(tibble(timestamp = POSIXct(), count = integer()))
  
  df |>
    mutate(timestamp = floor_date(as.POSIXct(timestamp), "hour")) |>
    count(timestamp, name = "count") |>
    arrange(timestamp)
}

# 3. Recursos más consultados
get_top_resources <- function(n = 10, source_type = "upload") {
  df <- get_processed_data(source_type)
  if (is.null(df) || nrow(df) == 0) return(tibble(recurso = character(), count = integer()))
  
  df |>
    count(recurso, sort = TRUE, name = "count") |>
    head(n)
}
