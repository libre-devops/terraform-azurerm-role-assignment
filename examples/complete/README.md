<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

The full surface of the module. The permanent assignments show cartesian expansion over two principals
(one a user-assigned identity whose principal id is only known after apply, which proves the module's
plan-known keys), the delegation guard applied automatically to Owner and deliberately opted out on
another, `principal_type` and `skip_service_principal_aad_check`, and a role supplied by definition id
rather than name. The PIM assignments (a just-in-time eligible Contributor and a time-bound active
grant) are in `local.pim_assignments`; they are applied when `enable_pim_examples = true`, which needs
Entra ID P2 on the tenant, and are off by default so the example applies cleanly without P2. Run it with
`just e2e complete`, which applies the stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  uai_name = "id-${var.short}-${var.loc}-${terraform.workspace}-002"

  # Custom role names are unique per tenant, so the name carries the example's identity to keep
  # repeat runs and other stacks from colliding.
  custom_role_name = "Tag Reader (${var.short}-${var.loc}-${terraform.workspace}-cmp)"

  # The permanent (standard azurerm_role_assignment) surface. Always applied.
  permanent_assignments = {
    # Cartesian expansion: Reader to both the running principal and the (computed) identity.
    # skip_service_principal_aad_check avoids a transient PrincipalNotFound while the newly created
    # identity replicates into Entra ID.
    readers = {
      scope                            = module.rg.ids[local.rg_name]
      principal_ids                    = [data.azurerm_client_config.current.object_id, azurerm_user_assigned_identity.example.principal_id]
      role_names                       = ["Reader"]
      skip_service_principal_aad_check = true
    }

    # Privileged role: the delegation guard is applied automatically (no flag needed).
    owner_guarded = {
      scope         = module.rg.ids[local.rg_name]
      principal_ids = [data.azurerm_client_config.current.object_id]
      role_names    = ["Owner"]
      description   = "Owner with the default privileged-delegation guard."
    }

    # Privileged role with the guard explicitly opted out, plus principal_type and the SP AAD check.
    owner_unguarded = {
      scope                            = module.rg.ids[local.rg_name]
      principal_ids                    = [azurerm_user_assigned_identity.example.principal_id]
      role_names                       = ["Owner"]
      constrain_delegation             = false
      principal_type                   = "ServicePrincipal"
      skip_service_principal_aad_check = true
      description                      = "Owner with the guard deliberately disabled."
    }

    # Role supplied by definition id rather than name.
    by_id = {
      scope         = module.rg.ids[local.rg_name]
      principal_ids = [data.azurerm_client_config.current.object_id]
      role_ids      = [data.azurerm_role_definition.monitoring_reader.id]
    }

    # Define-then-assign: the custom role created by role_definitions below, referenced by key and
    # assigned at the resource group (inside the definition's subscription assignable scope).
    custom_role_holder = {
      scope                = module.rg.ids[local.rg_name]
      principal_ids        = [data.azurerm_client_config.current.object_id]
      role_definition_keys = [local.custom_role_name]
    }
  }

  # The PIM surface. Applied only when var.enable_pim_examples is true, because PIM active and eligible
  # assignments require Entra ID P2 on the tenant (the module supports them regardless; this toggle just
  # keeps the applied example green on a tenant without P2).
  pim_assignments = {
    # PIM eligible: the workload identity can activate Contributor just-in-time (the "grant access via
    # PIM" pattern). role_names is resolved to the definition id PIM requires. Exercises justification,
    # ticket, and the schedule / expiration blocks.
    jit_contributor = {
      scope           = module.rg.ids[local.rg_name]
      principal_ids   = [azurerm_user_assigned_identity.example.principal_id]
      role_names      = ["Contributor"]
      assignment_type = "pim_eligible"
      justification   = "Just-in-time Contributor for the example identity"
      ticket          = { number = "CHG0001", system = "ServiceNow" }
      schedule        = { expiration = { duration_hours = 8 } }
    }

    # PIM active: a PIM-managed, time-bound active grant (active on creation, expires per the schedule).
    temporary_tagger = {
      scope           = module.rg.ids[local.rg_name]
      principal_ids   = [data.azurerm_client_config.current.object_id]
      role_names      = ["Tag Contributor"]
      assignment_type = "pim_active"
      justification   = "Temporary tag-management window"
      schedule        = { expiration = { duration_hours = 4 } }
    }
  }
}

data "azurerm_client_config" "current" {}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

# A second principal whose id is only known after apply, so the example proves the module keeps its
# for_each keys plan-known even when principal_id is computed.
resource "azurerm_user_assigned_identity" "example" {
  resource_group_name = module.rg.names[local.rg_name]
  location            = local.location
  tags                = module.tags.tags
  name                = local.uai_name
}

# Look up a role by name to feed role_ids (proves role_ids works alongside role_names).
data "azurerm_role_definition" "monitoring_reader" {
  name  = "Monitoring Reader"
  scope = module.rg.ids[local.rg_name]
}

# Complete call: the full surface of the module. The permanent assignments are always created; the PIM
# assignments (active and eligible) are included when enable_pim_examples is true, which needs Entra ID
# P2. See the PIM entries in local.pim_assignments for the eligible and active usage.
module "role_assignment" {
  source = "../../"

  # A minimal custom role (read resource groups) defined at the subscription and assigned by key in
  # local.permanent_assignments. Creating it needs roleDefinitions/write on the subscription (Owner).
  role_definitions = {
    (local.custom_role_name) = {
      scope       = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
      description = "Reads resource groups and tags; a minimal custom role demonstrating define-then-assign."
      permissions = {
        # Control-plane reads only: the resource group itself and the standalone Tags API (RG reads
        # already return tags in the body; tags/read covers the dedicated tags endpoints too).
        actions = [
          "Microsoft.Resources/subscriptions/resourceGroups/read",
          "Microsoft.Resources/tags/read",
        ]
      }
    }
  }

  role_assignments = merge(
    local.permanent_assignments,
    { for k, v in local.pim_assignments : k => v if var.enable_pim_examples },
  )
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0.0, < 5.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_role_assignment"></a> [role\_assignment](#module\_role\_assignment) | ../../ | n/a |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_user_assigned_identity.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_role_definition.monitoring_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/role_definition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_enable_pim_examples"></a> [enable\_pim\_examples](#input\_enable\_pim\_examples) | Create the PIM active and eligible example assignments (requires Entra ID P2). | `bool` | `false` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_conditions_applied"></a> [conditions\_applied](#output\_conditions\_applied) | The permanent assignments that carry an ABAC condition. |
| <a name="output_guarded_assignments"></a> [guarded\_assignments](#output\_guarded\_assignments) | Keys of assignments that received the privileged-delegation deny condition. |
| <a name="output_pim_active_role_assignment_ids"></a> [pim\_active\_role\_assignment\_ids](#output\_pim\_active\_role\_assignment\_ids) | Ids of the PIM active assignments (empty unless enable\_pim\_examples is true). |
| <a name="output_pim_eligible_role_assignment_ids"></a> [pim\_eligible\_role\_assignment\_ids](#output\_pim\_eligible\_role\_assignment\_ids) | Ids of the PIM eligible assignments (empty unless enable\_pim\_examples is true). |
| <a name="output_role_assignment_ids"></a> [role\_assignment\_ids](#output\_role\_assignment\_ids) | Map of assignment key to role assignment id (all types). |
| <a name="output_role_assignment_ids_zipmap"></a> [role\_assignment\_ids\_zipmap](#output\_role\_assignment\_ids\_zipmap) | Map of assignment key to { name, id }. |
<!-- END_TF_DOCS -->
