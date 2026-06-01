# Plan De Desarrollo Para 4 Desarrolladores

## Resumen

El proyecto se dividira entre 3 desarrolladores full-stack para frontend Shiny y backend R/Plumber, mas un cuarto desarrollador dedicado a infraestructura, Kubernetes y empaquetado Electron.

La version inicial procesara logs desde dos fuentes:

- Archivos `.log` cargados desde la aplicacion.
- Escucha local de una carpeta seleccionada desde la app desktop.

El parser inicial soportara access logs comunes Apache/Nginx. Las metricas principales seran:

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
Procesamiento R
  |
  v
Resultados CSV/JSON
```

## Flujo Funcional

1. El usuario abre la aplicacion de escritorio.
2. El usuario selecciona una fuente de logs:
   - Archivo `.log`.
   - Carpeta local para escucha.
3. La app muestra una previsualizacion de los logs detectados.
4. El usuario ejecuta el procesamiento.
5. El backend normaliza los logs.
6. El backend calcula metricas.
7. Shiny muestra:
   - Previsualizacion tabular.
   - Ranking de IPs.
   - Grafico temporal de peticiones.
   - Ranking de recursos.
8. El backend exporta resultados en JSON y CSV.

## Formato Base De Log

El parser inicial debe soportar logs HTTP comunes de Apache/Nginx:

```text
192.168.1.10 - - [29/May/2026:10:00:00 +0000] "GET /login HTTP/1.1" 200 532
```

Modelo normalizado minimo:

```text
ip
timestamp
metodo
recurso
status
bytes
fuente
archivo
raw
```

## Reparto De Trabajo

### Dev 1: Ingesta Y Previsualizacion

Responsabilidades backend:

- Implementar parser Apache/Nginx comun.
- Normalizar campos: `ip`, `timestamp`, `metodo`, `recurso`, `status`, `bytes`, `raw`, `fuente`.
- Crear `POST /logs/upload` para recibir contenido de archivos `.log`.
- Crear `GET /logs/preview` para devolver muestra parseada y errores.
- Manejar lineas invalidas sin romper el procesamiento.

Responsabilidades frontend:

- Crear vista de carga de archivo `.log`.
- Mostrar previsualizacion tabular.
- Mostrar resumen de lineas validas, invalidas y total procesado.
- Mostrar errores de parsing de forma clara.

Entregable:

- Flujo completo de carga de archivo `.log` y previsualizacion.

### Dev 2: Escucha Local Y Sincronizacion

Responsabilidades backend:

- Crear `POST /logs/batch` para recibir lotes detectados desde carpeta local.
- Evitar duplicados por archivo, linea o hash simple.
- Persistir logs recibidos para procesamiento posterior.
- Devolver conteo de registros aceptados, duplicados y rechazados.

Responsabilidades frontend:

- Crear vista para configurar carpeta local.
- Implementar polling de archivos `.log` en esa carpeta.
- Detectar nuevos archivos o nuevas lineas.
- Enviar lotes al backend.
- Mostrar estado de escucha: activa, detenida, error, ultima lectura.

Entregable:

- Flujo completo de escucha local desde app desktop hacia backend.

### Dev 3: Analitica Y Visualizacion

Responsabilidades backend:

- Crear `POST /logs/process`.
- Crear `GET /analytics/top-ips`.
- Crear `GET /analytics/requests-over-time`.
- Crear `GET /analytics/top-resources`.
- Generar salidas CSV/JSON en `apps/backend/output`.
- Mantener compatibilidad temporal con `/health`, `/log` y `/logs`.

Responsabilidades frontend:

- Crear vista de resultados.
- Mostrar ranking de IPs con mas peticiones.
- Mostrar grafico temporal de cantidad de peticiones.
- Mostrar ranking de recursos mas consultados.
- Agregar boton de procesamiento y refresco de metricas.
- Manejar estados sin datos, cargando, procesado y error.

Entregable:

- Flujo completo de procesamiento y visualizacion de las tres metricas.

### Dev 4: Infraestructura, Electron Y Empaquetado

Responsabilidades:

- Mantener AppImage y `.deb`.
- Asegurar que Electron inicie Shiny con dependencias R incluidas.
- Configurar `BACKEND_URL`, `R_LIBS_USER` y variables necesarias.
- Mantener Dockerfile del backend.
- Validar despliegue con Minikube.
- Mantener overlays Kubernetes `dev` y `prod`.
- Crear scripts de build, run, test y deploy.
- Documentar comandos de ejecucion local, Electron y Kubernetes.

Entregable:

- App desktop empaquetada y backend desplegable en Kubernetes.

## Endpoints Propuestos

```text
GET  /health
POST /logs/upload
POST /logs/batch
GET  /logs/preview
POST /logs/process
GET  /analytics/top-ips
GET  /analytics/requests-over-time
GET  /analytics/top-resources
```

Endpoints actuales a mantener temporalmente:

```text
POST /log
GET  /logs
```

## Fases

### Fase 1: Contratos Base

Objetivos:

- Definir parser, esquema normalizado y endpoints.
- Asegurar que backend y frontend puedan intercambiar datos.
- Mantener flujo actual funcionando mientras se agregan nuevos endpoints.

Criterios de aceptacion:

- Backend responde `/health`.
- Existe parser base para Apache/Nginx.
- Existe respuesta estructurada para preview y errores.

### Fase 2: Ingesta

Objetivos:

- Implementar subida de `.log`.
- Implementar escucha local por polling desde la app desktop.
- Unificar ambas fuentes en el mismo modelo normalizado.

Criterios de aceptacion:

- El usuario puede cargar un archivo `.log`.
- El usuario puede seleccionar una carpeta local.
- Nuevos logs detectados se envian al backend.
- Las lineas invalidas no detienen el flujo.

### Fase 3: Analitica

Objetivos:

- Calcular IPs con mas peticiones.
- Calcular peticiones por intervalo de tiempo.
- Calcular recursos mas consultados.
- Exponer resultados por API.

Criterios de aceptacion:

- Hay endpoint para cada analisis.
- La UI consume y muestra cada analisis.
- CSV/JSON se regeneran despues de procesar.

### Fase 4: Desktop

Objetivos:

- Empaquetar Electron con la UI corregida y dependencias R.
- Validar AppImage y `.deb`.
- Garantizar que Shiny arranque dentro del paquete.

Criterios de aceptacion:

- AppImage abre sin configurar `R_LIBS_USER` manualmente.
- `.deb` instala la aplicacion.
- La app puede enviar datos al backend y mostrar resultados.

### Fase 5: Kubernetes

Objetivos:

- Validar backend en Minikube.
- Validar servicio NodePort en desarrollo.
- Preparar overlay de produccion.

Criterios de aceptacion:

- `kubectl apply -k infra/k8s/overlays/dev` despliega el backend.
- El backend responde desde Minikube.
- La app puede apuntar al backend desplegado mediante `BACKEND_URL`.

## Pruebas Y Aceptacion

- Archivo `.log` valido se carga, parsea y previsualiza.
- Lineas invalidas aparecen como errores sin detener el flujo.
- Carpeta local detecta nuevos logs por polling.
- El backend evita duplicados basicos en lotes.
- Las tres metricas se calculan correctamente.
- Shiny muestra previsualizacion, estados y graficos.
- Electron abre la app sin configuracion manual de librerias R.
- Backend funciona localmente y en Minikube.

## Riesgos Tecnicos

- Variacion de formatos Apache/Nginx entre servidores.
- Permisos de acceso a carpetas locales desde la app empaquetada.
- Diferencias entre ejecucion Shiny local y Shiny dentro de Electron.
- Peso del paquete si se incluyen dependencias R en el AppImage.
- Persistencia limitada en Kubernetes si se mantiene `emptyDir`.

## Supuestos

- Los tres primeros desarrolladores pueden trabajar tanto frontend como backend.
- Infraestructura y empaquetado quedan para el cuarto desarrollador.
- La escucha en directo v1 sera local desde la app desktop.
- El parser v1 se limita a Apache/Nginx comun.
- La escucha usara polling; `inotify` queda como mejora posterior.
- La persistencia Kubernetes inicial puede seguir con almacenamiento efimero; PVC queda como mejora posterior.

## Definition Of Done

Una funcionalidad se considera terminada cuando:

- Tiene flujo funcional probado.
- Maneja errores esperados.
- Esta integrada con la UI o API correspondiente.
- Tiene documentacion minima.
- No rompe el empaquetado Electron.
- No rompe el despliegue Kubernetes de desarrollo.
