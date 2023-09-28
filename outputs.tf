output "role_assignments" {
  description = "Map of created role assignments."
  value = {
    for key, assignment in azurerm_role_assignment.this :
    key => {
      id                                      = assignment.id
      principal_type                          = assignment.principal_type
      name                                    = assignment.name
      scope                                   = assignment.scope
      role_definition_id                      = assignment.role_definition_id
      role_definition_name                    = assignment.role_definition_name
      principal_id                            = assignment.principal_id
      condition                               = assignment.condition
      condition_version                       = assignment.condition_version
      delegated_managed_identity_resource_id  = assignment.delegated_managed_identity_resource_id
      description                             = assignment.description
      skip_service_principal_aad_check        = assignment.skip_service_principal_aad_check
    }
  }
}
