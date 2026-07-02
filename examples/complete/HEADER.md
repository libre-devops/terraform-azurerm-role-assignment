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
