terraform {
  required_providers {
    nutanix = {
      source = "nutanix/nutanix"
    }
  }
}

variable "nutanix_username" {
  description = "Nutanix username"
  type        = string
  default     = "admin"
}

variable "nutanix_password" {
  description = "Nutanix password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "nutanix_endpoint" {
  description = "Nutanix endpoint"
  type        = string
  default     = ""
}

variable "nutanix_port" {
  description = "Nutanix port"
  type        = string
  default     = "9440"
}

variable "ssh_private_key_file" {
  description = "SSH private key file used to access instances"
  default     = "~/.ssh/hpoc"
  type        = string
}

variable "ssh_public_key_file" {
  description = "SSH public key file used to access instances"
  default     = "~/.ssh/hpoc.pub"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet to use"
  type        = string
  default     = "dp-offload-vlan2000"
}

variable "subnet_name2" {
  description = "Name of the subnet to use"
  type        = string
  default     = "User1"
}
variable "image_name" {
  description = "Name of the image to use"
  type        = string
  default     = "ubuntu-24.04"
}

provider "nutanix" {
  username     = var.nutanix_username
  password     = var.nutanix_password
  endpoint     = var.nutanix_endpoint
  port         = var.nutanix_port
  insecure     = true
  wait_timeout = 10
}

# Data sources for real environment
data "nutanix_clusters_v2" "clusters" {}

data "nutanix_subnets_v2" "vm-subnet" {
  filter = "name eq '${var.subnet_name}'"
}

data "nutanix_subnets_v2" "vm-subnet2" {
  filter = "name eq '${var.subnet_name2}'"
}
# Query all subnets to find advanced networking ones
data "nutanix_subnets_v2" "all_subnets" {}

data "nutanix_images_v2" "vm-image" {
  filter = "name eq '${var.image_name}'"
  limit  = 1
}

data "nutanix_nic_profiles_v2" "all_profiles" {}

locals {
  cluster_ext_id = [
    for cluster in data.nutanix_clusters_v2.clusters.cluster_entities :
    cluster.ext_id if cluster.config[0].cluster_function[0] != "PRISM_CENTRAL"
  ][0]
  
  # Filter DP-Offload profiles
  dp_offload_profiles = [
    for profile in data.nutanix_nic_profiles_v2.all_profiles.nic_profiles : {
      name   = profile.name
      ext_id = profile.ext_id
      capabilities = profile.capabilities
    } if length([
      for capability in profile.capabilities :
      capability if capability.capability_type == "DP_OFFLOAD"
    ]) > 0
  ]
  
  dp_offload_profile_id = length(local.dp_offload_profiles) > 0 ? local.dp_offload_profiles[0].ext_id : ""
}

data "nutanix_storage_containers_v2" "sc" {
  filter = "clusterExtId eq '${local.cluster_ext_id}'"
  limit  = 1
}

# Test VM with DP-Offload NIC
resource "nutanix_virtual_machine_v2" "test-dp-offload" {
  count = local.dp_offload_profile_id != "" ? 1 : 0
  
  name        = "test-vm-dp-offload"
  num_sockets = 1
  num_cores_per_socket = 1
  memory_size_bytes = 1073741824  # 1GB
  
  cluster {
    ext_id = local.cluster_ext_id
  }

  disks {
    disk_address {
      bus_type = "SCSI"
      index    = 0
    }
    backing_info {
      vm_disk {
        disk_size_bytes = 30 * pow(1024, 2)
        data_source {
          reference {
            image_reference {
              image_ext_id = data.nutanix_images_v2.vm-image.images[0].ext_id
            }
          }
        }
      }
    }
  }

  nics {
    network_info {
      nic_type = "NORMAL_NIC"
      subnet {
        ext_id = data.nutanix_subnets_v2.vm-subnet2.subnets[0].ext_id
      }
      vlan_mode = "ACCESS"
    }
  }

  # DP-Offload NIC for accelerated networking
  nics {
    backing_info {
      is_connected = true
      
      dp_offload_profile_reference {
        ext_id = local.dp_offload_profile_id
      }
    }
    
    network_info {
      nic_type = "DP_OFFLOAD_NIC"
      
      subnet {
        ext_id = data.nutanix_subnets_v2.vm-subnet.subnets[0].ext_id
      }
    }
  }

}

# Outputs
output "all_subnets" {
  description = "All available subnets with network types"
  value = [
    for subnet in data.nutanix_subnets_v2.all_subnets.subnets : {
      name = subnet.name
      ext_id = subnet.ext_id
      subnet_type = try(subnet.subnet_type, "unknown")
      description = try(subnet.description, "")
      vlan_id = try(subnet.vlan_id, null)
    }
  ]
}

output "dp_offload_profiles_found" {
  description = "Available DP-Offload profiles"
  value       = local.dp_offload_profiles
}

output "selected_dp_offload_profile_id" {
  description = "Selected DP-Offload profile ID"
  value       = local.dp_offload_profile_id
}

output "vm_created" {
  description = "Whether VM was created"
  value       = length(nutanix_virtual_machine_v2.test-dp-offload) > 0
}

output "vm_id" {
  description = "Created VM ID"
  value       = length(nutanix_virtual_machine_v2.test-dp-offload) > 0 ? nutanix_virtual_machine_v2.test-dp-offload[0].ext_id : ""
}
