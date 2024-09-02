variable "role_assignments" {
  type = list(object({
    principal_ids                          = optional(list(string), [])
    role_names                             = list(string)
    scope                                  = string
    set_condition                          = optional(bool, false)
    condition                              = optional(string)
    condition_version                      = optional(string)
    delegated_managed_identity_resource_id = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, null)
    description                            = optional(string)
  }))
  description = "The role assignments to create, with optional conditions, ticket information, and other attributes"
}
