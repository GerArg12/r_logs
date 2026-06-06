import http.server
import socketserver
import datetime
import os

PORT = 8080
LOG_FILE = "/home/carlos/r_logs/logs_demo/web_access.log"

class LogGeneratorHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        # Generar log en formato Apache Combined
        # 127.0.0.1 - - [29/May/2026:10:00:00 +0000] "GET /login HTTP/1.1" 200 532
        ip = self.client_address[0]
        timestamp = datetime.datetime.now().strftime("%d/%b/%Y:%H:%M:%S +0000")
        method = self.command
        path = self.path
        protocol = self.request_version
        status = "200" # Simplificado
        size = "512"   # Simplificado
        
        log_line = f'{ip} - - [{timestamp}] "{method} {path} {protocol}" {status} {size}\n'
        
        with open(LOG_FILE, "a") as f:
            f.write(log_line)
            
        print(f"Log generado: {log_line.strip()}")

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        html = f"""
        <html>
            <head><title>Generador de Logs</title></head>
            <body style='font-family: sans-serif; text-align: center; padding-top: 50px;'>
                <h1>Generador de Logs en Vivo</h1>
                <p>Cada vez que recargues esta página, se generará una línea de log en:</p>
                <code>{LOG_FILE}</code>
                <br><br>
                <button onclick='location.reload()'>Generar Nueva Petición</button>
                <hr>
                <p><a href='/api/data'>Visitar /api/data</a> | <a href='/dashboard'>Visitar /dashboard</a></p>
            </body>
        </html>
        """
        self.wfile.write(html.encode())

os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

with socketserver.TCPServer(("", PORT), LogGeneratorHandler) as httpd:
    print(f"Servidor de logs corriendo en http://localhost:{PORT}")
    httpd.serve_forever()
