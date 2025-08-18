# SR-IOV NIC Support Implementation

## Summary

This PR implements comprehensive SR-IOV (Single Root I/O Virtualization) NIC support for the Nutanix Terraform Provider v2.0, based on the VMM API v4.1 specification.

## Features Added

### 1. NIC Profiles Data Source (`nutanix_nic_profiles_v2`)
- **File**: `nutanix/services/networkingv2/data_source_nutanix_nic_profiles_v2.go`
- **API**: Networking v4.1 API
- **Purpose**: Retrieve available NIC profiles with SR-IOV and DP offload capabilities
- **Schema**: Returns profile details including ext_id, name, capabilities, and tenant information

### 2. Enhanced VM Resource (`nutanix_virtual_machine_v2`)
- **File**: `nutanix/services/vmmv2/resource_nutanix_virtual_machine_v2.go`
- **API**: VMM API v4.1 with polymorphic NIC support
- **Enhancements**:
  - Added `vlan_id` field for SR-IOV NICs
  - Added `nic_profile_reference` block for profile association
  - Polymorphic NIC backing info support (SriovNic/VirtualEthernetNic)
  - Polymorphic network info support (SriovNicNetworkInfo/VirtualEthernetNicNetworkInfo)

### 3. Enhanced VM Data Source
- **Improved SR-IOV detection**: More accurate identification of SR-IOV NICs
- **Profile extraction**: Extract NIC profile information from existing VMs
- **Enhanced NIC analysis**: Better handling of different NIC types

## Technical Implementation

### Polymorphic NIC Handling
The implementation uses OneOf polymorphic types to handle different NIC configurations:

```go
// SR-IOV NICs use SriovNic backing info
type SriovNic struct {
    SriovProfileReference *NicProfileReference
    IsConnected          *bool
    MacAddress           *string
}

// Regular NICs use VirtualEthernetNic backing info  
type VirtualEthernetNic struct {
    Model        *VirtualEthernetNicModel
    IsConnected  *bool
    MacAddress   *string
    NumQueues    *int
}
```

### Network Configuration
SR-IOV NICs support VLAN configuration through specialized network info:

```go
// SR-IOV network info with VLAN support
type SriovNicNetworkInfo struct {
    VlanId *int
}

// Regular network info
type VirtualEthernetNicNetworkInfo struct {
    Subnet      *SubnetReference
    Ipv4Config  *Ipv4Config
    // ... other standard fields
}
```

### API Integration
- **Networking API v4.1**: For NIC profiles discovery
- **VMM API v4.1**: For VM operations with proper polymorphic type handling
- **OneOf Constructors**: Uses proper constructor functions to ensure ObjectType_ initialization

## Files Changed

### Core Implementation
- `nutanix/services/vmmv2/resource_nutanix_virtual_machine_v2.go` - Enhanced VM resource
- `nutanix/services/networkingv2/data_source_nutanix_nic_profiles_v2.go` - New NIC profiles data source
- `nutanix/provider/provider.go` - Registered new data source

### Examples and Documentation
- `examples/virtual_machine_v2_with_sriov/` - Complete SR-IOV example
- `examples/virtual_machine_v2_with_sriov/README.md` - Comprehensive documentation

## Schema Changes

### VM Resource Enhancements
```hcl
resource "nutanix_virtual_machine_v2" "sriov_vm" {
  nics {
    network_info {
      nic_type = "DIRECT_NIC"
      vlan_id  = 2000  # New: VLAN ID for SR-IOV
    }
    backing_info {
      nic_profile_reference {  # New: SR-IOV profile reference
        ext_id = var.sriov_profile_id
      }
    }
  }
}
```

### New Data Source
```hcl
data "nutanix_nic_profiles_v2" "profiles" {}

output "sriov_profiles" {
  value = [for profile in data.nutanix_nic_profiles_v2.profiles.nic_profiles : 
           profile if contains([for cap in profile.capabilities : cap.capability_type], "SRIOV")]
}
```

## Testing

### Manual Testing Completed
- ✅ NIC profiles data source retrieval
- ✅ SR-IOV profile detection and filtering  
- ✅ VM creation with SR-IOV NICs
- ✅ VLAN configuration (vlan_id = 2000)
- ✅ Profile association and validation
- ✅ Existing VM SR-IOV detection improvement

### Example Output
```
Successfully created VM with SR-IOV NIC:
- VM ID: 17ca5111-2571-41c5-7167-5fca2e816300
- Profile: sr-iov-cx-6-dx-default (fbaa79db-1237-411f-a96f-9b95778e65d0)
- VLAN ID: 2000
- NIC Type: DIRECT_NIC
```

## Backward Compatibility

- ✅ No breaking changes to existing resources
- ✅ Existing VM configurations continue to work
- ✅ Enhanced detection improves accuracy without changing behavior
- ✅ New fields are optional and don't affect existing deployments

## API Compliance

- ✅ Follows VMM API v4.1 specification
- ✅ Uses proper polymorphic OneOf types
- ✅ Implements correct ObjectType_ initialization
- ✅ Networking API v4.1 for profile discovery

## Requirements

- Nutanix cluster with SR-IOV capable hardware
- SR-IOV profiles configured in Prism Central  
- Available SR-IOV profiles with associated host NICs

This implementation provides comprehensive SR-IOV support while maintaining full backward compatibility and following Nutanix API best practices.
