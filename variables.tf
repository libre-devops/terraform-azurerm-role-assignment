variable "role_assignments" {
  description = <<DESC
The role assignments to create, keyed by a logical label you choose (the label is only for readable
plan output and stable addressing, it is not the Azure resource name). Each entry is expanded over the
cartesian product of `principal_ids` and the combined set of `role_names` + `role_ids`, so one entry
can assign several roles to several principals at one scope.

`assignment_type` selects how the role is granted:

- `permanent` (default): a standard `azurerm_role_assignment` (a persistent, always-active grant).
- `pim_active`: a PIM active assignment (active now, but managed by PIM and typically time-bound).
- `pim_eligible`: a PIM eligible assignment (the principal can activate the role just-in-time).

`role_names` are resolved to a role definition id automatically for the PIM types (which require the
id, not the name); `role_ids` (full role definition resource ids) are used as-is. The privileged
delegation guard (see `constrained_delegation_role_ids`) only applies to `permanent` and `pim_eligible`
assignments, because `pim_active` has no condition argument.
DESC

  type = map(object({
    scope         = string
    principal_ids = optional(list(string), [])
    role_names    = optional(list(string), [])
    role_ids      = optional(list(string), [])

    assignment_type = optional(string, "permanent")
    principal_type  = optional(string)
    description     = optional(string)

    # permanent (azurerm_role_assignment) only
    name                                   = optional(string)
    condition                              = optional(string)
    condition_version                      = optional(string)
    delegated_managed_identity_resource_id = optional(string)
    skip_service_principal_aad_check       = optional(bool)

    # null: apply the delegation guard automatically when the role is privileged (secure default).
    # true: always apply it. false: never apply it. Ignored for pim_active (no condition support).
    constrain_delegation = optional(bool)

    # PIM (pim_active / pim_eligible) only
    justification = optional(string)
    ticket = optional(object({
      number = optional(string)
      system = optional(string)
    }))
    schedule = optional(object({
      start_date_time = optional(string)
      expiration = optional(object({
        duration_days  = optional(number)
        duration_hours = optional(number)
        end_date_time  = optional(string)
      }))
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for e in values(var.role_assignments) : contains(["permanent", "pim_active", "pim_eligible"], e.assignment_type)])
    error_message = "assignment_type must be one of: permanent, pim_active, pim_eligible."
  }

  validation {
    condition     = alltrue([for e in values(var.role_assignments) : e.principal_type == null || contains(["User", "Group", "ServicePrincipal", "ForeignGroup", "Device"], coalesce(e.principal_type, "User"))])
    error_message = "principal_type, when set, must be one of: User, Group, ServicePrincipal, ForeignGroup, Device."
  }

  validation {
    condition     = alltrue([for e in values(var.role_assignments) : e.condition_version == null || contains(["1.0", "2.0"], coalesce(e.condition_version, "2.0"))])
    error_message = "condition_version, when set, must be either \"1.0\" or \"2.0\"."
  }

  validation {
    condition     = alltrue([for e in values(var.role_assignments) : length(e.role_names) + length(e.role_ids) > 0])
    error_message = "Every role_assignments entry must set at least one of role_names or role_ids."
  }
}

variable "constrained_delegation_role_ids" {
  description = <<DESC
The privileged role definition ids (name => GUID) whose re-delegation is denied by the ABAC condition
this module applies to privileged assignments. Defaults to the three roles that can grant Azure RBAC
(Owner, User Access Administrator, Role Based Access Control Administrator). Extend this to treat more
roles as privileged. The guard denies the assignee the ability to create or delete role assignments for
any of these roles, so a granted Owner cannot hand Owner (or the other listed roles) to anyone else.
DESC

  type = map(string)
  default = {
    "Owner"                                   = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
    "User Access Administrator"               = "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9"
    "Role Based Access Control Administrator" = "f58310d9-a9f6-439a-9e8d-f62e7b41a168"
  }

  validation {
    condition     = alltrue([for g in values(var.constrained_delegation_role_ids) : can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", g))])
    error_message = "Each constrained_delegation_role_ids value must be a role definition GUID."
  }
}

variable "pim_role_definition_lookup_scope" {
  description = <<DESC
The scope at which PIM `role_names` are resolved to role definition ids (built-in roles resolve at any
scope). Defaults to the current subscription. Set this when a PIM assignment uses a custom role defined
at a different scope, or pass the full role definition id via `role_ids` instead.
DESC

  type    = string
  default = null
}
