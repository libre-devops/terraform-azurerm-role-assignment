locals {
  # Privileged roles (name => GUID) whose re-delegation is denied by the ABAC guard.
  privileged_names_lower = [for n in keys(var.constrained_delegation_role_ids) : lower(n)]
  privileged_guids_lower = [for g in values(var.constrained_delegation_role_ids) : lower(g)]
  delegated_role_ids_csv = join(", ", values(var.constrained_delegation_role_ids))

  # Microsoft ABAC condition (language version 2.0): the assignee may not write or delete a role
  # assignment for any of the privileged role definition ids, so a granted Owner cannot re-delegate
  # Owner (or the other listed roles) to anyone else.
  privileged_deny_condition = <<EOT
(
 (
  !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
 )
 OR
 (
  @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidNotEquals {${local.delegated_role_ids_csv}}
 )
)
AND
(
 (
  !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
 )
 OR
 (
  @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidNotEquals {${local.delegated_role_ids_csv}}
 )
)
EOT

  # Expand every entry over the cartesian product of (role, principal). Instance keys are index based
  # ("label|rN|pN") so they stay known at plan time even when principal_id or role_id are computed (a
  # for_each key must be known at plan). Computed values live only in the map VALUES and are read in the
  # resource body, never in for_each.
  combinations = flatten([
    for label, e in var.role_assignments : [
      for ri, role in concat(
        [for n in e.role_names : { name = n, id = null }],
        [for i in e.role_ids : { name = null, id = i }],
        ) : [
        for pi, pid in e.principal_ids : {
          key             = "${label}|r${ri}|p${pi}"
          label           = label
          scope           = e.scope
          principal_id    = pid
          principal_type  = e.principal_type
          role_name       = role.name
          role_id         = role.id
          assignment_type = e.assignment_type
          description     = e.description

          name                                   = e.name
          condition                              = e.condition
          condition_version                      = e.condition_version
          delegated_managed_identity_resource_id = e.delegated_managed_identity_resource_id
          skip_service_principal_aad_check       = e.skip_service_principal_aad_check
          constrain_delegation                   = e.constrain_delegation

          justification = e.justification
          ticket        = e.ticket
          schedule      = e.schedule

          # Known at plan (list lengths): a passthrough name is only applied to a single-assignment
          # entry, since Azure role assignment names must be unique.
          entry_expansion = (length(e.role_names) + length(e.role_ids)) * length(e.principal_ids)
        }
      ]
    ]
  ])

  by_key       = { for c in local.combinations : c.key => c }
  permanent    = { for k, c in local.by_key : k => c if c.assignment_type == "permanent" }
  pim_active   = { for k, c in local.by_key : k => c if c.assignment_type == "pim_active" }
  pim_eligible = { for k, c in local.by_key : k => c if c.assignment_type == "pim_eligible" }

  # Whether a combination targets a privileged role, by name or by the trailing GUID of a role id.
  # Each combination has exactly one of role_name / role_id set. Nested conditionals are used (not &&)
  # because Terraform does not short-circuit &&, so lower() would otherwise be evaluated on the null
  # side and error.
  is_privileged = {
    for k, c in local.by_key : k => (
      c.role_name != null ? contains(local.privileged_names_lower, lower(c.role_name)) : (
        c.role_id != null ? contains(local.privileged_guids_lower, lower(try(regex("[^/]+$", c.role_id), c.role_id))) : false
      )
    )
  }

  # The guard is applied to permanent and eligible assignments (both carry a condition). Default-on for
  # privileged roles unless the caller sets constrain_delegation = false. pim_active has no condition,
  # so it is never guarded.
  guard_applied = {
    for k, c in local.by_key : k => (
      contains(["permanent", "pim_eligible"], c.assignment_type) &&
      local.is_privileged[k] &&
      coalesce(c.constrain_delegation, true)
    )
  }

  # Effective condition / version for permanent and eligible assignments. condition_version is required
  # by the provider whenever condition is set, so it defaults to 2.0.
  effective_condition = {
    for k, c in local.by_key : k => local.guard_applied[k] ? local.privileged_deny_condition : c.condition
  }
  effective_condition_version = {
    for k, cond in local.effective_condition : k => cond != null ? coalesce(local.by_key[k].condition_version, "2.0") : null
  }

  # A passthrough name is only safe when the entry produces exactly one assignment.
  effective_name = {
    for k, c in local.permanent : k => c.entry_expansion == 1 ? c.name : null
  }

  # PIM resources require the full role definition id. role_ids are used as-is; role_names are resolved
  # via the data source. Names are known at plan, so the data source for_each key set stays valid.
  pim_role_names = toset([
    for c in local.combinations : c.role_name
    if contains(["pim_active", "pim_eligible"], c.assignment_type) && c.role_name != null
  ])
  pim_lookup_scope = coalesce(var.pim_role_definition_lookup_scope, data.azurerm_subscription.current.id)

  pim_role_definition_id = {
    for k, c in local.by_key : k => c.role_id != null ? c.role_id : data.azurerm_role_definition.pim[c.role_name].id
    if contains(["pim_active", "pim_eligible"], c.assignment_type)
  }
}
