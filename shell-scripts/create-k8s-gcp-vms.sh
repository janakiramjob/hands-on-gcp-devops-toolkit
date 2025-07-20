#!/bin/bash

# CONFIGURATION
ZONE="us-central1-a"
PROJECT_ID="$(gcloud config get-value project)"
NETWORK="default"
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"
BOOT_DISK_SIZE="30GB"
SSH_USER="root"
SSH_KEY_PATH="$HOME/.ssh/google_compute_engine.pub"
SSH_KEY_CONTENT=$(cat "$SSH_KEY_PATH")

# Common metadata (startup script + SSH key)
STARTUP_SCRIPT='#!/bin/bash
apt-get update && apt-get install -y apt-transport-https ca-certificates curl'
METADATA="startup-script=$STARTUP_SCRIPT,ssh-keys=$SSH_USER:$SSH_KEY_CONTENT"

# Create 2 master nodes with 4 vCPUs each
for i in 1 2; do
  gcloud compute instances create "k8s-master-$i" \
    --zone="$ZONE" \
    --machine-type="e2-standard-4" \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --boot-disk-size="$BOOT_DISK_SIZE" \
    --tags="k8s-cluster" \
    --metadata="$METADATA"
done

# Create 1 worker node with 8 vCPUs
gcloud compute instances create "k8s-worker-1" \
  --zone="$ZONE" \
  --machine-type="e2-standard-8" \
  --image-family="$IMAGE_FAMILY" \
  --image-project="$IMAGE_PROJECT" \
  --boot-disk-size="$BOOT_DISK_SIZE" \
  --tags="k8s-cluster" \
  --metadata="$METADATA"

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
