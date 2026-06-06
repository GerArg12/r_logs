import datetime
import random
import os

LOG_FILE = "/home/carlos/r_logs/logs_demo/web_access.log"
NUM_RECORDS = 1000

ips = [
    "192.168.1.10", "192.168.1.11", "192.168.1.12", "192.168.1.13",
    "10.0.0.5", "10.0.0.6", "172.16.0.20", "8.8.8.8", "1.1.1.1", "45.33.22.11"
]

resources = [
    "/index.html", "/login", "/api/v1/users", "/api/v1/data", "/dashboard",
    "/images/logo.png", "/css/style.css", "/js/app.js", "/contact", "/about",
    "/api/v1/auth/login", "/products", "/cart", "/checkout"
]

methods = ["GET", "POST", "PUT", "DELETE"]
statuses = [200, 201, 404, 500, 403, 301]

# Pesos para simular realismo
resource_weights = [20, 10, 15, 12, 8, 5, 5, 5, 4, 3, 5, 4, 2, 2]
status_weights = [80, 5, 10, 2, 2, 1]

os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

now = datetime.datetime.now()
log_entries = []

for i in range(NUM_RECORDS):
    # Generar timestamps en las últimas 24 horas de forma aleatoria
    delta = datetime.timedelta(minutes=random.randint(0, 1440))
    ts_obj = now - delta
    timestamp = ts_obj.strftime("%d/%b/%Y:%H:%M:%S +0000")
    
    ip = random.choice(ips)
    method = random.choice(methods)
    resource = random.choices(resources, weights=resource_weights)[0]
    status = random.choices(statuses, weights=status_weights)[0]
    size = random.randint(100, 15000)
    
    log_line = f'{ip} - - [{timestamp}] "{method} {resource} HTTP/1.1" {status} {size}\n'
    log_entries.append((ts_obj, log_line))

# Ordenar por tiempo para que el log sea cronológico
log_entries.sort()

with open(LOG_FILE, "w") as f:
    for _, line in log_entries:
        f.write(line)

print(f"Se han generado {NUM_RECORDS} registros en {LOG_FILE}")
