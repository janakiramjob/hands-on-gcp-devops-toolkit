output "instances" {
  description = "Per-node name, zone and internal IP."
  value = {
    for k, i in google_compute_instance.node : k => {
      id          = i.id
      zone        = i.zone
      internal_ip = i.network_interface[0].network_ip
    }
  }
}

output "instance_ids" {
  value = [for i in google_compute_instance.node : i.id]
}
