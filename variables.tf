variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "gcp region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "network_name" {
  description = "VPC Network name"
  type        = string
  default     = "k8s-vpc"
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
  default     = "k8s-subnet"
}

variable "machine_type" {
  description = "instance name"
  type        = string
  default     = "e2-small"
}

variable "ssh_username" {
  description = "Linux username used by Google OS Login"
  type        = string
  default     = "lokeshasi2604_gmail_com"
}

variable "kubeconfig_path" {
  description = "Path to the Kubernetes kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}