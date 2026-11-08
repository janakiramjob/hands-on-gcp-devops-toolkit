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

output "ssh_worker3" {
  value = "gcloud compute ssh worker3 --zone ${var.worker3_zone} --project ${var.project_id} --tunnel-through-iap"
}

output "ssh_worker4" {
  value = "gcloud compute ssh worker4 --zone ${var.worker4_zone} --project ${var.project_id} --tunnel-through-iap"
}

output "app_image" {
  value = module.kafka_lab.app_image
}

output "lab_cheatsheet" {
  value = "gcloud compute ssh controlplane --zone ${var.zone} --project ${var.project_id} --tunnel-through-iap  # then: cat ~/kafka-lab/CHEATSHEET.md"
}
