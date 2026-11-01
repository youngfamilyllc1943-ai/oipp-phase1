export default function main(input) {
  const o = input.order;
  const R = "https://raw.githubusercontent.com/youngfamilyllc1943-ai/oipp-phase1/main/rail/art/pf/";
  const items = [];
  for (const li of o.lineItems) {
    const mf = li.variant && li.variant.product && li.variant.product.metafield;
    if (!mf) continue;
    const m = JSON.parse(mf.value);
    const opt = {};
    for (const s of li.variant.selectedOptions) opt[s.name] = s.value;
    const hex = m.hex[opt.Color];
    const vid = (m.ids[opt.Color] || {})[opt.Size];
    if (!hex || !vid) continue;
    const sub = (s) => s.replace(/HEX/g, hex);
    items.push({
      variant_id: vid,
      quantity: li.quantity,
      external_id: String(li.id).split("/").pop(),
      files: m.files.map((f) => ({ type: f.type, url: R + sub(f.url) + ".png" })),
      options: m.options.map((p) => ({ id: p.id, value: p.value.map(sub) })),
    });
  }
  const a = o.shippingAddress || {};
  return {
    count: items.length,
    body: JSON.stringify({
      external_id: "GG" + String(o.name).replace("#", ""),
      shipping: "STANDARD",
      recipient: {
        name: a.name, address1: a.address1, address2: a.address2 || "",
        city: a.city, state_code: a.provinceCode, country_code: a.countryCodeV2,
        zip: a.zip, phone: a.phone || "", email: o.email || "",
      },
      items,
    }),
  };
}
