# KHAYA API

This service receives the real status payload sent by `KHAYA_API_BRIDGE_FIXED.mq5` and exposes it to KHAYA Mobile.

## Run

`python -m venv .venv`

Windows: `.venv\\Scripts\\python.exe -m pip install -r requirements.txt`

Start: `.venv\\Scripts\\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000`

The EA's `InpKHApiUrl` must point to this server's `/api/ea/status` endpoint. The mobile app's URL must point to the same server without `/api/ea/status`.
