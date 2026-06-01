#!/usr/bin/env bash
set -euo pipefail

kubectl apply -k infra/k8s/overlays/dev
kubectl rollout status deployment/r-log-backend -n r-logs-dev
