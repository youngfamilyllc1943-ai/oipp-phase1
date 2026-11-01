# One-time Shopify Flow setup — GOD GEAR order relay

1. Shopify admin → Apps → install **Shopify Flow** (free).
2. Flow → Create workflow → Trigger: **Order paid**.
3. Add action **Run code**:
   - Input: contents of `flow-run-code-input.graphql`
   - Output: contents of `flow-run-code-output.graphql`
   - Code: contents of `flow-run-code.js`
4. Add **Condition**: `Run code / count` is greater than `0`.
5. Under "Then" add **Send HTTP request**:
   - Method `POST`
   - URL `https://api.printful.com/orders`
   - Headers: `Content-Type: application/json`, `X-PF-Store-Id: 18823775`,
     `Authorization: Bearer` + Flow secret `PRINTFUL_TOKEN` (create a new Printful private token, paste only into Flow's secret field).
   - Body: `{{runCode.body}}`
6. Name: `GOD GEAR → Printful relay` → Turn on.

Orders arrive in Printful as drafts. Nothing is charged until confirmed.
