FROM rocker/shiny:4.4.2

RUN R -e "install.packages(c('jsonlite', 'httr'), repos = 'https://cloud.r-project.org')"

WORKDIR /srv/shiny-server/r-logs

COPY apps/desktop/shiny/ /srv/shiny-server/r-logs/

ENV BACKEND_URL=http://r-log-backend:8000

EXPOSE 3838
