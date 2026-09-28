resource "google_compute_network" "k8s_vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "k8s_subnet" {
  name          = var.subnet_name
  network       = google_compute_network.k8s_vpc.id
  region        = var.region
  ip_cidr_range = "10.10.0.0/24"
}
