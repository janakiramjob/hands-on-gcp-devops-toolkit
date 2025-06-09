resource "google_compute_subnetwork" "subnet" {
    name = var.name
    region = var.region
    network = var.network_id
    ip_cidr_range = var.ip_cidr_range

    secondary_ip_range {
        range_name = var.secondary_range_name
        ip_cidr_range = var.secondary_ip_cidr_range
    }

    secondary_ip_range {
        range_name = var.service_range_name
        ip_cidr_range = var.service_ip_cidr_range
    }
  
}