# Real article screenshots

These are crops of genuine browser captures from the disposable lab. No result,
text, checkbox or status was inserted or replaced. Cropping excludes account and
resource identifiers and unrelated records; JPEG crops were re-encoded with the
built-in macOS `sips` tool. Private originals and the crop/hash provenance remain
outside Git. Browser screenshots were captured through the Chrome extension;
the two current Azure captures are 1536 × 1048 pixels before cropping.

| Image | Captured UTC | What it supports | Limit |
|---|---|---|---|
| [Key Vault networking](assets/key-vault-networking.jpg) | 2026-10-20 18:37:45 | Public access disabled; trusted Microsoft services bypass selected | Configuration readback, not a photograph of the earlier denial or proof of the gateway packet path |
| [Gateway HTTPS backend health](assets/gateway-https-backends.jpg) | 2026-10-20 18:37:03 | Two backend probes Healthy, HTTPS/443, received HTTP 200 | Backend health does not establish the public listener certificate, all-instance coverage or uninterrupted availability |
| [Child-zone delegation](assets/child-zone-delegation.jpg) | 2026-10-19 23:53:30 | Four child-zone NS records with one-hour TTL in GoDaddy's saved-record view | Historical setup capture; crop omits the success toast and parent records; propagation was checked separately |

Times are the original capture-file completion times, not the time a setting
changed. The historical GoDaddy original is also bound by its retained lifecycle
record from 2026-10-19 23:54:15 UTC. The earlier stale TLS connection, zero-change
Terraform plan and explicit refresh have retained machine evidence, but no
contemporaneous screenshots. They have not been recreated or backdated for images.

Publication copies:

| File | Pixels | SHA-256 |
|---|---|---|
| `key-vault-networking.jpg` | 1188 × 340 | `3f2b938f62ed60afbd27e96b85338341b91540820428096c091a1c6e1f432dfb` |
| `gateway-https-backends.jpg` | 700 × 95 | `89dd0fcd40a5ce9bd44d1a216c9b3a252ccde6434b47901a20e72a7f09274176` |
| `child-zone-delegation.jpg` | 750 × 250 | `2f58964913695abb98006571f176dda7276dfa213bac52cf2e412982daeb045f` |

Each image was inspected at its publication size for legibility, accurate
captioning and accidental disclosure. Keep the captions when transferring the
draft into LinkedIn. These assets and the article remain unpublished.
