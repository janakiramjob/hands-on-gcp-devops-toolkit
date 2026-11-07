# Nodes have no public IP. Cloud NAT gives them outbound internet access
# (apt, container registries, GitHub) without exposing them inbound.
resource "google_compute_router" "router" {
  name    = "${var.name}-router"
  region  = var.region
  network = var.network_id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = false
    filter = "ERRORS_ONLY"
  }
}
