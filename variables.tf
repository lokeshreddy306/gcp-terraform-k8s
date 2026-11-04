
variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "portfolio-ai-project-495714"
}

variable "region" {
  description = "GKE cluster region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "portfolio-gke"
}
