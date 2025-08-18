# Example Terraform Variables for SR-IOV VM Creation
# Copy this file to terraform.tfvars and update with your environment details

# Nutanix Provider Configuration
#replace the values as per setup configuration
nutanix_username = "admin"
nutanix_password = "Nutanix/123456"
nutanix_endpoint = "10.xx.xx.xx"
nutanix_port     = 9440

image_name = "ubuntu-22.04"

subnet_name = "User1"