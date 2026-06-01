library(shiny)
library(jsonlite)

backend_url <- Sys.getenv("BACKEND_URL", unset = "http://127.0.0.1:8000")

ui <- fluidPage(
  tags$head(
    tags$title("R Logs Desktop"),
    tags$style(HTML("
      body { background: #f6f7f9; color: #20242a; }
      .app-shell { max-width: 1080px; margin: 24px auto; }
      .panel { background: #ffffff; border: 1px solid #d9dee7; border-radius: 8px; padding: 18px; }
      .status { font-family: monospace; white-space: pre-wrap; }
      textarea.form-control { min-height: 160px; font-family: monospace; }
    "))
  ),
  div(
    class = "app-shell",
    h2("R Logs Desktop"),
    fluidRow(
      column(
        5,
        div(
          class = "panel",
          h4("Enviar log"),
          textAreaInput(
            "payload",
            label = NULL,
            value = '{
  "ip": "10.0.0.5",
  "evento": "login_failed",
  "usuario": "admin",
  "timestamp": "2026-05-29T10:00:00"
}',
            width = "100%"
          ),
          actionButton("send", "Enviar", class = "btn-primary"),
          tags$hr(),
          strong("Respuesta"),
          verbatimTextOutput("response", placeholder = TRUE)
        )
      ),
      column(
        7,
        div(
          class = "panel",
          h4("Logs procesados"),
          actionButton("refresh", "Actualizar"),
          tags$hr(),
          tableOutput("logs")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  response_text <- reactiveVal("Sin solicitudes todavia.")
  logs_data <- reactiveVal(data.frame())

  fetch_logs <- function() {
    url <- paste0(backend_url, "/logs")
    raw <- tryCatch(
      readLines(url, warn = FALSE),
      error = function(error) NULL
    )

    if (is.null(raw)) {
      logs_data(data.frame())
      return(invisible(FALSE))
    }

    parsed <- fromJSON(paste(raw, collapse = "\n"), flatten = TRUE)
    logs_data(parsed)
    invisible(TRUE)
  }

  observeEvent(input$send, {
    parsed_payload <- tryCatch(
      fromJSON(input$payload),
      error = function(error) {
        response_text(paste("JSON invalido:", error$message))
        NULL
      }
    )

    if (is.null(parsed_payload)) {
      return()
    }

    response <- tryCatch(
      httr::POST(
        paste0(backend_url, "/log"),
        body = parsed_payload,
        encode = "json"
      ),
      error = function(error) error
    )

    if (inherits(response, "error")) {
      response_text(paste("Error:", response$message))
      return()
    }

    content <- httr::content(response, as = "text", encoding = "UTF-8")
    response_text(content)
    fetch_logs()
  })

  observeEvent(input$refresh, {
    fetch_logs()
  })

  output$response <- renderText(response_text())

  output$logs <- renderTable({
    logs_data()
  })

  fetch_logs()
}

shinyApp(ui = ui, server = server)
