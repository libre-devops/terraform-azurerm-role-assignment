output "role_assignments" {
  description = "The permanent (azurerm_role_assignment) assignments, keyed by \"label|rN|pN\". Full resource objects (all attributes)."
  value       = azurerm_role_assignment.this
}

output "pim_active_role_assignments" {
  description = "The PIM active assignments, keyed by \"label|rN|pN\". Full resource objects."
  value       = azurerm_pim_active_role_assignment.this
}

output "pim_eligible_role_assignments" {
  description = "The PIM eligible assignments, keyed by \"label|rN|pN\". Full resource objects."
  value       = azurerm_pim_eligible_role_assignment.this
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

output "principal_ids" {
  description = "The distinct principal ids that received an assignment."
  value       = distinct([for c in local.combinations : c.principal_id])
}

output "scopes" {
  description = "The distinct scopes assignments were created at."
  value       = distinct([for c in local.combinations : c.scope])
}

output "guarded_assignments" {
  description = "The keys of assignments that received the privileged-delegation deny condition."
  value       = [for k, applied in local.guard_applied : k if applied]
}

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
