# Plan de Desarrollo

## Objetivo

Desarrollar una aplicacion de escritorio para procesamiento y analisis de logs, construida con R Shiny y empaquetada con Electron, conectada a un backend R/Plumber desplegable sobre Docker y Kubernetes.

La aplicacion debe permitir capturar logs desde dos fuentes principales:

- Archivos directos: carga de archivos `.log` desde la interfaz.
- Escucha en directo: monitorizacion de una carpeta local o de servidor donde se escriban logs continuamente.

El flujo debe permitir previsualizar los logs detectados, procesarlos y mostrar tres categorias de analisis:

- IP con mas peticiones.
- Cantidad de peticiones en el tiempo.
- Recursos mas consultados.

## Arquitectura

```text
Usuario
  |
  v
Electron Desktop App
  |
  v
R Shiny Frontend
  |
  v
Backend R/Plumber
  |
  v
Procesamiento R + Tidyverse
  |
  v
Resultados CSV/JSON
```

## Componentes

### Frontend

Ubicacion: `apps/desktop`

Responsabilidades:

- Interfaz de carga de archivos `.log`.
- Interfaz para configurar carpeta de escucha local.
- Previsualizacion de logs crudos.
- Visualizacion de resultados procesados.
- Empaquetado de escritorio con Electron para Linux.

### Backend

Ubicacion: `apps/backend`

Responsabilidades:

- API REST con Plumber.
- Recepcion de logs cargados desde Shiny.
- Lectura y normalizacion de logs.
- Procesamiento de metricas.
- Exposicion de resultados en JSON y CSV.
- Despliegue en Kubernetes usando la infraestructura existente.

### Infraestructura

Ubicacion: `infra`

Responsabilidades:

- Imagen Docker del backend.
- Manifiestos Kubernetes para desarrollo y produccion.
- Despliegue local con Minikube.
- Scripts de automatizacion.

## Flujo Funcional

1. El usuario abre la aplicacion de escritorio.
2. El frontend permite seleccionar una fuente de logs:
   - Cargar archivo `.log`.
   - Elegir carpeta local para escucha en directo.
3. La aplicacion muestra una previsualizacion de los logs detectados.
4. El usuario ejecuta el procesamiento.
5. El backend transforma los logs a una estructura tabular.
6. Se generan metricas principales.
7. El frontend muestra:
   - Tabla de previsualizacion.
   - Ranking de IPs.
   - Grafico temporal de peticiones.
   - Ranking de recursos consultados.
8. Los resultados quedan disponibles como JSON y CSV.

## Formato Base de Log

El parser inicial debe soportar logs HTTP comunes, por ejemplo:

```text
192.168.1.10 - - [29/May/2026:10:00:00 +0000] "GET /login HTTP/1.1" 200 532
```

Campos minimos esperados:

- `ip`
- `timestamp`
- `metodo`
- `recurso`
- `status`
- `bytes`
- `raw`

## Equipo

### Desarrollador 1: Backend y Procesamiento

Responsabilidades:

- Disenar el parser de logs `.log`.
- Crear endpoints REST para carga, procesamiento y consulta.
- Implementar analisis de IPs, tiempo y recursos.
- Exportar resultados a CSV y JSON.
- Agregar pruebas unitarias del parser y procesamiento.

Tareas principales:

- Crear endpoint `POST /logs/upload`.
- Crear endpoint `POST /logs/process`.
- Crear endpoint `GET /logs/preview`.
- Crear endpoint `GET /analytics/top-ips`.
- Crear endpoint `GET /analytics/requests-over-time`.
- Crear endpoint `GET /analytics/top-resources`.
- Implementar parser para formato Apache/Nginx comun.
- Manejar errores por lineas invalidas o formatos desconocidos.

Entregables:

- API funcional.
- Parser probado.
- Resultados JSON/CSV.
- Documentacion de endpoints.

### Desarrollador 2: Frontend Shiny y UX

Responsabilidades:

- Construir la interfaz Shiny.
- Implementar carga de archivos `.log`.
- Implementar previsualizacion.
- Implementar vistas de analitica.
- Integrar llamadas al backend.

Tareas principales:

- Crear vista de carga de archivo.
- Crear vista de seleccion/configuracion de carpeta.
- Crear tabla de previsualizacion.
- Crear grafico temporal.
- Crear ranking de IPs.
- Crear ranking de recursos.
- Manejar estados de carga, error y exito.
- Ajustar la UI para escritorio dentro de Electron.

Entregables:

- UI Shiny navegable.
- Integracion con backend.
- Graficos y tablas funcionales.
- Flujo completo de carga, previsualizacion y analisis.

### Desarrollador 3: Electron, Docker y Kubernetes

Responsabilidades:

- Mantener empaquetado Electron.
- Automatizar ejecucion local.
- Mantener Dockerfile del backend.
- Mantener manifiestos Kubernetes.
- Documentar comandos de ejecucion.

Tareas principales:

- Ajustar Electron para iniciar Shiny correctamente.
- Incluir dependencias R necesarias en el paquete.
- Crear scripts de build y ejecucion.
- Mejorar Dockerfile del backend.
- Validar despliegue en Minikube.
- Crear overlay de desarrollo y produccion.
- Documentar flujo de instalacion y despliegue.

Entregables:

- AppImage y `.deb` generables.
- Backend desplegable en Minikube.
- Scripts de automatizacion.
- Guia de levantamiento local y Kubernetes.

## Fases

### Fase 1: Base Tecnica

Duracion estimada: 2 a 3 dias.

Objetivos:

- Consolidar dependencias R.
- Definir estructura final de endpoints.
- Validar ejecucion local de backend y frontend.
- Asegurar empaquetado Electron basico.

Criterios de aceptacion:

- Backend levanta en `http://127.0.0.1:8000`.
- Shiny levanta en `http://127.0.0.1:3838`.
- Electron abre la app Shiny.
- Docker build del backend funciona.

### Fase 2: Ingestion de Logs

Duracion estimada: 3 a 4 dias.

Objetivos:

- Soportar subida de archivos `.log`.
- Soportar lectura de carpeta local.
- Crear previsualizacion de logs.
- Normalizar campos principales.

Criterios de aceptacion:

- El usuario puede cargar un archivo `.log`.
- El usuario puede seleccionar/configurar una carpeta de escucha.
- La aplicacion muestra las primeras lineas parseadas.
- Los errores de parsing son visibles sin romper el flujo.

### Fase 3: Analitica

Duracion estimada: 3 a 4 dias.

Objetivos:

- Calcular IPs con mas peticiones.
- Calcular cantidad de peticiones por intervalo de tiempo.
- Calcular recursos mas consultados.
- Exponer resultados por API.

Criterios de aceptacion:

- Hay endpoint para cada analisis.
- La UI consume y muestra cada analisis.
- Los resultados pueden exportarse a CSV y JSON.
- Las metricas se actualizan al procesar nuevos logs.

### Fase 4: Integracion Desktop

Duracion estimada: 2 a 3 dias.

Objetivos:

- Empaquetar la aplicacion con Electron.
- Garantizar que Shiny arranque dentro del paquete.
- Validar conexion con backend local o remoto.
- Documentar instalacion en Linux.

Criterios de aceptacion:

- Se genera AppImage.
- Se genera paquete `.deb`.
- La app abre en Linux con doble clic o desde terminal.
- La app puede enviar logs al backend y mostrar resultados.

### Fase 5: Kubernetes y Produccion

Duracion estimada: 3 a 4 dias.

Objetivos:

- Desplegar backend en Minikube.
- Validar servicio NodePort en desarrollo.
- Preparar overlay de produccion.
- Documentar build, deploy y pruebas.

Criterios de aceptacion:

- `kubectl apply -k infra/k8s/overlays/dev` despliega el backend.
- El backend responde desde Minikube.
- La app Electron puede apuntar al backend desplegado.
- La documentacion incluye comandos reproducibles.

## Endpoints Propuestos

### Salud

```text
GET /health
```

### Carga de Logs

```text
POST /logs/upload
```

Recibe archivo o contenido de log enviado desde Shiny.

### Previsualizacion

```text
GET /logs/preview
```

Devuelve una muestra de logs parseados y errores encontrados.

### Procesamiento

```text
POST /logs/process
```

Ejecuta limpieza, transformacion y generacion de resultados.

### Analitica

```text
GET /analytics/top-ips
GET /analytics/requests-over-time
GET /analytics/top-resources
```

## Modelo de Datos Inicial

```text
logs_normalizados
├── ip
├── timestamp
├── metodo
├── recurso
├── status
├── bytes
├── fuente
├── archivo
└── raw
```

## Riesgos Tecnicos

- Variacion en formatos de logs Apache, Nginx o personalizados.
- Acceso a carpetas locales desde Electron/Shiny.
- Diferencia entre ejecucion local y ejecucion empaquetada.
- Persistencia de archivos en Kubernetes.
- Dependencias R nativas al empaquetar con Electron.

## Decisiones Iniciales

- El backend sera responsable del parsing y procesamiento.
- El frontend sera responsable de seleccionar fuentes, previsualizar y mostrar resultados.
- La escucha en directo se implementara primero como polling sobre una carpeta configurada.
- El almacenamiento inicial sera en archivos locales dentro del contenedor o entorno de desarrollo.
- En produccion se evaluara reemplazar `emptyDir` por `PersistentVolumeClaim`.

## Prioridades

1. Parser y previsualizacion de `.log`.
2. Analitica basica.
3. Integracion Shiny con backend.
4. Empaquetado Electron estable.
5. Despliegue Kubernetes.

## Definition of Done

Una funcionalidad se considera terminada cuando:

- Tiene flujo funcional probado.
- Maneja errores esperados.
- Esta integrada con la UI o API correspondiente.
- Tiene documentacion minima.
- No rompe el empaquetado Electron.
- No rompe el despliegue Kubernetes de desarrollo.

