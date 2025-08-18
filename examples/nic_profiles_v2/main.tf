terraform {
  required_providers {
    nutanix = {
      source  = "nutanix/nutanix"
      version = "2.0.0"
    }
  }
}

provider "nutanix" {
  username = var.nutanix_username
  password = var.nutanix_password
  endpoint = var.nutanix_endpoint
  insecure = true
  port     = "9440"
}

# Data source to fetch all NIC profiles
data "nutanix_nic_profiles_v2" "all_profiles" {}

# Output all NIC profiles
output "nic_profiles" {
  value = data.nutanix_nic_profiles_v2.all_profiles.nic_profiles
}

# Output SR-IOV enabled profiles only
output "sriov_profiles" {
  value = [
    for profile in data.nutanix_nic_profiles_v2.all_profiles.nic_profiles : profile
    if length(profile.capabilities) > 0 && profile.capabilities[0].capability_type == "SRIOV"
  ]
}

