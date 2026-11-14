const headers = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "public, max-age=300",
  "Access-Control-Allow-Origin": "*"
};

export async function onRequest({ request }) {
  const url = new URL(request.url);
  if (request.method !== "GET") return json({ error: "Method not allowed" }, 405);
  const action = url.searchParams.get("action") || "search";
  if (action !== "search") return json({ error: "Unsupported action" }, 400);
  const query = (url.searchParams.get("q") || "").trim().slice(0, 80);
  if (query.length < 2) return json({ results: [] });

  // Only return items whose uploader explicitly supplied a Creative Commons
  // license URL. A playable file alone is not proof of reuse permission.
  const safe = query.replace(/[\\+\-!(){}\[\]^"~*?:\/]/g, " ").replace(/\s+/g, " ").trim();
  if (!safe) return json({ results: [] });
  const search = new URL("https://archive.org/advancedsearch.php");
  search.searchParams.set("q", `mediatype:movies AND licenseurl:*creativecommons.org* AND title:"${safe}"`);
  ["identifier", "title", "year", "description", "licenseurl", "creator"].forEach(field => search.searchParams.append("fl[]", field));
  search.searchParams.set("rows", "12");
  search.searchParams.set("page", "1");
  search.searchParams.set("output", "json");

  try {
    const response = await fetch(search, { headers: { Accept: "application/json" } });
    if (!response.ok) throw new Error("Archive search failed");
    const data = await response.json();
    const docs = data.response?.docs || [];
    const results = await Promise.all(docs.slice(0, 8).map(async item => {
      try {
        const metaResponse = await fetch(`https://archive.org/metadata/${encodeURIComponent(item.identifier)}`, { headers: { Accept: "application/json" } });
        if (!metaResponse.ok) return null;
        const meta = await metaResponse.json();
        const license = String(meta.metadata?.licenseurl || item.licenseurl || "");
        if (!/creativecommons\.org/i.test(license)) return null;
        const files = (meta.files || []).filter(file =>
          typeof file.name === "string" &&
          file.name.toLowerCase().endsWith(".mp4") &&
          !file.name.includes("/") &&
          !file.name.toLowerCase().includes("_thumb") &&
          !file.name.toLowerCase().includes("sample")
        );
        if (!files.length) return null;
        files.sort((a, b) => {
          const score = file => (String(file.format || "").toLowerCase().includes("512kb") ? 0 : 1) + (Number(file.size || 0) > 1500000000 ? 2 : 0);
          return score(a) - score(b);
        });
        const file = files[0];
        return {
          identifier: item.identifier,
          title: meta.metadata?.title || item.title || item.identifier,
          year: meta.metadata?.year || item.year || "",
          creator: meta.metadata?.creator || item.creator || "",
          description: String(meta.metadata?.description || item.description || "").replace(/<[^>]*>/g, " ").slice(0, 500),
          license,
          file: file.name,
          format: file.format || "MP4",
          size: file.size || null,
          poster: `https://archive.org/services/img/${encodeURIComponent(item.identifier)}`,
          stream: `https://archive.org/download/${encodeURIComponent(item.identifier)}/${encodeURIComponent(file.name)}`,
          embed: `https://archive.org/embed/${encodeURIComponent(item.identifier)}`
        };
      } catch { return null; }
    }));
    return json({ results: results.filter(Boolean) });
  } catch {
    return json({ error: "Internet Archive is temporarily unavailable" }, 502);
  }
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers });
}
