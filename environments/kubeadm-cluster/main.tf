locals {
  network_tag = "${var.cluster_name}-node"
  install_script_path = (
    var.install_script_path != "" ? var.install_script_path :
    abspath("${path.module}/../../shell-scripts/kubeadm-install.sh")
  )

  nodes = {
    controlplane = { role = "control-plane", internal_ip = cidrhost(var.subnet_cidr, 10) }
    worker1      = { role = "worker", internal_ip = cidrhost(var.subnet_cidr, 11) }
    worker2      = { role = "worker", internal_ip = cidrhost(var.subnet_cidr, 12) }
    # Extra workers spread across other zones of the same region
    worker3 = { role = "worker", internal_ip = cidrhost(var.subnet_cidr, 13), zone = var.worker3_zone }
    worker4 = { role = "worker", internal_ip = cidrhost(var.subnet_cidr, 14), zone = var.worker4_zone }
  }
}

resource "google_project_service" "apis" {
  for_each = toset(["compute.googleapis.com", "iap.googleapis.com"])

  service            = each.value
  disable_on_destroy = false
}

module "vpc" {
  source = "../../modules/vpc"
  name   = "${var.cluster_name}-vpc"

  depends_on = [google_project_service.apis]
}

module "subnet" {
  source        = "../../modules/subnets"
  name          = "${var.cluster_name}-subnet"
  region        = var.region
  network_id    = module.vpc.id
  ip_cidr_range = var.subnet_cidr
}

module "nat" {
  source     = "../../modules/nat"
  name       = var.cluster_name
  region     = var.region
  network_id = module.vpc.id
}

module "firewall" {
  source       = "../../modules/firewall"
  name_prefix  = var.cluster_name
  network_name = module.vpc.name

  rules = {
    allow-iap-ssh = {
      description   = "SSH from Google IAP TCP forwarding"
      source_ranges = ["35.235.240.0/20"]
      target_tags   = [local.network_tag]
      allow         = [{ protocol = "tcp", ports = ["22"] }]
    }
    allow-internal = {
      description   = "All traffic between cluster nodes and pods (SSH, API 6443, etcd, kubelet, CNI, NodePorts)"
      source_ranges = [var.subnet_cidr, var.pod_cidr]
      target_tags   = [local.network_tag]
      allow = [
        { protocol = "tcp" },
        { protocol = "udp" },
        { protocol = "icmp" },
        { protocol = "ipip" },
      ]
    }
  }
}

module "node_sa" {
  source       = "../../modules/service_account"
  project_id   = var.project_id
  account_id   = "${var.cluster_name}-node"
  display_name = "kubeadm cluster nodes"
  roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]
}

module "compute" {
  source = "../../modules/compute"

  region                = var.region
  zone                  = var.zone
  subnet_id             = module.subnet.id
  nodes                 = local.nodes
  machine_type          = var.machine_type
  image                 = var.image
  disk_size_gb          = var.disk_size_gb
  network_tags          = [local.network_tag]
  labels                = { cluster = var.cluster_name }
  service_account_email = module.node_sa.email

  depends_on = [module.nat, module.firewall]
}

module "kubeadm_bootstrap" {
  source = "../../modules/kubeadm_bootstrap"

  project_id          = var.project_id
  zone                = var.zone
  control_plane       = "controlplane"
  workers             = ["worker1", "worker2", "worker3", "worker4"]
  node_ips            = { for k, v in local.nodes : k => v.internal_ip }
  node_zones          = { for k, v in local.nodes : k => try(v.zone, var.zone) }
  instance_ids        = module.compute.instance_ids
  install_script_path = local.install_script_path
  k8s_minor           = var.k8s_minor
  pod_cidr            = var.pod_cidr
  service_cidr        = var.service_cidr
  calico_version      = var.calico_version

  depends_on = [module.nat, module.firewall]
}
