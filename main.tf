
resource "google_container_cluster" "portfolio" {
  name     = var.cluster_name
  location = var.region

  enable_autopilot = true

  deletion_protection = false
}


# Automatically deploy the Kubernetes manifests after GKE is created.

resource "terraform_data" "deploy_k8s_manifest_files" {
  # Re-run if the cluster is recreated or a manifest changes.
  triggers_replace = concat(
    [google_container_cluster.portfolio.id],
    [
      for file in fileset("${path.module}/Kube-manifest-files", "*.yaml") :
      filesha256("${path.module}/Kube-manifest-files/${file}")
    ]
  )

  # Wait for the GKE cluster to be created.
  depends_on = [
    google_container_cluster.portfolio
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]

    command = <<-EOT
      $ErrorActionPreference = "Stop"

      Write-Host "Configuring access to the GKE cluster..."

      gcloud container clusters get-credentials ${google_container_cluster.portfolio.name} --region ${var.region} --project ${var.project_id}

      if ($LASTEXITCODE -ne 0) {
        throw "Failed to configure GKE credentials."
      }

      Write-Host "Creating namespace..."
      kubectl apply -f "${path.module}/Kube-manifest-files/namespace.yaml"
      if ($LASTEXITCODE -ne 0) { throw "Namespace creation failed." }

      Write-Host "Creating PostgreSQL Secret..."
      kubectl apply -f "${path.module}/Kube-manifest-files/postgres-secret.yaml"
      if ($LASTEXITCODE -ne 0) { throw "PostgreSQL Secret creation failed." }

      Write-Host "Creating PostgreSQL storage..."
      kubectl apply -f "${path.module}/Kube-manifest-files/postgres-pvc.yaml"
      if ($LASTEXITCODE -ne 0) { throw "PVC creation failed." }

      Write-Host "Deploying PostgreSQL..."
      kubectl apply -f "${path.module}/Kube-manifest-files/postgres-deploy.yaml"
      if ($LASTEXITCODE -ne 0) { throw "PostgreSQL deployment failed." }

      Write-Host "Deploying PostgreSQL Service"
      kubectl apply -f "${path.module}/Kube-manifest-files/postgres-service.yaml"
      if ($LASTEXITCODE -ne 0) { throw "PostgreSQL Service failed." }

      kubectl rollout status deployment/postgres -n myprofile --timeout=300s
      if ($LASTEXITCODE -ne 0) { throw "PostgreSQL did not become ready." }

      Write-Host "Creating application Secret..."
      kubectl apply -f "${path.module}/Kube-manifest-files/app-secret.yaml"
      if ($LASTEXITCODE -ne 0) { throw "Application Secret creation failed." }

      Write-Host "Deploying Flask application..."
      kubectl apply -f "${path.module}/Kube-manifest-files/app-deploy.yaml"
      if ($LASTEXITCODE -ne 0) { throw "Application deployment failed." }

      kubectl rollout status deployment/portfolio-app -n myprofile --timeout=300s
      if ($LASTEXITCODE -ne 0) { throw "Flask application did not become ready." }

      Write-Host "Creating Ingress..."
      kubectl apply -f "${path.module}/Kube-manifest-files/app-ingress.yaml"
      if ($LASTEXITCODE -ne 0) { throw "Ingress creation failed." }

      Write-Host "All Kubernetes manifests have been submitted successfully."

      Write-Host "Waiting for GKE to assign the Ingress external IP..."

      $ip = ""

      for ($i = 0; $i -lt 60; $i++) {
        $ip = kubectl get ingress portfolio-ingress `
          -n myprofile `
          -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

        if ($LASTEXITCODE -ne 0) {
          throw "Failed to retrieve the Ingress IP."
        }

        if ($ip) {
          break
        }

        Start-Sleep -Seconds 10
      }

      if (-not $ip) {
        throw "Ingress IP was not assigned within 10 minutes."
      }

      $hostname = "portfolio.$ip.nip.io"
      $url = "http://$hostname"

      Write-Host ""
      Write-Host "=========================================="
      Write-Host "GKE deployment completed!"
      Write-Host "Ingress IP : $ip"
      Write-Host "Hostname   : $hostname"
      Write-Host "Application: $url"
      Write-Host "=========================================="
    EOT
  }
}

