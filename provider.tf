terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "google" {
  region  = var.region
  zone    = var.zone
  project = var.project_id
}
provider "kubernetes" {
  config_path = var.kubeconfig_path
}