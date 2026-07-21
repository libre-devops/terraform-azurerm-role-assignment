<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Role Assignment

Azure RBAC and PIM assignments from one map, with a secure-by-default guard against re-delegating the
privileged roles.

[![CI](https://github.com/libre-devops/terraform-azurerm-role-assignment/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-role-assignment/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-role-assignment?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-role-assignment/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-role-assignment)](./LICENSE)

---

## Overview

Role assignments keyed by a logical label you choose, plus **custom Azure RBAC role definitions**
keyed by role name. Each assignment entry is expanded over the cartesian product of its
`principal_ids` and its `role_names` + `role_ids` + `role_definition_keys`, so one entry can grant
several roles to several principals at one scope. The module does four things a bare
`azurerm_role_assignment` cannot:

- **Secure-by-default delegation guard.** When an assignment grants a privileged role (Owner, User
  Access Administrator, or Role Based Access Control Administrator), the module attaches a Microsoft
  ABAC condition that denies the assignee the ability to create or delete role assignments for those
  same privileged roles. So a granted Owner cannot hand Owner to anyone else. It is on by default for
  privileged roles, opt out per assignment with `constrain_delegation = false`, and the privileged set
  is caller-overridable via `constrained_delegation_role_ids`.
- **PIM in the same interface.** Set `assignment_type` to `pim_active` (active, PIM managed, typically
  time-bound) or `pim_eligible` (the principal activates the role just-in-time) and the module creates
  the matching PIM resource. `role_names` are resolved to the role definition id PIM requires (via a
  data source), so you keep naming roles rather than pasting GUIDs. The guard also covers privileged
  `pim_eligible` grants.
- **Stable, plan-known keys.** Instance keys are index based (`label|rN|pN`), so assigning a role to a
  freshly created identity (a computed `principal_id`) never trips the "for_each argument must be known"
  error, and reordering inputs never churns unrelated assignments.
- **Define-then-assign custom roles.** `role_definitions` creates custom role definitions
  (actions/not_actions/data_actions, `assignable_scopes` defaulting to the definition's own scope) at
  a management group, subscription, or resource group, and assignments (permanent or PIM) reference
  them by key through `role_definition_keys` in the same call. Creating a definition needs
  `roleDefinitions/write` on the scope (Owner; User Access Administrator is not enough), and a check
  block flags wildcard-`*` custom roles (Owner-equivalents in disguise).

Assignments carry no tags and are global to their scope, so there is no `resource_group_id`, `location`,
or `tags` input. Pairs naturally with the `user-assigned-identity`, `keyvault`, and `storage-account`
modules to grant a workload identity exactly the access it needs.

## Usage

```hcl
module "role_assignment" {
  source  = "libre-devops/role-assignment/azurerm"
  version = "~> 4.0"

  role_assignments = {
    # Reader for a workload identity on a resource group.
    app_reader = {
      scope         = module.rg.ids["rg-ldo-uks-prd-001"]
      principal_ids = [module.identity.principal_ids["id-ldo-uks-prd-001"]]
      role_names    = ["Reader"]
    }

    # Owner for the platform group: the delegation guard is applied automatically.
    platform_owners = {
      scope         = module.rg.ids["rg-ldo-uks-prd-001"]
      principal_ids = [var.platform_group_object_id]
      role_names    = ["Owner"]
    }

    # Just-in-time Contributor via PIM eligibility, activated for up to 8 hours.
    break_glass = {
      scope           = module.rg.ids["rg-ldo-uks-prd-001"]
      principal_ids   = [var.oncall_group_object_id]
      role_names      = ["Contributor"]
      assignment_type = "pim_eligible"
      justification   = "On-call break-glass access"
      schedule        = { expiration = { duration_hours = 8 } }
    }
  }
}
```

## Examples

- [`examples/minimal`](./examples/minimal) - grant the running principal Reader on a resource group
  (required inputs only).
- [`examples/complete`](./examples/complete) - the full permanent surface: cartesian expansion over two
  principals (one with a computed id), the guard on and opted out, `principal_type`, and a role given by
  definition id. PIM active and eligible are exercised in [`tests`](./tests) with a mocked provider,
  since PIM needs Entra ID P2 that a test tenant may not carry.

## Developing

Local work needs **PowerShell 7+** and **[`just`](https://github.com/casey/just)**, because the recipes
wrap the [LibreDevOpsHelpers](https://www.powershellgallery.com/packages/LibreDevOpsHelpers)
PowerShell module (the same engine the `libre-devops/terraform-azure` action runs in CI). Install
just with `brew install just`, or `uv tool add rust-just` then `uv run just <recipe>`.

Run `just` to list recipes: `just update-ldo-pwsh` (install or force-update LibreDevOpsHelpers from
PSGallery), `just validate`, `just scan` (Trivy only), `just pwsh-analyze` (PSScriptAnalyzer only),
`just plan`, `just apply`, `just destroy`, `just e2e`, `just test`, and `just docs` (the
plan/apply/destroy recipes mirror the action, including the storage firewall dance; `just e2e`
applies an example then always destroys it, defaulting to `minimal`, so nothing is left running).
Releasing is also `just`:
`just increment-release [patch|minor|major]` bumps, tags, and publishes a GitHub release, and the
Terraform Registry picks up the tag.

## Security scan exceptions

This module is scanned with [Trivy](https://github.com/aquasecurity/trivy); HIGH and CRITICAL
findings fail the build. Any waiver is a deliberate, reviewed decision, never a way to quiet a
finding that should be fixed. Waivers live in [`.trivyignore.yaml`](./.trivyignore.yaml) (the
machine-applied source of truth, passed to Trivy with `--ignorefile`) and are mirrored in a table
here so the reason is auditable.

There are currently **no exceptions**: the module and its examples scan clean. A role assignment
grants access rather than deploying infrastructure, and the module's whole purpose is to make that
grant safer, so there is nothing to waive.

To add an exception: add an entry to `.trivyignore.yaml` (`id`, optional `paths` to scope it, and a
`statement` recording why), then add a matching row here recording the reason. Both the file and
the table are reviewed in the pull request.

## Reference

The Requirements, Providers, Inputs, Outputs, and Resources below are generated by `terraform-docs`.

<!-- BEGIN_TF_DOCS -->
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

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_pim_active_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/pim_active_role_assignment) | resource |
| [azurerm_pim_eligible_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/pim_eligible_role_assignment) | resource |
| [azurerm_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_role_definition.pim](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/role_definition) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_constrained_delegation_role_ids"></a> [constrained\_delegation\_role\_ids](#input\_constrained\_delegation\_role\_ids) | The privileged role definition ids (name => GUID) whose re-delegation is denied by the ABAC condition<br/>this module applies to privileged assignments. Defaults to the three roles that can grant Azure RBAC<br/>(Owner, User Access Administrator, Role Based Access Control Administrator). Extend this to treat more<br/>roles as privileged. The guard denies the assignee the ability to create or delete role assignments for<br/>any of these roles, so a granted Owner cannot hand Owner (or the other listed roles) to anyone else. | `map(string)` | <pre>{<br/>  "Owner": "8e3af657-a8ff-443c-a75c-2fe8c4bcb635",<br/>  "Role Based Access Control Administrator": "f58310d9-a9f6-439a-9e8d-f62e7b41a168",<br/>  "User Access Administrator": "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9"<br/>}</pre> | no |
| <a name="input_pim_role_definition_lookup_scope"></a> [pim\_role\_definition\_lookup\_scope](#input\_pim\_role\_definition\_lookup\_scope) | The scope at which PIM `role_names` are resolved to role definition ids (built-in roles resolve at any<br/>scope). Defaults to the current subscription. Set this when a PIM assignment uses a custom role defined<br/>at a different scope, or pass the full role definition id via `role_ids` instead. | `string` | `null` | no |
| <a name="input_role_assignments"></a> [role\_assignments](#input\_role\_assignments) | The role assignments to create, keyed by a logical label you choose (the label is only for readable<br/>plan output and stable addressing, it is not the Azure resource name). Each entry is expanded over the<br/>cartesian product of `principal_ids` and the combined set of `role_names` + `role_ids`, so one entry<br/>can assign several roles to several principals at one scope.<br/><br/>`assignment_type` selects how the role is granted:<br/><br/>- `permanent` (default): a standard `azurerm_role_assignment` (a persistent, always-active grant).<br/>- `pim_active`: a PIM active assignment (active now, but managed by PIM and typically time-bound).<br/>- `pim_eligible`: a PIM eligible assignment (the principal can activate the role just-in-time).<br/><br/>`role_names` are resolved to a role definition id automatically for the PIM types (which require the<br/>id, not the name); `role_ids` (full role definition resource ids) are used as-is; and<br/>`role_definition_keys` reference custom roles created in this call via `role_definitions`, so<br/>define-then-assign works in one module call. The privileged delegation guard (see<br/>`constrained_delegation_role_ids`) only applies to `permanent` and `pim_eligible` assignments, because<br/>`pim_active` has no condition argument. | <pre>map(object({<br/>    scope                = string<br/>    principal_ids        = optional(list(string), [])<br/>    role_names           = optional(list(string), [])<br/>    role_ids             = optional(list(string), [])<br/>    role_definition_keys = optional(list(string), [])<br/><br/>    assignment_type = optional(string, "permanent")<br/>    principal_type  = optional(string)<br/>    description     = optional(string)<br/><br/>    # permanent (azurerm_role_assignment) only<br/>    name                                   = optional(string)<br/>    condition                              = optional(string)<br/>    condition_version                      = optional(string)<br/>    delegated_managed_identity_resource_id = optional(string)<br/>    skip_service_principal_aad_check       = optional(bool)<br/><br/>    # null: apply the delegation guard automatically when the role is privileged (secure default).<br/>    # true: always apply it. false: never apply it. Ignored for pim_active (no condition support).<br/>    constrain_delegation = optional(bool)<br/><br/>    # PIM (pim_active / pim_eligible) only<br/>    justification = optional(string)<br/>    ticket = optional(object({<br/>      number = optional(string)<br/>      system = optional(string)<br/>    }))<br/>    schedule = optional(object({<br/>      start_date_time = optional(string)<br/>      expiration = optional(object({<br/>        duration_days  = optional(number)<br/>        duration_hours = optional(number)<br/>        end_date_time  = optional(string)<br/>      }))<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_role_definitions"></a> [role\_definitions](#input\_role\_definitions) | Custom Azure RBAC role definitions to create, keyed by role name (custom role names are unique per<br/>tenant, so make them distinctive). `scope` is where the definition is stored (a management group,<br/>subscription, or resource group id); `assignable_scopes` defaults to just that scope when empty.<br/>`permissions` holds the control-plane `actions`/`not_actions` and data-plane<br/>`data_actions`/`not_data_actions`. Assignments in the same call reference a definition through<br/>`role_definition_keys`. Creating a definition needs `Microsoft.Authorization/roleDefinitions/write`<br/>on the scope (Owner; User Access Administrator is NOT enough). A freshly created definition can take<br/>a short while to become assignable (Azure RBAC replication), so a first apply may need a retry when<br/>the definition and a same-call assignment race. | <pre>map(object({<br/>    scope              = string<br/>    description        = optional(string)<br/>    assignable_scopes  = optional(list(string), [])<br/>    role_definition_id = optional(string)<br/>    permissions = object({<br/>      actions          = optional(list(string), [])<br/>      not_actions      = optional(list(string), [])<br/>      data_actions     = optional(list(string), [])<br/>      not_data_actions = optional(list(string), [])<br/>    })<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_conditions_applied"></a> [conditions\_applied](#output\_conditions\_applied) | The permanent assignments that carry an ABAC condition, with their principal, role, scope, and condition version. |
| <a name="output_guarded_assignments"></a> [guarded\_assignments](#output\_guarded\_assignments) | The keys of assignments that received the privileged-delegation deny condition. |
| <a name="output_pim_active_role_assignments"></a> [pim\_active\_role\_assignments](#output\_pim\_active\_role\_assignments) | The PIM active assignments, keyed by "label\|rN\|pN". Full resource objects. |
| <a name="output_pim_eligible_role_assignments"></a> [pim\_eligible\_role\_assignments](#output\_pim\_eligible\_role\_assignments) | The PIM eligible assignments, keyed by "label\|rN\|pN". Full resource objects. |
| <a name="output_principal_ids"></a> [principal\_ids](#output\_principal\_ids) | The distinct principal ids that received an assignment. |
| <a name="output_role_assignment_ids"></a> [role\_assignment\_ids](#output\_role\_assignment\_ids) | All assignment ids across the three types, keyed by "label\|rN\|pN". |
| <a name="output_role_assignment_ids_zipmap"></a> [role\_assignment\_ids\_zipmap](#output\_role\_assignment\_ids\_zipmap) | key => { name, id } across all assignment types, for easy composition with other modules. |
| <a name="output_role_assignments"></a> [role\_assignments](#output\_role\_assignments) | The permanent (azurerm\_role\_assignment) assignments, keyed by "label\|rN\|pN". Full resource objects (all attributes). |
| <a name="output_role_definition_guids"></a> [role\_definition\_guids](#output\_role\_definition\_guids) | Map of custom role name to the role definition GUID (the name portion of the id). |
| <a name="output_role_definition_ids"></a> [role\_definition\_ids](#output\_role\_definition\_ids) | Map of custom role name to the full role definition resource id (feed this to role\_ids in other calls or modules). |
| <a name="output_role_definition_ids_zipmap"></a> [role\_definition\_ids\_zipmap](#output\_role\_definition\_ids\_zipmap) | Map of custom role name to an object of its name and full resource id, for easy composition. |
| <a name="output_role_definitions"></a> [role\_definitions](#output\_role\_definitions) | Map of custom role name to its useful attributes. |
| <a name="output_scopes"></a> [scopes](#output\_scopes) | The distinct scopes assignments were created at. |
<!-- END_TF_DOCS -->
