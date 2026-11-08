# Managed by Terraform (modules/kubeadm_bootstrap/kubectl-aliases.sh). Sourced from ~/.bash_aliases.

# ---- requested aliases
alias k='kubectl'
alias kc='kubectl create'
alias kg='kubectl get'
alias kgdp='kubectl get deployments'
alias kgn='kubectl get nodes'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kdp='kubectl delete pods'
alias kgns='kubectl get namespace'
alias kd='kubectl describe'
alias ka='kubectl apply'
alias kl='kubectl logs'
alias kdel='kubectl delete'
alias ke='kubectl exec -it'
alias kgans='kubectl get all --all-namespaces'

# ---- extras
alias kgpw='kubectl get pods -o wide'
alias kgnw='kubectl get nodes -o wide'
alias kgs='kubectl get svc'
alias kgsa='kubectl get svc -A'
alias kgpv='kubectl get pv,pvc'
alias kgsc='kubectl get storageclass'
alias kge='kubectl get events --sort-by=.lastTimestamp'
alias klf='kubectl logs -f'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kx='kubectl config use-context'
alias kctx='kubectl config current-context'
alias ktn='kubectl top nodes'
alias ktp='kubectl top pods'
alias h='helm'
alias hls='helm list -A'

# switch the default namespace: kns <namespace>
kns() { kubectl config set-context --current --namespace="${1:?usage: kns <namespace>}"; }

# dry-run helper:  k run nginx --image=nginx $do > pod.yaml
export do='--dry-run=client -o yaml'
export now='--force --grace-period=0'

# ---- completion (also for the k and h aliases)
if command -v kubectl >/dev/null 2>&1; then
  source <(kubectl completion bash)
  complete -o default -F __start_kubectl k
fi
if command -v helm >/dev/null 2>&1; then
  source <(helm completion bash)
  complete -o default -F __start_helm h
fi
