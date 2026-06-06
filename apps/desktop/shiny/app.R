library(shiny)
library(jsonlite)
library(ggplot2)

backend_url <- Sys.getenv("BACKEND_URL", unset = "http://127.0.0.1:8000")

ui <- fluidPage(
  tags$head(
    tags$title("R Logs Desktop"),
    tags$style(HTML("
      body { background: #f6f7f9; color: #20242a; }
      .app-shell { max-width: 1200px; margin: 24px auto; }
      .panel { background: #ffffff; border: 1px solid #d9dee7; border-radius: 8px; padding: 18px; margin-bottom: 20px; }
      .status { font-family: monospace; white-space: pre-wrap; }
      .table-container { overflow-x: auto; }
      .error-text { color: #dc3545; font-size: 0.9em; }
    "))
  ),
  div(
    class = "app-shell",
    h2("R Logs Desktop"),
    tabsetPanel(
      tabPanel(
        "Analítica",
        fluidRow(
          column(
            12,
            div(
              class = "panel",
              actionButton("refresh_analytics", "Refrescar Todas las Métricas", class = "btn-primary"),
              tags$hr()
            )
          )
        ),
        h3("📁 Ingesta de Archivos (Estático)", style = "margin-left: 15px;"),
        fluidRow(
          column(4, div(class = "panel", h4("Top IPs"), plotOutput("plot_ips_upload", height = "250px"))),
          column(4, div(class = "panel", h4("Top Recursos"), plotOutput("plot_resources_upload", height = "250px"))),
          column(4, div(class = "panel", h4("Tiempo"), plotOutput("plot_time_upload", height = "250px")))
        ),
        tags$hr(),
        h3("⚡ Monitoreo en Tiempo Real (Streaming)", style = "margin-left: 15px;"),
        fluidRow(
          column(4, div(class = "panel", h4("Top IPs"), plotOutput("plot_ips_streaming", height = "250px"))),
          column(4, div(class = "panel", h4("Top Recursos"), plotOutput("plot_resources_streaming", height = "250px"))),
          column(4, div(class = "panel", h4("Tiempo"), plotOutput("plot_time_streaming", height = "250px")))
        )
      ),
      tabPanel(
        "Ingesta de Archivos (.log)",
        fluidRow(
          column(
            4,
            div(
              class = "panel",
              h4("Cargar Archivo"),
              fileInput("log_file", "Seleccionar archivo .log", accept = c(".log", "text/plain")),
              actionButton("process_upload", "Procesar y Guardar", class = "btn-success", style = "width: 100%;")
            ),
            div(
              class = "panel",
              h4("Resumen de Preview"),
              uiOutput("preview_summary")
            )
          ),
          column(
            8,
            div(
              class = "panel",
              h4("Previsualización de Datos"),
              div(class = "table-container", tableOutput("preview_table"))
            )
          )
        )
      ),
      tabPanel(
        "Escucha Local (Monitoring)",
        fluidRow(
          column(
            4,
            div(
              class = "panel",
              h4("Configuración"),
              textInput("monitor_path", "Ruta de carpeta a monitorear", value = "/home/carlos/r_logs/logs_demo"),
              helpText("Se buscarán archivos .log cada 5 segundos."),
              actionButton("toggle_monitor", "Iniciar Monitoreo", class = "btn-primary", style = "width: 100%;"),
              tags$br(), tags$br(),
              uiOutput("monitor_status")
            )
          ),
          column(
            8,
            div(
              class = "panel",
              h4("Actividad Reciente"),
              verbatimTextOutput("monitor_log")
            )
          )
        )
      ),
      tabPanel(
        "Envío JSON (Legacy)",
        fluidRow(
          column(
            5,
            div(
              class = "panel",
              h4("Enviar log JSON"),
              textAreaInput("payload", label = NULL, value = '{"ip": "10.0.0.5", "evento": "login_failed", "usuario": "admin", "timestamp": "2026-05-29T10:00:00"}', width = "100%", height = "150px"),
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
              div(class = "table-container", tableOutput("logs"))
            )
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {
  # --- Estados Reactivos ---
  response_text <- reactiveVal("Sin solicitudes todavía.")
  logs_data <- reactiveVal(data.frame())
  preview_data <- reactiveVal(NULL)

  # --- Lógica de Ingesta .log ---
  observeEvent(input$log_file, {
    req(input$log_file)
    
    # Llamada al endpoint /logs/preview
    res <- tryCatch({
      system2("curl", args = c("-sS", "-X", "POST", paste0(backend_url, "/logs/preview"), 
                               "--data-binary", paste0("@", input$log_file$datapath)), 
              stdout = TRUE)
    }, error = function(e) return(NULL))
    
    if (!is.null(res)) {
      preview_data(fromJSON(res))
    }
  })

  output$preview_summary <- renderUI({
    req(preview_data())
    data <- preview_data()
    valid_count <- if(is.null(data$valid)) 0 else nrow(data$valid)
    invalid_count <- if(is.null(data$invalid)) 0 else nrow(data$invalid)
    
    tagList(
      p(strong("Total líneas: "), data$total),
      p(strong("Válidas: "), valid_count, style = "color: #28a745;"),
      p(strong("Inválidas: "), invalid_count, style = "color: #dc3545;"),
      if(invalid_count > 0) {
        div(class = "error-text", "Se detectaron formatos no reconocidos.")
      }
    )
  })

  output$preview_table <- renderTable({
    req(preview_data())
    preview_data()$valid
  })

  observeEvent(input$process_upload, {
    req(input$log_file)
    
    res <- tryCatch({
      system2("curl", args = c("-sS", "-X", "POST", paste0(backend_url, "/logs/upload"), 
                               "--data-binary", paste0("@", input$log_file$datapath)), 
              stdout = TRUE)
    }, error = function(e) return(NULL))
    
    if (!is.null(res)) {
      showNotification("Archivo procesado con éxito", type = "message")
      fetch_logs()
      update_analytics("upload")
    }
  })

  # --- Lógica Legacy (JSON) ---
  fetch_logs <- function() {
    url <- paste0(backend_url, "/logs")
    raw <- tryCatch(readLines(url, warn = FALSE), error = function(error) NULL)
    if (is.null(raw)) {
      logs_data(data.frame())
      return(invisible(FALSE))
    }
    parsed <- fromJSON(paste(raw, collapse = "\n"), flatten = TRUE)
    logs_data(parsed)
    invisible(TRUE)
  }

  observeEvent(input$send, {
    req(input$payload)
    payload_file <- tempfile(fileext = ".json")
    writeLines(input$payload, payload_file)
    on.exit(unlink(payload_file), add = TRUE)

    response <- tryCatch({
      system2("curl", args = c("-sS", "-X", "POST", paste0(backend_url, "/log"), 
                               "-H", "Content-Type:application/json", 
                               "--data-binary", paste0("@", payload_file)), 
              stdout = TRUE, stderr = TRUE)
    }, error = function(error) error)

    if (inherits(response, "error")) {
      response_text(paste("Error:", response$message))
    } else {
      response_text(paste(response, collapse = "\n"))
      fetch_logs()
    }
  })

  observeEvent(input$refresh, { fetch_logs() })
  output$response <- renderText(response_text())
  output$logs <- renderTable({ logs_data() })

  # --- Lógica de Monitoreo Local (Fase 2) ---
  is_monitoring <- reactiveVal(FALSE)
  monitor_history <- reactiveVal("Esperando inicio...")
  last_file_sizes <- reactiveVal(list()) # Para detectar nuevas líneas

  observeEvent(input$toggle_monitor, {
    if (is_monitoring()) {
      is_monitoring(FALSE)
      updateActionButton(session, "toggle_monitor", label = "Iniciar Monitoreo", icon = NULL)
    } else {
      if (!dir.exists(input$monitor_path)) {
        showNotification("La carpeta no existe", type = "error")
        return()
      }
      is_monitoring(TRUE)
      updateActionButton(session, "toggle_monitor", label = "Detener Monitoreo", icon = icon("stop"))
      monitor_history(paste0(Sys.time(), ": Monitoreo iniciado en ", input$monitor_path, "\n"))
    }
  })

  observe({
    invalidateLater(5000) # Polling cada 5 segundos
    req(is_monitoring())
    
    path <- input$monitor_path
    files <- list.files(path, pattern = "\\.log$", full.names = TRUE)
    
    if (length(files) == 0) return()
    
    current_sizes <- last_file_sizes()
    new_sizes <- list()
    activity <- ""
    
    for (f in files) {
      size <- file.info(f)$size
      old_size <- if (is.null(current_sizes[[f]])) 0 else current_sizes[[f]]
      
      if (size > old_size) {
        # Leer solo las nuevas líneas
        con <- file(f, "rb")
        seek(con, old_size)
        new_lines <- readLines(con, warn = FALSE)
        close(con)
        
        if (length(new_lines) > 0) {
          # Enviar al backend (/logs/batch)
          batch_payload <- list(logs = new_lines, source = basename(f))
          res <- tryCatch({
            system2("curl", args = c("-sS", "-X", "POST", paste0(backend_url, "/logs/batch"), 
                                     "-H", "Content-Type:application/json",
                                     "-d", shQuote(toJSON(batch_payload, auto_unbox = TRUE))), 
                    stdout = TRUE)
          }, error = function(e) NULL)
          
          activity <- paste0(activity, Sys.time(), ": ", basename(f), " -> Enviadas ", length(new_lines), " líneas\n")
        }
      }
      new_sizes[[f]] <- size
    }
    
    if (activity != "") {
      monitor_history(paste0(activity, monitor_history()))
      last_file_sizes(new_sizes)
      fetch_logs()
      update_analytics("streaming")
    } else {
      last_file_sizes(new_sizes) # Actualizar tamaños incluso si no hay cambios (primera vez)
    }
  })

  output$monitor_status <- renderUI({
    status_color <- if (is_monitoring()) "#28a745" else "#6c757d"
    status_text <- if (is_monitoring()) "ACTIVO" else "DETENIDO"
    div(style = paste0("color: ", status_color, "; font-weight: bold;"), "Estado: ", status_text)
  })

  output$monitor_log <- renderText({
    monitor_history()
  })

  # --- Lógica de Analítica (Fase 3 - Separada) ---
  analytics_data <- reactiveValues(
    upload = list(ips = NULL, time = NULL, resources = NULL),
    streaming = list(ips = NULL, time = NULL, resources = NULL)
  )

  update_analytics <- function(type = "all") {
    types <- if(type == "all") c("upload", "streaming") else type
    
    for(t in types) {
      ips <- tryCatch({ fromJSON(paste0(backend_url, "/analytics/top-ips?type=", t)) }, error = function(e) NULL)
      time <- tryCatch({ fromJSON(paste0(backend_url, "/analytics/requests-over-time?type=", t)) }, error = function(e) NULL)
      resources <- tryCatch({ fromJSON(paste0(backend_url, "/analytics/top-resources?type=", t)) }, error = function(e) NULL)
      
      analytics_data[[t]] <- list(ips = ips, time = time, resources = resources)
    }
  }

  observeEvent(input$refresh_analytics, { update_analytics() })

  # Render Plots Upload
  output$plot_ips_upload <- renderPlot({
    req(analytics_data$upload)
    df <- analytics_data$upload$ips
    if(is.null(df) || nrow(df) == 0) return(NULL)
    ggplot(df, aes(x = reorder(ip, count), y = count)) + geom_col(fill = "#007bff") + coord_flip() + labs(x = "IP", y = "Count") + theme_minimal()
  })
  output$plot_resources_upload <- renderPlot({
    req(analytics_data$upload)
    df <- analytics_data$upload$resources
    if(is.null(df) || nrow(df) == 0) return(NULL)
    ggplot(df, aes(x = reorder(recurso, count), y = count)) + geom_col(fill = "#28a745") + coord_flip() + labs(x = "Recurso", y = "Count") + theme_minimal()
  })
  output$plot_time_upload <- renderPlot({
    req(analytics_data$upload)
    df <- analytics_data$upload$time
    if(is.null(df) || nrow(df) == 0) return(NULL)
    df$timestamp <- as.POSIXct(df$timestamp)
    ggplot(df, aes(x = timestamp, y = count)) + geom_line(color = "#007bff") + geom_point() + theme_minimal()
  })

  # Render Plots Streaming
  output$plot_ips_streaming <- renderPlot({
    req(analytics_data$streaming)
    df <- analytics_data$streaming$ips
    if(is.null(df) || nrow(df) == 0) return(NULL)
    ggplot(df, aes(x = reorder(ip, count), y = count)) + geom_col(fill = "#ffc107") + coord_flip() + labs(x = "IP", y = "Count") + theme_minimal()
  })
  output$plot_resources_streaming <- renderPlot({
    req(analytics_data$streaming)
    df <- analytics_data$streaming$resources
    if(is.null(df) || nrow(df) == 0) return(NULL)
    ggplot(df, aes(x = reorder(recurso, count), y = count)) + geom_col(fill = "#17a2b8") + coord_flip() + labs(x = "Recurso", y = "Count") + theme_minimal()
  })
  output$plot_time_streaming <- renderPlot({
    req(analytics_data$streaming)
    df <- analytics_data$streaming$time
    if(is.null(df) || nrow(df) == 0) return(NULL)
    df$timestamp <- as.POSIXct(df$timestamp)
    ggplot(df, aes(x = timestamp, y = count)) + geom_line(color = "#dc3545") + geom_point() + theme_minimal()
  })

  isolate({ update_analytics() })
}

shinyApp(ui = ui, server = server)
