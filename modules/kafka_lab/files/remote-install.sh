#!/usr/bin/env bash
# Runs ON the control plane (copied + invoked by modules/kafka_lab/install.sh).
# Idempotent: every step is apply / helm upgrade --install.
set -Eeuo pipefail
cd "$(dirname "$0")"

: "${APP_IMAGE:?}" "${REGISTRY_HOST:?}" "${STRIMZI_VERSION:?}" "${KEDA_VERSION:?}" "${KPS_VERSION:?}"
: "${METRICS_SERVER_VERSION:?}" "${KAFKA_VOLUME_SIZE:?}" "${PROMETHEUS_VOLUME_SIZE:?}" "${GRAFANA_VOLUME_SIZE:?}"

log() { echo; echo "[$(date '+%T')] $*"; }
render() {
  sed -e "s|@@APP_IMAGE@@|${APP_IMAGE}|g" \
      -e "s|@@REGISTRY_HOST@@|${REGISTRY_HOST}|g" \
      -e "s|@@KAFKA_VOLUME_SIZE@@|${KAFKA_VOLUME_SIZE}|g" \
      -e "s|@@PROMETHEUS_VOLUME_SIZE@@|${PROMETHEUS_VOLUME_SIZE}|g" \
      -e "s|@@GRAFANA_VOLUME_SIZE@@|${GRAFANA_VOLUME_SIZE}|g" "$1"
}
apply() { render "$1" | kubectl apply -f -; }

# ------------------------------------------------------------ namespaces
for ns in kafka demo keda monitoring; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# ------------------------------------------------------------ metrics-server
log "metrics-server ${METRICS_SERVER_VERSION}"
curl -fsSLo /tmp/metrics-server.yaml \
  "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"
# kubeadm kubelet certs have no IP SANs
grep -q -- '--kubelet-insecure-tls' /tmp/metrics-server.yaml || \
  sed -i 's/^\(\s*\)- --secure-port=10250$/&\n\1- --kubelet-insecure-tls/' /tmp/metrics-server.yaml
kubectl apply -f /tmp/metrics-server.yaml
kubectl -n kube-system set resources deploy/metrics-server \
  --requests=cpu=100m,memory=200Mi --limits=cpu=200m,memory=256Mi
kubectl -n kube-system rollout status deploy/metrics-server --timeout=300s

# ------------------------------------------------------------ helm repos
helm repo add strimzi https://strimzi.io/charts/ --force-update >/dev/null
helm repo add kedacore https://kedacore.github.io/charts --force-update >/dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update >/dev/null
helm repo update >/dev/null

# ------------------------------------------------------------ Strimzi + Kafka
log "Strimzi ${STRIMZI_VERSION}"
helm upgrade --install strimzi strimzi/strimzi-kafka-operator --version "${STRIMZI_VERSION}" \
  --namespace kafka -f values/strimzi.yaml --wait --timeout 5m

log "Kafka cluster 'demo'"
apply manifests/kafka-cluster.yaml
kubectl -n kafka wait kafka/demo --for=condition=Ready --timeout=900s

log "Topics + kafka-client"
apply manifests/topics.yaml
kubectl -n kafka wait kafkatopic/orders kafkatopic/events --for=condition=Ready --timeout=300s
apply manifests/kafka-client.yaml
kubectl -n kafka wait pod/kafka-client --for=condition=Ready --timeout=300s

# ------------------------------------------------------------ image pull secret
log "Artifact Registry pull-secret refresher"
apply manifests/registry-refresh.yaml
kubectl -n demo delete job registry-refresh-init --ignore-not-found
kubectl -n demo create job registry-refresh-init --from=cronjob/registry-refresh
kubectl -n demo wait job/registry-refresh-init --for=condition=Complete --timeout=180s

# ------------------------------------------------------------ monitoring (before KEDA: needs the CRDs)
log "kube-prometheus-stack ${KPS_VERSION}"
render values/kube-prometheus-stack.yaml > /tmp/kps-values.yaml
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --version "${KPS_VERSION}" --namespace monitoring -f /tmp/kps-values.yaml --wait --timeout 10m

# ------------------------------------------------------------ KEDA
log "KEDA ${KEDA_VERSION}"
helm upgrade --install keda kedacore/keda --version "${KEDA_VERSION}" \
  --namespace keda -f values/keda.yaml --wait --timeout 5m
kubectl wait apiservice v1beta1.external.metrics.k8s.io --for=condition=Available --timeout=180s

# ------------------------------------------------------------ monitors + dashboard
log "PodMonitors/ServiceMonitors and Grafana dashboard"
apply manifests/monitors.yaml
kubectl -n monitoring create configmap kafka-keda-dashboard \
  --from-file=kafka-keda.json=dashboards/kafka-keda.json --dry-run=client -o yaml \
  | kubectl label --local -f - grafana_dashboard=1 -o yaml | kubectl apply -f -

# ------------------------------------------------------------ demo app + ScaledObject
log "Demo app + KEDA ScaledObject"
apply manifests/demo-app.yaml
apply manifests/scaledobject.yaml
render manifests/loadtest-job.yaml > loadtest-job.rendered.yaml

log "Done"
kubectl get pods -A -o wide | grep -v 'kube-system\|calico\|tigera' || true
kubectl -n demo get scaledobject,hpa
echo
echo "Next: cat ~/kafka-lab/CHEATSHEET.md   |   ~/kafka-lab/watch.sh all"
