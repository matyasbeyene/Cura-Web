"""Stable static server for the built Flutter web app.

Unlike `flutter run`, this does NOT quit when a browser window closes. It also
does SPA fallback (serves index.html for client-side routes like /sign-in) and
disables caching so a fresh `flutter build web` is always picked up on refresh.

Usage:
    python tool/serve.py [port] [directory]
    (defaults: port 8000, directory build/web)
"""
import http.server
import os
import socketserver
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
DIRECTORY = sys.argv[2] if len(sys.argv) > 2 else os.path.join("build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        # SPA fallback: for a path with no file extension that doesn't exist on
        # disk, serve index.html so client-side routing (go_router) can handle it.
        clean = self.path.split("?")[0].split("#")[0]
        disk = self.translate_path(clean)
        if not os.path.exists(disk) and "." not in os.path.basename(clean):
            self.path = "/index.html"
        return super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


socketserver.ThreadingTCPServer.allow_reuse_address = True
with socketserver.ThreadingTCPServer(("", PORT), Handler) as httpd:
    print(f"Serving {DIRECTORY} at http://localhost:{PORT}  (SPA fallback, no-cache)")
    httpd.serve_forever()
