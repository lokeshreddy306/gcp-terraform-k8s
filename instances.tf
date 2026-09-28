#create control plane VM
resource "google_compute_instance" "k8s-control-plane" {
  name         = "k8s-control-plane"
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["k8s-control-plane"]
  #create the VM with tag k8s-control-plane    
  boot_disk {
    #"Create a 30 GB balanced persistent boot disk, install Ubuntu 24.04 on it, and use it as the VM's boot disk."
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 30
      type  = "pd-balanced" #type of persistent disk GCP should create.
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    access_config {
    }
    #Empty access_config gives the VM an ephemeral external IP
  }
  metadata = {
    enable-oslogin = "True"
    #OS Login integrates SSH access to GCP VMs with IAM
    #It allows administrators to centrally control which users can SSH into Linux VMs instead of managing SSH keys individually on each VM.
  }
  metadata_startup_script = file("${path.module}/scripts/k8s-node.sh")
}

resource "google_compute_instance" "worker" {
  count        = 2
  name         = "k8s-worker-${count.index + 1}"
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["k8s-worker"]
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 20
      type  = "pd-balanced"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    access_config {

    }
  }
  metadata = {
    enable-oslogin = "True"
    #startup_script = file("${path.module}/scripts/k8s-node.sh")
    #You're explicitly saying:"Create a metadata key named startup-script and put my script there."
  }
  metadata_startup_script = file("${path.module}/scripts/k8s-node.sh")
  #use Terraform's dedicated argument. You're saying:"This is the startup script for this VM."
  #Terraform knows how to translate that into the appropriate GCP configuration.
}
