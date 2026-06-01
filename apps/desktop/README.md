# Desktop App

Aplicacion Linux de escritorio compuesta por:

- `shiny/`: interfaz en R Shiny.
- `electron/`: contenedor Electron que inicia Shiny y abre la ventana nativa.

## Requisitos

- R con paquetes `shiny` y `jsonlite`.
- Binario `curl` disponible en el sistema para enviar logs desde la UI.
- Node.js y npm.
- Backend disponible en `BACKEND_URL`.

## Shiny directo

```bash
cd apps/desktop/shiny
BACKEND_URL=http://127.0.0.1:8000 R -e "shiny::runApp('.', host='127.0.0.1', port=3838)"
```

## Electron

```bash
cd apps/desktop/electron
npm install
BACKEND_URL=http://127.0.0.1:8000 npm run dev
```

## Empaquetado Linux

```bash
cd apps/desktop/electron
npm run dist:linux
```

La salida se generara en `apps/desktop/electron/dist`.
