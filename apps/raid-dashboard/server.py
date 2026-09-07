import os, urllib.request
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        host=os.getenv('DASHBOARD_HOST')
        if host and self.headers.get('X-Forwarded-Proto','').split(',')[0].strip()=='http':
            self.send_response(308);self.send_header('Location','https://'+host+self.path);self.end_headers();return
        if self.path=='/metrics-json':
            try:
                with urllib.request.urlopen('http://raid-verifier:8080/metrics-json',timeout=10) as r:data=r.read()
                self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(data)
            except Exception:
                self.send_error(503,'Verifier unavailable')
        else:super().do_GET()
ThreadingHTTPServer(('0.0.0.0',8080),Handler).serve_forever()
