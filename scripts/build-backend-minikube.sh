#!/usr/bin/env bash
set -euo pipefail

eval "$(minikube docker-env)"
docker build -f infra/docker/backend.Dockerfile -t r-log-backend:dev .
