#Allow SSH
resource "google_compute_firewall" "allow_ssh" {
  name    = "k8s-allow-ssh"
  network = google_compute_network.k8s_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

#Kubernetes API server
resource "google_compute_firewall" "allow_kubernetes_api" {
  name    = "k8s-allow-api"
  network = google_compute_network.k8s_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }
  source_ranges = ["10.10.0.0/24"]
  target_tags   = ["k8s-control-plane"]
}
#Internal_pods_communication
resource "google_compute_firewall" "allow_internal" {
  name    = "k8s-allow-internal"
  network = google_compute_network.k8s_vpc.name
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["10.10.0.0/24"]
}