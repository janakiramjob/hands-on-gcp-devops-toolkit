terraform {
  required_version = ">= 1.5"

  backend "gcs" {
    bucket = "gcp-s3-bknd-bucket-7568"
    prefix = "terraform/state/kubeadm-cluster"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
