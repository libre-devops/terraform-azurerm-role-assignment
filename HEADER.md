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
