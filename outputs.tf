output "control_plane_external_ip" {
  value = google_compute_instance.k8s-control-plane.network_interface[0].access_config[0].nat_ip
  #A VM can have multiple network interfaces
  #[0] means:Use the first network interface.
  #nat_ip means the external/public IP address assigned to GCP VM through NAT (Network Address Translation).
}

output "control_plane_internal_ip" {
  value = google_compute_instance.k8s-control-plane.network_interface[0].network_ip
  #Internal/private IP
}

output "worker_external_ip" {
  value = [
    for instance in google_compute_instance.worker :
    instance.network_interface[0].access_config[0].nat_ip
  ]
  #here the worker external IPs values are stored in a list where as the Ips are stored in a dictionary
}

output "worker_internal_ip" {
  value = [
    for instance in google_compute_instance.worker :
    instance.network_interface[0].network_ip
  ]
}
