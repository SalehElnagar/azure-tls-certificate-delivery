# Claim ledger — 2026-10-20 UTC

Current result: both synthetic endpoints served both manually replaced staging
certificates after an **operator-triggered gateway tag update**. Three samples per
hostname passed TLS identity/validity/trust and HTTP route checks. The passive
four-hour polling window and timer-driven renewal were not completed.

| Claim | Evidence class and source | Result / boundary |
|---|---|---|
| Stale, wrong-host, untrusted and short-lived certificates fail | Current local real loopback TLS; integration/test_real_tls.py | Four real TLS cases; 22 combined unit/loopback tests passed on macOS; no Linux-container pass |
| Issuer client records accepted operations and refuses duplicate receipt paths | Current local filesystem/urllib tests; tests/test_issuer_client.py | Receipt retained after failed status GET; existing receipt prevents POST; completed receipt retains operation URL |
| Public-reader bearer redirects are blocked | Current local real urllib redirect machinery with fake transports | Red demonstrated cross-origin forwarding; repaired helper rejects redirect before forwarding |
| Four roots validate with pinned providers | Current local make validate | 18 unit tests, ten mocked Terraform runs and actionlint passed; no hosted CI execution |
| Isolated state and API identity were provisioned | Prior live Azure/Graph observations, retained privately | Fresh private container and container-scoped Blob role; five dedicated API identity resources; no shared account changes |
| Foundation and child delegation exist | Live saved-plan apply/control plane/authoritative DNS | 43 foundation instances; four child NS records; original parent nameservers and 31 records preserved at delegation readback |
| Article images are actual lab screenshots | Original browser captures and crop/hash provenance; [screenshot notes](screenshots.md) | Two current Azure portal readbacks at 18:37 UTC on 20 October; one historical GoDaddy setup capture. No contemporaneous screenshot of the stale TLS condition exists |
| Issuer runtime accepts/denies requests | Current live HTTP | Anonymous401; authenticated certificate-list200; issue-only revoke canary 403; other-user issuance denial untested |
| Two initial certificates and two replacements exist | Current live issuer API plus independent public-certificate reads | Staging only; exact SAN/RSA2048/enabled/expiry/exportable-PFX policy checked; private material never extracted |
| Verifier cannot read backing secret | Current live VM identity probe |403; response body not read; public certificate reads succeeded via exact private endpoint IP |
| A public operator request demonstrates firewall denial | Current live request | Withheld:403 reported ForbiddenByRbac; this does not isolate firewall enforcement. Control plane reports public network Disabled |
| Missing trusted-services bypass broke gateway deployment | Live failure, exact role readback, Microsoft network procedure and saved-plan repair | Gateway recovered after bypass None->AzureServices; public network remains Disabled/defaultDeny/RBAC enabled; precise gateway packet path not measured |
| Partial gateway creation was reconciled safely | Live Azure/state readback and declarative-import saved plan | Existing Failed gateway imported and updated; no duplicate create/destroy or IAM change |
| Both baseline routes worked | Current live client | Expected TLS fingerprints, HTTP 200 and exact route-specific bodies; direct origins403 |
| Certificate creation and endpoint delivery diverged | Current live private-vault read plus public TLS probe | New first certificate observed while listener stayed old; zero-change edge plan; later both listeners still old before explicit refresh |
| Explicit gateway refresh delivered both replacements | Current live tag-only saved-plan apply plus client samples | First both-new sample78.516 seconds after apply launch; three later samples per host; not exact transition time, all-instance proof or availability SLA |
| Versionless references / four-hour polling / configuration-triggered checks | Current Microsoft primary documentation | Versionless and tag-triggered path configured/tested; passive four-hour behavior unobserved |
| Issuer host-storage workaround converges | Live follow-up Terraform plan | Failed: AzureRM 4.81.0 repeatedly proposes the empty reserved setting; no blanket ignore or clean-foundation claim |
| No TLS PFX is read by this IaC | Source/data-flow review and edge plan | No TLS-secret data resource or PFX value; state still contains other provider-managed credentials and is sensitive |
| Final static scanners pass | Current Checkov 3.2.528/Gitleaks 8.30.1 | Gitleaks 0; Checkov 62 passed/30 failed/0 skipped/0 parse errors. Findings retained; no security sign-off |
| Independent review completed | Tool result | Unavailable before reviewer start; lead security/DevOps/platform/Docs/Test/Clean Code review only |
| Whole shared workspace is green | Separate repository inventories and gate runs | Earlier managed-root gate passed; screenshot-phase recheck stopped after the unchanged capture-evidence shell test stalled. Larger shared-workspace missing-article failures retained; no fresh whole-repository green claim |
| Cleanup happened | None | Unexecuted; expiry tags are not deletion. Resources continue accruing charges |

Private receipts bind UTC, commands, source candidates, tool/provider/input/plan
digests and targets. The sanitized report is at
[reports/tls-certificate-automation-final.md](../../../reports/tls-certificate-automation-final.md).
No publication, production-CA issuance, destructive permission injection or
cleanup result is claimed.
