# GOD GEAR™ Order Relay — Shopify Flow → Printful (draft orders)

Trigger: **Order created** (paid orders only, via condition).
Scope: only line items whose variant has metafield `gg.printful`. The 2 Printful-synced live
products have no such metafield, so Printful's own app keeps fulfilling them as today.
Safety: orders are created in Printful as **drafts** (`confirm` omitted → draft). Nothing is charged
or produced until confirmed. Flip to auto-confirm later by adding `?confirm=true` to the URL.

## Condition
`order.displayFinancialStatus` is `PAID`

## Action: Send HTTP request
- Method: `POST`
- URL: `https://api.printful.com/orders`
- Headers:
  - `Content-Type`: `application/json`
  - `Authorization`: `Bearer {{secrets.PRINTFUL_TOKEN}}`   (Flow secret, never in chat)
  - `X-PF-Store-Id`: `18823775`
- Body (Liquid):

```liquid
{"external_id":"GG{{order.name | remove: "#"}}","shipping":"STANDARD","recipient":{"name":"{{order.shippingAddress.name}}","address1":"{{order.shippingAddress.address1}}","address2":"{{order.shippingAddress.address2}}","city":"{{order.shippingAddress.city}}","state_code":"{{order.shippingAddress.provinceCode}}","country_code":"{{order.shippingAddress.countryCodeV2}}","zip":"{{order.shippingAddress.zip}}","phone":"{{order.shippingAddress.phone}}","email":"{{order.email}}"},"items":[{% assign first = true %}{% for li in order.lineItems %}{% for mf in li.variant.metafields %}{% if mf.namespace == "gg" and mf.key == "printful" %}{% unless first %},{% endunless %}{"quantity":{{li.quantity}},"external_id":"{{li.id | split: "/" | last}}",{{mf.value}}}{% assign first = false %}{% endif %}{% endfor %}{% endfor %}]}
```

## Variant metafield format (`gg.printful`, multi_line_text_field)
`"variant_id":<printful catalog variant id>,"files":[{"type":"<placement>","url":"<raw github art url>"}],"options":[{"id":"thread_colors_<x>","value":["#HEX"]}]`

Written by the agent for every line variant from `rail/line/gg-line.json` + `pf.sh map`.
