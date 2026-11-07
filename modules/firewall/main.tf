resource "google_compute_firewall" "rule" {
  for_each = var.rules

  name        = "${var.name_prefix}-${each.key}"
  network     = var.network_name
  description = each.value.description
  direction   = "INGRESS"
  priority    = each.value.priority

  source_ranges = each.value.source_ranges
  target_tags   = each.value.target_tags

  dynamic "allow" {
    for_each = each.value.allow
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }
}
