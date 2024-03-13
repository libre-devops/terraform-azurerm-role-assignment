module "rg" {
  source = "cyber-scot/rg/azurerm"

  name     = "rg-${var.short}-${var.loc}-${var.env}-01"
  location = local.location
  tags     = local.tags
}

resource "azurerm_user_assigned_identity" "uaid" {
  resource_group_name = module.rg.rg_name
  location            = module.rg.rg_location
  tags                = module.rg.rg_tags

  name = "id-${var.short}-${var.loc}-${var.env}-build"
}

module "role_assignments" {
  source = "../../"

  assignments = [
    {
      role_definition_name = "Reader"
      scope                = module.rg.rg_id
      principal_id         = azurerm_user_assigned_identity.uaid.principal_id
    },
    {
      role_definition_id = "b24988ac-6180-42a0-ab88-20f7382dd24c" # Contributor
      scope              = format("/subscriptions/%s", data.azurerm_client_config.current.subscription_id)
      principal_id       = azurerm_user_assigned_identity.uaid.principal_id
    },
  ]
}
