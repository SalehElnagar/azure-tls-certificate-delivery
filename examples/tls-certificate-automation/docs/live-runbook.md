# Live verification and recovery runbook

This is a reproducible procedure and evidence guide, not a shell transcript.
Actual targets, operator/contact IDs, private inputs, tokens, state, saved plans,
receipts and raw outputs belong in a private directory outside Git. Public names
below use example.com. The recorded live result is in [claims.md](claims.md).

## Prepare the target and state

Verify the selected subscription/tenant/operator, regional quotas and supported
Flex .NET10 runtime, exact VM image, provider registrations and resource-name
availability. Review current regional cost. This run's model was approximately
USD10.01/day for foundation plus edge, before usage/tax/discount differences;
it is an estimate, not measured spend or a hard cap. Expiry tags do not delete resources.

Use a fresh private container in the approved state account, with separate
identity/foundation/edge keys and Entra backend authentication. Bootstrap manages
only that container and a container-scoped operator Blob role. It does not manage
the shared account or unrelated state. A control-plane Owner role did not provide
Blob access in the live run; the scoped data role repaired it without key fallback.

Protect local bootstrap state too. Never publish terraform output JSON, raw plans,
bootstrap output or backend files. Provider state may contain managed storage
keys/publishing credentials even when those authentication paths are disabled.

For every live change, bind current readback, exact target/operator, source/input/
lock/tool/package/plan hashes and existing authority. Review the saved plan before
its apply. Reconcile a failed or uncertain operation before considering another
mutation. The source tree and successful tests do not confer execution authority.

## Provision in lifecycle order

Normal sequence: **bootstrap -> identity -> foundation -> issuer deployment and
issuance -> edge**. These are separate Terraform roots. Do not put a placeholder
PFX into the first deployment or use resource targeting as routine sequencing.

Identity creates dedicated single-tenant API objects, an issue-only operator role
and API-specific CLI preauthorization, with no password or changes to existing
application registrations. Foundation creates the lab VNet, private vault/DNS,
managed identities, issuer/storage, synthetic backends and verifier VM.

Generic saved-plan form, run from the reviewed root with private absolute paths:

```sh
terraform init -input=false -lockfile=readonly -backend-config="$BACKEND_FILE"
terraform plan -input=false -lock-timeout=60s -var-file="$INPUT_FILE" -out="$SAVED_PLAN"
terraform apply -input=false -lock-timeout=60s "$SAVED_PLAN"
```

The apply requires the matching reviewed plan and current authority; these commands
must not be copied into credential-free source CI. Keep private TF_DATA_DIR per
root. On macOS, use a short private TMPDIR: an excessively long provider socket
path prevented the local regression runner from starting until that path was shortened.

Create the child Azure DNS zone first. Read its four authoritative nameservers,
then add only that child's NS records in the parent DNS manager. Preserve parent
nameservers and unrelated records. Check authoritative NS/SOA, CAA and challenge
resolution. Live delegation and DNS-01 issuance succeeded in this lab.

## Deploy the pinned issuer and demo

Verify the exact Acmebot release using upstream.lock.json:

```sh
python3 scripts/verify_package.py "$ISSUER_ZIP"
python3 scripts/build_artifacts.py demo --output "$DEMO_ZIP"
```

The issuer ZIP is pinned to v5.1.5 and its reviewed SHA256. A matching hash is an
integrity check, not a vulnerability assessment. The synthetic demo ZIP contains
only app.py at archive root; its Gunicorn startup loads app:app and LAB_APP_NAME
distinguishes the one/two responses.

The live operator used Entra bearer authentication and exactly one ZIP POST per
target, without publishing profiles, basic authentication or host master keys:

| Target | Observed deployment contract |
|---|---|
| Flex issuer SCM origin | POST /api/publish?RemoteBuild=false&Deployer=mvp_tls_lab, application/zip |
| Each demo SCM origin | POST /api/publish?type=zip&async=true&restart=true&clean=true, binary ZIP |
| Status | GET /api/deployments/latest, then bind the returned deployment ID and fresh start_time |

All these paths are relative to the exact reviewed app's HTTPS SCM origin. Tokens
stay in memory; redirects/proxies are refused; no POST retry occurs. Ignore an
untrusted Location and reconcile at the known SCM origin. The actual demo Location
contained explicit :443 and deployment query parameters; the original strict
parser stopped, then read-only status reconciliation completed without another
upload. The second app initially returned404 from status before its deployment
record appeared; a later read confirmed completion. These failures remain recorded.

Do not substitute a CLI deployment path without auditing its hidden calls. The
stock Flex path inspected in Azure CLI 2.87.0 can read a host master key for health
checking; it was not invoked here. [Pinned CLI source](https://github.com/Azure/azure-cli/blob/azure-cli-2.87.0/src/azure-cli/azure/cli/command_modules/appservice/custom.py)

The first issuer host needed AzureWebJobsStorage explicitly empty because a
provider-generated exact connection string overrode identity-based host settings.
The repair produced anonymous 401/authenticated 200 and working staging orders.
**AzureRM 4.81.0 still proposes the empty setting after refresh.** This is an
unresolved convergence limitation; do not apply repeatedly or hide the whole
settings map with ignore_changes. Resolve provider ownership before production reuse.

## Issue and independently read certificates

Review CA environment/contact/terms first. This run used the previously approved
Let's Encrypt staging endpoint and Subscriber Agreement. No production CA was used.
The pinned API uses Entra roles; a Functions key is insufficient.

Create a private issuance JSON containing certificateName, dnsNames,
dnsProviderName="Azure DNS", keyType="RSA", keySize=2048 and reuseKey=false.
Then use a fresh private receipt path:

```sh
python3 scripts/issuer_request.py --endpoint "$ISSUER_ORIGIN" \
  --subscription "$SUBSCRIPTION_ID" --scope "$ISSUER_TOKEN_SCOPE" \
  --issue-request "$ISSUE_JSON" --receipt "$PRIVATE_RECEIPT"
```

The client makes one POST and polls a validated same-origin operation. A completed
API operation still needs independent public-certificate readback. The receipt is
exclusive and mode 0600; after an uncertain request, inspect the accepted operation
or existing certificates, rather than deleting the receipt to try again. fsync
reduces evidence loss; it does not make an ambiguous network outcome reversible.

On the approved private VM, prepare and inspect the exact wrapper before Run Command:

```sh
python3 scripts/build_artifacts.py verifier --output "$VERIFIER_SCRIPT" \
  --vault-url "$VAULT_URI" --certificate app-one-staging --client-id "$VERIFIER_CLIENT_ID"
```

public_certificate.py obtains an IMDS token in memory and reads only /certificates.
The live target-bound wrapper additionally checked exact private DNS resolution,
actual SAN/RSA/issuer/expiry and exportable PFX policy. A separate status-only
/secrets read returned403 with its body unread. A403 from an operator's public
request reported ForbiddenByRbac, so it does not establish firewall enforcement.

## Provision edge and check delivery

The vault needs public network Disabled, defaultDeny, RBAC, private endpoint/DNS
and the documented AzureServices trusted-service bypass. The gateway uses its own
Key Vault Secrets User identity; the verifier has Reader. Do not put unrelated
secrets in this certificate-only vault. [Microsoft network procedure](https://learn.microsoft.com/en-us/azure/application-gateway/key-vault-certs)

Pass the reviewed foundation output object to edge rather than granting general
foundation-state access. For staging set certificate_names to app-one-staging and
app-two-staging. Review that the edge plan contains versionless secret references
and no PFX data. Apply only the reviewed saved plan. Verify gateway/backend health.

The first live edge apply partially succeeded and left an Azure Failed gateway
absent from state. Recovery reviewed current state and the exact owned Azure ID,
repaired only the vault bypass with a targeted recovery plan, then used a private
declarative import overlay plus one gateway tag update and pending diagnostics.
Five already recorded resources remained unchanged. Targeting/import were bounded
incident recovery exceptions, not the normal provisioning sequence.

For both hostnames, obtain expected fingerprints independently and run:

```sh
python3 scripts/tls_probe.py --hostname one.tls-lab.example.com \
  --expected-sha256 "$EXPECTED_SHA256" --min-days 7 --ca-file "$STAGING_CA_FILE"
```

The TLS probe checks chain/name/expiry/fingerprint, not HTTP. Check HTTP 200 and the
exact expected app response separately. Direct origins should deny the operator
path; both returned403in this run. Use staging roots only in this lab client;
never use -k or modify the ordinary trust store.

## Manual replacement and explicit refresh

```sh
python3 scripts/issuer_request.py --endpoint "$ISSUER_ORIGIN" \
  --subscription "$SUBSCRIPTION_ID" --scope "$ISSUER_TOKEN_SCOPE" \
  --renew app-one-staging --receipt "$NEW_PRIVATE_RECEIPT"
```

Read the new public fingerprint, then sample both endpoints. The unchanged host
is a useful control. This run captured new Key Vault bytes, an old first listener
and a zero-change gateway Terraform plan. It subsequently replaced the second
certificate and verified both new public fingerprints.

For deliberate operator-triggered synchronization, set certificate_refresh_marker
to a new non-sensitive marker in private edge inputs. Review a plan containing
**one gateway tag update only**, then apply that saved plan. Retain the marker
afterward. The live drill changed only certificate_refresh to replacement-drill-1.
Both new certificates and correct responses were observed78.516 seconds after apply
launch, followed by three passing samples per host. Exact transition time, every
instance and uninterrupted availability were not measured.

For passive verification, leave the gateway unchanged and observe through the
documented four-hour interval plus an operational margin. That full window was
not run. Scheduled renewal separately needs timer/ARI or fallback decisions,
operation completion and later endpoint evidence. The manual drills prove neither.

Do not revoke gateway access casually: it can disable listeners. This lab used
the naturally failed initial provisioning/recovery and non-destructive denial
probes; it did not inject a DNS outage, revoke a working gateway role or disable a certificate.

## Lifecycle

No cleanup has run. Read current resources and delegation, prepare reviewed
destroy plans for edge/foundation/identity/bootstrap in that order, and obtain
exact deletion authority before execution. Never delete the shared state account
or unrelated blobs/records. Removing the lab container would remove its state;
preserve required private evidence first. Key Vault purge protection retains
soft-deleted data. Report actual remaining resources after deletion; tags and
repository prose are not cleanup evidence.
