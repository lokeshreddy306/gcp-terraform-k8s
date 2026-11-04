
output "cluster_name" {
  value = google_container_cluster.portfolio.name
}

output "cluster_location" {
  value = google_container_cluster.portfolio.location
}
