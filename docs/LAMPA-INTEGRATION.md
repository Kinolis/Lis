# LIS × Lampa integration

## Project rule

Preserve the upstream Lampa runtime and behavior. LIS owns the presentation layer; integration code must adapt to Lampa rather than reimplement its internals. Do not modify upstream files in place until a change is isolated, documented, and regression-tested.

## Repository layout target

- `vendor/lampa/` — pinned upstream Lampa source snapshot; keep upstream files unchanged.
- `vendor/lampac/` — optional self-hosted backend, isolated from the static LIS frontend.
- `functions/api/lampa/` — LIS-owned server-side adapter/proxy endpoints only; never expose backend secrets.
- `lis-interface/` — LIS presentation components and styles.
- `lis-adapter/` — narrow compatibility layer between LIS UI and documented Lampa APIs/events.
- `docs/LAMPA-INTEGRATION.md` — integration checklist and risk register.

The layout is a target, not a claim that these components are already installed.

## Compatibility and licensing gates

1. Pin exact upstream repository, commit/tag, and license before importing code.
2. Keep upstream copyright and license files with every copied source tree.
3. Both yumata/lampa-source and the main yumata/lampa repository expose a GPL-2.0 LICENSE file. The lampa-source package.json nevertheless declares `license: ISC`. Treat this as an unresolved licensing metadata conflict; do not bundle/distribute source until the project owner clarifies the applicable terms. Preserve the full LICENSE and notices if permission is confirmed.
4. Lampac NextGen identifies itself as AGPL-3.0. Review network-use and source-disclosure obligations before deploying a modified service.
5. Do not copy third-party plugins or provider implementations without reviewing their individual licenses and content rights.
6. Only integrate sources and playback links that are authorized for the intended territories and use.

## Risk legend

- 🟢 GREEN — isolated/documented change; upstream runtime untouched; tests pass.
- 🟡 YELLOW — compatibility uncertain or touches integration boundaries; test on a separate branch/staging build first.
- 🔴 RED — modifies upstream core, plugin execution, playback resolution, authentication, or security boundaries; do not merge without explicit review and regression evidence.

## Checklist

| Item | Status | Risk | Notes |
|---|---|---|---|
| Inspect current LIS frontend and deployment shape | DONE | 🟢 | Static HTML frontend; package build copies index.html to dist. |
| Create isolated integration branch | DONE | 🟢 | Work is isolated from main. |
| Verify upstream Lampa source and license | BLOCKED | 🟡 | Rechecked both yumata/lampa-source and yumata/lampa: LICENSE is GPL-2.0; lampa-source/package.json says ISC. Main repo also has GPL-2.0. Obtain owner clarification and pin exact commits before bundling. |
| Verify Lampac backend API and license | IN PROGRESS | 🟡 | Inspected LICENSE (AGPL-3.0), docker-compose (service exposes 9118), and Online/README (plugin /online.js; provider routes /lite/{provider}; externalids). |
| Map Lampa UI/runtime boundaries | IN PROGRESS | 🟡 | Lampa 3 migration guide documents modular classes via Lampa.Maker; identify safe theme/extension points before overriding UI. |
| Import immutable upstream snapshot | TODO | 🟡 | Only after license review; preserve upstream tree and attribution. |
| Build LIS adapter against documented interfaces | TODO | 🟡 | Avoid monkey-patching core or depending on private internals. |
| Add LIS visual shell | TODO | 🟢 | Must remain separate from upstream runtime. |
| Validate plugins, search, detail pages, playback, subtitles and audio tracks | TODO | 🟡 | Use test sources that are authorized for embedding. |
| Security review of third-party plugins | IN PROGRESS | 🔴 | Confirmed upstream Lampac warning about publicly exposed modules lacking request sanitization. Require firewall, reverse proxy and authentication; audit each plugin before enabling. |
| Production deployment | TODO | 🟡 | Requires a separately hosted backend for Lampac; static Pages alone cannot run its .NET service. |

## Detailed verification notes

- Lampa source README says the repository contains the application source and gives the Gulp-based local run workflow (`npm install`, `npm run start`). The `UPGRADE.md` documents Lampa 3 modular classes and `Lampa.Maker` extension points.
- License evidence is inconsistent: both the source repository LICENSE and main application LICENSE are GPL-2.0, but source package metadata says ISC. The repository metadata alone does not resolve the legal conflict; upstream clarification is required.
- Lampac README describes it as a self-hosted Lampa backend, with 70+ provider modules and a default port of 9118. Its LICENSE is AGPL-3.0.
- Lampac README explicitly warns that Catalog, Tracks, Transcoding, GStreamer and other selected modules do not sanitize incoming requests as a public API; do not expose them publicly without firewall, reverse proxy and authentication.
- Lampac Online module documentation confirms `/online.js`, `/lite/*` provider routes and `/externalids` integration.

## Initial repository audit

- LIS is currently a static HTML frontend; package.json build script only copies index.html into dist. It does not build or host a .NET service.
- Lampac NextGen is a separate ASP.NET Core/.NET 10 backend. Its documented Docker deployment exposes port 9118; it must be hosted separately from the current static Pages build.
- Lampac Online module exposes the Lampa VOD plugin at /online.js, provider routes at /lite/{provider}, and external ID mapping at /externalids.
- Lampa source package.json has a `start` Gulp workflow and a separate `license: ISC` field, but the repository LICENSE file is GPL-2.0. This mismatch is a hard import gate.

## First implementation milestone

1. Finish source/license audit and pin upstream revisions.
2. Run the unmodified Lampa client in an isolated test path.
3. Connect a test Lampac instance only after deployment/security review.
4. Add a LIS-owned shell around documented extension points.
5. Compare the unmodified baseline with the integrated build before any production release.

## Regression rule

Every change must record: affected files, risk color, reason, test performed, result, and rollback commit. A red item is not changed without explicit user approval.


## Experiment branch: source import preparation

- Experiment branch: `experiment/lampa-source` (created from `feature/lampa-integration`).
- Production branch `main` is untouched.
- Upstream source repository confirmed: `https://github.com/yumata/lampa-source`; it contains `src/`, `plugins/`, `public/`, `index/`, `spec/`, `docs/`, `gulpfile.js`, and `package.json`.
- Upstream README documents local development via `npm install` and `npm run start`; this is a Gulp-based source project, not a single HTML file.
- Upstream `package.json` currently declares `license: ISC`, while the repository's `LICENSE` file is the full GPL-2.0 text. Do not silently choose one: retain both pieces of evidence and obtain maintainer clarification before publishing a redistributed derivative.
- No Lampa source files have been imported in this commit. The connected GitHub actions available in this session do not expose a repository-fork or bulk Git-clone/import operation; creating placeholder files would falsely imply a working import. The actual source import must be done as a real upstream fork/clone, preserving history and all notices, then pushed to this experiment branch.
- Next technical gate after import: run the upstream Gulp build unchanged and verify the generated app locally before connecting LIS UI or any provider backend.


## Source architecture map (read-only audit)

- `src/app.js` is the application entry point. It wires core services, UI interactions, the player, search, TMDB and the plugin subsystem into the Lampa runtime.
- `gulpfile.js` bundles `src/app.js` with Rollup (IIFE output), Babel, CommonJS/node resolution and the web-worker plugin. Development server is BrowserSync; build output is written under `dest/`.
- `src/core/api/api.js` routes catalog operations (main/category/full/search and discovery) through source adapters. Current built-in sources include TMDB and CUB.
- `src/interaction/player.js` orchestrates the playback UI and playback subsystems (video, panel, subtitles, audio tracks, playlist, external players, etc.). This is the real playback runtime, not a visual placeholder.
- `src/interaction/search/global.js` owns global search UI and composes search sources.
- `src/core/plugins.js` reads enabled plugin URLs from persistent storage and loads enabled plugins dynamically. This is a security-sensitive extension boundary: never preload arbitrary third-party plugin URLs by default; require an explicit allowlist and review.
- `src/core/manifest.js` contains upstream identity/version and service-domain configuration. LIS branding should be implemented in a separate adapter/configuration layer, not by casually editing upstream identity fields.
- `src/core/api/sources/parser.js` integrates a parser/torrent source and related playback-card behavior. Do not enable this provider path automatically; audit the backend and content rights first.
- `UPGRADE.md` documents Lampa 3's modular class system through `Lampa.Maker`, including module replacement/mapping. Treat this as a candidate customization API, but verify each override against the pinned version and tests.

## Import decision

- 🟢 Read-only source architecture audit completed for the files listed above.
- 🟡 Next safe engineering step: establish an upstream fork or a reproducible source sync that preserves the upstream commit and notices; run the unmodified upstream build before any LIS branding/customization.
- 🔴 Do not enable arbitrary plugin URLs, parser/torrent providers, or unauthenticated backend endpoints as part of the initial import.
- No upstream runtime files have been copied into LIS yet. The source import is still pending; this branch currently contains planning/audit documentation only.
