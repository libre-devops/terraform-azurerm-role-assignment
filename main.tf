resource "azurerm_role_assignment" "this" {
    for_each = { for idx, assignment in var.assignments : tostring(idx) => assignment }


  name                                  = try(each.value.name, null)
  scope                                 = each.value.scope
  role_definition_id                    = lookup(each.value, "role_definition_id", null) != null ? data.azurerm_role_definition.by_id[each.key].id : null
  role_definition_name                  = lookup(each.value, "role_definition_name", null) != null ? data.azurerm_role_definition.by_name[each.key].name : null
  principal_id                          = each.value.principal_id
  condition                             = lookup(each.value, "condition", null)
  condition_version                     = lookup(each.value, "condition_version", null)
  delegated_managed_identity_resource_id = lookup(each.value, "delegated_managed_identity_resource_id", null)
  description                           = lookup(each.value, "description", null)
  skip_service_principal_aad_check      = lookup(each.value, "skip_service_principal_aad_check", false)
}


data "azurerm_role_definition" "by_name" {
    for_each = { for idx, assignment in var.assignments : tostring(idx) => assignment if lookup(assignment, "role_definition_name", null) != null }


  name = each.value.role_definition_name
  scope = each.value.scope
}


data "azurerm_role_definition" "by_id" {
    for_each = { for idx, assignment in var.assignments : tostring(idx) => assignment if lookup(assignment, "role_definition_id", null) != null }


  role_definition_id = each.value.role_definition_id
  scope = each.value.scope
}
