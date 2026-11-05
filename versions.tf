
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "helm" {
  kubernetes = {
    config_path = pathexpand("~/.kube/config")
  }

}