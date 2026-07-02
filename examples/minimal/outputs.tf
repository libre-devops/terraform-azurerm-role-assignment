output "role_assignment_ids" {
  description = "Map of assignment key to role assignment id."
  value       = module.role_assignment.role_assignment_ids
}

output "role_assignment_ids_zipmap" {
  description = "Map of assignment key to { name, id }."
  value       = module.role_assignment.role_assignment_ids_zipmap
}
