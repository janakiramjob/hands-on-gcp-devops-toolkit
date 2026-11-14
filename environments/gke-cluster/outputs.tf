output "cluster_name" {
  value = module.gke.name
}

output "cluster_location" {
  value = module.gke.location
}

output "cluster_endpoint" {
  value = module.gke.endpoint
}

output "node_pool" {
  value = module.gke.node_pool_name
}

output "get_credentials" {
  description = "Run this locally to point kubectl at the cluster."
  value       = "gcloud container clusters get-credentials ${module.gke.name} --zone ${module.gke.location} --project ${var.project_id}"
}

output "project_id" {
  value = var.project_id
}

output "node_service_account" {
  description = "Service account attached to system-pool and Karpenter-provisioned nodes."
  value       = module.node_sa.email
}

output "karpenter_controller_sa" {
  description = "GCP service account Karpenter impersonates through Workload Identity."
  value       = google_service_account.karpenter_controller.email
}

output "system_node_pool" {
  value = module.gke.node_pool_name
}

output "network_tag" {
  description = "Network tag on all nodes; firewall rules target it. Put it in the GCENodeClass networkTags."
  value       = local.network_tag
}
