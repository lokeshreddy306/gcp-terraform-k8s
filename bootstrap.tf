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
            echo "Make sure the directory and config belong to SSH User"
            sudo chown -R ${var.ssh_username}:${var.ssh_username} \
              "/home/${var.ssh_username}/.kube"

            sudo chmod 700 \
              "/home/${var.ssh_username}/.kube"

            sudo chmod 600 \
              "/home/${var.ssh_username}/.kube/config"
            
            echo "kubectl permissions verified."

          else
            echo "Creating kubectl configuration..."

            sudo mkdir -p "/home/${var.ssh_username}/.kube"

            sudo cp /etc/kubernetes/admin.conf \
              "/home/${var.ssh_username}/.kube/config"

            sudo chown -R ${var.ssh_username}:${var.ssh_username} \
              "/home/${var.ssh_username}/.kube"

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
*/

# ---------------------------------------------------------
# Configure kubectl
#
# This resource does two things:
#
# 1. Creates/configures kubectl on the control-plane VM.
#
# 2. Copies the Kubernetes admin.conf to the Windows
#    machine where Terraform is running.
#
# The Windows kubeconfig will later communicate with the
# Kubernetes API server through an SSH tunnel.
# ---------------------------------------------------------

resource "terraform_data" "kubectl_config" {

  depends_on = [
    terraform_data.kubeadm_init
  ]

  provisioner "local-exec" {

    # Terraform is running on Windows.
    # We use Git Bash because the rest of this bootstrap.tf
    # already uses Git Bash for shell commands.

    interpreter = ["C:\\Program Files\\Git\\bin\\bash.exe", "-c"]

    command = <<-EOT

      set -e

      echo "=============================================="
      echo " Configuring Kubernetes kubectl"
      echo "=============================================="

      # ---------------------------------------------------
      # STEP 1
      # Configure kubectl on the control-plane VM
      # ---------------------------------------------------

      echo ""
      echo "Checking kubectl configuration on control plane..."

      gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --quiet \
        --command='
          if [ -f "/home/${var.ssh_username}/.kube/config" ]; then

            echo "kubectl configuration already exists."

            sudo chown -R ${var.ssh_username}:${var.ssh_username} \
              "/home/${var.ssh_username}/.kube"

            sudo chmod 700 \
              "/home/${var.ssh_username}/.kube"

            sudo chmod 600 \
              "/home/${var.ssh_username}/.kube/config"

          else

            echo "Creating kubectl configuration..."

            sudo mkdir -p \
              "/home/${var.ssh_username}/.kube"

            sudo cp \
              /etc/kubernetes/admin.conf \
              "/home/${var.ssh_username}/.kube/config"

            sudo chown -R \
              ${var.ssh_username}:${var.ssh_username} \
              "/home/${var.ssh_username}/.kube"

            sudo chmod 700 \
              "/home/${var.ssh_username}/.kube"

            sudo chmod 600 \
              "/home/${var.ssh_username}/.kube/config"

          fi

          echo "Control-plane kubectl configuration completed."
        '


      # ---------------------------------------------------
      # STEP 2
      # Create Windows .kube directory
      # ---------------------------------------------------

      echo ""
      echo "Creating Windows .kube directory..."

      mkdir -p "$HOME/.kube"


      # ---------------------------------------------------
      # STEP 3
      # Copy admin.conf from the control plane
      #
      # We use sudo cat remotely because /etc/kubernetes/
      # admin.conf is normally readable only by root.
      # ---------------------------------------------------

      echo ""
      echo "Copying Kubernetes admin.conf to Windows..."

      gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --quiet \
        --command="sudo cat /etc/kubernetes/admin.conf" \
        > "$HOME/.kube/config"


      # ---------------------------------------------------
      # STEP 4
      # Configure the Windows kubeconfig to use the SSH
      # tunnel.
      #
      # The real Kubernetes API server is:
      #
      # https://10.10.0.3:6443
      #
      # Windows will connect through:
      #
      # https://127.0.0.1:6443
      #
      # Therefore we replace the server address.
      # ---------------------------------------------------

      echo ""
      echo "Configuring Windows API server address..."

      CONTROL_PLANE_IP="${google_compute_instance.k8s-control-plane.network_interface[0].network_ip}"

      sed -i \
        "s#server: https://$CONTROL_PLANE_IP:6443#server: https://127.0.0.1:6443#g" \
        "$HOME/.kube/config"


      # ---------------------------------------------------
      # STEP 5
      # Tell kubectl to verify the Kubernetes TLS
      # certificate against the control-plane IP.
      #
      # This is necessary because kubectl connects to
      # 127.0.0.1 but the kubeadm certificate normally
      # contains the control-plane IP.
      # ---------------------------------------------------

      echo ""
      echo "Configuring TLS server name..."

      sed -i \
        "/server: https:\/\/127.0.0.1:6443/a\\    tls-server-name: $CONTROL_PLANE_IP" \
        "$HOME/.kube/config"


      # ---------------------------------------------------
      # STEP 6
      # Set the kubeconfig permissions.
      # ---------------------------------------------------

      chmod 600 "$HOME/.kube/config"


      # ---------------------------------------------------
      # STEP 7
      # Verify the kubeconfig.
      # ---------------------------------------------------

      echo ""
      echo "=============================================="
      echo " Windows kubeconfig created"
      echo "=============================================="

      echo ""
      echo "Kubeconfig:"
      echo "$HOME/.kube/config"

      echo ""
      echo "Kubernetes contexts:"

      KUBECONFIG="$HOME/.kube/config" \
        kubectl config get-contexts

      echo ""
      echo "Current context:"

      KUBECONFIG="$HOME/.kube/config" \
        kubectl config current-context || true

      echo ""
      echo "Windows kubeconfig configuration completed."

    EOT
  }
}

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

        gcloud compute scp join_worker.sh k8s-worker-1:/tmp/join_worker.sh --zone=${var.zone} --quiet

        gcloud compute ssh k8s-worker-1 --zone=${var.zone} --quiet --command="sudo bash /tmp/join_worker.sh"

        gcloud compute ssh k8s-worker-1 --zone=${var.zone} --quiet --command="rm -f /tmp/join_worker.sh"

        echo "Worker-1 joined."
      fi


      # ---------------------------------
      # Worker 2
      # ---------------------------------

      WORKER2_EXISTS=$(gcloud compute ssh k8s-control-plane --zone=${var.zone} --quiet \
        --command="kubectl get node k8s-worker-2 --ignore-not-found -o name")

      if [ "$WORKER2_EXISTS" = "node/k8s-worker-2" ]; then
        echo "Worker-2 is already part of the cluster."
        echo "Skipping Worker-2."
      else
        echo "Worker-2 is not part of the cluster."
        echo "Joining Worker-2..."

        echo "$JOIN_COMMAND" > join_worker.sh

        gcloud compute scp join_worker.sh k8s-worker-2:/tmp/join_worker.sh --zone=${var.zone} --quiet

        gcloud compute ssh k8s-worker-2 --zone=${var.zone} --quiet --command="sudo bash /tmp/join_worker.sh"

        gcloud compute ssh k8s-worker-2 --zone=${var.zone} --quiet --command="rm -f /tmp/join_worker.sh"

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

# ---------------------------------------------------------
# Deploy Kubernetes application manifests
# ---------------------------------------------------------
#
# This resource runs after:
#
#   1. Kubernetes control plane is initialized
#   2. kubectl is configured on the control plane
#   3. Calico CNI is installed
#   4. Worker nodes have joined the cluster
#
# Terraform then copies the local k8s/ directory to the
# control-plane VM and applies all Kubernetes manifests.
#
# IMPORTANT:
# The manifests are applied from the control-plane VM.
# Therefore this deployment does NOT depend on the Windows
# kubectl SSH tunnel.
# ---------------------------------------------------------
/*resource "kubernetes_secret" "artifact_registry" {
  metadata {
    name      = "artifact-registry-secret"
    namespace = "default"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = file("${path.module}/dockerconfigjson")
  }
}
*/

resource "terraform_data" "deploy_k8s_manifests" {

  depends_on = [
    terraform_data.worker_join
    #kubernetes_secret.artifact_registry
  ]

  # Re-run this resource automatically whenever the contents
  # of a Kubernetes manifest change.
  triggers_replace = [
    for file in fileset("${path.module}/k8s", "*.yaml") :
    filesha256("${path.module}/k8s/${file}")
  ]

  provisioner "local-exec" {

    interpreter = ["C:\\Program Files\\Git\\bin\\bash.exe", "-c"]

    command = <<-EOT
      set -e

      echo "=============================================="
      echo " Deploying Kubernetes Application"
      echo "=============================================="

      # ---------------------------------------------------
      # STEP 1
      # Wait until every Kubernetes node is Ready.
      # ---------------------------------------------------

      echo ""
      echo "Waiting for all Kubernetes nodes to become Ready..."

      gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --quiet \
        --command="kubectl --kubeconfig=/home/${var.ssh_username}/.kube/config wait --for=condition=Ready nodes --all --timeout=10m"

      echo "All Kubernetes nodes are Ready."

      # ---------------------------------------------------
      # STEP 2
      # Create a directory on the control plane for the
      # Kubernetes manifest files.
      # ---------------------------------------------------

      echo ""
      echo "Creating manifest directory on control plane..."

      gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --quiet \
        --command="rm -rf /home/${var.ssh_username}/k8s-manifests && mkdir -p /home/${var.ssh_username}/k8s-manifests"

      # ---------------------------------------------------
      # STEP 3
      # Copy the local k8s manifest directory to the
      # control-plane VM.
      #
      # --recurse copies all YAML files and subdirectories.
      # ---------------------------------------------------
      #path.module means: "The directory containing the Terraform module where this code is executing."

      echo ""
      echo "Copying Kubernetes manifests..."

      gcloud compute scp \
        --recurse \
        "${path.module}/k8s" \
        "k8s-control-plane:/home/${var.ssh_username}/k8s-manifests" \
        --zone=${var.zone} \
        --quiet

      # ---------------------------------------------------
      # STEP 4
      # Fix ownership of the copied files.
      # ---------------------------------------------------

      gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --quiet \
        --command="sudo chown -R ${var.ssh_username}:${var.ssh_username} /home/${var.ssh_username}/k8s-manifests"

      # ---------------------------------------------------
      # STEP 5
      # Apply all Kubernetes manifests.
      #
      # kubectl apply is idempotent:
      # - New resources are created.
      # - Existing resources are updated.
      # - Unchanged resources remain unchanged.
      # ---------------------------------------------------

      echo ""
      echo "Applying Kubernetes manifests..."

      gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --quiet \
        --command="kubectl --kubeconfig=/home/${var.ssh_username}/.kube/config apply -f /home/${var.ssh_username}/k8s-manifests/k8s"

      # ---------------------------------------------------
      # STEP 6
      # Display the deployed resources.
      # ---------------------------------------------------

      echo ""
      echo "=============================================="
      echo " Kubernetes Application Resources"
      echo "=============================================="

      gcloud compute ssh k8s-control-plane \
        --zone=${var.zone} \
        --quiet \
        --command="kubectl --kubeconfig=/home/${var.ssh_username}/.kube/config get pv,pvc,secrets,svc,deploy,pods -o wide"

      echo ""
      echo "=============================================="
      echo " Kubernetes Application Deployment Completed"
      echo "=============================================="

    EOT
  }
}
