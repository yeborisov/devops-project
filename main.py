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
from flask import Flask, jsonify, Response
import socket

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
