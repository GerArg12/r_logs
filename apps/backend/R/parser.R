library(stringr)
library(dplyr)
library(lubridate)

#' Parser para logs Apache/Nginx (Combined Log Format)
#' Formato: 192.168.1.10 - - [29/May/2026:10:00:00 +0000] "GET /login HTTP/1.1" 200 532
parse_apache_line <- function(line) {
  pattern <- '^(\\S+) (\\S+) (\\S+) \\[([^\\]]+)\\] "(\\S+) (.*?) (\\S+)" (\\d+) (\\d+|-)'
  
  matches <- str_match(line, pattern)
  
  if (all(is.na(matches))) {
    return(NULL)
  }
  
  # Extraer campos
  ip <- matches[2]
  raw_ts <- matches[5]
  metodo <- matches[6]
  recurso <- matches[7]
  status <- as.integer(matches[9])
  bytes <- if (matches[10] == "-") 0L else as.integer(matches[10])
  
  # Parsear timestamp: 29/May/2026:10:00:00 +0000
  timestamp <- as.POSIXct(raw_ts, format = "%d/%b/%Y:%H:%M:%S %z", tz = "UTC")
  
  list(
    ip = ip,
    timestamp = timestamp,
    metodo = metodo,
    recurso = recurso,
    status = status,
    bytes = bytes,
    raw = line
  )
}

parse_log_content <- function(content) {
  lines <- readLines(textConnection(content))
  
  results <- lapply(lines, function(line) {
    parsed <- parse_apache_line(line)
    if (is.null(parsed)) {
      return(list(valid = FALSE, raw = line, error = "Formato no reconocido"))
    }
    parsed$valid <- TRUE
    parsed
  })
  
  valid_logs <- Filter(function(x) x$valid, results)
  invalid_logs <- Filter(function(x) !x$valid, results)
  
  list(
    valid = bind_rows(lapply(valid_logs, as.data.frame)),
    invalid = bind_rows(lapply(invalid_logs, as.data.frame)),
    total = length(lines)
  )
}
