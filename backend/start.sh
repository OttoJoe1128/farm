#!/bin/bash
# Backend'i 8000 portunda baslatir. Port doluysa once o islemi sonlandirir.
cd "$(dirname "$0")"
ROOT="$(pwd)"
PYTHON="${ROOT}/.venv/bin/python3"
echo "Port 8000 temizleniyor..."
PID=$(lsof -t -i:8000 2>/dev/null) || true
[ -n "$PID" ] && kill $PID 2>/dev/null || true
sleep 1
if [ ! -x "$PYTHON" ]; then
  echo "Hata: .venv yok: $PYTHON"
  echo "Once: python3 -m venv .venv && .venv/bin/pip install -r requirements-backend.txt"
  exit 1
fi
if ! "$PYTHON" -c "import uvicorn" 2>/dev/null; then
  echo "Hata: uvicorn yok. Calistir: .venv/bin/pip install -r requirements-backend.txt"
  exit 1
fi
echo "Backend baslatiliyor: http://0.0.0.0:8000"
exec "$PYTHON" -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
