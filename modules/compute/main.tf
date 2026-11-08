# Reserved static internal IPs keep node addresses stable across stop/start,
# which matters because kubeadm bakes the control-plane IP into the cluster.
resource "google_compute_address" "internal" {
  for_each = var.nodes

  name         = "${each.key}-ip"
  region       = var.region
  subnetwork   = var.subnet_id
  address_type = "INTERNAL"
  address      = each.value.internal_ip
}

resource "google_compute_instance" "node" {
  for_each = var.nodes

  name         = each.key
  zone         = coalesce(each.value.zone, var.zone)
  machine_type = coalesce(each.value.machine_type, var.machine_type)
  tags         = var.network_tags
  labels       = merge(var.labels, { role = each.value.role })

  # Required to keep kubelet/pod networking happy if you later add a CNI that
  # routes pod traffic through the node (Calico VXLAN works either way).
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size_gb
      type  = var.disk_type
    }
  }

  network_interface {
    subnetwork = var.subnet_id
    network_ip = google_compute_address.internal[each.key].address
    # No access_config block => no public IP. Reach nodes via IAP; egress via NAT.
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  metadata = {
    # gcloud compute ssh manages the user's SSH keys in metadata.
    enable-oslogin = "FALSE"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [metadata["ssh-keys"]]
  }
}
