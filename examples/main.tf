
terraform {

  required_providers {
    nutanix = {
      source = "nutanix/nutanix"
    }
  }
}

provider "nutanix" {
  username  = "admin"
  password  = "nx2Tech100!"
  endpoint  = "172.23.0.7"
  insecure  = true
  port      = 9440
}

data "nutanix_clusters" "clusters" {
}

### Define Script Local Variables
### This can be used for any manner of things, but is useful for like clusterid,
###   to store a mapping of targets for provisioning
### TODO: Need to make clusters a data source object, such that consumers do
###       not need to manually provision cluster ID
locals {
  cluster1 = data.nutanix_clusters.clusters.entities[1].metadata.uuid
}


resource "nutanix_image" "cirros-034-disk" {
  name = "cirros-034-disk"

  source_uri  = "http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img"
  description = "heres a tiny linux image, not an iso, but a real disk!"
}


