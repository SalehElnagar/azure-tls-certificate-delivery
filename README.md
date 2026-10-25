# Azure TLS certificate delivery lab

Terraform, Acmebot, Key Vault and Application Gateway v2 companion code for a real certificate-delivery drill.

On 20 October 2026, the lab observed replacement certificates in Key Vault while the public listeners still served their predecessors. An explicit gateway tag update was followed by verified replacement certificates and correct app responses at both hostnames. Passive polling and timer-driven renewal were not observed.

## Start here

- [Lab code and limitations](examples/tls-certificate-automation/README.md)
- [Live runbook](examples/tls-certificate-automation/docs/live-runbook.md)
- [Claim ledger](examples/tls-certificate-automation/docs/claims.md)
- [Security, DevOps and platform review](examples/tls-certificate-automation/docs/security-review.md)
- [Real screenshot provenance](examples/tls-certificate-automation/docs/screenshots.md)
- [Sanitized verification report](reports/tls-certificate-automation-final.md)

## Local validation

Use Terraform 1.14.7, Python 3.9+ and actionlint 1.7.12, with the checked-in provider locks. From this repository root:

```sh
make validate
```

The Makefile delegates to the lab's credential-free local unit/schema/mock checks. The pipeline example is inactive under `pipelines/`; this repository installs no hosted workflow and deploys nothing automatically.

## Scope

This is a disposable staging lab, not a production reference deployment. The issuer's reserved host-storage setting does not converge cleanly with AzureRM 4.81.0; scanner findings, production design gaps and unavailable independent review are documented. Runtime observations are historical and do not establish current Azure state or cleanup.

No tenant/subscription identifiers, private operational inputs, state, plans, credentials or private keys are part of this release. The full LinkedIn article and teaser remain separate unpublished drafts. Read the runbook before proposing any deployment or cleanup.
