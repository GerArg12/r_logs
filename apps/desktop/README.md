# Desktop App

Aplicacion Linux de escritorio compuesta por:

- `shiny/`: interfaz en R Shiny.
- `electron/`: contenedor Electron que inicia Shiny y abre la ventana nativa.

## Requisitos

- R con paquetes `shiny`, `jsonlite` y `ggplot2`.
- Binario `curl` disponible en el sistema para enviar logs desde la UI.
- Node.js y npm.
- Backend disponible en `BACKEND_URL`.

## Shiny directo

```bash
cd apps/desktop/shiny
BACKEND_URL=http://127.0.0.1:8000 R -e "shiny::runApp('.', host='127.0.0.1', port=3838)"
```

Con backend en Minikube:

```bash
MINIKUBE_IP=$(minikube ip)
cd apps/desktop/shiny
BACKEND_URL="http://${MINIKUBE_IP}:30080" R -e "shiny::runApp('.', host='127.0.0.1', port=3838)"
```

## Electron

```bash
cd apps/desktop/electron
npm install
BACKEND_URL=http://127.0.0.1:8000 npm run dev
```

Con backend en Minikube:

```bash
MINIKUBE_IP=$(minikube ip)
BACKEND_URL="http://${MINIKUBE_IP}:30080" npm run dev
```

La pestaña `Escucha Local (Monitoring)` usa el dialogo nativo de Electron para seleccionar un archivo `.log` real del sistema de archivos. En ejecucion Shiny directa desde navegador, pega manualmente la ruta completa del archivo.

El monitoreo inicia desde el final actual del archivo, revisa cambios cada 5 segundos y envia solo las nuevas lineas a `POST /logs/batch`. El panel muestra estado, ultima lectura y conteos de registros aceptados, duplicados y rechazados.

## Empaquetado Linux

```bash
cd apps/desktop/electron
npm run dist:linux
```

La salida se generara en `apps/desktop/electron/dist`.
