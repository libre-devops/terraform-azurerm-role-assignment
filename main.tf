# The subscription is used as the default scope for resolving PIM role_names to role definition ids.
data "azurerm_subscription" "current" {}

# PIM active and eligible assignments require the full role definition id (not a name), so any PIM
# entry given a role_name is resolved here. Keyed by name (known at plan) to keep the for_each valid.
data "azurerm_role_definition" "pim" {
  for_each = local.pim_role_names

  name  = each.value
  scope = local.pim_lookup_scope
}

# Custom Azure RBAC role definitions, keyed by role name. assignable_scopes defaults to the
# definition's own scope. Assignments below reference these through role_definition_keys.
resource "azurerm_role_definition" "this" {
  for_each = var.role_definitions

  name               = each.key
  scope              = each.value.scope
  description        = each.value.description
  role_definition_id = each.value.role_definition_id

  permissions {
    actions          = each.value.permissions.actions
    not_actions      = each.value.permissions.not_actions
    data_actions     = each.value.permissions.data_actions
    not_data_actions = each.value.permissions.not_data_actions
  }

  assignable_scopes = length(each.value.assignable_scopes) > 0 ? each.value.assignable_scopes : [each.value.scope]
}

# Standard, always-active RBAC assignments. Privileged roles receive the delegation-deny condition by
# default (see locals.privileged_deny_condition and var.constrained_delegation_role_ids).
resource "azurerm_role_assignment" "this" {
  for_each = local.permanent

  scope                = each.value.scope
  principal_id         = each.value.principal_id
  principal_type       = each.value.principal_type
  role_definition_name = each.value.role_name
  role_definition_id   = local.effective_role_id[each.key]
  name                 = local.effective_name[each.key]
  description          = each.value.description
  condition            = local.effective_condition[each.key]
  condition_version    = local.effective_condition_version[each.key]

  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

# PIM active assignments: managed by PIM and typically time-bound, but active on creation. No condition
# argument exists on this resource, so the delegation guard does not apply here.
resource "azurerm_pim_active_role_assignment" "this" {
  for_each = local.pim_active

  scope              = each.value.scope
  principal_id       = each.value.principal_id
  role_definition_id = local.pim_role_definition_id[each.key]
  justification      = each.value.justification

  dynamic "ticket" {
    for_each = each.value.ticket != null ? [each.value.ticket] : []
    content {
      number = ticket.value.number
      system = ticket.value.system
    }
  }

  dynamic "schedule" {
    for_each = each.value.schedule != null ? [each.value.schedule] : []
    content {
      start_date_time = schedule.value.start_date_time
      dynamic "expiration" {
        for_each = schedule.value.expiration != null ? [schedule.value.expiration] : []
        content {
          duration_days  = expiration.value.duration_days
          duration_hours = expiration.value.duration_hours
          end_date_time  = expiration.value.end_date_time
        }
      }
    }
  }
}

# PIM eligible assignments: the principal can activate the role just-in-time. This resource supports a
# condition, so privileged eligible roles are guarded the same way as permanent ones.
resource "azurerm_pim_eligible_role_assignment" "this" {
  for_each = local.pim_eligible

  scope              = each.value.scope
  principal_id       = each.value.principal_id
  role_definition_id = local.pim_role_definition_id[each.key]
  justification      = each.value.justification
  condition          = local.effective_condition[each.key]
  condition_version  = local.effective_condition_version[each.key]

  dynamic "ticket" {
    for_each = each.value.ticket != null ? [each.value.ticket] : []
    content {
      number = ticket.value.number
      system = ticket.value.system
    }
  }

  dynamic "schedule" {
    for_each = each.value.schedule != null ? [each.value.schedule] : []
    content {
      start_date_time = schedule.value.start_date_time
      dynamic "expiration" {
        for_each = schedule.value.expiration != null ? [schedule.value.expiration] : []
        content {
          duration_days  = expiration.value.duration_days
          duration_hours = expiration.value.duration_hours
          end_date_time  = expiration.value.end_date_time
        }
      }
    }
  }
}
