#!/usr/bin/env bash
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run as root after reviewing source'; exit 1; }
cd "$(dirname "$0")/.."
[[ -d dist && -f dist-server/index.js && -d node_modules ]] || { echo 'Run npm install and npm run build as unprivileged operator first'; exit 1; }
getent group adaptive-api >/dev/null || groupadd --system adaptive-api
id adaptive-web >/dev/null 2>&1 || useradd --system --gid www-data --no-create-home --shell /usr/sbin/nologin adaptive-web
usermod -aG adaptive-api adaptive-web
install -d -m 0755 /opt/adaptive-client
# Only copy reviewed code and locally built dependencies, never execute npm as root.
cp -a dist dist-server node_modules package.json /opt/adaptive-client/
chown -hR root:root /opt/adaptive-client
chmod -R go-w /opt/adaptive-client
if ! runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='adaptive-web'" | grep -qx 1; then
  runuser -u postgres -- createuser --no-superuser --no-createdb --no-createrole adaptive-web
fi
if ! runuser -u postgres -- psql -tAc "SELECT 1 FROM pg_database WHERE datname='adaptive_deploy'" | grep -qx 1; then
  runuser -u postgres -- createdb --owner=adaptive-web adaptive_deploy
fi
runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d adaptive_deploy -c 'REVOKE CONNECT ON DATABASE adaptive_deploy FROM PUBLIC'
runuser -u adaptive-web -- psql -v ON_ERROR_STOP=1 -h /var/run/postgresql -d adaptive_deploy < ops/schema.sql
install -m 0644 ops/adaptive-web.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now adaptive-web.service
