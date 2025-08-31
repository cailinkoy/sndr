import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

const region = "us-central1";
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

// bump when you change handler; visible in response headers
const HANDLER_VERSION = "2025-08-31f";

// CORS helper
function allowCors(res: any) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
}

// parse "$25-$100" → min/max
function parseBudget(budget?: string) {
  if (!budget) return {} as { budgetMin?: number; budgetMax?: number };
  const nums = (budget.match(/(\d+(\.\d+)?)/g) || [])
    .map(Number)
    .filter((n) => !Number.isNaN(n))
    .sort((a, b) => a - b);
  if (!nums.length) return {};
  if (nums.length === 1) return { budgetMin: nums[0], budgetMax: nums[0] };
  return { budgetMin: nums[0], budgetMax: nums[nums.length - 1] };
}

// guaranteed non-empty fallback
function fallbackIdeas(name = "them") {
  return [
    { title: "Artisan Chocolate Box", rationale: `Small-batch truffles for ${name}`, approxPriceUSD: 25, categories: ["treats"], urlHint: "artisan chocolate truffle box", wowFactor: 4 },
    { title: "Hinoki Scented Candle", rationale: "Calm Japandi vibe, neutral décor", approxPriceUSD: 22, categories: ["home"], urlHint: "hinoki candle", wowFactor: 3 },
    { title: "Engraved Phone Stand", rationale: `Personalized desk stand for ${name}`, approxPriceUSD: 20, categories: ["desk"], urlHint: "engraved wooden phone stand", wowFactor: 3 },
    { title: "Mini AeroPress Go", rationale: "Travel-friendly coffee press", approxPriceUSD: 40, categories: ["coffee","gadgets"], urlHint: "AeroPress Go coffee press", wowFactor: 4 },
    { title: "Cozy Neutral Throw", rationale: "Soft, machine-washable", approxPriceUSD: 25, categories: ["home"], urlHint: "fleece throw blanket neutral", wowFactor: 3 },
  ];
}

export const giftIdeas = onRequest(
  { region, secrets: [OPENAI_API_KEY], cors: true, timeoutSeconds: 60, memory: "256MiB" },
  async (req, res): Promise<void> => {
    allowCors(res);

    // Debug headers (safe to expose; remove later if you want)
    res.set("X-GiftIdeas-Handler", HANDLER_VERSION);
    res.set("X-Node-Version", process.versions.node);

    if (req.method === "OPTIONS") { res.status(204).send(); return; }
    if (req.method !== "POST") { res.status(405).json({ error: "Use POST" }); return; }

    try {
      const body = (req.body ?? {}) as any;
      const occasion = String(body.occasion ?? "Gift");
      const budget = String(body.budget ?? "");
      const recipient = body.recipient ?? {};
      const name = (recipient?.name ? String(recipient.name) : "them");
      const locale = String(body.locale ?? "en-US");
      const interests: string[] = Array.isArray(body.interests) ? body.interests : [];

      const parsed = parseBudget(budget);
      const budgetMin = body.budgetMin ?? parsed.budgetMin ?? null;
      const budgetMax = body.budgetMax ?? parsed.budgetMax ?? null;

      const instructions = `
You return ONLY JSON with top-level key "ideas" (array of 5-8 items). Each idea:
- title (string, concise gift/product name)
- rationale (string, 1-2 sentences)
- approxPriceUSD (number)
- categories (array of 1-3 short strings)
- urlHint (string, a search phrase users can paste into Amazon/Google)
- wowFactor (integer 1-5)
No prose, no markdown, no extra fields. Keep roughly within budget if provided; US shipping preferred; avoid subscriptions unless asked.
      `.trim();

      const user = {
        occasion, budget, budgetMin, budgetMax, interests,
        recipient: { name }, locale,
        constraints: "Prefer items available to ship within ~7 days."
      };

      // --- DIAGNOSTIC: check secret presence ---
      const apiKey = OPENAI_API_KEY.value();
      const hasKey = !!apiKey && apiKey.trim().length > 0;
      res.set("X-OpenAI-Key", hasKey ? "set" : "missing");
      if (!hasKey) {
        console.error("[giftIdeas] OPENAI_API_KEY missing");
        res.set("X-GiftIdeas-Source", "fallback_no_key");
        res.status(200).json({ ideas: fallbackIdeas(name), meta: { source: "fallback_no_key", handlerVersion: HANDLER_VERSION } });
        return;
      }

      // ---------- 1) Try Responses API (JSON-forced) ----------
      let modelIdeas: any[] | null = null;
      let responsesErrorText = "";

      try {
        const r = await fetch("https://api.openai.com/v1/responses", {
          method: "POST",
          headers: {
            Authorization: "Bearer " + apiKey,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "gpt-4.1-mini",
            instructions,                     // system guidance
            text: { format: "json_object" },  // JSON mode (Responses API)
            input: [
              { role: "user", content: [{ type: "input_text", text: JSON.stringify(user) }] }
            ],
            temperature: 0.7,
          }),
        });

        if (!r.ok) {
          responsesErrorText = await r.text().catch(() => "");
          throw new Error(`ResponsesAPI ${r.status} ${responsesErrorText}`);
        }

        const data: any = await r.json();
        let jsonText: string = typeof data?.output_text === "string" ? data.output_text : "";

        if (!jsonText) {
          try {
            const out = Array.isArray(data?.output) ? data.output : [];
            const first = out[0] || {};
            const content = Array.isArray(first.content) ? first.content : [];
            const txt = content.find((c: any) => c && c.type === "output_text");
            if (txt && typeof txt.text === "string") jsonText = txt.text;
          } catch { /* ignore */ }
        }

        const parsedOut: any = jsonText ? JSON.parse(jsonText) : {};
        if (Array.isArray(parsedOut.ideas)) modelIdeas = parsedOut.ideas as any[];
        if (modelIdeas && modelIdeas.length) {
          res.set("X-GiftIdeas-Source", "model");
        }
      } catch (e) {
        console.error("[giftIdeas] Responses API failed:", (e as any)?.message || e, responsesErrorText || "");
      }

      // ---------- 2) Fallback to Chat Completions JSON mode ----------
      if (!modelIdeas || !modelIdeas.length) {
        try {
          const r2 = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
              Authorization: "Bearer " + apiKey,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              model: "gpt-4o-mini", // chat-capable, supports response_format json
              response_format: { type: "json_object" },
              messages: [
                { role: "system", content: instructions },
                { role: "user", content: JSON.stringify(user) }
              ],
              temperature: 0.7,
            }),
          });

          if (!r2.ok) {
            const t2 = await r2.text().catch(() => "");
            throw new Error(`ChatCompletions ${r2.status} ${t2}`);
          }

          const data2: any = await r2.json();
          const msg = data2?.choices?.[0]?.message?.content ?? "";
          const parsedOut2: any = msg ? JSON.parse(msg) : {};
          if (Array.isArray(parsedOut2.ideas)) modelIdeas = parsedOut2.ideas as any[];
          if (modelIdeas && modelIdeas.length) {
            res.set("X-GiftIdeas-Source", "model_chat");
          }
        } catch (e) {
          console.error("[giftIdeas] Chat Completions failed:", (e as any)?.message || e);
        }
      }

      // ---------- Sanitize / finalize ----------
      let ideas: any[] = Array.isArray(modelIdeas) ? modelIdeas : [];
      ideas = ideas
        .filter((it) => it && typeof it === "object")
        .map((it) => ({
          title: String(it.title ?? "").trim(),
          rationale: String(it.rationale ?? "").trim(),
          approxPriceUSD: Number.isFinite(Number(it.approxPriceUSD)) ? Number(it.approxPriceUSD) : null,
          categories: Array.isArray(it.categories) ? it.categories.map(String) : [],
          urlHint: String(it.urlHint ?? it.title ?? "").trim(),
          wowFactor: Number.isInteger(it.wowFactor) ? it.wowFactor : 3,
        }))
        .filter((it) => it.title.length > 0);

      if (!ideas.length) {
        console.warn("[giftIdeas] Model returned 0 items; serving fallback.");
        res.set("X-GiftIdeas-Source", "fallback_empty");
        res.status(200).json({ ideas: fallbackIdeas(name), meta: { source: "fallback_empty", handlerVersion: HANDLER_VERSION } });
        return;
      }

      res.status(200).json({
        ideas,
        meta: { source: (res.getHeader && res.getHeader("X-GiftIdeas-Source")) || "model", handlerVersion: HANDLER_VERSION }
      });
      return;
    } catch (e: any) {
      console.error("[giftIdeas] handler error:", e?.stack || e);
      res.set("X-GiftIdeas-Source", "fallback_error");
      res.status(200).json({ ideas: fallbackIdeas(), meta: { source: "fallback_error", handlerVersion: HANDLER_VERSION } });
      return;
    }
  }
);
