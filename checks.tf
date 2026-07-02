# check blocks run after every plan and apply and emit a warning (without blocking) when an
# invariant is violated. They surface configuration that would silently do the wrong thing.

# An entry with no principals expands to nothing, which is almost always a mistake.
check "entries_have_principals" {
  assert {
    condition     = alltrue([for e in values(var.role_assignments) : length(e.principal_ids) > 0])
    error_message = "These role_assignments entries set no principal_ids and create nothing: ${join(", ", [for label, e in var.role_assignments : label if length(e.principal_ids) == 0])}."
  }
}

# pim_active has no condition argument, so a condition set on such an entry is silently ignored.
check "pim_active_condition_ignored" {
  assert {
    condition     = alltrue([for e in values(var.role_assignments) : !(e.assignment_type == "pim_active" && e.condition != null)])
    error_message = "These pim_active entries set a condition, which azurerm_pim_active_role_assignment does not support and will ignore: ${join(", ", [for label, e in var.role_assignments : label if e.assignment_type == "pim_active" && e.condition != null])}."
  }
}

# The delegation guard needs a condition, so it cannot apply to pim_active.
check "guard_only_where_supported" {
  assert {
    condition     = alltrue([for e in values(var.role_assignments) : !(e.assignment_type == "pim_active" && coalesce(e.constrain_delegation, false))])
    error_message = "These pim_active entries request constrain_delegation, but pim_active has no condition to carry the guard: ${join(", ", [for label, e in var.role_assignments : label if e.assignment_type == "pim_active" && coalesce(e.constrain_delegation, false)])}. Use pim_eligible or permanent for a guarded privileged grant."
  }
}

# A passthrough name cannot be reused across the several assignments a multi-expansion entry creates,
# so the module only applies it to single-assignment entries. Warn when it is dropped.
check "name_only_on_single_expansion" {
  assert {
    condition     = alltrue([for e in values(var.role_assignments) : !(e.assignment_type == "permanent" && e.name != null && (length(e.role_names) + length(e.role_ids)) * length(e.principal_ids) > 1)])
    error_message = "These permanent entries set name but expand to more than one assignment, so name is ignored (names must be unique): ${join(", ", [for label, e in var.role_assignments : label if e.assignment_type == "permanent" && e.name != null && (length(e.role_names) + length(e.role_ids)) * length(e.principal_ids) > 1])}."
  }
}
