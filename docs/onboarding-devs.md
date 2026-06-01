# Onboarding De Desarrolladores

Guia para clonar, configurar y ejecutar el proyecto localmente.

## 1. Requisitos

Instalar en Linux:

```bash
sudo apt-get update
sudo apt-get install -y git curl build-essential r-base libsodium-dev libcurl4-openssl-dev
```

Instalar Node.js y npm si no estan disponibles:

```bash
node --version
npm --version
```

Instalar Docker, Minikube y kubectl si se va a trabajar con Kubernetes:

```bash
docker --version
minikube version
kubectl version --client
```

## 2. Acceso Con Deploy Keys

Cada desarrollador debe generar una llave SSH propia y enviar solo la llave publica.

En la maquina del desarrollador:

```bash
ssh-keygen -t ed25519 -C "nombre-dev-r-logs" -f ~/.ssh/r_logs_deploy_key
cat ~/.ssh/r_logs_deploy_key.pub
```

El responsable del repo debe agregar el contenido de `r_logs_deploy_key.pub` en GitHub:

```text
Repository -> Settings -> Deploy keys -> Add deploy key
```

Notas:

- Para solo clonar, la deploy key puede ser read-only.
- Para que el dev pueda hacer `git push`, marcar `Allow write access`.
- GitHub no permite reutilizar la misma deploy key en multiples repos. Cada repo necesita su propia key.
- Nunca compartir la llave privada `~/.ssh/r_logs_deploy_key`.

## 3. Configurar SSH Para Este Repo

Crear o editar `~/.ssh/config`:

```sshconfig
Host github-r-logs
  HostName github.com
  User git
  IdentityFile ~/.ssh/r_logs_deploy_key
  IdentitiesOnly yes
```

Probar acceso:

```bash
ssh -T git@github-r-logs
```

GitHub puede responder que no da acceso shell; eso es normal si autentica correctamente.

## 4. Clonar El Proyecto

Con el alias SSH recomendado:

```bash
git clone git@github-r-logs:GerArg12/r_logs.git
cd r_logs
```

Alternativa sin alias, si el dev usa su llave SSH principal de GitHub:

```bash
git clone git@github.com:GerArg12/r_logs.git
cd r_logs
```

Confirmar remoto:

```bash
git remote -v
```

Si se clono con la URL normal y se quiere usar la deploy key:

```bash
git remote set-url origin git@github-r-logs:GerArg12/r_logs.git
```

Configurar identidad de commits:

```bash
git config user.name "Nombre Del Dev"
git config user.email "correo-del-dev@example.com"
```

## 5. Configurar Dependencias R

Desde la raiz del repo:

```bash
mkdir -p r-lib
Rscript -e ".libPaths(normalizePath('r-lib')); install.packages(c('jsonlite','dplyr','purrr','readr','tibble','shiny','curl','sodium','webutils','plumber'), repos='https://cloud.r-project.org')"
```

Verificar paquetes:

```bash
Rscript -e ".libPaths(normalizePath('r-lib')); library(plumber); library(shiny); library(jsonlite); cat('R deps ok\n')"
```

## 6. Configurar Dependencias Electron

```bash
cd apps/desktop/electron
npm install
cd ../../..
```

## 7. Ejecutar Backend Local

Terminal 1:

```bash
cd r_logs
./scripts/run-backend-local.sh
```

Validar:

```bash
curl http://127.0.0.1:8000/health
```

Swagger:

```text
http://127.0.0.1:8000/__docs__/
```

Enviar log de prueba:

```bash
curl -X POST http://127.0.0.1:8000/log \
  -H "Content-Type: application/json" \
  -d '{
    "ip": "10.0.0.5",
    "evento": "login_failed",
    "usuario": "admin",
    "timestamp": "2026-05-29T10:00:00"
  }'
```

## 8. Ejecutar Shiny Local

Terminal 2:

```bash
cd r_logs
BACKEND_URL=http://127.0.0.1:8000 R -e "setwd('apps/desktop/shiny'); source('.Rprofile'); shiny::runApp('.', host='127.0.0.1', port=3838)"
```

Abrir:

```text
http://127.0.0.1:3838
```

## 9. Ejecutar Electron En Desarrollo

No levantar Shiny manualmente en este modo; Electron lo inicia internamente.

Terminal 2:

```bash
cd r_logs/apps/desktop/electron
BACKEND_URL=http://127.0.0.1:8000 npm run dev
```

## 10. Empaquetar Electron Para Linux

```bash
cd r_logs/apps/desktop/electron
npm run dist:linux
```

Artefactos esperados:

```text
apps/desktop/electron/dist/R Logs Desktop-0.1.0.AppImage
apps/desktop/electron/dist/r-logs-desktop_0.1.0_amd64.deb
```

Ejecutar AppImage:

```bash
cd r_logs
BACKEND_URL=http://127.0.0.1:8000 "apps/desktop/electron/dist/R Logs Desktop-0.1.0.AppImage"
```

Instalar `.deb`:

```bash
sudo apt install "./apps/desktop/electron/dist/r-logs-desktop_0.1.0_amd64.deb"
```

## 11. Ejecutar Backend En Minikube

```bash
cd r_logs
minikube start --driver=docker
./scripts/build-backend-minikube.sh
./scripts/deploy-dev.sh
```

Probar:

```bash
./scripts/send-sample-log.sh
```

Ver recursos:

```bash
kubectl get pods -n r-logs-dev
kubectl get svc -n r-logs-dev
```

Usar backend de Minikube desde la app:

```bash
MINIKUBE_IP=$(minikube ip)
cd apps/desktop/electron
BACKEND_URL="http://${MINIKUBE_IP}:30080" npm run dev
```

## 12. Flujo De Trabajo Git

Crear rama por tarea:

```bash
git checkout main
git pull origin main
git checkout -b feature/nombre-corto
```

Guardar cambios:

```bash
git status
git add .
git commit -m "Describe el cambio"
git push -u origin feature/nombre-corto
```

Actualizar rama con cambios recientes:

```bash
git checkout main
git pull origin main
git checkout feature/nombre-corto
git merge main
```

## 13. Pruebas Rapidas

Procesamiento backend:

```bash
./scripts/test-backend-processing.sh
```

Kustomize dev:

```bash
kubectl kustomize infra/k8s/overlays/dev
```

Kustomize prod:

```bash
kubectl kustomize infra/k8s/overlays/prod
```
