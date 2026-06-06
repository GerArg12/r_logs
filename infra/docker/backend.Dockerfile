FROM rocker/tidyverse:4.4.2

# Install system dependencies for R packages
RUN apt-get update && apt-get install -y \
    libsodium-dev \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('plumber', 'jsonlite', 'dplyr', 'lubridate', 'stringr', 'purrr', 'readr', 'tibble'), repos = 'https://cloud.r-project.org')"

WORKDIR /app

COPY apps/backend/ /app/

ENV LOG_STORAGE_DIR=logs
ENV LOG_OUTPUT_DIR=output
ENV BACKEND_PORT=8000

EXPOSE 8000

CMD ["R", "-e", "pr <- plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=as.integer(Sys.getenv('BACKEND_PORT', '8000')))"]
