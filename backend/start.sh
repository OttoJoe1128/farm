#!/bin/bash
# Backend'i 8000 portunda baslatir. Port doluysa once o islemi sonlandirir.
set -e
cd "$(dirname "$0")"
echo "Port 8000 temizleniyor..."
PID=$(lsof -t -i:8000 2>/dev/null); [ -n "$PID" ] && kill $PID 2>/dev/null || true
sleep 1
echo "Backend baslatiliyor: http://0.0.0.0:8000"
exec python3 -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
