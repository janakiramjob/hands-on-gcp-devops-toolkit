resource "google_container_cluster" "cluster" {
  name     = var.name
  location = var.location

  network    = var.network_id
  subnetwork = var.subnet_id

  # GKE cannot create a cluster without a node pool, but the pool is managed
  # separately below. The throwaway default pool is deleted right after creation.
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = var.deletion_protection

  # VPC-native cluster: pods and services use the subnet's secondary ranges
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Nodes have no public IP (outbound goes through Cloud NAT);
  # the control plane keeps a public endpoint so kubectl works from a laptop.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Only rendered when CIDRs are given; otherwise the endpoint is reachable from anywhere
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          display_name = cidr_blocks.key
          cidr_block   = cidr_blocks.value
        }
      }
    }
  }

  release_channel {
    channel = var.release_channel
  }

  # GKE enables Google Managed Prometheus on new clusters by default. It is turned
  # off here: metrics are collected by the self-hosted Prometheus in apps/monitoring.
  # System metrics (kubelet/cAdvisor to Cloud Monitoring) stay on.
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]

    managed_prometheus {
      enabled = var.enable_managed_prometheus
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "pool" {
  name     = var.node_pool_name
  cluster  = google_container_cluster.cluster.id
  location = var.location

  # Zonal cluster: total node count. Regional cluster: count PER ZONE.
  # With autoscaling enabled it is only the starting size (GKE then manages it between min and max).
  initial_node_count = var.autoscaling_enabled ? var.node_count : null
  node_count         = var.autoscaling_enabled ? null : var.node_count

  dynamic "autoscaling" {
    for_each = var.autoscaling_enabled ? [1] : []
    content {
      min_node_count = var.min_node_count
      max_node_count = var.max_node_count
    }
  }

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = var.disk_size_gb
    disk_type       = var.disk_type
    service_account = var.service_account_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    tags            = var.network_tags

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
