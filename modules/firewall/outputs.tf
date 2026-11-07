output "rule_names" {
  value = [for r in google_compute_firewall.rule : r.name]
}
