# Backend R/Plumber

API REST para recibir logs, almacenarlos como JSON temporal y generar salidas procesadas con Tidyverse.

## Endpoints

- `GET /health`: verifica que el servicio responde.
- `POST /log`: recibe un log en JSON, lo almacena y reprocesa el conjunto.
- `GET /logs`: devuelve el JSON procesado.

## Desarrollo local

```bash
R -e "install.packages(c('plumber', 'jsonlite', 'tidyverse'))"
R -e "pr <- plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=8000)"
```

## Variables de entorno

- `BACKEND_PORT`: puerto HTTP. Valor por defecto: `8000`.
- `LOG_STORAGE_DIR`: carpeta de logs crudos. Valor por defecto: `logs`.
- `LOG_OUTPUT_DIR`: carpeta de resultados. Valor por defecto: `output`.
