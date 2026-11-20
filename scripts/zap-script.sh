#!/usr/bin/env bash
set -euo pipefail
site="$(pwd)/dist/bitcoin"
test -s "$site/index.html"
web_image=nginx:stable-alpine
zap_image=ghcr.io/zaproxy/zaproxy:stable
docker pull "$web_image"
docker pull "$zap_image"
network="workshop-zap-$$"
web="$network-site"
scanner="$network-reader"
docker network create --internal "$network" >/dev/null
cleanup() {
  docker rm -f "$scanner" "$web" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
}
trap cleanup EXIT
docker run -d --name "$web" --network "$network" --network-alias app.workshop.test \
  --mount "type=bind,src=$site,dst=/usr/share/nginx/html/bitcoin-order-app,readonly" "$web_image" >/dev/null
for ((attempt=0; attempt<15; attempt++)); do
  if docker exec "$web" wget -q -O /dev/null http://127.0.0.1/bitcoin-order-app/; then break; fi
  sleep 1
done
docker exec "$web" wget -q -O /dev/null http://127.0.0.1/bitcoin-order-app/
docker create --name "$scanner" --network "$network" "$zap_image" \
  zap.sh -cmd -silent -autorun /tmp/workshop-plan.yaml >/dev/null
docker cp scripts/zap-passive.yaml "$scanner:/tmp/workshop-plan.yaml"
docker start --attach "$scanner"
test "$(docker inspect -f '{{.State.ExitCode}}' "$scanner")" = 0
docker cp "$scanner:/tmp/zap_baseline_report.html" ./zap_baseline_report.html
test -s ./zap_baseline_report.html
