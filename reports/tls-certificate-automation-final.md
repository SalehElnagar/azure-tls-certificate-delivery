# TLS lab verification and article handoff

**The manual end-to-end lab is verified and the LinkedIn article remains a draft.**
Both certificates were issued and manually replaced through the staging issuer.
Independent public-certificate reads showed replacements while the gateway still
served predecessors. A tag-only saved-plan apply triggered an explicit gateway
refresh; both new certificates and correct HTTP responses were then observed,
followed by three passing samples per hostname. This is operator-triggered
recovery evidence. Passive four-hour polling and timer-driven renewal were not observed.

Observations: 2026-10-19–20 UTC. Base commit:
`8802d3350999d7787e5f229b3127fd44a0144c7e`. Live explicit-refresh source candidate:
`2fda3fe2503fead59c795b7bc9e7339c75894f12991e4dee94fe9eaa43e605d6`.
Final readback/plan candidate before prose-only polish:
`aca15066fedac7ffd9c48c01563d0fa791ce2a396545f47a61ef05e035eb49e7`.
The private final manifest/delta binds subsequent documentation-only edits;
runtime code, Terraform, lockfiles and pipeline hashes remain unchanged.

## Deliverables

- [Terraform and executable helpers](../examples/tls-certificate-automation/README.md)
- [Inactive source CI](../examples/tls-certificate-automation/pipelines/source-ci.yml)
- [Live/recovery runbook](../examples/tls-certificate-automation/docs/live-runbook.md)
- [Claim ledger](../examples/tls-certificate-automation/docs/claims.md)
- [Security/DevOps/platform review](../examples/tls-certificate-automation/docs/security-review.md)
- [Real screenshots and provenance notes](../examples/tls-certificate-automation/docs/screenshots.md)

## Article screenshot addition

The draft now embeds three genuine browser captures: the saved child-zone NS
records from 19 October, and current Key Vault networking and Gateway backend
health readbacks from 20 October at 18:37 UTC. Crops exclude identifiers and
unrelated records; private full originals and crop/hash provenance were retained.
Each publication copy was visually inspected. No earlier failure or stale TLS
moment was recreated for a screenshot. The network image shows selected settings;
backend probe health is not client-certificate evidence.

A fresh read-only check sampled one TLS/HTTP connection to each public hostname
on 20 October after those captures. Both matched the independently recorded
replacement public certificate hashes, verified the chain/hostname using only the
explicit staging roots, and returned HTTP 200 with the correct distinct app body.
This does not refresh the earlier Key Vault read or establish all-instance coverage.
No cloud configuration, DNS, certificate order or infrastructure state changed.

Screenshot verification checked all three JPEGs against their hashes, all 24
relative documentation links, the exact article HCL/source match, and the shared
and managed copies. The source guard passed 46 files; Gitleaks 8.30.1 found zero
secrets. A fresh managed-root `make validate` passed Terraform validation, its
one mock run and five Python tests, then stalled in the unchanged
`tests/test_capture_evidence.sh`. The observed local test subshell was terminated
after more than three minutes; the gate exited 2 and was not retried. Its output
is retained. The earlier managed-root pass below remains a prior observation;
the screenshot-phase whole-root recheck is incomplete, not green.

## Observed live sequence

| Event, 2026-10-20UTC | Evidence / result |
|---|---|
| Initial state/identity/foundation/delegation, prior approved phases | Private container and scoped Blob role; five dedicated identity objects; 43 foundation instances; four child NS records preserving 31 original records at delegation readback |
| Issuer host repair,02:41 | One empty AzureWebJobsStorage override; runtime subsequently anonymous 401/authenticated 200; 27 function metadata entries matched pinned ZIP |
| Initial certificate readback,03:00:14 | Both enabled staging RSA 2048/SAN/validity/exportable-PFX policies checked via exact private IP; verifier secret 403 without body read |
| Initial edge create | Failed with KeyVaultSecretAccessDenied; five supporting instances recorded; Failed gateway existed in Azure but was absent from Terraform state |
| Network/partial-state recovery | Exact vault-scoped Secrets User role verified; vault bypass None->AzureServices with public network Disabled/defaultDeny/RBAC preserved; exact gateway declaratively imported/recovered plus pending diagnostics |
| Demo deployment | One Entra-only ZIP upload each; unexpected Location/first status 404reconciled read-only; no duplicate upload |
| Baseline,03:29:18 | Both expected certificates, TLS 1.3, HTTP 200 and distinct correct app bodies; direct origins 403; ordinary trust rejected staging; wrong fingerprint probe failed |
| First manual replacement public readback,03:30:46 | New first public fingerprint; unchanged second certificate |
| Stale client/clean plan | First hostname still old and both app bodies healthy; edge plan proposed zero managed changes |
| Both replacement public readbacks,03:36:13 | Both expected new fingerprints independently verified; verifier secret 403 remained enforced |
| Pre-refresh client sample,03:37:03 | Both listeners still served old fingerprints with correct app responses |
| Explicit refresh apply launch,03:37:33 | One gateway tag update only; no IAM/network/listener/URI change |
| First both-new sample,03:38:51 | Both replacements and correct app bodies; 78.516 seconds after apply launch, not exact transition latency |
| Repeated verification,through 03:39:38 | Three passing samples per host plus public executable TLS probes |
| Final readback,03:47:21 | Gateway Running/Succeeded; both backend servers Healthy; parent NS unchanged; child A records match gateway; edge convergence plan zero changes |

The final foundation plan still proposes **one issuer setting update**:
AzureWebJobsStorage to empty. It was not applied. The issuer works, but this
workaround does not converge cleanly with AzureRM 4.81.0. No broad ignore_changes
or repeated apply hid that limitation. Final edge and foundation plans remain
private and unapplied. Their digests are recorded in private receipts.

## Verification and review

Terraform 1.14.7; AzureRM 4.81.0; AzureAD 3.7.0; Python 3.13.13; Azure CLI 2.87.0.

- Example make validate passed18 unit tests, ten mocked Terraform runs and actionlint.
- Combined local unit/real-loopback TLS suite passed22 tests on macOS, including
  four actual TLS cases. The Linux isolated runner did not start; no container pass.
- Earlier managed-root make validate passed its five-test Python baseline plus Terraform
  and shell checks. The shared workspace's current make validate ran22Python tests
  and failed nine missing-article assertions for a different feature. No unrelated
  article files were fabricated. It is not a whole-repository green result.
- Current Gitleaks 8.30.1 found0 secrets in the example. Checkov 3.2.528 reported
  62 passed/30 failed/0 skipped/0 parse errors. Findings and lab/production tradeoffs are
  classified in the review, with no blanket suppressions. Historical Checkov 3.2.530
  53/21 and earlier fixture/helper-scan failures remain separate observations.
- Lead review covers security, DevOps, platform engineering, IaC, Test Guard,
  Docs Guard and Clean Code Guard. Independent review was unavailable before start;
  the original reservation was not replaced or its budget reset.
- New public-reader redirect behavior first failed at the real urllib boundary,
  then passed. Receipt tests verify accepted evidence survives failed polling,
  exclusive paths prevent duplicate POST and completed operations retain their URL.
  The updated receipt client also completed the second manual live replacement.

## Material limits and retained failures

This is a staging lab, not production acceptance. The foundation convergence issue,
failed scanner, missing shared article package and unavailable independent reviewer
remain open. The design is single-region/shared-plan/Standard_v2 without WAF; issuer
storage is network reachable with RBAC and disabled shared-key/anonymous paths.
Private storage, segmentation, alert ownership/log ingestion, availability/capacity,
application controls and independent review need a production design.

No other-user issuance denial, passive four-hour observation, timer/ARI renewal,
all-instance proof, uninterrupted-availability measurement, injected DNS/role outage
or working-listener permission revocation was performed. Public operator vault 403
was ForbiddenByRbac, so it is not a proven firewall denial. Healthy runtime log
queries returned no rows earlier; authenticated execution and certificate behavior
provide the actual runtime proof instead.

Original controller/history loss was preserved; no history or budgets were recreated.
Direct execution used the human-approved exceptions and later direct continuation
instruction. Socket-path, ANSI-parser, formatting, incomplete-mirror-license and
inventory fixture failures were diagnosed and retained. An asynchronous raw backend
health request returned no JSON; the documented CLI read correctly followed the
health operation. No failed mutation was blindly replayed.

An unintended local log-analytics1.0.0b3 extension installation from an earlier
help command remains recorded and was not removed. Subsequent commands disabled
dynamic extension installation. Protected state/plans/credentials/contact/cloud IDs,
private operational wrappers and raw outputs remain outside Git with restricted
file permissions. No issuer package re-upload, production CA, push, PR or publication
was performed.

## Remaining lifecycle

Read-only ARM enumeration returned 28 entries in the dedicated lab resource group;
this is not a complete count of child/IAM/directory/state objects. It includes an
Application Insights action group absent from Terraform state; ownership/automatic
service creation must be attributed before any deletion scope is approved.
Bootstrap state resources live in the existing state account, and identity objects
live in Entra. No deletion ran. Expiry metadata proves no cleanup.

The recorded retail model is about USD10.01/day for foundation plus edge, before
usage/tax/discount differences; actual spend was not queried. At that readback the lab still existed; current spend and cleanup were not
checked for this code release. A cleanup proposal must bind fresh inventory and reviewed destroy
plans, preserve evidence, exclude the shared account/unrelated objects and account
for protected/soft-deleted vault data before seeking exact deletion authority.
