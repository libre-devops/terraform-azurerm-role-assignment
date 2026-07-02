# Plan-time tests for the module. The azurerm provider is mocked, so no credentials, no features
# block, and no cloud calls are needed (PIM here needs no Entra ID P2):
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}

# Default-on delegation guard: privileged roles are guarded, ordinary roles are not.
run "guard_defaults_on_for_privileged" {
  command = plan

  variables {
    role_assignments = {
      reader = {
        scope         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
        principal_ids = ["11111111-1111-1111-1111-111111111111"]
        role_names    = ["Reader"]
      }
      owner = {
        scope         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
        principal_ids = ["22222222-2222-2222-2222-222222222222"]
        role_names    = ["Owner"]
      }
    }
  }

  assert {
    condition     = azurerm_role_assignment.this["reader|r0|p0"].condition == null
    error_message = "A non-privileged role (Reader) should not receive the delegation guard."
  }

  assert {
    condition     = azurerm_role_assignment.this["owner|r0|p0"].condition != null
    error_message = "A privileged role (Owner) should receive the delegation guard by default."
  }

  assert {
    condition     = azurerm_role_assignment.this["owner|r0|p0"].condition_version == "2.0"
    error_message = "The guard condition must set condition_version 2.0."
  }
}

# The guard can be opted out per assignment.
run "guard_opts_out" {
  command = plan

  variables {
    role_assignments = {
      owner = {
        scope                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
        principal_ids        = ["22222222-2222-2222-2222-222222222222"]
        role_names           = ["Owner"]
        constrain_delegation = false
      }
    }
  }

  assert {
    condition     = azurerm_role_assignment.this["owner|r0|p0"].condition == null
    error_message = "constrain_delegation = false should suppress the guard even for a privileged role."
  }
}

# A privileged role identified by its definition id (not name) is still guarded.
run "guard_detects_privileged_by_id" {
  command = plan

  variables {
    role_assignments = {
      byid = {
        scope         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
        principal_ids = ["33333333-3333-3333-3333-333333333333"]
        role_ids      = ["/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635"]
      }
    }
  }

  assert {
    condition     = azurerm_role_assignment.this["byid|r0|p0"].condition != null
    error_message = "A privileged role given by definition id (Owner GUID) should be guarded."
  }
}

# One entry expands over principal_ids x roles.
run "cartesian_expansion" {
  command = plan

  variables {
    role_assignments = {
      multi = {
        scope         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
        principal_ids = ["11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222"]
        role_names    = ["Reader", "Contributor"]
      }
    }
  }

  assert {
    condition     = length(azurerm_role_assignment.this) == 4
    error_message = "Two principals x two roles should create four assignments."
  }

  assert {
    condition     = azurerm_role_assignment.this["multi|r1|p1"].role_definition_name == "Contributor"
    error_message = "Index-based keys should map r1 to the second role and p1 to the second principal."
  }
}

# PIM active: a separate resource, resolved role definition id, schedule and ticket.
run "pim_active" {
  command = plan

  variables {
    role_assignments = {
      pa = {
        scope           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
        principal_ids   = ["11111111-1111-1111-1111-111111111111"]
        role_names      = ["Reader"]
        assignment_type = "pim_active"
        justification   = "temporary access"
        ticket          = { number = "INC1", system = "snow" }
        schedule        = { expiration = { duration_hours = 8 } }
      }
    }
  }

  assert {
    condition     = length(azurerm_pim_active_role_assignment.this) == 1 && length(azurerm_role_assignment.this) == 0
    error_message = "assignment_type pim_active should create only a PIM active assignment."
  }

  assert {
    condition     = azurerm_pim_active_role_assignment.this["pa|r0|p0"].justification == "temporary access"
    error_message = "The justification should flow through to the PIM active assignment."
  }
}

# PIM eligible: a privileged eligible role is guarded (this resource supports a condition).
run "pim_eligible_guarded" {
  command = plan

  variables {
    role_assignments = {
      pe = {
        scope           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
        principal_ids   = ["44444444-4444-4444-4444-444444444444"]
        role_names      = ["Owner"]
        assignment_type = "pim_eligible"
      }
    }
  }

  assert {
    condition     = length(azurerm_pim_eligible_role_assignment.this) == 1
    error_message = "assignment_type pim_eligible should create a PIM eligible assignment."
  }

  assert {
    condition     = azurerm_pim_eligible_role_assignment.this["pe|r0|p0"].condition != null
    error_message = "A privileged eligible role should carry the delegation guard condition."
  }
}
