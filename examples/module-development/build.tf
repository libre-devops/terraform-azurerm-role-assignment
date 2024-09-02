module "rg" {
  source = "libre-devops/rg/azurerm"

  rg_name  = "rg-${var.short}-${var.loc}-${var.env}-01"
  location = local.location
  tags     = local.tags
}

resource "azurerm_user_assigned_identity" "uid" {
  resource_group_name = module.rg.rg_name
  location            = module.rg.rg_location
  tags                = module.rg.rg_tags

  name = "id-${var.short}-${var.loc}-${var.env}-build"
}

data "azurerm_role_definition" "owner" {
  name = "Owner"
}

data "azurerm_role_definition" "contributor" {
  name = "Contributor"
}

data "azurerm_subscription" "current" {}


module "role_assignments" {
  source = "../../"

  role_assignments = [
    {
      principal_ids = [azurerm_user_assigned_identity.uid.principal_id]
      role_names    = [data.azurerm_role_definition.owner.name, data.azurerm_role_definition.contributor.name]
      scope         = module.rg.rg_id
      set_condition = true
    },
    {
      principal_ids = [azurerm_user_assigned_identity.uid.principal_id]
      role_names    = [data.azurerm_role_definition.owner.name]
      scope         = data.azurerm_subscription.current.id
      set_condition = false
    }
  ]
}