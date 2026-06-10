library(dplyr)

normalized_log_columns <- c(
  "ip",
  "timestamp",
  "metodo",
  "recurso",
  "status",
  "bytes",
  "fuente",
  "archivo",
  "raw",
  "linea"
)

empty_valid_logs <- function() {
  tibble::tibble(
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

empty_invalid_logs <- function() {
  tibble::tibble(
    linea = integer(),
    raw = character(),
    error = character(),
    fuente = character(),
    archivo = character()
  )
}

as_missing_text <- function(value) {
  if (is.null(value) || length(value) == 0 || is.na(value) || identical(value, "")) {
    return(NA_character_)
  }

  as.character(value)
}

#' Parser para logs Apache/Nginx comunes.
#' Formato: 192.168.1.10 - - [29/May/2026:10:00:00 +0000] "GET /login HTTP/1.1" 200 532
parse_apache_line <- function(
  line,
  fuente = "upload",
  archivo = NA_character_
) {
  pattern <- paste0(
    '^([^[:space:]]+) [^[:space:]]+ [^[:space:]]+ ',
    '\\[([^\\]]+)\\] ',
    '"([A-Z]+) ([^"]*?)(?: [^"]*)?" ',
    '([0-9]{3}) ([0-9]+|-)',
    '(?: .*)?$'
  )

  matches <- regexec(pattern, line, perl = TRUE)
  parts <- regmatches(line, matches)[[1]]

  if (length(parts) == 0) {
    return(list(valid = FALSE, error = "Formato Apache/Nginx no reconocido"))
  }

  timestamp <- as.POSIXct(parts[3], format = "%d/%b/%Y:%H:%M:%S %z", tz = "UTC")
  if (is.na(timestamp)) {
    return(list(valid = FALSE, error = "Timestamp invalido"))
  }

  status <- suppressWarnings(as.integer(parts[6]))
  bytes <- if (identical(parts[7], "-")) 0L else suppressWarnings(as.integer(parts[7]))

  if (is.na(status) || is.na(bytes)) {
    return(list(valid = FALSE, error = "Status o bytes invalidos"))
  }

  list(
    valid = TRUE,
    data = tibble::tibble(
      ip = parts[2],
      timestamp = timestamp,
      metodo = parts[4],
      recurso = parts[5],
      status = status,
      bytes = bytes,
      fuente = as_missing_text(fuente),
      archivo = as_missing_text(archivo),
      raw = line,
      linea = NA_integer_
    )
  )
}

parse_log_content <- function(
  content,
  fuente = "upload",
  archivo = NA_character_,
  preview_limit = 50
) {
  if (is.null(content) || !nzchar(content)) {
    return(list(
      status = "ok",
      summary = list(total = 0L, valid = 0L, invalid = 0L),
      valid = empty_valid_logs(),
      invalid = empty_invalid_logs()
    ))
  }

  con <- textConnection(content)
  on.exit(close(con), add = TRUE)
  lines <- readLines(con, warn = FALSE)

  parsed <- lapply(seq_along(lines), function(index) {
    line <- lines[[index]]
    result <- parse_apache_line(line, fuente = fuente, archivo = archivo)

    if (isTRUE(result$valid)) {
      result$data$linea <- index
      return(result$data)
    }

    tibble::tibble(
      linea = index,
      raw = line,
      error = result$error,
      fuente = as_missing_text(fuente),
      archivo = as_missing_text(archivo)
    )
  })

  valid_logs <- bind_rows(parsed[vapply(parsed, function(row) "ip" %in% names(row), logical(1))])
  invalid_logs <- bind_rows(parsed[vapply(parsed, function(row) "error" %in% names(row), logical(1))])

  if (nrow(valid_logs) == 0) {
    valid_logs <- empty_valid_logs()
  }
  if (nrow(invalid_logs) == 0) {
    invalid_logs <- empty_invalid_logs()
  }

  list(
    status = "ok",
    summary = list(
      total = length(lines),
      valid = nrow(valid_logs),
      invalid = nrow(invalid_logs)
    ),
    valid = head(valid_logs[, normalized_log_columns], preview_limit),
    invalid = head(invalid_logs, preview_limit)
  )
}
