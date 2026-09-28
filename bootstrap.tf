#terraform_data is a Terraform resource that lets you attach Terraform lifecycle/provisioner logic without creating an actual GCP resource.
resource "terraform_data" "wait-for-kubeadm" {
  depends_on = [google_compute_instance.k8s-control-plane, google_compute_instance.worker]
  #This tells Terraform:Don't execute wait_for_kubeadm until both VM resources have been created.
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    #local-exec itself eventually runs a shell command, but Terraform first needs that command represented as a string.
    #local-exec will take ssh to control plane VM and while loop will run on the control plane VM
    command = <<-EOF
    set -e
        echo "Waiting for Kubernetes packages on control plane..."
        gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --command='while ! command -v kubeadm > /dev/null 2>&1; do 
                        echo "Waiting for kubeadm..."
                        sleep 10
                    done'
        echo "control plane is ready"
        EOF
    #This means Terraform waits until kubeadm exists on the control-plane VM.
  }
}


/*
#Initializing Kubernetes Control Plane
resource "terraform_data" "kubeadm_init" {
  depends_on = [terraform_data.wait-for-kubeadm]
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOF
    set -e
    echo "Initializing Kubernetes Control Plane"
    gcloud compute ssh k8s-control-plane \
    --zone=${var.zone} \
    --command="sudo kubeadm init \
    --apiserver-advertise-address=${google_compute_instance.k8s-control-plane.network_interface[0].network_ip} \
    --pod-network-cidr=192.168.0.0/16"
    #Reserve 192.168.0.0/16 as the address space that the Kubernetes networking layer can use for Pods.
    #The important requirement is that the Pod CIDR must not conflict with your existing GCP VMs(Node network).
    echo "Kubernetes control plane initialized."
    EOF
  }
  #kubeadm init creates the control-plane components, local etcd, certificates, bootstrap token, and other configuration required for the control plane
}
*/

resource "terraform_data" "kubeadm_init" {

  depends_on = [
    terraform_data.wait-for-kubeadm
  ]

  provisioner "local-exec" {
    interpreter = ["C:\\Program Files\\Git\\bin\\bash.exe", "-c"]

    command = <<-EOT
      set -e

      echo "====================================="
      echo " Checking Kubernetes Control Plane"
      echo "====================================="

      INITIALIZED=$(gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --quiet \
        --command="sudo test -f /etc/kubernetes/admin.conf && echo yes || echo no")

      if [ "$INITIALIZED" = "yes" ]; then
        echo "Control plane is already initialized."
        echo "Skipping kubeadm init."
      else
        echo "Control plane is NOT initialized."
        echo "Running kubeadm init..."

        gcloud compute ssh k8s-control-plane \
          --zone=${var.zone} \
          --quiet \
          --command="sudo kubeadm init --apiserver-advertise-address=$(hostname -I | awk '{print $1}') --pod-network-cidr=192.168.0.0/16"
      fi

      echo "Control plane initialization check completed."
    EOT
  }
}

/*
#Configuring kubernetes config file
resource "terraform_data" "kubectl_config" {
  depends_on = [terraform_data.kubeadm_init]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]

    command = <<-EOF
      set -e

      echo "Configuring Kubectl.."

      gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --command='
          sudo mkdir -p "/home/${var.ssh_username}/.kube" && \
          sudo cp -f /etc/kubernetes/admin.conf "/home/${var.ssh_username}/.kube/config" && \
          sudo chown -R ${var.ssh_username}:${var.ssh_username} "/home/${var.ssh_username}/.kube/" && \
          sudo chmod 700 "/home/${var.ssh_username}/.kube"
          sudo chmod 600 "/home/${var.ssh_username}/.kube/config"
        '
    #This makes your current Linux user the owner of the configuration file.
    #Also, because $HOME and $(id -u) need to be evaluated on the control-plane VM, use single quotes around the remote comman
    #kubectl looks for its configuration by default at:~/.kube/config
    echo "kubectl configured for ${var.ssh_username}"
    EOF
  }
}
*/

resource "terraform_data" "kubectl_config" {

  depends_on = [
    terraform_data.kubeadm_init
  ]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]

    command = <<-EOT
      set -e

      echo "====================================="
      echo " Configuring kubectl"
      echo "====================================="

      gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --quiet \
        --command='
          if [ -f "/home/${var.ssh_username}/.kube/config" ]; then
            echo "kubectl configuration already exists."
            echo "Skipping configuration."
          else
            echo "Creating kubectl configuration..."

            sudo mkdir -p "/home/${var.ssh_username}/.kube"

            sudo cp /etc/kubernetes/admin.conf \
              "/home/${var.ssh_username}/.kube/config"

            sudo chown ${var.ssh_username}:${var.ssh_username} \
              "/home/${var.ssh_username}/.kube/config"

            sudo chmod 700 \
              "/home/${var.ssh_username}/.kube"

            sudo chmod 600 \
              "/home/${var.ssh_username}/.kube/config"

            echo "kubectl configuration created."
          fi
        '
    EOT
  }
}
/*
#Installing Calico
resource "terraform_data" "install-calico-CNI" {
  depends_on = [terraform_data.kubectl_config]
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
    set -e
    echo "installing Calico CNI"
    gcloud compute ssh k8s-control-plane \
    --zone=${var.zone} \
    --command='sudo kubectl --kubeconfig="/home/${var.ssh_username}/.kube/config" apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/calico.yaml'
    #Download this Kubernetes manifest and ask the Kubernetes API server to create/update all the objects described in it
    #Calico's v3.32.2 release includes components such as calico/node, calico/cni, and calico/kube-controllers
    echo "Calico manifest applied"
    EOT
  }
}
*/

resource "terraform_data" "install-calico-CNI" {

  depends_on = [
    terraform_data.kubectl_config
  ]

  provisioner "local-exec" {
    interpreter = ["C:\\Program Files\\Git\\bin\\bash.exe", "-c"]

    command = <<-EOT
      set -e

      echo "====================================="
      echo " Checking Calico CNI"
      echo "====================================="

      CALICO=$(gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --quiet \
        --command="kubectl get daemonset calico-node -n kube-system --ignore-not-found -o name")

      if [ "$CALICO" = "daemonset.apps/calico-node" ]; then
        echo "Calico is already installed."
        echo "Skipping Calico installation."
      else
        echo "Calico is not installed."
        echo "Installing Calico..."

        gcloud compute ssh k8s-control-plane \
          --zone=${var.zone} \
          --quiet \
          --command="kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/calico.yaml"

        echo "Calico installation completed."
      fi
    EOT
  }
}

#Wait for Calico to be installed completely and all the Pods comes to ready state
resource "terraform_data" "wait-for-calico" {
  depends_on = [terraform_data.install-calico-CNI]
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
    set -e
    echo "Waiting for Calico.."
    gcloud compute ssh k8s-control-plane \
    --zone=${var.zone} \
    --command='sudo kubectl --kubeconfig="/home/${var.ssh_username}/.kube/config" wait --for=condition=Ready pods --all -n kube-system --timeout=300s'
    #--for=condition=Ready is not a Bash for loop. It's a kubectl wait option; 
    #--for is the option name, and condition=Ready tells it which Kubernetes condition to wait for.
    echo "Calico/Kubernetes system pods have been checked."
    EOT
  }
}
/*
#Generate the worker join command and join workers in cluster
resource "terraform_data" "worker_join" {
  depends_on = [terraform_data.wait-for-calico]
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = <<-EOT
    set -e
    echo " Generating join command in control plane"
    gcloud compute ssh k8s-control-plane --zone=us-central1-c --quiet --command="sudo kubeadm token create --print-join-command" > join_cmd.sh

    echo "Joining worker-1..."
    gcloud compute scp join_cmd.sh k8s-worker-1:/tmp/join_cmd.sh --zone=us-central1-c --quiet
    gcloud compute ssh k8s-worker-1 --zone=us-central1-c --quiet --command="sudo bash /tmp/join_cmd.sh"

    echo "Joining worker-2..."
    gcloud compute scp join_cmd.sh k8s-worker-2:/tmp/join_cmd.sh --zone=us-central1-c --quiet
    gcloud compute ssh k8s-worker-2 --zone=us-central1-c --quiet --command="sudo bash /tmp/join_cmd.sh"

    rm -f join_cmd.sh
    echo "Worker-2 joined."
    EOT
  }
}
*/
resource "terraform_data" "worker_join" {

  depends_on = [
    terraform_data.wait-for-calico
  ]

  provisioner "local-exec" {
    interpreter = ["C:\\Program Files\\Git\\bin\\bash.exe", "-c"]

    command = <<-EOT
      set -e

      echo "====================================="
      echo " Checking Worker Nodes"
      echo "====================================="

      JOIN_COMMAND=$(gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --quiet \
        --command="sudo kubeadm token create --print-join-command" \
        | tail -1)

      echo "Join command generated."

      # ---------------------------------
      # Worker 1
      # ---------------------------------

      WORKER1_EXISTS=$(gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --quiet \
        --command="kubectl get node k8s-worker-1 --ignore-not-found -o name")

      if [ "$WORKER1_EXISTS" = "node/k8s-worker-1" ]; then
        echo "Worker-1 is already part of the cluster."
        echo "Skipping Worker-1."
      else
        echo "Worker-1 is not part of the cluster."
        echo "Joining Worker-1..."

        echo "$JOIN_COMMAND" > join_worker.sh

        gcloud compute scp join_worker.sh \
          k8s-worker-1:/tmp/join_worker.sh \
          --zone=${var.zone} \
          --quiet

        gcloud compute ssh k8s-worker-1 \
          --zone=${var.zone} \
          --quiet \
          --command="sudo bash /tmp/join_worker.sh"

        gcloud compute ssh k8s-worker-1 \
          --zone=${var.zone} \
          --quiet \
          --command="rm -f /tmp/join_worker.sh"

        echo "Worker-1 joined."
      fi


      # ---------------------------------
      # Worker 2
      # ---------------------------------

      WORKER2_EXISTS=$(gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --quiet \
        --command="kubectl get node k8s-worker-2 --ignore-not-found -o name")

      if [ "$WORKER2_EXISTS" = "node/k8s-worker-2" ]; then
        echo "Worker-2 is already part of the cluster."
        echo "Skipping Worker-2."
      else
        echo "Worker-2 is not part of the cluster."
        echo "Joining Worker-2..."

        echo "$JOIN_COMMAND" > join_worker.sh

        gcloud compute scp join_worker.sh \
          k8s-worker-2:/tmp/join_worker.sh \
          --zone=${var.zone} \
          --quiet

        gcloud compute ssh k8s-worker-2 \
          --zone=${var.zone} \
          --quiet \
          --command="sudo bash /tmp/join_worker.sh"

        gcloud compute ssh k8s-worker-2 \
          --zone=${var.zone} \
          --quiet \
          --command="rm -f /tmp/join_worker.sh"

        echo "Worker-2 joined."
      fi

      rm -f join_worker.sh

      echo "====================================="
      echo " Worker Join Check Completed"
      echo "====================================="
    EOT
  }
}
#Verify the cluster automatically
resource "terraform_data" "verify_cluster" {

  depends_on = [
    terraform_data.worker_join
  ]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
    set -e
      echo "====================================="
      echo " Kubernetes Cluster Status"
      echo "====================================="

      gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --command='kubectl get nodes -o wide'

      echo ""
      echo "====================================="
      echo " Kubernetes System Pods"
      echo "====================================="

      gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --command='kubectl get pods -A'

      echo ""
      echo "====================================="
      echo " Cluster Info"
      echo "====================================="

      gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --command='kubectl cluster-info'
    EOT
  }
}