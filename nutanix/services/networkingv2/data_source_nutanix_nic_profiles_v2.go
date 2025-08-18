package networkingv2

import (
	"context"

	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
	import1 "github.com/nutanix/ntnx-api-golang-clients/networking-go-client/v4/models/networking/v4/config"
	conns "github.com/terraform-providers/terraform-provider-nutanix/nutanix"
)

// DataSourceNutanixNicProfilesV2 returns a data source to read NIC profiles.
// NIC profiles define capabilities for network interfaces, including SR-IOV and DP offload features.
// This data source uses the networking v4.1 API to retrieve available NIC profiles in the cluster.
func DataSourceNutanixNicProfilesV2() *schema.Resource {
	return &schema.Resource{
		ReadContext: dataSourceNutanixNicProfilesV2Read,
		Schema: map[string]*schema.Schema{
			"nic_profiles": {
				Type:     schema.TypeList,
				Computed: true,
				Elem: &schema.Resource{
					Schema: map[string]*schema.Schema{
						"ext_id": {
							Type:     schema.TypeString,
							Computed: true,
						},
						"name": {
							Type:     schema.TypeString,
							Computed: true,
						},
						"description": {
							Type:     schema.TypeString,
							Computed: true,
						},
						"capabilities": {
							Type:     schema.TypeList,
							Computed: true,
							Elem: &schema.Resource{
								Schema: map[string]*schema.Schema{
									"capability_type": {
										Type:     schema.TypeString,
										Computed: true,
									},
								},
							},
						},
						"tenant_id": {
							Type:     schema.TypeString,
							Computed: true,
						},
						"links": {
							Type:     schema.TypeList,
							Computed: true,
							Elem: &schema.Resource{
								Schema: map[string]*schema.Schema{
									"href": {
										Type:     schema.TypeString,
										Computed: true,
									},
									"rel": {
										Type:     schema.TypeString,
										Computed: true,
									},
								},
							},
						},
					},
				},
			},
		},
	}
}

// dataSourceNutanixNicProfilesV2Read fetches NIC profiles from the Nutanix cluster.
// This function calls the networking v4.1 API to retrieve all available NIC profiles,
// which include SR-IOV and DP offload capabilities that can be used for VM network interfaces.
func dataSourceNutanixNicProfilesV2Read(ctx context.Context, d *schema.ResourceData, meta interface{}) diag.Diagnostics {
	conn := meta.(*conns.Client).NetworkingAPI

	// Call the ListNicProfiles API
	resp, err := conn.NicProfilesAPI.ListNicProfiles(nil, nil, nil, nil, nil)
	if err != nil {
		return diag.Errorf("error while fetching nic profiles: %v", err)
	}

	// Handle the API response which can have different structures
	var nicProfilesList []import1.NicProfile

	// Direct response handling - check the actual type from the error message
	respValue := resp.Data.GetValue()
	switch v := respValue.(type) {
	case []import1.NicProfile:
		// Direct slice response (what the error shows us)
		nicProfilesList = v
	case import1.ListNicProfilesApiResponse:
		// Structured response
		if v.Data != nil {
			responseData := v.Data.GetValue()
			switch dataType := responseData.(type) {
			case []import1.NicProfile:
				nicProfilesList = dataType
			case []import1.NicProfileProjection:
				// Convert projections to full profiles if needed
				for _, projection := range dataType {
					nicProfile := import1.NicProfile{
						ExtId:       projection.ExtId,
						Name:        projection.Name,
						Description: projection.Description,
						TenantId:    projection.TenantId,
						Links:       projection.Links,
					}
					nicProfilesList = append(nicProfilesList, nicProfile)
				}
			default:
				return diag.Errorf("unexpected response data type for nic profiles: %T", dataType)
			}
		}
	default:
		return diag.Errorf("unexpected response type for nic profiles: %T (expected []import1.NicProfile or import1.ListNicProfilesApiResponse)", v)
	}

	nicProfiles := make([]map[string]interface{}, 0)
	for _, nicProfile := range nicProfilesList {
		nicProfileMap := make(map[string]interface{})

		if nicProfile.ExtId != nil {
			nicProfileMap["ext_id"] = *nicProfile.ExtId
		}
		if nicProfile.Name != nil {
			nicProfileMap["name"] = *nicProfile.Name
		}
		if nicProfile.Description != nil {
			nicProfileMap["description"] = *nicProfile.Description
		}
		if nicProfile.TenantId != nil {
			nicProfileMap["tenant_id"] = *nicProfile.TenantId
		}

		// Handle capabilities
		if nicProfile.CapabilityConfig != nil && nicProfile.CapabilityConfig.CapabilityType != nil {
			capabilities := make([]map[string]interface{}, 1)
			capMap := make(map[string]interface{})

			capMap["capability_type"] = nicProfile.CapabilityConfig.CapabilityType.GetName()

			capabilities[0] = capMap
			nicProfileMap["capabilities"] = capabilities
		}

		// Handle links
		if nicProfile.Links != nil {
			nicProfileMap["links"] = flattenLinks(nicProfile.Links)
		}

		nicProfiles = append(nicProfiles, nicProfileMap)
	}

	if err := d.Set("nic_profiles", nicProfiles); err != nil {
		return diag.FromErr(err)
	}

	// Use a simple generated ID since this is a list operation
	d.SetId("nic-profiles-list")

	return nil
}
