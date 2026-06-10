# Backend R/Plumber

API REST para recibir logs, almacenarlos como JSON temporal y generar salidas procesadas con Tidyverse.

## Endpoints

- `GET /health`: verifica que el servicio responde.
- `POST /logs/preview`: recibe contenido `.log` y devuelve muestra parseada con errores.
- `GET /logs/preview`: devuelve el ultimo preview parseado.
- `POST /logs/upload`: recibe contenido `.log`, persiste registros validos y reporta errores.
- `POST /logs/batch`: recibe nuevas lineas detectadas por escucha local, evita duplicados por archivo/linea/contenido y devuelve aceptados, duplicados y rechazados.
- `POST /logs/process`: regenera las salidas CSV/JSON de analitica para `upload`, `streaming` o `all`.
- `GET /analytics/top-ips`: devuelve ranking de IPs con mas peticiones.
- `GET /analytics/requests-over-time`: devuelve peticiones agrupadas por hora.
- `GET /analytics/top-resources`: devuelve ranking de recursos consultados.
- `POST /log`: recibe un log en JSON, lo almacena y reprocesa el conjunto.
- `GET /logs`: devuelve el JSON procesado.

Payload minimo para escucha local:

```json
{
  "source": "access.log",
  "line_start": 125,
  "byte_start": 9821,
  "byte_end": 10244,
  "logs": [
    "192.168.1.10 - - [29/May/2026:10:00:00 +0000] \"GET /login HTTP/1.1\" 200 532"
  ]
}
```

## Desarrollo local

```bash
R -e "install.packages(c('plumber', 'jsonlite', 'dplyr', 'lubridate', 'purrr', 'readr', 'tibble'))"
R -e "pr <- plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=8000)"
```

## Variables de entorno

- `BACKEND_PORT`: puerto HTTP. Valor por defecto: `8000`.
- `LOG_STORAGE_DIR`: carpeta de logs crudos. Valor por defecto: `logs`.
- `LOG_OUTPUT_DIR`: carpeta de resultados. Valor por defecto: `output`.
