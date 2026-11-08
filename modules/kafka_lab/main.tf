# Installs the Kafka + KEDA + observability lab on the kubeadm cluster:
# metrics-server, Strimzi + Kafka (KRaft), topics, kube-prometheus-stack, KEDA,
# Artifact Registry pull-secret refresher, demo producer/consumer + ScaledObject.
locals {
  app_dir    = abspath("${path.module}/../../apps/kafka-demo")
  files_dir  = abspath("${path.module}/files")
  registry   = "${var.region}-docker.pkg.dev"
  app_hash   = substr(sha256(join("", [for f in sort(fileset(local.app_dir, "*")) : filesha256("${local.app_dir}/${f}")])), 0, 12)
  files_hash = sha256(join("", [for f in sort(fileset(local.files_dir, "**")) : filesha256("${local.files_dir}/${f}")]))
  app_image  = "${local.registry}/${var.project_id}/${var.registry_repository}/kafka-demo-app:${local.app_hash}"
}

resource "terraform_data" "lab" {
  triggers_replace = {
    bootstrap_id = var.bootstrap_id
    files        = local.files_hash
    app_image    = local.app_image
    install      = filesha256("${path.module}/install.sh")
    versions     = join(",", [var.strimzi_version, var.keda_version, var.kube_prometheus_stack_version, var.metrics_server_version])
    volumes      = join(",", [var.kafka_volume_size, var.prometheus_volume_size, var.grafana_volume_size])
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "bash '${path.module}/install.sh'"

    environment = {
      PROJECT_ID             = var.project_id
      ZONE                   = var.zone
      CONTROL_PLANE          = var.control_plane
      APP_IMAGE              = local.app_image
      REGISTRY_HOST          = local.registry
      APP_DIR                = local.app_dir
      FILES_DIR              = local.files_dir
      BUILD_IMAGE            = tostring(var.build_app_image)
      STRIMZI_VERSION        = var.strimzi_version
      KEDA_VERSION           = var.keda_version
      KPS_VERSION            = var.kube_prometheus_stack_version
      METRICS_SERVER_VERSION = var.metrics_server_version
      KAFKA_VOLUME_SIZE      = var.kafka_volume_size
      PROMETHEUS_VOLUME_SIZE = var.prometheus_volume_size
      GRAFANA_VOLUME_SIZE    = var.grafana_volume_size
    }
  }
}
