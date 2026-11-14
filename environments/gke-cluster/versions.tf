terraform {
  required_version = ">= 1.5"

  # Same bucket as the kubeadm cluster, separate prefix so the two states never collide
  backend "gcs" {
    bucket = "gcp-s3-bknd-bucket-7568"
    prefix = "terraform/state/gke-cluster"
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
