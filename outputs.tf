output "conditions_applied" {
  description = "A list of conditions applied to the role assignments."
  value = [
    for ra in azurerm_role_assignment.principal_ids_assignment :
    {
      principal_id         = ra.principal_id
      role_definition_name = ra.role_definition_name
      scope                = ra.scope
      condition            = ra.condition
      condition_version    = ra.condition_version
    } if ra.condition != null
  ]
}

output "principal_ids" {
  description = "A list of all principal IDs to which roles were assigned."
  value = [
    for ra in azurerm_role_assignment.principal_ids_assignment :
    ra.principal_id
  ]
}

output "role_assignments" {
  description = "A list of all role assignments created by this module."
  value = [
    for ra in azurerm_role_assignment.principal_ids_assignment :
    {
      principal_id                           = ra.principal_id
      role_definition_name                   = ra.role_definition_name
      scope                                  = ra.scope
      condition                              = ra.condition
      condition_version                      = ra.condition_version
      delegated_managed_identity_resource_id = ra.delegated_managed_identity_resource_id
      description                            = ra.description
      skip_service_principal_aad_check       = ra.skip_service_principal_aad_check
    }
  ]
}

output "role_names" {
  description = "A list of all role names assigned."
  value = [
    for ra in azurerm_role_assignment.principal_ids_assignment :
    ra.role_definition_name
  ]
}

output "scopes" {
  description = "A list of all scopes where roles were assigned."
  value = [
    for ra in azurerm_role_assignment.principal_ids_assignment :
    ra.scope
  ]
}
