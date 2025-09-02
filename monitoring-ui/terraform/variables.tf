variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for the monitoring service"
  type        = string
  default     = "monitoring.your-domain.com"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}
