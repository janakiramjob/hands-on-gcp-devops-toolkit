#!/usr/bin/env bash
# Runs on the machine executing `terraform apply`:
#   1. build + push the demo app image to Artifact Registry (needs docker + gcloud)
#   2. copy files/ to the control plane and run remote-install.sh there
set -Eeuo pipefail
: "${PROJECT_ID:?}" "${ZONE:?}" "${CONTROL_PLANE:?}" "${APP_IMAGE:?}" "${REGISTRY_HOST:?}" "${APP_DIR:?}" "${FILES_DIR:?}"
log() { echo; echo "[$(date '+%T')] $*"; }

if [[ "${BUILD_IMAGE:-true}" == "true" ]]; then
  command -v docker >/dev/null || { echo "docker not found; install it or set build_app_image=false"; exit 1; }
  log "Building and pushing ${APP_IMAGE}"
  gcloud auth configure-docker "${REGISTRY_HOST}" --quiet
  docker build --platform linux/amd64 -t "${APP_IMAGE}" "${APP_DIR}"
  docker push "${APP_IMAGE}"
else
  log "build_app_image=false: assuming ${APP_IMAGE} already exists in the registry"
fi

SSH_FLAGS=(--project="${PROJECT_ID}" --zone="${ZONE}" --tunnel-through-iap --quiet --strict-host-key-checking=no)

log "Copying lab files to ${CONTROL_PLANE}:~/kafka-lab"
BUNDLE="$(mktemp --suffix=.tgz)"
trap 'rm -f "${BUNDLE}"' EXIT
tar -C "${FILES_DIR}" -czf "${BUNDLE}" .
gcloud compute scp "${SSH_FLAGS[@]}" "${BUNDLE}" "${CONTROL_PLANE}:/tmp/kafka-lab.tgz"

log "Installing the stack on ${CONTROL_PLANE} (Kafka, KEDA, monitoring, demo app) - this takes a while"
gcloud compute ssh "${CONTROL_PLANE}" "${SSH_FLAGS[@]}" --command "
  set -e
  mkdir -p \$HOME/kafka-lab && tar -C \$HOME/kafka-lab -xzf /tmp/kafka-lab.tgz
  export APP_IMAGE='${APP_IMAGE}' REGISTRY_HOST='${REGISTRY_HOST}' \
    STRIMZI_VERSION='${STRIMZI_VERSION}' KEDA_VERSION='${KEDA_VERSION}' KPS_VERSION='${KPS_VERSION}' \
    METRICS_SERVER_VERSION='${METRICS_SERVER_VERSION}' KAFKA_VOLUME_SIZE='${KAFKA_VOLUME_SIZE}' \
    PROMETHEUS_VOLUME_SIZE='${PROMETHEUS_VOLUME_SIZE}' GRAFANA_VOLUME_SIZE='${GRAFANA_VOLUME_SIZE}'
  bash \$HOME/kafka-lab/remote-install.sh
" -- -o ServerAliveInterval=30
