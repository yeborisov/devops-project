"""
Simple REST Service - DevOps Project

A minimalist Flask application that demonstrates containerized deployment
with Docker, Terraform, and Ansible.

Endpoints:
    GET /          - Returns "Hello World" as plain text
    GET /hostname  - Returns container/server hostname as JSON

Environment Variables:
    PORT - Server port (default: 5000)

Usage:
    python main.py --port 8080
    python main.py  # Uses PORT env var or defaults to 5000
"""
from flask import Flask, jsonify, Response, request
import socket
import platform
import sys
import base64
import os
from typing import Optional

# Initialize Flask application
app = Flask(__name__)


def _get_allowed_host() -> str:
    """Return the allowed hostname for Host header restriction (empty disables restriction)."""
    return os.environ.get("ALLOWED_HOST", "").strip()


def _get_basic_auth_credentials():
    """Return (user, pass) for basic auth. Empty user or pass disables auth."""
    user = os.environ.get("BASIC_AUTH_USER", "").strip()
    password = os.environ.get("BASIC_AUTH_PASS", "").strip()
    return user, password


def _is_auth_enabled() -> bool:
    """Return True if auth is enabled via AUTH_ENABLED env var."""
    return os.environ.get("AUTH_ENABLED", "").strip().lower() in {"1", "true", "yes", "on"}


def _is_https_request() -> bool:
    """Detect HTTPS even when behind a proxy (X-Forwarded-Proto)."""
    if request.is_secure:
        return True
    forwarded_proto = request.headers.get("X-Forwarded-Proto", "").lower()
    return forwarded_proto == "https"


@app.before_request
def enforce_allowed_host():
    """Restrict access to requests with the configured Host header (if set)."""
    allowed = _get_allowed_host()
    if not allowed:
        return None

    host_header = request.headers.get("Host", "")
    host_only = host_header.split(":")[0].strip()
    if host_only != allowed:
        return Response("Forbidden: invalid host", status=403, mimetype="text/plain")
    return None


def _require_basic_auth() -> Optional[Response]:
    """Require HTTP Basic Auth for protected pages. Returns a Response if unauthorized."""
    if not _is_auth_enabled():
        return None

    # Only enforce auth over HTTPS. If not HTTPS, block to avoid leaking creds.
    if not _is_https_request():
        return Response("HTTPS required", status=403, mimetype="text/plain")

    user, password = _get_basic_auth_credentials()
    if not user or not password:
        return None

    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Basic "):
        return Response(
            "Unauthorized",
            status=401,
            headers={"WWW-Authenticate": 'Basic realm="Restricted"'},
        )

    try:
        token = auth_header.split(" ", 1)[1]
        decoded = base64.b64decode(token).decode("utf-8")
        supplied_user, supplied_pass = decoded.split(":", 1)
    except Exception:
        return Response(
            "Unauthorized",
            status=401,
            headers={"WWW-Authenticate": 'Basic realm="Restricted"'},
        )

    if supplied_user != user or supplied_pass != password:
        return Response(
            "Unauthorized",
            status=401,
            headers={"WWW-Authenticate": 'Basic realm="Restricted"'},
        )

    return None

@app.route("/", methods=["GET"])
def hello_root():
    # Return plain text "Hello World"
    return Response("Hello World", mimetype="text/plain")

@app.route("/hostname", methods=["GET"])
def get_hostname():
    # Return hostname as JSON for easy consumption
    hostname = socket.gethostname()
    return jsonify({"hostname": hostname})


# Health check endpoint
@app.route("/health", methods=["GET"])
def health_check():
        return jsonify({"status": "ok"})


# Info endpoint with some environment details
@app.route("/info", methods=["GET"])
def info():
        return jsonify({
                "hostname": socket.gethostname(),
                "platform": platform.platform(),
                "python_version": sys.version.split('\n')[0]
        })


# Simple index page (HTML) and favicon
INDEX_HTML = """
<!doctype html>
<html lang="en">
    <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Simple REST Service</title>
        <link rel="icon" href="/favicon.ico" />
        <style>
            body { font-family: system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial; padding: 2rem; background:#f7f9fc; color:#111 }
            .card { background:white; border-radius:8px; padding:1.5rem; box-shadow: 0 2px 8px rgba(20,30,50,0.06); max-width:780px }
            h1 { margin-top:0 }
            pre { background:#f1f5f9; padding:0.75rem; border-radius:6px }
            a.button { display:inline-block; margin-top:1rem; padding:0.5rem 0.75rem; background:#0366d6; color:white; border-radius:6px; text-decoration:none }
        </style>
    </head>
    <body>
        <div class="card">
            <h1>Simple REST Service</h1>
            <p>This service exposes a couple of simple endpoints:</p>
            <ul>
                <li><strong>GET /</strong> — plain text greeting</li>
                <li><strong>GET /hostname</strong> — JSON with the machine hostname</li>
                <li><strong>GET /health</strong> — JSON health check</li>
                <li><strong>GET /info</strong> — JSON with runtime info</li>
            </ul>
            <p>Try it out:</p>
            <pre>curl http://&lt;host&gt;:{{port}}/</pre>
            <a class="button" href="/hostname">View hostname</a>
        </div>
    </body>
</html>
"""

# A tiny 16x16 favicon (generated as a small red square) encoded as ICO-like PNG data for simplicity.
# This is a minimal inline image (PNG) served as image/x-icon; browsers accept PNG too.
FAVICON_BASE64 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII="
)


@app.route('/favicon.ico')
def favicon():
    data = base64.b64decode(FAVICON_BASE64)
    return Response(data, mimetype='image/x-icon')


@app.route('/index', methods=['GET'])
@app.route('/index.html', methods=['GET'])
def index() -> Response:
    auth_response = _require_basic_auth()
    if auth_response is not None:
        return auth_response

    # Render the index HTML. We attempt to fill port for display, but it's only cosmetic.
    port = request.environ.get('SERVER_PORT', '80')
    html = INDEX_HTML.replace('{{port}}', str(port))
    return Response(html, mimetype='text/html')

if __name__ == "__main__":
    # Allow the port to be specified via CLI or PORT env var; default to 5000
    import os
    import argparse

    parser = argparse.ArgumentParser(description="Simple REST Service")
    parser.add_argument("--port", "-p", type=int, help="Port to listen on")
    args = parser.parse_args()

    try:
        port = args.port if args.port is not None else int(os.environ.get("PORT", 5000))
    except ValueError:
        # If PORT env var is set but not an int, fall back to 5000
        port = 5000

    app.run(host="0.0.0.0", port=port)
