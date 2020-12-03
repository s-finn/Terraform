# terraform {
#  required_providers {
#    azurerm = {
#      source  = "hashicorp/azurerm"
#      version = "~> 2.38"
#    }
#  }
# }

module "zca-in-azure" {
  source = "./modules/zca_in_azure"
}