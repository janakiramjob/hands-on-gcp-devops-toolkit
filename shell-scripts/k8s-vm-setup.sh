#!/bin/bash

# CONFIGURATION
ZONE="us-central1-a"
PROJECT_ID="$(gcloud config get-value project)"
NETWORK="default"
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"
BOOT_DISK_SIZE="50GB"

# Create 1 master node with 4 vCPUs
gcloud compute instances create "k8s-master-1" \
  --zone="$ZONE" \
  --machine-type="e2-standard-4" \
  --image-family="$IMAGE_FAMILY" \
  --image-project="$IMAGE_PROJECT" \
  --boot-disk-size="$BOOT_DISK_SIZE" \
  --tags="k8s-cluster"

# Create 1 worker node with 8 vCPUs
gcloud compute instances create "k8s-worker-1" \
  --zone="$ZONE" \
  --machine-type="e2-standard-4" \
  --image-family="$IMAGE_FAMILY" \
  --image-project="$IMAGE_PROJECT" \
  --boot-disk-size="$BOOT_DISK_SIZE" \
  --tags="k8s-cluster"

# Create a firewall rule only if it doesn't exist
if ! gcloud compute firewall-rules describe allow-k8s-ports --quiet >/dev/null 2>&1; then
  gcloud compute firewall-rules create allow-k8s-ports \
    --allow tcp:6443,tcp:2379-2380,tcp:10250,tcp:10251,tcp:10252,tcp:30000-32767 \
    --target-tags="k8s-cluster" \
    --description="Allow Kubernetes required ports" \
    --network="$NETWORK"
else
  echo "Firewall rule 'allow-k8s-ports' already exists. Skipping creation."
fi