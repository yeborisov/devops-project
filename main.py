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

# Initialize Flask application
app = Flask(__name__)

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
        "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAQAAAC1+jfqAAAAH0lEQVQoz2NgoBvgP4P8n4GBgYGBgYGBg" 
        "AAAABJRU5ErkJggg=="
)


@app.route('/favicon.ico')
def favicon():
        data = base64.b64decode(FAVICON_BASE64)
        return Response(data, mimetype='image/x-icon')


@app.route('/index', methods=['GET'])
@app.route('/index.html', methods=['GET'])
def index():
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
