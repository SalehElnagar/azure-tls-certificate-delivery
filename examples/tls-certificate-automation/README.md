# Your certificate renewed. Are clients receiving it?

A working disposable lab for Terraform, Key Vault, Acmebot and Application Gateway v2.
On 2026-10-20UTC it demonstrated new certificates in Key Vault while public listeners
still served their predecessors, including a zero-change gateway plan. An explicit
gateway tag update was followed by both replacement certificates and correct app
responses, with three confirming samples per hostname. This is manual replacement
and operator-triggered refresh evidence; passive polling and scheduled renewal
remain unobserved. The LinkedIn article is maintained separately as an unpublished draft.

## Code and lifecycle

- bootstrap: fresh private state container and container-scoped operator Blob role in an approved existing account.
- identity: dedicated single-tenant API registration/service principal and issue-only operator assignment, without a client password.
- foundation: DNS child zone, VNet/private vault/DNS, separate issuer/gateway/verifier identities, Flex issuer/storage, two restricted synthetic backends, audit configuration and private verifier VM with explicit NAT egress.
- Acmebot: DNS-01 issuance and manual replacement into the certificate-only vault.
- edge: Standard_v2 gateway, two SNI HTTPS listeners, versionless secret references, HTTPS backends, child A records and diagnostics.
- scripts: deterministic app/wrapper artifacts, pinned-package verification, public-certificate fingerprint reads, TLS validation and single-POST issuer client with private operation receipts.

Normal ordering is bootstrap -> identity -> foundation -> issuance -> edge. A first
certificate must exist before its listener. The live partial-deployment recovery
used a targeted vault repair and exact declarative gateway import; these are
incident exceptions, not routine sequencing. Backend app access uses a gateway
subnet service endpoint, not app private endpoints. The vault has a private endpoint,
public access Disabled and a documented trusted-service exception. Issuer storage
remains network reachable with RBAC/shared-key restrictions. No WAF/HA claim is made.

## Run local checks

Prerequisites: Terraform 1.14.7, Python 3.9+, actionlint 1.7.12; locked AzureRM 4.81.0
and AzureAD 3.7.0. From this example directory:

```sh
make validate
```

The current suite runs18 Python tests, schema checks, ten mocked Terraform runs and
actionlint with backend=false. The positive edge apply occurs only in a mock
provider. No cloud credentials are needed. The22-test combined suite additionally
passed four real loopback TLS tests using temporary keys on macOS after user
authorization; the Linux sandbox did not start. Hosted CI was not executed.
The pipeline at pipelines/source-ci.yml remains inactive and obtains no cloud token.

Use [the runbook](docs/live-runbook.md) for exact sequencing, private state handling,
CA/deployment contracts and reconciliation. [The claim ledger](docs/claims.md) and
[review](docs/security-review.md) distinguish live/local/documented/unverified results.
The LinkedIn article and teaser are maintained separately; they are not part of this code release.

## Material limits

The issuer's empty AzureWebJobsStorage workaround runs successfully but does not
converge cleanly with AzureRM 4.81.0. Checkov remains failed; Gitleaks found0 secrets.
Independent review was unavailable. The managed-root validation inventory differs
from the larger shared workspace's retained missing-article failures. State/plans
can contain provider credentials despite keeping the TLS PFX out of Terraform.
Resolve these production requirements before reuse. At the last recorded readback no cleanup had run;
current resource state is not asserted by this release. See the sanitized
[verification report](../../reports/tls-certificate-automation-final.md).
