import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

// web_search / web_fetch for Pi through Ollama Cloud's hosted API (https://docs.ollama.com/capabilities/web-search).
// The stock @ollama/pi-web-search package only talks to a *local* Ollama daemon (http://localhost:11434), which
// does not exist inside the agent container, so this extension calls ollama.com directly with OLLAMA_API_KEY.

const HOST = "https://ollama.com";
const MAX_CHARS = 20000; // keep tool output from flooding the model's context

async function call(path: string, body: unknown, signal?: AbortSignal): Promise<any> {
  const key = process.env.OLLAMA_API_KEY;
  if (!key) throw new Error("OLLAMA_API_KEY is not set in the agent environment");
  const response = await fetch(`${HOST}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify(body),
    signal,
  });
  if (!response.ok) {
    const text = await response.text().catch(() => "");
    throw new Error(`Ollama Cloud ${path} failed (status ${response.status}): ${text || response.statusText}`);
  }
  return response.json();
}

const clip = (text: string) => (text.length > MAX_CHARS ? text.slice(0, MAX_CHARS) + "\n[truncated]" : text);

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "web_search",
    label: "Web Search",
    description: "Search the web for current information (Ollama Cloud web search). Returns titles, URLs and snippets.",
    parameters: Type.Object({
      query: Type.String({ description: "The search query" }),
      max_results: Type.Optional(Type.Number({ description: "Maximum results (1-10, default 5)", default: 5 })),
    }),
    async execute(_toolCallId, params, signal) {
      const max = Math.min(10, Math.max(1, params.max_results ?? 5));
      const data = await call("/api/web_search", { query: params.query, max_results: max }, signal);
      const results: Array<{ title: string; url: string; content: string }> = data.results ?? [];
      const text = results.map((r, i) => `${i + 1}. ${r.title}\n   URL: ${r.url}\n   ${r.content}`).join("\n\n");
      return { content: [{ type: "text", text: clip(text || "No results found.") }], details: { results } };
    },
  });

  pi.registerTool({
    name: "web_fetch",
    label: "Web Fetch",
    description: "Fetch a web page and extract its main content (Ollama Cloud web fetch).",
    parameters: Type.Object({ url: Type.String({ description: "The URL to fetch" }) }),
    async execute(_toolCallId, params, signal) {
      const data = await call("/api/web_fetch", { url: params.url }, signal);
      const links: string[] = data.links ?? [];
      const text = `${data.title ?? ""}\n\n${data.content ?? ""}${links.length ? "\n\nLinks:\n" + links.slice(0, 30).join("\n") : ""}`;
      return { content: [{ type: "text", text: clip(text) }], details: { url: params.url } };
    },
  });
}
