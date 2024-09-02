resource "azurerm_role_assignment" "principal_ids_assignment" {
  count = length(local.role_principal_id_combinations)

  scope                                  = local.role_principal_id_combinations[count.index].scope
  principal_id                           = local.role_principal_id_combinations[count.index].principal_id
  role_definition_name                   = local.role_principal_id_combinations[count.index].role_name
  condition                              = local.role_principal_id_combinations[count.index].condition
  condition_version                      = local.role_principal_id_combinations[count.index].condition != null ? "2.0" : null
  delegated_managed_identity_resource_id = local.role_principal_id_combinations[count.index].delegated_managed_identity_resource_id
  description                            = local.role_principal_id_combinations[count.index].description
  skip_service_principal_aad_check       = local.role_principal_id_combinations[count.index].skip_service_principal_aad_check
}
