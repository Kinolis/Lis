const headers = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "public, max-age=180",
  "Access-Control-Allow-Origin": "*"
};

export async function onRequest({ request }) {
  if (request.method !== "GET") return json({ error: "Method not allowed" }, 405);
  const url = new URL(request.url);
  const query = (url.searchParams.get("q") || "").trim();
  if (!query || query.length > 160) return json({ error: "A valid q parameter is required" }, 400);

  try {
    const endpoint = new URL("https://rutube.ru/api/search/video/");
    endpoint.searchParams.set("query", query);
    endpoint.searchParams.set("page", "1");
    endpoint.searchParams.set("limit", "12");
    const upstream = await fetch(endpoint, {
      headers: {
        "Accept": "application/json, text/plain, */*",
        "User-Agent": "Mozilla/5.0 (compatible; LISPlayer/1.0)"
      }
    });
    if (!upstream.ok) return json({ error: "RUTUBE search unavailable", status: upstream.status }, 502);
    const data = await upstream.json();
    const raw = Array.isArray(data.results) ? data.results : Array.isArray(data) ? data : [];
    const results = raw.map(item => {
      const id = String(item.id || item.video_id || item.uuid || "");
      const title = String(item.title || item.name || "").trim();
      const author = item.author?.name || item.author_name || item.channel?.name || "";
      const duration = Number(item.duration || item.video_duration || 0);
      const views = Number(item.views || item.hits || item.views_count || 0);
      const thumbnail = item.thumbnail_url || item.thumbnail || item.preview || item.image || "";
      return { id, title, author: String(author), duration, views, thumbnail: /^https:\/\//i.test(thumbnail) ? thumbnail : "" };
    }).filter(item => /^[a-zA-Z0-9_-]{8,80}$/.test(item.id) && item.title).slice(0, 12);
    return json({ results });
  } catch {
    return json({ error: "Unable to reach RUTUBE search" }, 502);
  }
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers });
}
