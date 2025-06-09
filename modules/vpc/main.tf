resource "google_compute_network" "vpc" {
    name = var.name
    auto_create_subnetworks = false

}