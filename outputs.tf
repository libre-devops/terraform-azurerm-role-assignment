output "conditions_applied" {
  description = "The permanent assignments that carry an ABAC condition, with their principal, role, scope, and condition version."
  value = {
    for k, r in azurerm_role_assignment.this : k => {
      principal_id      = r.principal_id
      role              = coalesce(r.role_definition_name, r.role_definition_id)
      scope             = r.scope
      condition_version = r.condition_version
    } if r.condition != null
  }
}

output "guarded_assignments" {
  description = "The keys of assignments that received the privileged-delegation deny condition."
  value       = [for k, applied in local.guard_applied : k if applied]
}

output "pim_active_role_assignments" {
  description = "The PIM active assignments, keyed by \"label|rN|pN\". Full resource objects."
  value       = azurerm_pim_active_role_assignment.this
}

output "pim_eligible_role_assignments" {
  description = "The PIM eligible assignments, keyed by \"label|rN|pN\". Full resource objects."
  value       = azurerm_pim_eligible_role_assignment.this
}

output "principal_ids" {
  description = "The distinct principal ids that received an assignment."
  value       = distinct([for c in local.combinations : c.principal_id])
}

output "role_assignment_ids" {
  description = "All assignment ids across the three types, keyed by \"label|rN|pN\"."
  value = merge(
    { for k, r in azurerm_role_assignment.this : k => r.id },
    { for k, r in azurerm_pim_active_role_assignment.this : k => r.id },
    { for k, r in azurerm_pim_eligible_role_assignment.this : k => r.id },
  )
}

output "role_assignment_ids_zipmap" {
  description = "key => { name, id } across all assignment types, for easy composition with other modules."
  value = merge(
    { for k, r in azurerm_role_assignment.this : k => { name = k, id = r.id } },
    { for k, r in azurerm_pim_active_role_assignment.this : k => { name = k, id = r.id } },
    { for k, r in azurerm_pim_eligible_role_assignment.this : k => { name = k, id = r.id } },
  )
}

output "role_assignments" {
  description = "The permanent (azurerm_role_assignment) assignments, keyed by \"label|rN|pN\". Full resource objects (all attributes)."
  value       = azurerm_role_assignment.this
}

output "role_definition_guids" {
  description = "Map of custom role name to the role definition GUID (the name portion of the id)."
  value       = { for k, v in azurerm_role_definition.this : k => v.role_definition_id }
}

output "role_definition_ids" {
  description = "Map of custom role name to the full role definition resource id (feed this to role_ids in other calls or modules)."
  value       = { for k, v in azurerm_role_definition.this : k => v.role_definition_resource_id }
}

output "role_definition_ids_zipmap" {
  description = "Map of custom role name to an object of its name and full resource id, for easy composition."
  value       = { for k, v in azurerm_role_definition.this : k => { name = k, id = v.role_definition_resource_id } }
}

output "role_definitions" {
  description = "Map of custom role name to its useful attributes."
  value = {
    for k, v in azurerm_role_definition.this : k => {
      id                          = v.id
      role_definition_id          = v.role_definition_id
      role_definition_resource_id = v.role_definition_resource_id
      scope                       = v.scope
      assignable_scopes           = v.assignable_scopes
    }
  }
}

output "scopes" {
  description = "The distinct scopes assignments were created at."
  value       = distinct([for c in local.combinations : c.scope])
}
