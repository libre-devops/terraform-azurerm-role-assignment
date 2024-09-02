locals {
  # Key-value pairs of role names and GUIDs
  delegated_roles = {
    "Owner"                                   = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
    "Role Based Access Control Administrator" = "f58310d9-a9f6-439a-9e8d-f62e7b41a168"
    "User Access Administrator"               = "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9"
  }

  # Convert GUIDs map to string
  delegated_role_ids_as_string = join(", ", values(local.delegated_roles))

  # Microsoft condition language
  privileged_roles_deny_condition = <<EOF
(
 (
  !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
 )
 OR
 (
  @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidNotEquals {${local.delegated_role_ids_as_string}}
 )
)
AND
(
 (
  !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
 )
 OR
 (
  @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidNotEquals {${local.delegated_role_ids_as_string}}
 )
)
EOF

  # Combine roles with principal_ids, scope, and conditional logic
  role_principal_id_combinations = flatten([
    for policy in var.role_assignments :
    [
      for role_name in policy.role_names :
      [
        for principal_id in policy.principal_ids :
        {
          role_name                              = role_name
          principal_id                           = principal_id
          scope                                  = policy.scope
          condition                              = policy.set_condition && contains(keys(local.delegated_roles), role_name) ? local.privileged_roles_deny_condition : policy.condition
          condition_version                      = policy.set_condition && contains(keys(local.delegated_roles), role_name) ? "2.0" : policy.condition_version
          delegated_managed_identity_resource_id = policy.delegated_managed_identity_resource_id
          skip_service_principal_aad_check       = policy.skip_service_principal_aad_check
          description                            = policy.description != null ? policy.description : "Role is assigned to ${principal_id} as ${role_name} to scope ${policy.scope}."
        }
      ]
    ]
  ])
}
