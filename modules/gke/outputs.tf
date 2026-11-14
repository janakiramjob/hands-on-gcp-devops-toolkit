output "name" {
  value = google_container_cluster.cluster.name
}

output "location" {
  value = google_container_cluster.cluster.location
}

output "endpoint" {
  value = google_container_cluster.cluster.endpoint
}

output "node_pool_name" {
  value = google_container_node_pool.pool.name
}
