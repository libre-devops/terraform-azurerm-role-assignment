```hcl
resource "azurerm_role_assignment" "this" {
  for_each                               = { for idx, assignment in var.assignments : tostring(idx) => assignment }
  name                                   = try(each.value.name, null)
  scope                                  = each.value.scope
  role_definition_id                     = lookup(each.value, "role_definition_id", null) != null ? data.azurerm_role_definition.by_id[each.key].id : null
  role_definition_name                   = lookup(each.value, "role_definition_name", null) != null ? data.azurerm_role_definition.by_name[each.key].name : null
  principal_id                           = each.value.principal_id
  condition                              = lookup(each.value, "condition", null)
  condition_version                      = lookup(each.value, "condition_version", null)
  delegated_managed_identity_resource_id = lookup(each.value, "delegated_managed_identity_resource_id", null)
  description                            = lookup(each.value, "description", null)
  skip_service_principal_aad_check       = lookup(each.value, "skip_service_principal_aad_check", false)
}


data "azurerm_role_definition" "by_name" {
  for_each = { for idx, assignment in var.assignments : tostring(idx) => assignment if lookup(assignment, "role_definition_name", null) != null }
  name     = each.value.role_definition_name
  scope    = each.value.scope
}


data "azurerm_role_definition" "by_id" {
  for_each           = { for idx, assignment in var.assignments : tostring(idx) => assignment if lookup(assignment, "role_definition_id", null) != null }
  role_definition_id = each.value.role_definition_id
  scope              = each.value.scope
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
| [azurerm_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.by_id](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/role_definition) | data source |
| [azurerm_role_definition.by_name](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/role_definition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_assignments"></a> [assignments](#input\_assignments) | List of role assignments | <pre>list(object({<br>    name                                   = optional(string)<br>    scope                                  = string<br>    role_definition_id                     = optional(string)<br>    role_definition_name                   = optional(string)<br>    principal_id                           = string<br>    condition                              = optional(string)<br>    condition_version                      = optional(string)<br>    delegated_managed_identity_resource_id = optional(string)<br>    description                            = optional(string)<br>    skip_service_principal_aad_check       = optional(bool)<br>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_assignments"></a> [role\_assignments](#output\_role\_assignments) | Map of created role assignments. |
