#!/usr/bin/env bash
# Orchestrates kubeadm cluster creation over IAP SSH. Safe to re-run.
set -Eeuo pipefail

: "${PROJECT_ID:?}" "${ZONE:?}" "${CONTROL_PLANE:?}" "${WORKERS:?}" "${NODE_IPS:?}"
: "${INSTALL_SCRIPT_PATH:?}" "${POD_CIDR:?}" "${SERVICE_CIDR:?}" "${CALICO_VERSION:?}"

ALL_NODES="${CONTROL_PLANE} ${WORKERS}"
CP_IP=""
for kv in ${NODE_IPS}; do [[ "${kv%%=*}" == "${CONTROL_PLANE}" ]] && CP_IP="${kv#*=}"; done
[[ -n "${CP_IP}" ]] || { echo "control plane IP not found"; exit 1; }

LOGDIR="$(mktemp -d)"
log() { echo; echo "[$(date '+%T')] $*"; }

SSH_FLAGS=(--project="${PROJECT_ID}" --zone="${ZONE}" --tunnel-through-iap --quiet
           --strict-host-key-checking=no)

# rssh <node> <command...>   run a command on a node
rssh() { local n="$1"; shift; gcloud compute ssh "${n}" "${SSH_FLAGS[@]}" --command "$*" -- -o ServerAliveInterval=30; }
# rscp <local> <node>:<remote>
rscp() { gcloud compute scp "${SSH_FLAGS[@]}" "$1" "$2"; }

# ---------------------------------------------------------------- 1. wait
log "Waiting for SSH over IAP on: ${ALL_NODES}"
for n in ${ALL_NODES}; do
  for i in $(seq 1 40); do
    if rssh "${n}" "true" >/dev/null 2>&1; then echo "  ${n}: ready"; break; fi
    [[ $i -eq 40 ]] && { echo "  ${n}: SSH never became ready"; exit 1; }
    sleep 15
  done
done

# ---------------------------------------------------------------- 2. install
log "Copying kubeadm-install.sh to all nodes"
for n in ${ALL_NODES}; do rscp "${INSTALL_SCRIPT_PATH}" "${n}:/tmp/kubeadm-install.sh"; done

log "Running kubeadm-install.sh on all nodes in parallel (logs: ${LOGDIR})"
pids=()
for n in ${ALL_NODES}; do
  ( rssh "${n}" "sudo K8S_MINOR='${K8S_MINOR:-v1.33}' bash /tmp/kubeadm-install.sh" ) >"${LOGDIR}/${n}-install.log" 2>&1 &
  pids+=($!)
done
fail=0
i=0
for n in ${ALL_NODES}; do
  if wait "${pids[$i]}"; then echo "  ${n}: install OK"; else echo "  ${n}: install FAILED"; tail -30 "${LOGDIR}/${n}-install.log"; fail=1; fi
  i=$((i+1))
done
[[ $fail -eq 0 ]] || exit 1

# ---------------------------------------------------------------- 3. hosts + ssh mesh
log "Configuring /etc/hosts and node-to-node SSH"
HOSTS_BLOCK=""
for kv in ${NODE_IPS}; do HOSTS_BLOCK+="${kv#*=} ${kv%%=*}"$'\n'; done
for n in ${ALL_NODES}; do
  rssh "${n}" "sudo sed -i '/# k8s-nodes-begin/,/# k8s-nodes-end/d' /etc/hosts && \
    printf '# k8s-nodes-begin\n%s# k8s-nodes-end\n' '${HOSTS_BLOCK}' | sudo tee -a /etc/hosts >/dev/null && \
    mkdir -p ~/.ssh; chmod 700 ~/.ssh; [ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519; \
    printf 'Host *\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n' > ~/.ssh/config; chmod 600 ~/.ssh/config"
done
ALL_PUBS=""
for n in ${ALL_NODES}; do ALL_PUBS+="$(rssh "${n}" 'cat ~/.ssh/id_ed25519.pub' 2>/dev/null | tail -1)"$'\n'; done
for n in ${ALL_NODES}; do
  rssh "${n}" "touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && \
    printf '%s' '${ALL_PUBS}' | while read -r l; do [ -n \"\$l\" ] && (grep -qxF \"\$l\" ~/.ssh/authorized_keys || echo \"\$l\" >> ~/.ssh/authorized_keys); done"
done

# ---------------------------------------------------------------- 4. init
log "kubeadm init on ${CONTROL_PLANE}"
rssh "${CONTROL_PLANE}" "
  if [ -f /etc/kubernetes/admin.conf ]; then
    echo 'cluster already initialised, skipping kubeadm init'
  else
    sudo kubeadm init \
      --node-name='${CONTROL_PLANE}' \
      --apiserver-advertise-address='${CP_IP}' \
      --pod-network-cidr='${POD_CIDR}' \
      --service-cidr='${SERVICE_CIDR}'
  fi
  mkdir -p \$HOME/.kube
  sudo cp -f /etc/kubernetes/admin.conf \$HOME/.kube/config
  sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config
  CAL=https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests
  # operator CRDs are large: create/server-side apply, not client-side apply
  kubectl create -f \$CAL/tigera-operator.yaml 2>&1 || kubectl replace -f \$CAL/tigera-operator.yaml
  curl -fsSL \$CAL/custom-resources.yaml | sed 's|cidr: 192.168.0.0/16|cidr: ${POD_CIDR}|' | kubectl apply -f -
"

# ---------------------------------------------------------------- 5. join
log "Creating join command and distributing it to workers"
JOIN_CMD="$(rssh "${CONTROL_PLANE}" 'sudo kubeadm token create --ttl 1h --print-join-command' | tail -1)"
[[ "${JOIN_CMD}" == kubeadm\ join* ]] || { echo "unexpected join command: ${JOIN_CMD}"; exit 1; }
printf '#!/usr/bin/env bash\nset -e\nif [ -f /etc/kubernetes/kubelet.conf ]; then echo "already joined"; exit 0; fi\nsudo %s --node-name "$(hostname -s)"\n' "${JOIN_CMD}" > "${LOGDIR}/join.sh"

for w in ${WORKERS}; do
  rscp "${LOGDIR}/join.sh" "${w}:/tmp/join.sh"
  rssh "${w}" "bash /tmp/join.sh"
done

# ---------------------------------------------------------------- 6. verify
log "Waiting for all nodes to be Ready"
for i in $(seq 1 40); do
  not_ready="$(rssh "${CONTROL_PLANE}" "kubectl get nodes --no-headers 2>/dev/null | grep -vc ' Ready ' || true" | tail -1)"
  total="$(rssh "${CONTROL_PLANE}" "kubectl get nodes --no-headers 2>/dev/null | wc -l" | tail -1)"
  [[ "${not_ready}" == "0" && "${total}" == "$(wc -w <<<"${ALL_NODES}")" ]] && break
  sleep 15
done
rssh "${CONTROL_PLANE}" "kubectl get nodes -o wide"
log "Cluster ready. Connect: gcloud compute ssh ${CONTROL_PLANE} --zone ${ZONE} --project ${PROJECT_ID} --tunnel-through-iap"
