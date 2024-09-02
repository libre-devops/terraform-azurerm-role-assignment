```hcl
resource "azurerm_role_assignment" "principal_ids_assignment" {
  count = length(local.role_principal_id_combinations)

  scope                                  = local.role_principal_id_combinations[count.index].scope
  principal_id                           = local.role_principal_id_combinations[count.index].principal_id
  role_definition_name                   = local.role_principal_id_combinations[count.index].role_name
  condition                              = local.role_principal_id_combinations[count.index].condition
  condition_version                      = local.role_principal_id_combinations[count.index].condition != null ? "2.0" : null
  delegated_managed_identity_resource_id = local.role_principal_id_combinations[count.index].delegated_managed_identity_resource_id
  description                            = local.role_principal_id_combinations[count.index].description
  skip_service_principal_aad_check       = local.role_principal_id_combinations[count.index].skip_service_principal_aad_check
}
```
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_role_assignment.principal_ids_assignment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_role_assignments"></a> [role\_assignments](#input\_role\_assignments) | The role assignments to create, with optional conditions, ticket information, and other attributes | <pre>list(object({<br>    principal_ids                          = optional(list(string), [])<br>    role_names                             = list(string)<br>    scope                                  = string<br>    set_condition                          = optional(bool, false)<br>    condition                              = optional(string)<br>    condition_version                      = optional(string)<br>    delegated_managed_identity_resource_id = optional(string, null)<br>    skip_service_principal_aad_check       = optional(bool, null)<br>    description                            = optional(string)<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_conditions_applied"></a> [conditions\_applied](#output\_conditions\_applied) | A list of conditions applied to the role assignments. |
| <a name="output_principal_ids"></a> [principal\_ids](#output\_principal\_ids) | A list of all principal IDs to which roles were assigned. |
| <a name="output_role_assignments"></a> [role\_assignments](#output\_role\_assignments) | A list of all role assignments created by this module. |
| <a name="output_role_names"></a> [role\_names](#output\_role\_names) | A list of all role names assigned. |
| <a name="output_scopes"></a> [scopes](#output\_scopes) | A list of all scopes where roles were assigned. |
