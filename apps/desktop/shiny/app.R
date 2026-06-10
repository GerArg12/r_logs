library(shiny)
library(jsonlite)
library(ggplot2)

backend_url <- Sys.getenv("BACKEND_URL", unset = "http://127.0.0.1:8000")

ui <- fluidPage(
  tags$head(
    tags$title("R Logs Desktop"),
    tags$style(HTML("
      body { background: #f4f6f8; color: #1f2933; margin: 0; }
      .container-fluid { padding-left: 0; padding-right: 0; }
      .app-layout { display: flex; min-height: 100vh; }
      .sidebar {
        width: 248px; flex: 0 0 248px; background: #111827; color: #f9fafb;
        padding: 22px 18px; display: flex; flex-direction: column; gap: 18px;
      }
      .brand { font-size: 20px; font-weight: 700; margin-bottom: 6px; }
      .brand-subtitle { color: #a7b0bf; font-size: 12px; margin-bottom: 10px; }
      .nav-stack .btn {
        width: 100%; text-align: left; margin-bottom: 8px; border: 0; border-radius: 8px;
        background: transparent; color: #d8dee9; padding: 10px 12px;
      }
      .nav-stack .btn:hover, .nav-stack .btn:focus { background: #1f2937; color: #ffffff; }
      .main-content { flex: 1; padding: 24px 30px; min-width: 0; }
      .topbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px; }
      .topbar h2 { margin: 0; font-size: 24px; font-weight: 700; }
      .backend-pill {
        background: #e7eef8; color: #24476f; border: 1px solid #c9d8ea;
        border-radius: 999px; padding: 7px 12px; font-size: 12px; font-family: monospace;
      }
      .panel {
        background: #ffffff; border: 1px solid #d7dee8; border-radius: 8px;
        padding: 18px; margin-bottom: 18px; box-shadow: 0 1px 2px rgba(15, 23, 42, 0.05);
      }
      .panel-header { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; margin-bottom: 14px; }
      .panel-header h3, .panel-header h4 { margin-top: 0; margin-bottom: 4px; }
      .control-grid { display: grid; grid-template-columns: minmax(220px, 1fr) minmax(260px, 1.2fr); gap: 16px; }
      .metric-grid { display: grid; grid-template-columns: 1.2fr 2.8fr; gap: 18px; align-items: start; }
      .metric-side { display: flex; flex-direction: column; gap: 14px; }
      .metric-card {
        border: 1px solid #dbe3ee; border-radius: 8px; padding: 14px;
        background: #fbfcfe;
      }
      .metric-card-title { font-size: 12px; color: #5d6b7c; text-transform: uppercase; letter-spacing: 0.04em; }
      .metric-card-value { font-size: 26px; font-weight: 700; margin-top: 4px; }
      .plot-panel { min-height: 600px; }
      .status { font-family: monospace; white-space: pre-wrap; }
      .table-container { overflow-x: auto; }
      .error-text { color: #c7362f; font-size: 0.9em; }
      .success-text { color: #0f7b52; font-size: 0.9em; }
      .muted-text { color: #687789; font-size: 0.92em; }
      .path-field input { font-family: monospace; }
      .radio-inline { margin-right: 16px; }
      @media (max-width: 900px) {
        .app-layout { flex-direction: column; }
        .sidebar { width: 100%; flex-basis: auto; }
        .metric-grid, .control-grid { grid-template-columns: 1fr; }
      }
    ")),
    tags$script(HTML("
      document.addEventListener('click', async function(event) {
        const button = event.target && event.target.closest('#select_monitor_file');
        if (!button) return;

        if (!window.rLogsDesktop || !window.rLogsDesktop.selectLogFile) {
          Shiny.setInputValue('monitor_file_picker_error', Date.now(), {priority: 'event'});
          return;
        }

        const selectedPath = await window.rLogsDesktop.selectLogFile();
        if (!selectedPath) return;

        const input = document.getElementById('monitor_file_path');
        if (input) {
          input.value = selectedPath;
          input.dispatchEvent(new Event('input', { bubbles: true }));
          input.dispatchEvent(new Event('change', { bubbles: true }));
        }

        Shiny.setInputValue('monitor_file_path', selectedPath, {priority: 'event'});
      });
    "))
  ),
  div(
    class = "app-layout",
    div(
      class = "sidebar",
      div(class = "brand", "R Logs Desktop"),
      div(class = "brand-subtitle", "Ingesta, monitoreo y analítica"),
      div(
        class = "nav-stack",
        actionButton("nav_analytics", "Analítica"),
        actionButton("nav_upload", "Ingesta de archivos"),
        actionButton("nav_monitor", "Escucha local"),
        actionButton("nav_legacy", "Legacy JSON")
      )
    ),
    div(
      class = "main-content",
      div(
        class = "topbar",
        h2("Panel de métricas de logs"),
        div(class = "backend-pill", backend_url)
      ),
      tabsetPanel(
        id = "main_nav",
        type = "hidden",
        tabPanel(
          "analytics",
          value = "analytics",
          div(
            class = "panel",
            div(
              class = "panel-header",
              div(
                h3("Analítica"),
                div(class = "muted-text", "Selecciona una fuente y una métrica para ver el gráfico principal.")
              ),
              div(
                actionButton("process_analytics", "Procesar Analítica", class = "btn-success"),
                actionButton("refresh_analytics", "Refrescar Métricas", class = "btn-primary")
              )
            ),
            div(
              class = "control-grid",
              radioButtons(
                "analytics_source",
                "Tipo de ingesta",
                choices = c("Ingesta de archivos" = "upload", "Escucha local" = "streaming"),
                selected = "upload",
                inline = TRUE
              ),
              radioButtons(
                "analytics_metric",
                "Métrica",
                choices = c("IPs con más peticiones" = "ips", "Recursos consultados" = "resources", "Peticiones por hora" = "time"),
                selected = "ips",
                inline = TRUE
              )
            ),
            tags$hr(),
            uiOutput("analytics_status")
          ),
          div(
            class = "metric-grid",
            div(
              class = "metric-side",
              uiOutput("metric_summary_cards"),
              div(
                class = "panel",
                h4("Datos del gráfico"),
                div(class = "table-container", tableOutput("main_metric_table"))
              )
            ),
            div(
              class = "panel plot-panel",
              div(class = "panel-header", h3(textOutput("main_metric_title", inline = TRUE))),
              plotOutput("main_metric_plot", height = "520px")
            )
          )
        ),
        tabPanel(
          "upload",
          value = "upload",
          fluidRow(
            column(
              4,
              div(
                class = "panel",
                h4("Cargar archivo .log"),
                fileInput("log_file", "Seleccionar archivo .log", accept = c(".log", "text/plain")),
                actionButton("process_upload", "Procesar y Guardar", class = "btn-success", style = "width: 100%;")
              ),
              div(
                class = "panel",
                h4("Resumen de preview"),
                uiOutput("preview_summary"),
                uiOutput("upload_result")
              )
            ),
            column(
              8,
              div(
                class = "panel",
                h4("Previsualización de datos"),
                div(class = "table-container", tableOutput("preview_table"))
              ),
              div(
                class = "panel",
                h4("Errores de parsing"),
                div(class = "table-container", tableOutput("preview_errors"))
              )
            )
          )
        ),
        tabPanel(
          "monitor",
          value = "monitor",
          fluidRow(
            column(
              4,
              div(
                class = "panel",
                h4("Escucha local"),
                actionButton("select_monitor_file", "Seleccionar archivo .log", class = "btn-default", style = "width: 100%;"),
                tags$br(), tags$br(),
                div(
                  class = "path-field",
                  textInput("monitor_file_path", "Archivo .log a monitorear", value = "")
                ),
                actionButton("toggle_monitor", "Iniciar Monitoreo", class = "btn-primary", style = "width: 100%;"),
                tags$br(), tags$br(),
                uiOutput("monitor_status")
              )
            ),
            column(
              8,
              div(
                class = "panel",
                h4("Actividad reciente"),
                verbatimTextOutput("monitor_log")
              )
            )
          )
        ),
        tabPanel(
          "legacy",
          value = "legacy",
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
)

server <- function(input, output, session) {
  # --- Estados Reactivos ---
  response_text <- reactiveVal("Sin solicitudes todavía.")
  logs_data <- reactiveVal(data.frame())
  preview_data <- reactiveVal(NULL)
  upload_result <- reactiveVal(NULL)

  observeEvent(input$nav_analytics, { updateTabsetPanel(session, "main_nav", selected = "analytics") })
  observeEvent(input$nav_upload, { updateTabsetPanel(session, "main_nav", selected = "upload") })
  observeEvent(input$nav_monitor, { updateTabsetPanel(session, "main_nav", selected = "monitor") })
  observeEvent(input$nav_legacy, { updateTabsetPanel(session, "main_nav", selected = "legacy") })

  fetch_backend_json <- function(path) {
    tryCatch(
      suppressWarnings(fromJSON(paste0(backend_url, path), flatten = TRUE)),
      error = function(e) NULL
    )
  }

  post_backend_json <- function(path) {
    response <- tryCatch({
      system2("curl", args = c("-sS", "-X", "POST", paste0(backend_url, path)), stdout = TRUE)
    }, error = function(e) NULL)

    if (is.null(response)) {
      return(NULL)
    }

    tryCatch(
      fromJSON(paste(response, collapse = "\n"), flatten = TRUE),
      error = function(e) NULL
    )
  }

  as_analytics_table <- function(value, required_columns) {
    if (is.null(value)) {
      return(data.frame())
    }

    table <- tryCatch(
      {
        if (is.data.frame(value)) {
          value
        } else {
          as.data.frame(value, stringsAsFactors = FALSE)
        }
      },
      error = function(e) data.frame()
    )

    if (!all(required_columns %in% names(table))) {
      return(data.frame())
    }

    if ("count" %in% names(table)) {
      table$count <- suppressWarnings(as.integer(table$count))
    }

    table
  }

  is_empty_table <- function(value) {
    !is.data.frame(value) || nrow(value) == 0
  }

  count_file_lines <- function(path) {
    tryCatch(
      length(readLines(path, warn = FALSE)),
      error = function(e) 0L
    )
  }

  response_count <- function(response, name) {
    value <- response[[name]]
    if (is.null(value) || length(value) == 0 || is.na(value)) {
      return(0L)
    }

    as.integer(value[[1]])
  }

  metric_source_label <- function(source) {
    if (identical(source, "streaming")) "Escucha local" else "Ingesta de archivos"
  }

  metric_label <- function(metric) {
    switch(
      metric,
      ips = "IPs con más peticiones",
      resources = "Recursos consultados",
      time = "Peticiones por hora",
      "Métrica"
    )
  }

  metric_color <- function(metric) {
    switch(metric, ips = "#0072B2", resources = "#009E73", time = "#D55E00", "#0072B2")
  }

  metric_theme <- function() {
    theme_minimal(base_size = 13) +
      theme(
        panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank(),
        plot.title = element_text(face = "bold", size = 16, color = "#1f2933"),
        plot.subtitle = element_text(color = "#5d6b7c"),
        axis.title = element_text(color = "#394657"),
        axis.text = element_text(color = "#394657")
      )
  }

  # --- Lógica de Ingesta .log ---
  observeEvent(input$log_file, {
    req(input$log_file)
    upload_result(NULL)
    
    # Llamada al endpoint /logs/preview
    res <- tryCatch({
      system2("curl", args = c("-sS", "-X", "POST", paste0(backend_url, "/logs/preview"), 
                               "-H", paste0("X-Log-Filename:", basename(input$log_file$name)),
                               "--data-binary", paste0("@", input$log_file$datapath)), 
              stdout = TRUE)
    }, error = function(e) return(NULL))
    
    if (!is.null(res)) {
      preview_data(fromJSON(paste(res, collapse = "\n"), flatten = TRUE))
    }
  })

  output$preview_summary <- renderUI({
    req(preview_data())
    data <- preview_data()
    total_count <- if (is.null(data$summary$total)) 0 else data$summary$total
    valid_count <- if (is.null(data$summary$valid)) 0 else data$summary$valid
    invalid_count <- if (is.null(data$summary$invalid)) 0 else data$summary$invalid
    
    tagList(
      p(strong("Total líneas: "), total_count),
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

  output$preview_errors <- renderTable({
    req(preview_data())
    errors <- tryCatch(
      as.data.frame(preview_data()$invalid, stringsAsFactors = FALSE),
      error = function(e) data.frame()
    )
    if (is_empty_table(errors)) {
      return(data.frame())
    }

    errors
  })

  output$upload_result <- renderUI({
    req(upload_result())
    result <- upload_result()
    if (identical(result$status, "ok")) {
      return(paste("Registros aceptados:", result$records_accepted, "| Rechazados:", result$records_rejected))
    }

    div(class = "error-text", result$message)
  })

  observeEvent(input$process_upload, {
    req(input$log_file)
    
    res <- tryCatch({
      system2("curl", args = c("-sS", "-X", "POST", paste0(backend_url, "/logs/upload"), 
                               "-H", paste0("X-Log-Filename:", basename(input$log_file$name)),
                               "--data-binary", paste0("@", input$log_file$datapath)), 
              stdout = TRUE)
    }, error = function(e) return(NULL))
    
    if (!is.null(res)) {
      parsed_response <- fromJSON(paste(res, collapse = "\n"), flatten = TRUE)
      upload_result(parsed_response)

      if (identical(parsed_response$status, "ok")) {
        showNotification("Archivo procesado con éxito", type = "message")
        fetch_logs()
        update_analytics("upload")
      } else {
        showNotification(parsed_response$message, type = "error")
      }
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
  monitor_state <- reactiveVal("detenido")
  monitor_history <- reactiveVal("Esperando inicio...")
  last_file_size <- reactiveVal(NULL)
  last_file_line_count <- reactiveVal(0L)
  last_monitor_read <- reactiveVal(NULL)
  last_batch_summary <- reactiveVal(NULL)

  observeEvent(input$monitor_file_picker_error, {
    showNotification("El selector de archivos solo esta disponible en la app Electron. Puedes pegar la ruta manualmente.", type = "warning")
  })

  observeEvent(input$toggle_monitor, {
    if (is_monitoring()) {
      is_monitoring(FALSE)
      monitor_state("detenido")
      updateActionButton(session, "toggle_monitor", label = "Iniciar Monitoreo", icon = NULL)
    } else {
      log_file <- input$monitor_file_path
      if (is.null(log_file) || !nzchar(log_file)) {
        showNotification("Selecciona un archivo .log para monitorear", type = "error")
        return()
      }
      if (!file.exists(log_file)) {
        showNotification("El archivo seleccionado no existe", type = "error")
        return()
      }
      if (!grepl("\\.log$", log_file, ignore.case = TRUE)) {
        showNotification("Selecciona un archivo con extension .log", type = "error")
        return()
      }

      last_file_size(file.info(log_file)$size)
      last_file_line_count(count_file_lines(log_file))
      last_batch_summary(NULL)
      is_monitoring(TRUE)
      monitor_state("activa")
      updateActionButton(session, "toggle_monitor", label = "Detener Monitoreo", icon = icon("stop"))
      monitor_history(paste0(Sys.time(), ": Monitoreo iniciado en ", log_file, "\n"))
    }
  })

  observe({
    invalidateLater(5000) # Polling cada 5 segundos
    req(is_monitoring())
    
    log_file <- input$monitor_file_path
    if (is.null(log_file) || !file.exists(log_file)) {
      is_monitoring(FALSE)
      monitor_state("error")
      updateActionButton(session, "toggle_monitor", label = "Iniciar Monitoreo", icon = NULL)
      monitor_history(paste0(Sys.time(), ": El archivo monitoreado ya no existe\n", monitor_history()))
      return()
    }

    size <- file.info(log_file)$size
    old_size <- last_file_size()
    if (is.null(old_size) || is.na(old_size) || size < old_size) {
      old_size <- 0
      last_file_line_count(0L)
      monitor_history(paste0(Sys.time(), ": Archivo reiniciado o truncado, lectura desde el inicio\n", monitor_history()))
    }

    if (size > old_size) {
      con <- file(log_file, "rb")
      on.exit(close(con), add = TRUE)
      seek(con, old_size)
      new_lines <- readLines(con, warn = FALSE)

      last_file_size(size)

      if (length(new_lines) > 0) {
        line_start <- last_file_line_count() + 1L
        line_end <- line_start + length(new_lines) - 1L
        batch_payload <- list(
          logs = new_lines,
          source = basename(log_file),
          line_start = line_start,
          byte_start = old_size,
          byte_end = size
        )
        res <- tryCatch({
          system2("curl", args = c("-sS", "-X", "POST", paste0(backend_url, "/logs/batch"),
                                   "-H", "Content-Type:application/json",
                                   "-d", shQuote(toJSON(batch_payload, auto_unbox = TRUE))),
                  stdout = TRUE)
        }, error = function(e) NULL)

        if (is.null(res)) {
          monitor_state("error")
          monitor_history(paste0(Sys.time(), ": Error enviando nuevas lineas al backend\n", monitor_history()))
          return()
        }

        response <- tryCatch(
          fromJSON(paste(res, collapse = "\n"), flatten = TRUE),
          error = function(e) NULL
        )
        last_file_line_count(line_end)
        last_monitor_read(Sys.time())

        if (is.null(response) || !identical(response$status, "ok")) {
          monitor_state("error")
          monitor_history(paste0(Sys.time(), ": El backend no confirmo el lote enviado\n", monitor_history()))
          return()
        }

        monitor_state("activa")
        last_batch_summary(response)
        monitor_history(paste0(
          Sys.time(), ": ", basename(log_file),
          " -> aceptadas ", response_count(response, "records_accepted"),
          ", duplicadas ", response_count(response, "records_duplicated"),
          ", rechazadas ", response_count(response, "records_rejected"),
          " (lineas ", line_start, "-", line_end, ")\n",
          monitor_history()
        ))
        fetch_logs()
        update_analytics("streaming")
      }
    } else {
      last_file_size(size)
    }
  })

  output$monitor_status <- renderUI({
    state <- monitor_state()
    status_color <- switch(state, activa = "#28a745", error = "#dc3545", "#6c757d")
    status_text <- toupper(state)
    selected_file <- input$monitor_file_path
    last_read <- last_monitor_read()
    batch_summary <- last_batch_summary()

    tagList(
      div(style = paste0("color: ", status_color, "; font-weight: bold;"), "Estado: ", status_text),
      if (!is.null(selected_file) && nzchar(selected_file)) {
        div(class = "status", "Archivo: ", selected_file)
      },
      if (!is.null(last_read)) {
        div(class = "status", "Ultima lectura: ", format(last_read, "%Y-%m-%d %H:%M:%S"))
      },
      if (!is.null(batch_summary)) {
        div(
          class = "status",
          "Ultimo lote: aceptadas ", response_count(batch_summary, "records_accepted"),
          ", duplicadas ", response_count(batch_summary, "records_duplicated"),
          ", rechazadas ", response_count(batch_summary, "records_rejected")
        )
      }
    )
  })

  output$monitor_log <- renderText({
    monitor_history()
  })

  # --- Lógica de Analítica (Fase 3 - Separada) ---
  analytics_data <- reactiveValues(
    upload = list(ips = NULL, time = NULL, resources = NULL),
    streaming = list(ips = NULL, time = NULL, resources = NULL)
  )
  analytics_state <- reactiveVal("sin_datos")
  analytics_message <- reactiveVal("Sin métricas procesadas todavía.")
  last_analytics_process <- reactiveVal(NULL)

  update_analytics <- function(type = "all") {
    analytics_state("cargando")
    analytics_message("Cargando métricas...")
    types <- if(type == "all") c("upload", "streaming") else type
    
    for(t in types) {
      ips <- as_analytics_table(
        fetch_backend_json(paste0("/analytics/top-ips?type=", t)),
        c("ip", "count")
      )
      time <- as_analytics_table(
        fetch_backend_json(paste0("/analytics/requests-over-time?type=", t)),
        c("timestamp", "count")
      )
      resources <- as_analytics_table(
        fetch_backend_json(paste0("/analytics/top-resources?type=", t)),
        c("recurso", "count")
      )
      
      analytics_data[[t]] <- list(ips = ips, time = time, resources = resources)
    }

    has_data <- any(vapply(c("upload", "streaming"), function(t) {
      !is_empty_table(analytics_data[[t]]$ips) ||
        !is_empty_table(analytics_data[[t]]$time) ||
        !is_empty_table(analytics_data[[t]]$resources)
    }, logical(1)))

    if (has_data) {
      analytics_state("procesado")
      analytics_message("Métricas actualizadas.")
    } else {
      analytics_state("sin_datos")
      analytics_message("No hay datos disponibles para graficar.")
    }
  }

  observeEvent(input$process_analytics, {
    analytics_state("cargando")
    analytics_message("Procesando métricas...")

    result <- post_backend_json("/logs/process?type=all")
    if (is.null(result) || !identical(result$status, "ok")) {
      analytics_state("error")
      analytics_message("No se pudo procesar la analítica en el backend.")
      return()
    }

    last_analytics_process(Sys.time())
    update_analytics()
  })

  observeEvent(input$refresh_analytics, { update_analytics() })

  output$analytics_status <- renderUI({
    state <- analytics_state()
    message <- analytics_message()
    processed_at <- last_analytics_process()
    css_class <- switch(state, procesado = "success-text", error = "error-text", "status")

    tagList(
      div(class = css_class, message),
      if (!is.null(processed_at)) {
        div(class = "status", "Último procesamiento: ", format(processed_at, "%Y-%m-%d %H:%M:%S"))
      }
    )
  })

  selected_metric_data <- reactive({
    source <- if (is.null(input$analytics_source)) "upload" else input$analytics_source
    metric <- if (is.null(input$analytics_metric)) "ips" else input$analytics_metric
    source_data <- analytics_data[[source]]

    if (identical(metric, "resources")) {
      return(source_data$resources)
    }
    if (identical(metric, "time")) {
      return(source_data$time)
    }

    source_data$ips
  })

  output$main_metric_title <- renderText({
    source <- if (is.null(input$analytics_source)) "upload" else input$analytics_source
    metric <- if (is.null(input$analytics_metric)) "ips" else input$analytics_metric

    paste(metric_label(metric), "-", metric_source_label(source))
  })

  output$metric_summary_cards <- renderUI({
    source <- if (is.null(input$analytics_source)) "upload" else input$analytics_source
    source_data <- analytics_data[[source]]
    ips_total <- if (is_empty_table(source_data$ips)) 0L else sum(source_data$ips$count, na.rm = TRUE)
    resources_total <- if (is_empty_table(source_data$resources)) 0L else nrow(source_data$resources)
    time_points <- if (is_empty_table(source_data$time)) 0L else nrow(source_data$time)

    tagList(
      div(
        class = "metric-card",
        div(class = "metric-card-title", "Peticiones en ranking"),
        div(class = "metric-card-value", ips_total)
      ),
      div(
        class = "metric-card",
        div(class = "metric-card-title", "Recursos en ranking"),
        div(class = "metric-card-value", resources_total)
      ),
      div(
        class = "metric-card",
        div(class = "metric-card-title", "Horas con actividad"),
        div(class = "metric-card-value", time_points)
      )
    )
  })

  output$main_metric_table <- renderTable({
    df <- selected_metric_data()
    if (is_empty_table(df)) {
      return(data.frame())
    }

    head(df, 12)
  })

  output$main_metric_plot <- renderPlot({
    source <- if (is.null(input$analytics_source)) "upload" else input$analytics_source
    metric <- if (is.null(input$analytics_metric)) "ips" else input$analytics_metric
    df <- selected_metric_data()

    if (is_empty_table(df)) {
      ggplot() +
        annotate("text", x = 0, y = 0, label = "Sin datos para la selección actual", size = 5, color = "#5d6b7c") +
        xlim(-1, 1) +
        ylim(-1, 1) +
        theme_void()
    } else if (identical(metric, "resources")) {
      ggplot(df, aes(x = reorder(recurso, count), y = count)) +
        geom_col(fill = metric_color(metric), width = 0.68) +
        coord_flip() +
        labs(
          title = "Recursos más consultados",
          subtitle = metric_source_label(source),
          x = "Recurso",
          y = "Peticiones"
        ) +
        metric_theme()
    } else if (identical(metric, "time")) {
      df$timestamp <- as.POSIXct(df$timestamp)
      ggplot(df, aes(x = timestamp, y = count)) +
        geom_line(color = metric_color(metric), size = 1.1) +
        geom_point(shape = 21, size = 3.5, stroke = 1, color = "#78350f", fill = "#F6C85F") +
        labs(
          title = "Peticiones por hora",
          subtitle = metric_source_label(source),
          x = "Hora",
          y = "Peticiones"
        ) +
        metric_theme()
    } else {
      ggplot(df, aes(x = reorder(ip, count), y = count)) +
        geom_col(fill = metric_color(metric), width = 0.68) +
        coord_flip() +
        labs(
          title = "IPs con más peticiones",
          subtitle = metric_source_label(source),
          x = "IP",
          y = "Peticiones"
        ) +
        metric_theme()
    }
  })

  isolate({ update_analytics() })
}

shinyApp(ui = ui, server = server)
