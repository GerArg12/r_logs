#!/usr/bin/env bash
set -euo pipefail

Rscript -e 'setwd("apps/backend"); source(".Rprofile"); source("R/log_store.R"); source("R/process_logs.R"); store_log(list(ip="127.0.0.1", evento="test", usuario="codex", timestamp="2026-05-29T10:00:00")); result <- process_logs(); stopifnot(result$records_processed >= 1); stopifnot(file.exists(result$outputs$csv)); stopifnot(file.exists(result$outputs$json)); print(result)'
