# GOD GEAR™ — Resume Point (checkpoint 2026-11-01, line v1 built)

## Live (untouched)
- Store ggmovement818.myshopify.com (Basic plan). Checkout verified.
- GG ACTIVE™ Tee 10288338567360 + GG MOVE™ Hoodie 10248986656960 — Printful-synced, DO NOT TOUCH.

## Line v1 — built, HIDDEN (DRAFT), awaiting Founder "Done"
| Key | Shopify product | Colors | Variants |
|---|---|---|---|
| active-tee | 10310626607296 | 6 | 42 |
| move-hoodie | 10310626640064 | 5 | 36 |
| classic-crew | 10310626672832 | 6 | 43 |
| flow-sweats | 10310626705600 | 4 | 20 |
| culture-dad | 10310626738368 | 5 | 5 |
| culture-cap | 10310626771136 | 5 | 10 |
- All media on Shopify CDN + archived in rail/art/mockups/line-v{1,2,3}-media (SHA-256).
- v1 Black tonal images REJECTED by CRITIC (invisible logo) — detached from products, kept in archive.
- Approval sheet: rail/review/GG-LINE-V1-APPROVAL.jpg
- Each product has metafield godgear.printful (hex map, Printful variant ids, files, thread options).

## Order relay (proven)
- Shopify Flow: Order paid → Run code (rail/relay/flow-run-code.js) → Send HTTP request POST https://api.printful.com/orders (draft).
- Payload verified against Printful /orders/estimate-costs: HTTP 200 (relaytest op).
- Needs one-time Founder setup in Flow (Printful token as Flow secret). Paste blocks: rail/relay/FLOW-SETUP.md

## On Founder "Done"
1. productUpdate status ACTIVE for the 6 drafts + publishablePublish (Online Store 221335879872, Shop 221335945408).
2. Add to collections; verify storefront + variant images.
3. After Flow is on: place no real order; watch first real order → confirm Printful draft created.

## Tools
- Printful rail: .github/workflows/gg-printful-rail.yml (ops: build key[:Color,..], map, relaytest, ...). Local: /home/claude/gg/pf.sh
- Media archive: .github/workflows/gg-archive-media.yml
- Playbook: rail/PLAYBOOK-RINSE-REPEAT.md

## Ruling
- One supplier: Printful (orders API). Printify retired (drafts hidden, no deletes without Founder OK).
- Thread must contrast fabric (Black cap tonal is the only approved exception).
