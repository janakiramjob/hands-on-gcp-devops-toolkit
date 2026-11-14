locals {
  network_tag         = "${var.cluster_name}-node"
  pods_range_name     = "${var.cluster_name}-pods"
  services_range_name = "${var.cluster_name}-services"
}

resource "google_project_service" "apis" {
  for_each = toset(["compute.googleapis.com", "container.googleapis.com"])

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

  secondary_ranges = {
    (local.pods_range_name)     = var.pod_cidr
    (local.services_range_name) = var.service_cidr
  }
}

# Nodes are private; NAT gives them outbound internet (Docker Hub, GitHub, ...)
module "nat" {
  source     = "../../modules/nat"
  name       = var.cluster_name
  region     = var.region
  network_id = module.vpc.id
}

module "node_sa" {
  source       = "../../modules/service_account"
  project_id   = var.project_id
  account_id   = "${var.cluster_name}-node"
  display_name = "GKE cluster nodes"
  roles = [
    # Minimum role for GKE nodes (logging, monitoring, autoscaling metrics)
    "roles/container.defaultNodeServiceAccount",
    # Pull images from Artifact Registry repos in this project (e.g. kafka-demo)
    "roles/artifactregistry.reader",
  ]
}

# ---------------------------------------------------------------- firewall
# GKE only auto-opens 443/10250 from the control plane to nodes. Admission
# webhooks and aggregated APIs of the add-ons in apps/ listen on other ports,
# and the private control plane must reach them or installs hang/fail.
module "firewall" {
  source       = "../../modules/firewall"
  name_prefix  = var.cluster_name
  network_name = module.vpc.name

  rules = {
    allow-master-webhooks = {
      description   = "GKE control plane -> add-on webhooks/APIs (istiod 15017, KEDA 6443/9443, Kyverno 9443, OTel operator 9443, Karpenter 8443)"
      source_ranges = [var.master_cidr]
      target_tags   = [local.network_tag]
      allow         = [{ protocol = "tcp", ports = ["6443", "8000", "8443", "9443", "9666", "15017"] }]
    }
    allow-internal = {
      description   = "Node <-> node and pod <-> pod traffic"
      source_ranges = [var.subnet_cidr, var.pod_cidr, var.service_cidr]
      target_tags   = [local.network_tag]
      allow = [
        { protocol = "tcp" },
        { protocol = "udp" },
        { protocol = "icmp" },
      ]
    }
  }
}

# ---------------------------------------------------------------- Karpenter IAM
# Permission list is the upstream canonical one, kept in apps/karpenter/ so the
# same file can be used with gcloud.
locals {
  karpenter_role = yamldecode(file("${path.module}/../../apps/karpenter/controller-role.yaml"))
}

resource "google_service_account" "karpenter_controller" {
  account_id   = "${var.cluster_name}-karpenter"
  display_name = "Karpenter controller (${var.cluster_name})"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_custom_role" "karpenter_controller" {
  role_id     = "${replace(var.cluster_name, "-", "_")}_karpenter_controller"
  title       = local.karpenter_role.title
  description = local.karpenter_role.description
  permissions = local.karpenter_role.includedPermissions
}

resource "google_project_iam_member" "karpenter_controller" {
  project = var.project_id
  role    = google_project_iam_custom_role.karpenter_controller.id
  member  = "serviceAccount:${google_service_account.karpenter_controller.email}"
}

# Karpenter attaches the node SA to the VMs it creates
resource "google_service_account_iam_member" "karpenter_act_as_node_sa" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${module.node_sa.email}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.karpenter_controller.email}"
}

# Workload Identity: karpenter-system/karpenter KSA -> controller GSA
resource "google_service_account_iam_member" "karpenter_workload_identity" {
  service_account_id = google_service_account.karpenter_controller.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.karpenter_namespace}/${var.karpenter_service_account}]"

  # the workload pool is created together with the cluster
  depends_on = [module.gke]
}

module "gke" {
  source = "../../modules/gke"

  project_id = var.project_id
  name       = var.cluster_name
  location   = var.zone

  network_id          = module.vpc.id
  subnet_id           = module.subnet.id
  pods_range_name     = local.pods_range_name
  services_range_name = local.services_range_name

  master_ipv4_cidr_block     = var.master_cidr
  master_authorized_networks = var.master_authorized_networks
  release_channel            = var.release_channel

  node_pool_name        = "${var.cluster_name}-system"
  node_count            = var.node_count
  autoscaling_enabled   = var.autoscaling_enabled
  min_node_count        = var.min_node_count
  max_node_count        = var.max_node_count
  machine_type          = var.machine_type
  disk_size_gb          = var.disk_size_gb
  service_account_email = module.node_sa.email
  network_tags          = [local.network_tag]

  depends_on = [google_project_service.apis, module.nat, module.node_sa]
}
