# Security, DevOps and platform review — 2026-10-20

This is a lead review of the current source and scoped live evidence. The reserved
independent reviewer was unavailable before starting; no substitute panel or
provider fallback was used. It is not an independent security sign-off or
production-readiness certification.

## Security evidence and limits

The issuer controls one dedicated DNS zone and one certificate-only vault.
DNS Zone Contributor can edit every record in that zone; Certificates Officer
is broader than issuance-only. Gateway Secrets User can export every backing
certificate secret in the vault. Isolation of the zone/vault is therefore part of
the boundary; no unrelated secrets belong there. Private keys remain exportable
software keys because the gateway integration needs PFX.

Current live observations: anonymous API 401, authenticated API 200, issue-only
revoke canary403, public certificate reads from the verifier over the exact private
IP, and secret 403 with no response-body read. Other-user issuance denial was not
tested. Both direct app origins returned403; both gateway routes returned the
correct public synthetic body. The public operator vault403 was ForbiddenByRbac;
it cannot be relabeled a firewall denial.

Vault public access remains Disabled/defaultDeny/RBAC, with the documented limited
trusted-services bypass as well as the private endpoint. The actual gateway packet
path was not captured. VM Run Command is powerful control-plane code execution;
the live runs bound exact VM/script/identity and never used SSH or public VM ingress.
The verifier NIC denies inbound traffic and uses an explicit NAT egress path.

Tokens are process-memory only. The public-certificate helper now refuses redirects;
a real urllib redirect fixture first demonstrated cross-origin forwarding, then
passed after the repair. Issuer requests refuse redirects/proxies and never retry
POST. Exclusive0600receipts retain accepted operation URLs after polling failure.
No secret/PFX Terraform data source exists. Other managed provider credentials can
still enter protected state; disabling their use does not make state publishable.

## DevOps evidence and limits

Separate roots encode bootstrap/identity/foundation/issuance/edge ordering. Current
local checks passed18 unit tests, ten Terraform mock runs, actionlint, and22 combined
unit/real-loopback tests on macOS. The Linux sandbox never started successfully;
hosted CI was not run. Managed-root make validate passed its distinct five-test
baseline; the larger shared inventory's missing-article failures remain separate.

The first edge create partially failed. Exact readback showed five tracked resources
and a Failed gateway absent from state. Recovery applied a vault-only saved plan,
then imported/updated that exact gateway and created diagnostics; no duplicate
create, destroy or IAM widening occurred. Both first demo uploads were retained:
an unexpected Location and initial status 404were reconciled read-only rather than
re-uploaded. Initial parser/format/socket/mirror fixture failures remain recorded.

Both manual replacements reached the endpoints after one explicit gateway tag
update. Three samples per hostname verified expected certificate identity and HTTP
body. The78.516-second first-confirmation interval is not exact transition latency
or an SLA. Passive four-hour polling, all-instance convergence, timer/ARI renewal,
uninterrupted availability and injected DNS/role-outage recovery remain unverified.

**Open production blocker:** the empty AzureWebJobsStorage repair makes this issuer
work, but AzureRM 4.81.0 continues proposing that reserved setting. Do not repeatedly
apply it or suppress the whole app-settings map. Resolve provider ownership and
prove clean convergence before promoting this pattern into production automation.

## Current scanner disposition

Gitleaks 8.30.1 found0 secrets in the example. Checkov 3.2.528 returned62 passed,
30 failed,0 skipped and0 parse errors. This is a failed scanner gate. The earlier
3.2.530 result 53/21 remains historical; different versions/check sets are not a
security trend. No blanket suppression was added.

| Checks | Disposition |
|---|---|
| AZURE_206/225/212/211 | LRS, B1/shared plan and single-region/minimum-one topology are lab choices, not production failover or zone redundancy |
| AZURE_71 | Synthetic backends access no protected service and have no identity; do not copy that choice to apps that need service access |
| AZURE_222/17/16/13 | Backends are public endpoints restricted by gateway subnet, with no client-cert/application login; only public synthetic text is served. Origin403 was observed; application security remains a production design task |
| AZURE_88 | No custom Azure Files mount is required by this dependency-free ZIP; no production storage-mount control is claimed |
| AZURE_50 | VM extensions remain enabled for the reviewed Run Command path; constrain operator authority and code digests |
| CKV2_AZURE_33/1 | Issuer storage is network reachable, uses Microsoft-managed encryption, RBAC and disabled shared-key/anonymous paths. Private storage/CMK requirements need explicit production design; this is a real residual tradeoff |
| AZURE_33 and CKV2_AZURE_21 | Source has blob/queue/table read/write/delete resource diagnostics; matching scanner interpretation needs care. Existing shared state-account audit policy is outside this lab's management scope; no live log-ingestion success is inferred |
| AZURE_59 | Source sets allow_nested_items_to_be_public=false. The failed policy remains recorded; no live anonymous Blob denial test was performed |
| AZURE_120 | Standard_v2 does not include WAF. No WAF protection is claimed; production ingress must assess it |
| CKV2_AZURE_31 | Gateway NSG association lives in edge; verifier NSG is on its NIC. Issuer/private-endpoint subnet NSG segmentation is absent and needs production assessment. Do not call all four findings false positives |

## Platform acceptance

The useful platform contract is expected public certificate identity plus a checked
hostname and application response, with explicit ownership of issuance and delivery.
This lab shares one gateway and app plan and is not self-service multi-tenant
infrastructure or an HA platform. Staging trust is local to the verifier client.
Before production reuse: resolve convergence, private connected delivery/storage,
alert ownership and log ingestion, certificate expiry/served-version monitoring,
recovery drills, tenant boundaries, capacity/SLOs, application/WAF controls and
independent review. No cleanup/publication has occurred; expiry is metadata only.
