#!/usr/bin/env bash
set -euo pipefail

cd apps/backend

Rscript -e 'source(".Rprofile"); if (!requireNamespace("plumber", quietly = TRUE)) stop("Falta el paquete R plumber. Instala primero las librerias de sistema libsodium-dev y libcurl4-openssl-dev, luego ejecuta install.packages(c(\"curl\", \"sodium\", \"webutils\", \"plumber\"), lib = \"../../r-lib\", repos = \"https://cloud.r-project.org\")", call. = FALSE)'

R -e "source('.Rprofile'); pr <- plumber::plumb('plumber.R'); pr\$run(host='0.0.0.0', port=as.integer(Sys.getenv('BACKEND_PORT', '8000')))"
