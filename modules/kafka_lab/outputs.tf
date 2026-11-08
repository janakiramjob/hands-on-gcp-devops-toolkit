output "app_image" {
  value = local.app_image
}

output "lab_id" {
  value = terraform_data.lab.id
}
