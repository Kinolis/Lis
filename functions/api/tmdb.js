const headers = { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "public, max-age=3600", "Access-Control-Allow-Origin": "*" };

export async function onRequest({ request, env }) {
  const url = new URL(request.url);
  const query = (url.searchParams.get("q") || "").trim();
  const kind = url.searchParams.get("type") === "tv" ? "tv" : "movie";

  if (request.method !== "GET") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers });
  }
  if (!query || query.length > 120) {
    return new Response(JSON.stringify({ error: "A valid q parameter is required" }), { status: 400, headers });
  }
  if (!env.TMDB_TOKEN) {
    return new Response(JSON.stringify({ error: "TMDB_TOKEN is not configured in Cloudflare Pages" }), { status: 503, headers });
  }

  const endpoint = new URL(`https://api.themoviedb.org/3/search/${kind}`);
  endpoint.searchParams.set("query", query);
  endpoint.searchParams.set("language", "ru-RU");
  endpoint.searchParams.set("include_adult", "false");

  try {
    const upstream = await fetch(endpoint, {
      headers: { Authorization: `Bearer ${env.TMDB_TOKEN}`, Accept: "application/json" }
    });
    if (!upstream.ok) {
      return new Response(JSON.stringify({ error: "TMDB request failed", status: upstream.status }), { status: 502, headers });
    }
    const data = await upstream.json();
    const results = (data.results || []).slice(0, 5).map(item => ({
      id: item.id,
      title: item.title || item.name || query,
      poster_path: item.poster_path,
      backdrop_path: item.backdrop_path,
      overview: item.overview,
      release_date: item.release_date || item.first_air_date,
      vote_average: item.vote_average
    }));
    return new Response(JSON.stringify({ results }), { headers });
  } catch {
    return new Response(JSON.stringify({ error: "Unable to reach TMDB" }), { status: 502, headers });
  }
}
