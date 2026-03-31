#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

echo "Checking database availability..."

START_TIME=$(date +%s)
WARNING_THRESHOLD=30  # seconds
MAX_TIMEOUT=120       # 2 minutes hard timeout

while true; do
  # We use 'check --database default' because it validates the connection 
  # using your DATABASE_URL regardless of the provider (Render/RDS).
  if python manage.py check --database default > /dev/null 2>&1; then
    break
  fi

  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))

  echo "Database not ready yet (elapsed: ${ELAPSED}s)... retrying in 3s"

  if [ "$ELAPSED" -gt "$WARNING_THRESHOLD" ]; then
    echo "WARNING: This is taking longer than expected."
    echo "Possible causes: DB is initializing, incorrect DATABASE_URL, or Security Group/Firewall blocking."
  fi

  if [ "$ELAPSED" -gt "$MAX_TIMEOUT" ]; then
    echo "ERROR: Database not available after ${MAX_TIMEOUT}s. Exiting."
    exit 1
  fi

  sleep 3
done

echo "Database is available!"

echo "Collecting static files..."
python manage.py collectstatic --noinput

echo "Starting Gunicorn..."
# exec replaces the shell with the CMD from the Dockerfile
exec "$@"
