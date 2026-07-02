locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-001"
}

data "azurerm_client_config" "current" {}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

# Minimal call: grant the running principal Reader on the resource group. Only the required inputs
# (scope, principal_ids, role_names) are set; assignment_type defaults to permanent.
module "role_assignment" {
  source = "../../"

  role_assignments = {
    rg_reader = {
      scope         = module.rg.ids[local.rg_name]
      principal_ids = [data.azurerm_client_config.current.object_id]
      role_names    = ["Reader"]
    }
  }
}
