resource "google_compute_subnetwork" "subnet" {
  name                     = var.name
  region                   = var.region
  network                  = var.network_id
  ip_cidr_range            = var.ip_cidr_range
  private_ip_google_access = true

  # Optional secondary ranges (only needed for GKE-style alias IPs;
  # a self-managed kubeadm cluster does not need them).
  dynamic "secondary_ip_range" {
    for_each = var.secondary_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }
}
