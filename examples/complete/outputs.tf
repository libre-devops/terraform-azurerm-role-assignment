output "role_assignment_ids" {
  description = "Map of assignment key to role assignment id (all types)."
  value       = module.role_assignment.role_assignment_ids
}

output "role_assignment_ids_zipmap" {
  description = "Map of assignment key to { name, id }."
  value       = module.role_assignment.role_assignment_ids_zipmap
}

output "guarded_assignments" {
  description = "Keys of assignments that received the privileged-delegation deny condition."
  value       = module.role_assignment.guarded_assignments
}

output "conditions_applied" {
  description = "The permanent assignments that carry an ABAC condition."
  value       = module.role_assignment.conditions_applied
}

output "pim_eligible_role_assignment_ids" {
  description = "Ids of the PIM eligible assignments (empty unless enable_pim_examples is true)."
  value       = { for k, r in module.role_assignment.pim_eligible_role_assignments : k => r.id }
}

output "pim_active_role_assignment_ids" {
  description = "Ids of the PIM active assignments (empty unless enable_pim_examples is true)."
  value       = { for k, r in module.role_assignment.pim_active_role_assignments : k => r.id }
}
