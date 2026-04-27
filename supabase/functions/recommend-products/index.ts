import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

type CatalogMap = Record<string, string>

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

function cleanJsonFence(text: string) {
  return text.replace(/```json/gi, "").replace(/```/g, "").trim()
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const payload = await req.json().catch(() => null)
    const cartDescriptions = payload?.cartDescriptions
    const catalogMap = payload?.catalogMap as CatalogMap | undefined

    if (typeof cartDescriptions !== "string" || !catalogMap || typeof catalogMap !== "object") {
      console.error("Invalid payload:", payload)
      return jsonResponse([])
    }

    const catalogIds = Object.keys(catalogMap)
    if (catalogIds.length === 0) {
      return jsonResponse([])
    }

    const groqApiKey = Deno.env.get("GROQ_API_KEY")
    if (!groqApiKey) {
      console.error("Missing GROQ_API_KEY secret")
      return jsonResponse([])
    }

    const systemPrompt = `You are an expert luxury retail stylist.

Here is the context about the client's current cart, past purchases, or general preferences:
"${cartDescriptions}"

Here is the store's available catalog mapped by Product ID to Product Name:
${JSON.stringify(catalogMap)}

Based on the client context, choose exactly 3 items from the catalog that best complement their style, history, or current selections.
Return ONLY a raw JSON array of the 3 product IDs. Do not include markdown formatting, backticks, or any explanations.`

    const groqResponse = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${groqApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "llama3-70b-8192",
        messages: [{ role: "user", content: systemPrompt }],
        temperature: 0.2,
      }),
    })

    const groqText = await groqResponse.text()
    let groqJson: any = null
    try {
      groqJson = JSON.parse(groqText)
    } catch {
      console.error("Groq non-JSON response:", groqText)
      return jsonResponse([])
    }

    if (!groqResponse.ok) {
      console.error("Groq API error:", groqJson?.error ?? groqJson)
      return jsonResponse([])
    }

    const content = groqJson?.choices?.[0]?.message?.content
    if (typeof content !== "string" || content.trim().length === 0) {
      console.error("Groq empty content:", groqJson)
      return jsonResponse([])
    }

    const cleaned = cleanJsonFence(content)
    let parsed: unknown
    try {
      parsed = JSON.parse(cleaned)
    } catch {
      console.error("Failed to parse model output:", cleaned)
      return jsonResponse([])
    }

    if (!Array.isArray(parsed)) {
      console.error("Model output is not array:", parsed)
      return jsonResponse([])
    }

    const catalogSet = new Set(catalogIds.map((id) => id.toLowerCase()))
    const seen = new Set<string>()
    const recommendedIds: string[] = []

    for (const item of parsed) {
      if (typeof item !== "string") continue
      const id = item.trim()
      const key = id.toLowerCase()
      if (!catalogSet.has(key)) continue
      if (seen.has(key)) continue
      seen.add(key)
      recommendedIds.push(id)
      if (recommendedIds.length >= 3) break
    }

    return jsonResponse(recommendedIds)
  } catch (error) {
    console.error("Function Error:", error)
    return jsonResponse([])
  }
})
