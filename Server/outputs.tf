output "internal_ip" {
  description = "Статический private (internal) IP сервера"
  value       = google_compute_address.internal.address
}

output "external_ip" {
  description = "Публичный (external) IP сервера"
  value       = google_compute_instance.server.network_interface[0].access_config[0].nat_ip
}

output "private_key_path" {
  description = "Путь к локальному файлу приватного SSH-ключа"
  value       = local_sensitive_file.private_key.filename
}

output "private_key_pem" {
  description = "Содержимое приватного ключа (terraform output -raw private_key_pem)"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "ssh_command" {
  description = "Готовая SSH-команда для подключения"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} -o StrictHostKeyChecking=no ${var.ssh_user}@${google_compute_instance.server.network_interface[0].access_config[0].nat_ip}"
}

output "public_key_openssh" {
  description = "Публичный SSH-ключ (OpenSSH-формат): terraform output -raw public_key_openssh"
  value       = tls_private_key.ssh.public_key_openssh
}
