terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.6.14, <= 0.7.1"
    }
    template = {
      source  = "hashicorp/template"
      version = "= 2.2.0"
    }
  }
  required_version = ">= 1.0.0"
}