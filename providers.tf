terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source = "hashicorp/random"
    }
    lxd = {
      source = "terraform-lxd/lxd"
    }

  }
  required_version = ">= 0.13"
}

# Providers
provider "cloudflare" {
  api_token    = var.cloudflare_token
}
provider "random" {
}
provider "lxd" {
}
