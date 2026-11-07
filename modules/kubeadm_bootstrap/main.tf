# Runs after the VMs exist. Uses `gcloud compute ssh --tunnel-through-iap`
# (no public IPs involved) to:
#   1. copy + run kubeadm-install.sh on every node
#   2. set /etc/hosts and passwordless node-to-node SSH
#   3. kubeadm init on the control plane (+ Calico CNI via the Tigera operator)
#   4. copy the kubeadm join command to the workers and run it
resource "terraform_data" "bootstrap" {
  triggers_replace = {
    instance_ids   = join(",", var.instance_ids)
    install_script = filesha256(var.install_script_path)
    bootstrap      = filesha256("${path.module}/bootstrap.sh")
    pod_cidr       = var.pod_cidr
    service_cidr   = var.service_cidr
    calico_version = var.calico_version
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "bash '${path.module}/bootstrap.sh'"

    environment = {
      PROJECT_ID          = var.project_id
      ZONE                = var.zone
      CONTROL_PLANE       = var.control_plane
      WORKERS             = join(" ", var.workers)
      NODE_IPS            = join(" ", [for n, ip in var.node_ips : "${n}=${ip}"])
      INSTALL_SCRIPT_PATH = var.install_script_path
      K8S_MINOR           = var.k8s_minor
      POD_CIDR            = var.pod_cidr
      SERVICE_CIDR        = var.service_cidr
      CALICO_VERSION      = var.calico_version
    }
  }
}
