# Simple REST Service

This small service exposes two endpoints:

- `GET /` — returns plain text "Hello World"
- `GET /hostname` — returns JSON with the machine hostname: `{ "hostname": "..." }`

Quick start (macOS / zsh):

```bash
# Create and activate a virtualenv (optional but recommended)
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
python -m pip install -r requirements.txt

# Run the app
python main.py -p <PORT>

# Root
curl http://127.0.0.1:<PORT>/

# Hostname
curl http://127.0.0.1:<PORT>/hostname

# Run tests
pytest -q
```

