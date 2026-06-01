#!/usr/bin/env bash
set -euo pipefail

MINIKUBE_IP="${MINIKUBE_IP:-$(minikube ip)}"

curl -X POST "http://${MINIKUBE_IP}:30080/log" \
  -H "Content-Type: application/json" \
  -d '{
    "ip": "10.0.0.5",
    "evento": "login_failed",
    "usuario": "admin",
    "timestamp": "2026-05-29T10:00:00"
  }'
