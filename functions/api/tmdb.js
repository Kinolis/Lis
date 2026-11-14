const headers = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "public, max-age=900",
  "Access-Control-Allow-Origin": "*"
};

export async function onRequest({ request, env }) {
  const url = new URL(request.url);
  const query = (url.searchParams.get("q") || "").trim();
  const kind = url.searchParams.get("type") === "tv" ? "tv" : "movie";
  const action = url.searchParams.get("action") || "search";
  const page = Math.max(1, Math.min(20, Number(url.searchParams.get("page") || 1)));
  const category = url.searchParams.get("category") || "popular";

  if (request.method !== "GET") return json({ error: "Method not allowed" }, 405);
  if (!env.TMDB_TOKEN) return json({ error: "TMDB_TOKEN is not configured in Cloudflare Pages" }, 503);

  let endpoint;
  if (action === "discover") {
    endpoint = new URL(`https://api.themoviedb.org/3/${category === "top_rated" ? kind + "/top_rated" : category === "upcoming" && kind === "movie" ? "movie/upcoming" : kind + "/popular"}`);
    endpoint.searchParams.set("language", "ru-RU");
    endpoint.searchParams.set("page", String(page));
    if (category === "popular") endpoint.searchParams.set("region", "RU");
  } else if (action === "search") {
    if (!query || query.length > 120) return json({ error: "A valid q parameter is required" }, 400);
    endpoint = new URL(`https://api.themoviedb.org/3/search/${kind}`);
    endpoint.searchParams.set("query", query);
    endpoint.searchParams.set("language", "ru-RU");
    endpoint.searchParams.set("include_adult", "false");
    endpoint.searchParams.set("page", String(page));
  } else {
    return json({ error: "Unsupported action" }, 400);
  }

  try {
    const upstream = await fetch(endpoint, {
      headers: { Authorization: `Bearer ${env.TMDB_TOKEN}`, Accept: "application/json" }
    });
    if (!upstream.ok) return json({ error: "TMDB request failed", status: upstream.status }, 502);
    const data = await upstream.json();
    const results = (data.results || []).map(item => ({
      id: item.id,
      title: item.title || item.name || "",
      poster_path: item.poster_path,
      backdrop_path: item.backdrop_path,
      overview: item.overview || "",
      release_date: item.release_date || item.first_air_date || "",
      vote_average: item.vote_average || 0,
      genre_ids: item.genre_ids || [],
      media_type: kind
    }));
    return json({ page: data.page || page, total_pages: Math.min(data.total_pages || 1, 500), results });
  } catch {
    return json({ error: "Unable to reach TMDB" }, 502);
  }
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers });
}
