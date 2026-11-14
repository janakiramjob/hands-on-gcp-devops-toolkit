# Cluster add-ons for `environments/gke-cluster`

Everything is declarative YAML. Each folder has a `helmfile.yaml` that lists exactly which Helm
chart, version and namespace gets installed (with comments on what it does), plus a `values*.yaml`
with the small-footprint settings, and plain manifests/examples applied with `kubectl`.

Needs [`helmfile`](https://github.com/helmfile/helmfile) (v1.x) and `helm` 3. Use `helmfile ... sync`
(the `helm-diff` plugin is only needed for `apply`/`diff`). `helmfile ... template` shows the final manifests.

| #  | Folder       | Installs                                                            | Chart / version                         |
|----|--------------|---------------------------------------------------------------------|-----------------------------------------|
| 1  | `karpenter`  | Node autoscaler (+ default `GCENodeClass` / `NodePool`)             | karpenter + karpenter-crd 0.8.0         |
| 2  | `monitoring` | Prometheus, Grafana, kube-state-metrics, node-exporter; Tempo (traces) | kube-prometheus-stack 93.3.0, Tempo 2.9.0 |
| 3  | `keda`       | Event-driven pod autoscaling                                        | keda 2.21.0                             |
| 4  | `istio`      | Service mesh + ingress gateway (= the single load balancer) + Kiali | base / istiod / gateway 1.30.8, kiali-server 2.34.1 |
| 5  | `kyverno`    | Policy engine (+ audit-only starter policies)                       | kyverno 3.10.0 (v1.20.0)                |
| 6  | `otel`       | OpenTelemetry Collector agent on every node                         | opentelemetry-collector 0.178.3         |
| 7  | `argocd`     | GitOps                                                              | argo-cd 10.18.0 (v3.6.1)                |
| -  | `ingress.yaml` | One Gateway + VirtualService: `/grafana`, `/prometheus`, `/argocd`, `/kiali`, `/otel` | Istio resources |

Karpenter goes first: the 2-node system pool is deliberately small, everything else lands on nodes Karpenter creates.

## Install (from the repo root, after `terraform apply` + `get-credentials`)

```bash
# 1. Karpenter, then tell it what nodes it may create
helmfile -f apps/karpenter/helmfile.yaml sync
kubectl apply -f apps/karpenter/gcenodeclass.yaml -f apps/karpenter/nodepool.yaml

# 2. Monitoring (Grafana password is required: the UI sits behind a public load balancer)
export GRAFANA_ADMIN_PASSWORD='change-me'
helmfile -f apps/monitoring/helmfile.yaml sync
kubectl apply -f apps/monitoring/tempo.yaml

# 3. the rest
helmfile -f apps/keda/helmfile.yaml sync
helmfile -f apps/istio/helmfile.yaml sync       # istio + Kiali
kubectl apply -f apps/istio/monitoring.yaml     # Prometheus scrapes istiod + Envoy (Kiali graph needs it)
helmfile -f apps/kyverno/helmfile.yaml sync
kubectl apply -f apps/kyverno/policies/
helmfile -f apps/otel/helmfile.yaml sync
helmfile -f apps/argocd/helmfile.yaml sync

# 4. single load balancer with paths
kubectl apply -f apps/ingress.yaml
kubectl -n istio-ingress get svc istio-ingress      # EXTERNAL-IP may take a minute
```

Then open `http://<EXTERNAL-IP>/grafana` (admin / your password), `/prometheus`, `/argocd`, `/kiali`.
`/otel` is not a UI: it is the collector's OTLP/HTTP endpoint for apps outside the cluster, e.g.
`OTEL_EXPORTER_OTLP_ENDPOINT=http://<EXTERNAL-IP>/otel` (SDKs append `/v1/traces`). Inside the cluster use `http://otel-agent.observability:4318`.

Kiali's graph needs sidecar traffic: `kubectl apply -f apps/istio/examples/httpbin.yaml` and send some requests to it.

## Checking OpenTelemetry end to end

```bash
kubectl apply -f apps/otel/examples/telemetrygen.yaml       # 20 test spans
```
Grafana -> Explore -> **Tempo** -> Search: you should see the `telemetrygen` traces.
Grafana -> Explore -> **Prometheus**: node/kubelet metrics sent by the agent (e.g. `k8s_pod_cpu_usage`, `system_cpu_time`).
Container logs and a copy of the spans also appear in `kubectl -n observability logs ds/otel-agent`.

## Overrides and notes

- `karpenter/values-cluster.yaml.gotmpl` defaults to the terraform defaults (`cka-comingsoon`, `gke-lab`, `us-east1-b`);
  override with `PROJECT_ID`, `CLUSTER_NAME`, `CLUSTER_ZONE`. `gcenodeclass.yaml` / `nodepool.yaml` hold the same values as literals.
- GKE's managed Prometheus is disabled in terraform (`modules/gke`, `enable_managed_prometheus = false`).
- `karpenter/controller-role.yaml` is the upstream IAM permission list; terraform reads it to create the custom role.
- Terraform opens the control-plane -> node webhook ports these add-ons need (6443, 8443, 9443, 15017, ...).
- Kiali is read-only with no login (`auth.strategy: anonymous`), and `/otel` accepts unauthenticated telemetry.
- The ingress is plain HTTP and public. Set `loadBalancerSourceRanges` in `istio/values-gateway.yaml` to your IP.
- Tempo keeps traces on an `emptyDir` (lost on pod restart). Prometheus uses a 10Gi PVC with 2d retention.
- Kyverno policies run in `Audit` mode; flip `validationActions` to `[Deny]` when ready.
