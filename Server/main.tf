provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ---------------------------------------------------------------------------
# SSH-ключ: генерируем пару RSA 4096
# ВНИМАНИЕ: приватный ключ попадёт в Terraform state (бакет gorcupvibecoding).
# Это особенность генерации ключей через tls-provider.
# ---------------------------------------------------------------------------
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Пишем приватный ключ локально в .pem с правами 0600.
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/vibecode-server-key.pem"
  file_permission = "0600"
}

# ---------------------------------------------------------------------------
# Сеть: своя VPC + подсеть, чтобы контролировать статический internal IP
# ---------------------------------------------------------------------------
resource "google_compute_network" "vpc" {
  name                    = "${var.instance_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.instance_name}-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Статический PRIVATE (internal) IP в подсети.
resource "google_compute_address" "internal" {
  name         = "${var.instance_name}-internal-ip"
  subnetwork   = google_compute_subnetwork.subnet.id
  address_type = "INTERNAL"
  region       = var.region
}

# Статический EXTERNAL IP — чтобы внешний адрес НЕ менялся при stop/start VM.
resource "google_compute_address" "external" {
  name         = "${var.instance_name}-external-ip"
  address_type = "EXTERNAL"
  region       = var.region
}

# ---------------------------------------------------------------------------
# Firewall: ОТКРЫТЫ ВСЕ ПОРТЫ (tcp/udp/icmp) со всех адресов.
# ВНИМАНИЕ: небезопасно для production.
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "allow_all" {
  name    = "${var.instance_name}-allow-all"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# VM
# ---------------------------------------------------------------------------
resource "google_compute_instance" "server" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    network_ip = google_compute_address.internal.address # статический private IP

    # Внешний IP, чтобы SSH работал из интернета.
    # Зарезервированный статический external IP (не меняется при stop/start).
    access_config {
      nat_ip = google_compute_address.external.address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${tls_private_key.ssh.public_key_openssh}"
  }

  # Чтобы фаервол применился к этому инстансу через сеть (правило без target_tags
  # действует на всю сеть, так что теги тут не обязательны).
}
