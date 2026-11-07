output "nodes" {
  value = module.compute.instances
}

output "ssh_controlplane" {
  value = "gcloud compute ssh controlplane --zone ${var.zone} --project ${var.project_id} --tunnel-through-iap"
}

output "ssh_worker1" {
  value = "gcloud compute ssh worker1 --zone ${var.zone} --project ${var.project_id} --tunnel-through-iap"
}

output "ssh_worker2" {
  value = "gcloud compute ssh worker2 --zone ${var.zone} --project ${var.project_id} --tunnel-through-iap"
}
