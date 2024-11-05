variable "name" {
  description = "Name to give to the vm."
  type        = string
}

variable "vcpus" {
  description = "Number of vcpus to assign to the vm"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Amount of memory in MiB"
  type        = number
  default     = 8192
}

variable "volume_id" {
  description = "Id of the disk volume to attach to the vm"
  type        = string
}

variable "network_id" {
  description = "Id of the libvirt network to connect the vm to if you plan on connecting the vm to a libvirt network"
  type        = string
  default     = ""
}

variable "ip" {
  description = "Ip address of the vm if a libvirt network is selected"
  type        = string
  default     = ""
}

variable "mac" {
  description = "Mac address of the vm if a libvirt network is selected"
  type        = string
  default     = ""
}

variable "macvtap_interfaces" {
  description = "List of macvtap interfaces. Mutually exclusive with the network_id, ip and mac fields. Each entry has the following keys: interface, prefix_length, ip, mac, gateway and dns_servers"
  type = list(object({
    interface     = string,
    prefix_length = number,
    ip            = string,
    mac           = string,
    gateway       = string,
    dns_servers   = list(string),
  }))
  default = []
}

variable "cloud_init_volume_pool" {
  description = "Name of the volume pool that will contain the cloud init volume"
  type        = string
}

variable "cloud_init_volume_name" {
  description = "Name of the cloud init volume"
  type        = string
  default     = ""
}

variable "ssh_admin_user" {
  description = "Pre-existing ssh admin user of the image"
  type        = string
  default     = "ubuntu"
}

variable "admin_user_password" {
  description = "Optional password for admin user"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_admin_public_key" {
  description = "Public ssh part of the ssh key the admin will be able to login as"
  type        = string
}

variable "nameserver_ips" {
  description = "Ips of the nameservers"
  type        = list(string)
  default     = []
}

variable "zeppelin_version" {
  description = "Version of zeppelin"
  type        = string
  default     = "0.10.0"
}

variable "zeppelin_mirror" {
  description = "Mirror from which to download zeppelin"
  type        = string
  default     = "https://dlcdn.apache.org"
}

variable "k8_executor_image" {
  description = "Image to launch k8 executor from"
  type        = string
  default     = "chusj/spark:7508c20ef44952f1ee2af91a26822b6efc10998f"
}

variable "k8_api_endpoint" {
  description = "Endpoint to access the k8 masters"
  type        = string
}

variable "k8_ca_certificate" {
  description = "CA certicate of kubernetes api"
  type        = string
}

variable "k8_client_certificate" {
  description = "Client certicate to access kubernetes api"
  type        = string
}

variable "k8_client_private_key" {
  description = "Client private key to access kubernetes api"
  type        = string
}

variable "s3_access" {
  description = "S3 access key"
  type        = string
}

variable "s3_secret" {
  description = "S3 secret key"
  type        = string
}

variable "s3_url" {
  description = "url of the S3 store"
  type        = string
}

variable "hive_metastore_port" {
  description = "Port of the hive metastore on the kubernetes cluster"
  type        = number
  default     = null
}

variable "hive_metastore_url" {
  description = "Url of the hive metastore"
  type        = string
  default     = ""
}

variable "spark_sql_warehouse_dir" {
  description = "S3 path of the spark sql warehouse"
  type        = string
}

variable "notebook_s3_bucket" {
  description = "S3 bucket to store notebooks under"
  type        = string
}

variable "additional_certificates" {
  description = "Additional list of certificates to install on the system. Useful if your keycloak or s3 store having certificates signed by an internal CA for example."
  type        = list(string)
  default     = []
}

variable "keycloak" {
  description = "Keycloak configuration for user authentication"
  type = object({
    enabled       = bool
    url           = string
    realm         = string
    client_id     = string
    client_secret = string
    zeppelin_url  = string
    max_clock_skew = number
  })
  default = {
    enabled       = false
    url           = ""
    realm         = ""
    client_id     = ""
    client_secret = ""
    zeppelin_url  = ""
    max_clock_skew = 0
  }
}

variable "chrony" {
  description = "Chrony configuration for ntp. If enabled, chrony is installed and configured, else the default image ntp settings are kept"
  type = object({
    enabled = bool,
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server
    servers = list(object({
      url     = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool
    pools = list(object({
      url     = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep
    makestep = object({
      threshold = number,
      limit     = number
    })
  })
  default = {
    enabled = false
    servers = []
    pools   = []
    makestep = {
      threshold = 0,
      limit     = 0
    }
  }
}