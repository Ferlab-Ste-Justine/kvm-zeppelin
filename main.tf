locals {
  cloud_init_volume_name = var.cloud_init_volume_name == "" ? "${var.name}-cloud-init.iso" : var.cloud_init_volume_name
  network_config = templatefile(
    "${path.module}/files/network_config.yaml.tpl",
    {
      macvtap_interfaces = var.macvtap_interfaces
    }
  )
  network_interfaces = length(var.macvtap_interfaces) == 0 ? [{
    network_id = var.network_id
    macvtap    = null
    addresses  = [var.ip]
    mac        = var.mac != "" ? var.mac : null
    hostname   = var.name
    }] : [for macvtap_interface in var.macvtap_interfaces : {
    network_id = null
    macvtap    = macvtap_interface.interface
    addresses  = null
    mac        = macvtap_interface.mac
    hostname   = null
  }]
}

data "template_cloudinit_config" "user_data" {
  gzip          = false
  base64_encode = false
  part {
    content_type = "text/cloud-config"
    content = templatefile(
      "${path.module}/files/user_data.yaml.tpl",
      {
        node_name               = var.name
        ssh_admin_public_key    = var.ssh_admin_public_key
        ssh_admin_user          = var.ssh_admin_user
        admin_user_password     = var.admin_user_password
        nameserver_ips          = var.nameserver_ips
        s3_access               = var.s3_access
        s3_secret               = var.s3_secret
        s3_url                  = var.s3_url
        notebook_s3_bucket      = var.notebook_s3_bucket
        hive_metastore_port     = var.hive_metastore_port
        hive_metastore_url      = var.hive_metastore_url
        spark_sql_warehouse_dir = var.spark_sql_warehouse_dir
        zeppelin_version        = var.zeppelin_version
        zeppelin_mirror         = var.zeppelin_mirror
        k8_api_endpoint         = var.k8_api_endpoint
        k8_client_certificate   = var.k8_client_certificate
        k8_client_private_key   = var.k8_client_private_key
        k8_ca_certificate       = var.k8_ca_certificate
        k8_executor_image       = var.k8_executor_image
        keycloak_discovery_url  = var.keycloak_discovery_url
        keycloak_client_id      = var.keycloak_client_id
        keycloak_client_secret  = var.keycloak_client_secret
        keycloak_max_clock_skew = var.keycloak_max_clock_skew
        zeppelin_url            = var.zeppelin_url
        additional_certificates = var.additional_certificates
        chrony                  = var.chrony
      }
    )
  }
}

resource "libvirt_cloudinit_disk" "zeppelin" {
  name           = local.cloud_init_volume_name
  user_data      = data.template_cloudinit_config.user_data.rendered
  network_config = length(var.macvtap_interfaces) > 0 ? local.network_config : null
  pool           = var.cloud_init_volume_pool
}

resource "libvirt_domain" "zeppelin" {
  name = var.name

  cpu {
    mode = "host-passthrough"
  }

  vcpu   = var.vcpus
  memory = var.memory

  disk {
    volume_id = var.volume_id
  }

  dynamic "network_interface" {
    for_each = local.network_interfaces
    content {
      network_id = network_interface.value["network_id"]
      macvtap    = network_interface.value["macvtap"]
      addresses  = network_interface.value["addresses"]
      mac        = network_interface.value["mac"]
      hostname   = network_interface.value["hostname"]
    }
  }

  autostart = true

  cloudinit = libvirt_cloudinit_disk.zeppelin.id

  //https://github.com/dmacvicar/terraform-provider-libvirt/blob/main/examples/v0.13/ubuntu/ubuntu-example.tf#L61
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }
}