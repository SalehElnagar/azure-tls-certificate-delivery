# Lab cost estimate — 2026-10-19

USD retail estimate for Canada Central, 24 hours provisioned, before tax, exchange
rates or subscription discounts. This is a planning estimate, not observed billing
or a spending cap. No credits or free usage are assumed. Foundation and edge were subsequently deployed; this remains a model rather than a bill. No cleanup has occurred and charges continue.

| Component | Verified retail rate | 24-hour model |
|---|---|---|
| Shared Linux B1 app plan | $0.018/hour | $0.432 |
| Regular Linux B2ats_v2 verifier | $0.0105/hour | $0.252 |
| Standard NAT gateway | $0.045/hour | $1.080 |
| Foundation Standard IPv4 | $0.005/hour | $0.120 |
| One private endpoint | $0.01/hour | $0.240 |
| Public and private DNS zones | $0.50/zone-month at first tier | About $0.033, using 730 hours/month |
| Verifier Standard HDD | S4 LRS $1.69/month plus transactions | About $0.056 if the image-derived disk uses the 32 GiB S4 tier |
| Later Standard_v2 gateway | $0.24/hour + $0.008/CU-hour | $7.680 at 10 reserved CUs |
| Later gateway Standard IPv4 | $0.005/hour | $0.120 |

The foundation subtotal is about **$2.21/day**, and foundation plus edge about
**$10.01/day**, under the explicit S4-disk and ten-CU assumptions above. The image
metadata read confirms x64, Gen2 and Trusted Launch support, but does not return
its OS disk size; verify the allocated tier after deployment and adjust that line.
The gateway is not in the foundation plan. One configured minimum gateway instance
reserves ten CUs; actual utilization above that reservation increases billing.
[Gateway billing model](https://learn.microsoft.com/en-us/azure/application-gateway/understanding-pricing)

Usage additions include:

- Analytics log ingestion: $2.76/GB without an assumed free allowance. One GB/day
  adds about $2.76/day. The configured one-GB daily cap can overshoot and stop
  monitoring; it is not a financial limit.
- Flex on-demand compute: $0.000037/GB-second and $0.40/million executions without
  free allowances. A 1,000 GB-second exercise adds $0.037. A two-instance scale
  setting applies per function group and is not a total-spend cap.
- NAT processing: $0.045/GB. Private endpoint processing: $0.01/GB in each direction
  at the first tier. Internet bandwidth is additional according to actual traffic.
- Hot LRS blob storage: $0.02/GB-month, plus versions, retained/deleted data and
  transactions. Per 10,000 operations: reads $0.0044; writes/list/create $0.055.
  Queue/table, disk, DNS, Key Vault and metric operations add usage charges.
- Log diagnostics target Log Analytics, which has ingestion charges but no separate
  platform-log export charge for that destination. No Event Hubs or log-export
  storage destination is configured.

A **$20/day planning allowance** provides room above the light lab model; it does
not authorize overage, enforce a cap or predict the invoice. The user has not set
a hard numeric cap. Review the actual scoped costs before any extension. The expiry
tag is metadata, not automatic cleanup. No automatic deletion is authorized.

Rates were captured from the official [Azure Retail Prices API](https://prices.azure.com/api/retail/prices)
with Consumption/USD filters for Canada Central (Global for NAT/private-link
meters). Raw meter responses and exact filter strings remain in private evidence;
the rows above omit operational identifiers. This estimate excludes separately
purchased CA products and makes no inference about Microsoft subscription credits.
[Retail API contract](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices),
[daily-cap limits](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/daily-cap),
[log export destination billing](https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/diagnostic-settings-faq).
