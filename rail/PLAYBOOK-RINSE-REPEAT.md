# Rinse & Repeat™ — Store Line Factory (proven on GOD GEAR™, 2026-11-01)

One spec file in, a full premium line out: costs, mockups, Shopify listings, fulfillment mapping.
No product designer clicks. No Printify. One supplier: Printful (orders API).

## Inputs (per store)
1. Canon art as transparent PNGs, one file per thread/print color: `rail/art/pf/{art}-{HEX}.png`
   (HEX = Printful thread hex: 000000 FFFFFF 96A1A8 A67843 CC3333 333366 660000 …).
2. Line spec `rail/line/<store>-line.json`: per product → Printful catalog id, title, type,
   size→price map, color→thread hex, embroidery placements, print placements.

## Thread rule (CRITIC lesson, line v1)
Thread must CONTRAST the garment. Tonal (thread = fabric color) makes the logo vanish.
Only exception: a deliberately tonal colorway the Founder approved (e.g., Black cap, black G).

## Pipeline
| Step | Tool | Output |
|---|---|---|
| 1 Cost check | `pf.sh build <key>[:Color,Color]` → `POST /orders/estimate-costs` | unit cost + shipping per colorway |
| 2 Mockups | same run → `/mockup-generator/create-task` (EMBROIDERY + DTG) | Printful mockup URLs (expire — attach fast) |
| 3 Listing | Shopify Admin GraphQL: `productCreate` (DRAFT) → `productUpdate(media)` → `productVariantsBulkCreate` | hidden draft with images on Shopify CDN |
| 4 Custody | `gg-archive-media.yml` | mockups archived in repo + SHA-256 + contact sheets in `rail/review/` |
| 5 CRITIC | read contact sheets; RED = fix spec, rerun only failing colors | approved set |
| 6 Founder approval | one approval set; reply "Done" | publish |
| 7 Fulfillment map | `pf.sh map` → variant metafield `gg.printful` per Shopify variant | order relay payload |
| 8 Publish | `productUpdate status ACTIVE` + `publishablePublish` (Online Store, Shop) | live |

## Known API facts (save hours)
- Printful mockup placements can differ from order placements (hats: `embroidery_front` ↔ mockup `embroidery_front_large`); `pf_build.py` aliases automatically.
- Thread option ids: `embroidery_front` → `thread_colors`; `embroidery_apparel_front` → `thread_colors_apparel`; others → `thread_colors_<placement minus "embroidery_">`.
- Do not pass thread options to mockup tasks (errors). Mockup rate limit ≈ 1 task / 60 s.
- Positions must be computed from `/mockup-generator/printfiles/{id}` (+ `?technique=EMBROIDERY`).
- Printful cannot import Shopify-created products into a Shopify-type store; fulfillment goes through `POST /orders` with files + options.
- Mockup S3 URLs are temporary; Shopify copies on attach. Agent proxy cannot read S3 or cdn.shopify.com — use the archive workflow.
- Embroidery digitization: $6.50 one-time per design per placement.

## Line v1 unit economics (Printful estimate, US ship)
| Product | Blank+deco | Ship | Price |
|---|---|---|---|
| ACTIVE tee CC1717 (chest emb + sleeve emb + back DTG) | $25.82 | $5.35 | $49–64 |
| MOVE hoodie M2580 (front emb + wrist emb + back DTG) | $38.79 | $9.19 | $69–84 |
| CLASSIC crew 18000 (chest emb + sleeve emb) | $22.73 | $9.19 | $59–79 |
| CULTURE dad hat 6245CM | $14.94 | $5.09 | $39 |
| CULTURE cap 6277 (front + back emb) | $19.46 | $5.09 | $44 |
| FLOW sweats CC1469 | see build3 | | $64–69 |

## Next store
Copy `gg-line.json` → `<store>-line.json`, swap art + colors + titles, run steps 1–8.
