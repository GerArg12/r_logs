# R Logs Monorepo

Monorepo para un laboratorio de procesamiento de logs con R.

La base del proyecto incluye:

- Backend REST en R usando Plumber.
- Procesamiento y limpieza con Tidyverse.
- Exportacion de resultados en CSV y JSON.
- Infraestructura local con Docker, Kubernetes y Minikube.
- Aplicacion de escritorio Linux con R Shiny empaquetada en Electron.

## Estructura

```text
.
├── apps/
│   ├── backend/              # API REST Plumber y procesamiento de logs
│   └── desktop/              # Shiny + Electron para escritorio Linux
├── infra/
│   ├── docker/               # Dockerfiles por servicio
│   └── k8s/                  # Manifiestos Kubernetes base, dev y prod
├── scripts/                  # Comandos auxiliares para desarrollo
└── docs/                     # Guias del laboratorio
```

## Backend local con R

Requisitos:

- R 4.x
- Paquetes: `plumber`, `jsonlite`, `tidyverse`

Ejecutar la API:

```bash
cd apps/backend
R -e "pr <- plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=8000)"
```

Enviar un log:

```bash
curl -X POST http://localhost:8000/log \
  -H "Content-Type: application/json" \
  -d '{
    "ip": "10.0.0.5",
    "evento": "login_failed",
    "usuario": "admin",
    "timestamp": "2026-05-29T10:00:00"
  }'
```

Los resultados se generan en:

- `apps/backend/output/logs_procesados.csv`
- `apps/backend/output/logs_procesados.json`

## Backend con Minikube

Iniciar Minikube:

```bash
minikube start --driver=docker
```

Construir la imagen dentro del Docker daemon de Minikube:

```bash
eval $(minikube docker-env)
docker build -f infra/docker/backend.Dockerfile -t r-log-backend:dev .
```

Desplegar ambiente de desarrollo:

```bash
kubectl apply -k infra/k8s/overlays/dev
```

Probar el servicio:

```bash
MINIKUBE_IP=$(minikube ip)

curl -X POST "http://${MINIKUBE_IP}:30080/log" \
  -H "Content-Type: application/json" \
  -d '{
    "ip": "10.0.0.5",
    "evento": "login_failed",
    "usuario": "admin",
    "timestamp": "2026-05-29T10:00:00"
  }'
```

## Aplicacion de escritorio

La app de escritorio vive en `apps/desktop`.

Modo Shiny directo:

```bash
cd apps/desktop/shiny
R -e "shiny::runApp('.', host='127.0.0.1', port=3838)"
```

Modo Electron:

```bash
cd apps/desktop/electron
npm install
npm run dev
```

Electron inicia el proceso Shiny local y abre la ventana de escritorio contra `http://127.0.0.1:3838`.

## Ambientes Kubernetes

- `infra/k8s/overlays/dev`: pensado para Minikube, usa `imagePullPolicy: Never` y `NodePort`.
- `infra/k8s/overlays/prod`: base para produccion, usa mas replicas y debe apuntar a una imagen publicada en un registry.

Antes de usar produccion, cambiar la imagen `registry.example.com/r-log-backend:latest` por la imagen real.
