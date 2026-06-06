library(dplyr)
library(lubridate)
library(jsonlite)

# Directorio de salida (mismo que process_logs.R)
get_output_dir <- function() {
  path <- "output"
  if (!dir.exists(path)) dir.create(path, recursive = TRUE)
  path
}

get_processed_data <- function() {
  json_path <- file.path(get_output_dir(), "logs_procesados.json")
  if (!file.exists(json_path)) return(NULL)
  
  fromJSON(json_path) |> as_tibble()
}

# 1. IP con más peticiones
get_top_ips <- function(n = 10) {
  df <- get_processed_data()
  if (is.null(df) || nrow(df) == 0) return(tibble(ip = character(), count = integer()))
  
  df |>
    count(ip, sort = TRUE, name = "count") |>
    head(n)
}

# 2. Cantidad de peticiones en el tiempo (por hora)
get_requests_over_time <- function() {
  df <- get_processed_data()
  if (is.null(df) || nrow(df) == 0) return(tibble(timestamp = POSIXct(), count = integer()))
  
  df |>
    mutate(timestamp = floor_date(as.POSIXct(timestamp), "hour")) |>
    count(timestamp, name = "count") |>
    arrange(timestamp)
}

# 3. Recursos más consultados
get_top_resources <- function(n = 10) {
  df <- get_processed_data()
  if (is.null(df) || nrow(df) == 0) return(tibble(recurso = character(), count = integer()))
  
  df |>
    count(recurso, sort = TRUE, name = "count") |>
    head(n)
}
