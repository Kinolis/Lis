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
  if (action === "related") {
    const id = url.searchParams.get("id");
    if (!id || !/^[0-9]+$/.test(id)) return json({ error: "A valid id parameter is required" }, 400);
    const base = `https://api.themoviedb.org/3/${kind}`;
    const auth = { Authorization: `Bearer ${env.TMDB_TOKEN}`, Accept: "application/json" };
    const get = async path => {
      const response = await fetch(base + path, { headers: auth });
      if (!response.ok) throw new Error("TMDB related request failed");
      return response.json();
    };
    const [details, similar] = await Promise.all([
      get(`/${id}?language=ru-RU`),
      get(`/${id}/similar?language=ru-RU&page=1`)
    ]);
    let franchise = null;
    if (kind === "movie" && details.belongs_to_collection?.id) {
      const collectionResponse = await fetch(`https://api.themoviedb.org/3/collection/${details.belongs_to_collection.id}?language=ru-RU`, { headers: auth });
      if (collectionResponse.ok) {
        const collection = await collectionResponse.json();
        franchise = { id: collection.id, name: collection.name, parts: (collection.parts || []).map(item => ({
          id: item.id, title: item.title || item.name || "", poster_path: item.poster_path,
          backdrop_path: item.backdrop_path, overview: item.overview || "",
          release_date: item.release_date || "", vote_average: item.vote_average || 0
        })) };
      }
    }
    const map = item => ({ id:item.id,title:item.title||item.name||"",poster_path:item.poster_path,
      backdrop_path:item.backdrop_path,overview:item.overview||"",
      release_date:item.release_date||item.first_air_date||"",vote_average:item.vote_average||0 });
    return json({ franchise, similar: (similar.results || []).filter(item => Number(item.vote_average || 0) >= 6 && Number(item.vote_count || 0) >= 30).map(map) });
  } else if (action === "videos") {
    const id = url.searchParams.get("id");
    if (!id || !/^[0-9]+$/.test(id)) return json({ error: "A valid id parameter is required" }, 400);
    endpoint = new URL(`https://api.themoviedb.org/3/${kind}/${id}/videos`);
    endpoint.searchParams.set("language", "ru-RU");
  } else if (action === "credits") {
    const id = url.searchParams.get("id");
    if (!id || !/^[0-9]+$/.test(id)) return json({ error: "A valid id parameter is required" }, 400);
    endpoint = new URL(`https://api.themoviedb.org/3/${kind}/${id}/credits`);
  } else if (action === "images") {
    const id = url.searchParams.get("id");
    if (!id || !/^[0-9]+$/.test(id)) return json({ error: "A valid id parameter is required" }, 400);
    endpoint = new URL(`https://api.themoviedb.org/3/${kind}/${id}/images`);
    endpoint.searchParams.set("include_image_language", "ru,en,null");
  } else if (action === "discover") {
    const genre=url.searchParams.get("genre"),year=url.searchParams.get("year"),rating=url.searchParams.get("rating"),sort=url.searchParams.get("sort");
    if (category === "classics") {
      endpoint = new URL("https://api.themoviedb.org/3/discover/movie");
      endpoint.searchParams.set("sort_by", "popularity.desc");
      endpoint.searchParams.set("primary_release_date.lte", "2005-12-31");
      endpoint.searchParams.set("vote_count.gte", "100");
    } else if (category === "animation" || category === "anime") {
      const discoveryKind = category === "anime" ? "tv" : "movie";
      endpoint = new URL(`https://api.themoviedb.org/3/discover/${discoveryKind}`);
      endpoint.searchParams.set("with_genres", "16");
      if (category === "anime") endpoint.searchParams.set("with_original_language", "ja");
    } else {
      const hasFilters=!!(genre||year||rating||sort&&sort!=="popularity.desc");
      if(hasFilters){
        endpoint = new URL(`https://api.themoviedb.org/3/discover/${kind}`);
      } else {
        endpoint = new URL(`https://api.themoviedb.org/3/${category === "top_rated" ? kind + "/top_rated" : category === "upcoming" && kind === "movie" ? "movie/upcoming" : kind + "/popular"}`);
      }
    }
    if(genre&&/^[0-9]+$/.test(genre))endpoint.searchParams.set("with_genres",genre);
    if(year&&/^\d{4}$/.test(year))endpoint.searchParams.set(kind==="tv"?"first_air_date_year":"primary_release_year",year);
    if(rating&&!Number.isNaN(Number(rating)))endpoint.searchParams.set("vote_average.gte",String(Math.max(0,Math.min(10,Number(rating)))));
    if(sort){const safeSort=kind==="tv"?({"popularity.desc":"popularity.desc","vote_average.desc":"vote_average.desc","primary_release_date.desc":"first_air_date.desc","original_title.asc":"original_name.asc"}[sort]||"popularity.desc"):sort;endpoint.searchParams.set("sort_by",safeSort)}
    if(sort==="vote_average.desc")endpoint.searchParams.set("vote_count.gte","100");
    endpoint.searchParams.set("language", "ru-RU");
    endpoint.searchParams.set("page", String(page));
    if (category === "popular" && !genre && !year && !rating && (!sort || sort==="popularity.desc")) endpoint.searchParams.set("region", "RU");
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
    if (action === "images") return json({ logos: data.logos || [] });
    if (action === "videos") return json({ videos: (data.results || []).map(video => ({ key: video.key, site: video.site, type: video.type, official: !!video.official, name: video.name || "" })) });
    if (action === "credits") return json({ cast: (data.cast || []).slice(0, 16).map(person => ({ id: person.id, name: person.name, character: person.character || "", profile_path: person.profile_path || null })) });
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
