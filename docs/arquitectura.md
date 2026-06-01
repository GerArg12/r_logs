# Arquitectura Inicial

## Componentes

### Backend

Servicio R con Plumber que expone una API REST.

Responsabilidades:

- Recibir logs por HTTP.
- Guardar eventos crudos como JSON.
- Procesar datos con Tidyverse.
- Exportar resultados a CSV y JSON.

### Desktop

Cliente Linux con Shiny y Electron.

Responsabilidades:

- Mostrar una interfaz local de escritorio.
- Enviar logs de prueba al backend.
- Consultar logs procesados.

### Infraestructura

La carpeta `infra` concentra Docker y Kubernetes.

- `infra/docker/backend.Dockerfile`: imagen del backend.
- `infra/docker/shiny.Dockerfile`: imagen opcional para correr la UI Shiny en contenedor.
- `infra/k8s/base`: manifiestos reutilizables.
- `infra/k8s/overlays/dev`: Minikube y desarrollo local.
- `infra/k8s/overlays/prod`: punto de partida para produccion.

## Flujo

```text
Aplicacion o cliente
        |
        v
POST /log en Plumber
        |
        v
JSON crudo en LOG_STORAGE_DIR
        |
        v
Procesamiento con Tidyverse
        |
        v
CSV/JSON procesados en LOG_OUTPUT_DIR
        |
        v
Dashboard Shiny/Electron o consumidores externos
```

## Consideraciones para evolucionar

- Sustituir `emptyDir` por `PersistentVolumeClaim` si los resultados deben sobrevivir reinicios.
- Agregar autenticacion si el API queda expuesto fuera del laboratorio.
- Incorporar Kafka o una cola si el volumen de logs crece.
- Publicar imagenes en un registry para el overlay de produccion.
- Separar procesamiento batch/worker si el reprocesamiento por request deja de ser suficiente.
