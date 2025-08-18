terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.0"
    }
  }
  required_version = ">= 1.0"
}

provider "hcloud" {
  token = var.hcloud_token
}

# Create Kubernetes cluster
resource "hcloud_network" "thesauros_network" {
  name     = "thesauros-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "thesauros_subnet" {
  network_id   = hcloud_network.thesauros_network.id
  name         = "thesauros-subnet"
  ip_range     = "10.0.1.0/24"
  network_zone = "eu-central"
}

resource "hcloud_kubernetes_cluster" "thesauros_cluster" {
  name       = "thesauros-cluster"
  network_id = hcloud_network.thesauros_network.id
  
  location = "fsn1"
  
  default_node_pool {
    name       = "default"
    node_type  = "cx21"
    location   = "fsn1"
    min_nodes  = 2
    max_nodes  = 4
  }
}

# Create load balancer
resource "hcloud_load_balancer" "thesauros_lb" {
  name               = "thesauros-load-balancer"
  load_balancer_type = "lb11"
  location           = "fsn1"
  
  algorithm {
    type = "round_robin"
  }
}

resource "hcloud_load_balancer_target" "thesauros_lb_target" {
  type             = "label_selector"
  load_balancer_id = hcloud_load_balancer.thesauros_lb.id
  label_selector   = "app=thesauros-monitoring"
  use_private_ip   = true
}

resource "hcloud_load_balancer_service" "thesauros_lb_service" {
  load_balancer_id = hcloud_load_balancer.thesauros_lb.id
  protocol         = "http"
  listen_port      = 80
  destination_port = 3001
  
  health_check {
    protocol = "http"
    port     = 3001
    interval = 10
    timeout  = 5
    retries  = 3
    http {
      path = "/api/health"
    }
  }
}

# Create firewall
resource "hcloud_firewall" "thesauros_firewall" {
  name = "thesauros-firewall"
  
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

# Outputs
output "kubeconfig" {
  value     = hcloud_kubernetes_cluster.thesauros_cluster.kube_config
  sensitive = true
}

output "load_balancer_ip" {
  value = hcloud_load_balancer.thesauros_lb.ipv4
}
