#Here we will create a VM with SR-IOV NIC capabilities
#This example demonstrates the enhanced SR-IOV support in the Nutanix provider
#using the VMM API v4.1 with polymorphic NIC handling and NIC profiles.
#The variable values are present in terraform.tfvars file.
#Note - Replace appropriate values of variables in terraform.tfvars file as per setup

terraform {
  required_providers {
    nutanix = {
      source = "nutanix/nutanix"
      version = "~> 2.0"
    }
  }
}

#defining nutanix configuration
provider "nutanix" {
  username = var.nutanix_username
  password = var.nutanix_password
  endpoint = var.nutanix_endpoint
  port     = var.nutanix_port
  insecure = true
}

data "nutanix_clusters_v2" "clusters" {}

locals {
  cluster_ext_id = [
    for cluster in data.nutanix_clusters_v2.clusters.cluster_entities :
    cluster.ext_id if cluster.config[0].cluster_function[0] != "PRISM_CENTRAL"
  ][0]
}


# pull storage container data
data "nutanix_storage_containers_v2" "sc" {
  filter = "clusterExtId eq '${local.cluster_ext_id}'"
  limit  = 1
}

# pull subnet data
data "nutanix_subnets_v2" "vm-subnet" {
  filter = "name eq '${var.subnet_name}'"
}

# pull image data
data "nutanix_images_v2" "vm-image" {
  filter = "name eq '${var.image_name}'"
  limit  = 1
}

# pull NIC profiles data for SR-IOV
data "nutanix_nic_profiles_v2" "sriov_profiles" {}

locals {
  sriov_profiles = [
    for profile in data.nutanix_nic_profiles_v2.sriov_profiles.nic_profiles : profile
    if length(profile.capabilities) > 0 && profile.capabilities[0].capability_type == "SRIOV"
  ]
  # Use the first available SR-IOV profile, or fallback to hardcoded value
  # Select the appropriate SR-IOV profile (use index 1 for sr-iov-cx-6-dx-default)
  sriov_profile_id = length(local.sriov_profiles) > 0 ? local.sriov_profiles[1].ext_id : "fbaa79db-1237-411f-a96f-9b95778e65d0"
}

#pull all categories data
data "nutanix_categories_v2" "categories-list" {}


# Create virtual machine with SR-IOV NIC
resource "nutanix_virtual_machine_v2" "example-4" {
  name                 = "example-vm-sriov"
  num_cores_per_socket = 1
  num_sockets          = 1
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
        disk_size_bytes = "1073741824"
        storage_container {
          ext_id = data.nutanix_storage_containers_v2.sc.storage_containers[0].ext_id
        }
      }
    }
  }
  nics {
    network_info {
      nic_type = "DIRECT_NIC"
      vlan_id = 2000  # VLAN ID for SR-IOV NIC
      subnet {
        ext_id = data.nutanix_subnets_v2.vm-subnet.subnets[0].ext_id
      }
      ipv4_config {
        should_assign_ip = false
      }
    }
    backing_info {
      is_connected = true
      nic_profile_reference {  # SR-IOV profile reference
        ext_id = local.sriov_profile_id
      }
    }
  }
  power_state = "OFF"
}


# list all virtual machines
data "nutanix_virtual_machines_v2" "vms" {}


# get vm by id - COMMENTED OUT SINCE VM CREATION IS DISABLED
/*
data "nutanix_virtual_machine_v2" "vm" {
  ext_id = nutanix_virtual_machine_v2.example-4.id
}
*/

# find existing VM with SR-IOV configuration by name
data "nutanix_virtual_machines_v2" "sriov_vm_search" {
  filter = "name eq 'sriov-test'"
  limit  = 1
}

# get detailed SR-IOV VM info using ext_id from search
data "nutanix_virtual_machine_v2" "sriov_vm" {
  ext_id = length(data.nutanix_virtual_machines_v2.sriov_vm_search.vms) > 0 ? data.nutanix_virtual_machines_v2.sriov_vm_search.vms[0].ext_id : null
}

# Output to demonstrate SR-IOV detection - COMMENTED OUT SINCE VM CREATION IS DISABLED
/*
output "created_vm_nics" {
  description = "NIC information for the created VM with enhanced SR-IOV detection"
  value = [
    for nic in data.nutanix_virtual_machine_v2.vm.nics : {
      ext_id          = nic.ext_id
      nic_type        = try(nic.network_info[0].nic_type, "unknown")
      model           = try(nic.backing_info[0].model, "unknown")
      mac_address     = try(nic.backing_info[0].mac_address, "unknown")
      is_connected    = try(nic.backing_info[0].is_connected, false)
      num_queues      = try(nic.backing_info[0].num_queues, 0)
      sriov_enabled   = try(nic.backing_info[0].sriov_enabled, false)
      is_pass_through = try(nic.backing_info[0].is_pass_through, false)
      physical_address = try(nic.backing_info[0].physical_address, [])
      nic_profile_ext_id = try(nic.backing_info[0].nic_profile_reference[0].ext_id, "")
      vlan_mode       = try(nic.network_info[0].vlan_mode, "unknown")
      trunked_vlans   = try(nic.network_info[0].trunked_vlans, [])
    }
  ]
}
*/

# Output to demonstrate SR-IOV detection on existing SR-IOV VM
output "sriov_vm_nics" {
  description = "NIC information for existing SR-IOV VM demonstrating enhanced detection"
  value = length(data.nutanix_virtual_machines_v2.sriov_vm_search.vms) > 0 ? [
    for nic in data.nutanix_virtual_machine_v2.sriov_vm.nics : {
      ext_id          = nic.ext_id
      nic_type        = try(nic.network_info[0].nic_type, "unknown")
      model           = try(nic.backing_info[0].model, "unknown")
      mac_address     = try(nic.backing_info[0].mac_address, "unknown")
      is_connected    = try(nic.backing_info[0].is_connected, false)
      num_queues      = try(nic.backing_info[0].num_queues, 0)
      sriov_enabled   = try(nic.backing_info[0].sriov_enabled, false)
      is_pass_through = try(nic.backing_info[0].is_pass_through, false)
      physical_address = try(nic.backing_info[0].physical_address, [])
      nic_profile_ext_id = try(nic.backing_info[0].nic_profile_reference[0].ext_id, "")
      vlan_mode       = try(nic.network_info[0].vlan_mode, "unknown")
      trunked_vlans   = try(nic.network_info[0].trunked_vlans, [])
    }
  ] : []
}

# Compare SR-IOV capabilities between VMs - COMMENTED OUT SINCE VM CREATION IS DISABLED
/*
output "sriov_comparison" {
  description = "Comparison of SR-IOV capabilities between created VM and existing SR-IOV VM"
  value = {
    created_vm_has_sriov = length([
      for nic in data.nutanix_virtual_machine_v2.vm.nics : nic
      if try(nic.backing_info[0].sriov_enabled, false) == true
    ]) > 0
    
    sriov_vm_found = length(data.nutanix_virtual_machines_v2.sriov_vm_search.vms) > 0
    
    sriov_vm_has_sriov = length(data.nutanix_virtual_machines_v2.sriov_vm_search.vms) > 0 ? length([
      for nic in data.nutanix_virtual_machine_v2.sriov_vm.nics : nic
      if try(nic.backing_info[0].sriov_enabled, false) == true
    ]) > 0 : false
    
    total_sriov_nics_found = length([
      for nic in data.nutanix_virtual_machine_v2.vm.nics : nic
      if try(nic.backing_info[0].sriov_enabled, false) == true
    ]) + (length(data.nutanix_virtual_machines_v2.sriov_vm_search.vms) > 0 ? length([
      for nic in data.nutanix_virtual_machine_v2.sriov_vm.nics : nic
      if try(nic.backing_info[0].sriov_enabled, false) == true
    ]) : 0)
  }
}
*/

# Demonstrate filtering - count SR-IOV NICs across analyzed VMs - COMMENTED OUT SINCE VM CREATION IS DISABLED
/*
output "sriov_nics_count" {
  description = "Total count of SR-IOV enabled NICs across all analyzed VMs"
  value = length([
    for nic in data.nutanix_virtual_machine_v2.vm.nics : nic
    if try(nic.backing_info[0].sriov_enabled, false) == true
  ]) + (length(data.nutanix_virtual_machines_v2.sriov_vm_search.vms) > 0 ? length([
    for nic in data.nutanix_virtual_machine_v2.sriov_vm.nics : nic
    if try(nic.backing_info[0].sriov_enabled, false) == true
  ]) : 0)
}

output "created_vm_nics" {
  description = "NICs of the created VM to validate SR-IOV configuration"
  value = data.nutanix_virtual_machine_v2.vm.nics
}

output "sriov_comparison" {
  description = "Compare SR-IOV settings between existing and created VMs"
  value = {
    sriov_vm_found = length(data.nutanix_virtual_machines_v2.sriov_vm_search.vms) > 0
    sriov_vm_has_sriov = length(data.nutanix_virtual_machines_v2.sriov_vm_search.vms) > 0 ? length([
      for nic in data.nutanix_virtual_machine_v2.sriov_vm.nics : nic
      if try(nic.backing_info[0].sriov_enabled, false) == true
    ]) > 0 : false
    created_vm_has_sriov = length([
      for nic in data.nutanix_virtual_machine_v2.vm.nics : nic
      if try(nic.backing_info[0].sriov_enabled, false) == true
    ]) > 0
    total_sriov_nics_found = (length(data.nutanix_virtual_machines_v2.sriov_vm_search.vms) > 0 ? length([
      for nic in data.nutanix_virtual_machine_v2.sriov_vm.nics : nic
      if try(nic.backing_info[0].sriov_enabled, false) == true
    ]) : 0)
  }
}
*/

# Show all VMs with enhanced NIC detection and SR-IOV summary
output "all_vms_nic_summary" {
  description = "Summary of NIC types across all VMs with SR-IOV analysis"
  value = {
    total_vms = length(data.nutanix_virtual_machines_v2.vms.vms)
    vms_with_nics = length([
      for vm in data.nutanix_virtual_machines_v2.vms.vms : vm
      if length(try(vm.nics, [])) > 0
    ])
    total_nics_across_all_vms = sum([
      for vm in data.nutanix_virtual_machines_v2.vms.vms : length(try(vm.nics, []))
    ])
    
    # Enhanced SR-IOV analysis across all VMs
    vms_with_sriov_nics = length([
      for vm in data.nutanix_virtual_machines_v2.vms.vms : vm
      if length([
        for nic in try(vm.nics, []) : nic
        if try(nic.backing_info[0].sriov_enabled, false) == true
      ]) > 0
    ])
    
    total_sriov_nics_in_cluster = sum([
      for vm in data.nutanix_virtual_machines_v2.vms.vms : length([
        for nic in try(vm.nics, []) : nic
        if try(nic.backing_info[0].sriov_enabled, false) == true
      ])
    ])
    
    total_direct_nics_in_cluster = sum([
      for vm in data.nutanix_virtual_machines_v2.vms.vms : length([
        for nic in try(vm.nics, []) : nic
        if try(nic.network_info[0].nic_type, "") == "DIRECT_NIC"
      ])
    ])
  }
}

# Output NIC profiles information for SR-IOV reference
output "all_nic_profiles" {
  description = "All available NIC profiles discovered via networking v4.1 API"
  value = data.nutanix_nic_profiles_v2.sriov_profiles.nic_profiles
}

output "sriov_nic_profiles" {
  description = "Only SR-IOV enabled NIC profiles"
  value = local.sriov_profiles
}

output "selected_sriov_profile_id" {
  description = "The SR-IOV profile ID used for VM creation"
  value = local.sriov_profile_id
}
