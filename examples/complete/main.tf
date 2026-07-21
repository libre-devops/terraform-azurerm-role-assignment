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
      description = "Reads resource groups; a minimal custom role demonstrating define-then-assign."
      permissions = {
        actions = ["Microsoft.Resources/subscriptions/resourceGroups/read"]
      }
    }
  }

  role_assignments = merge(
    local.permanent_assignments,
    { for k, v in local.pim_assignments : k => v if var.enable_pim_examples },
  )
}
