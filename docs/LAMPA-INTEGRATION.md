# LIS × Lampa integration

## Project rule

Preserve the upstream Lampa runtime and behavior. LIS owns the presentation layer; integration code must adapt to Lampa rather than reimplement its internals. Do not modify upstream files in place until a change is isolated, documented, and regression-tested.

## Repository layout target

- `vendor/lampa-source/` — upstream Lampa source Git submodule pinned to an exact commit; keep upstream files unchanged.
- `vendor/lampac/` — optional self-hosted backend, isolated from the static LIS frontend.
- `functions/api/lampa/` — LIS-owned server-side adapter/proxy endpoints only; never expose backend secrets.
- `lis-interface/` — LIS presentation components and styles.
- `lis-adapter/` — narrow compatibility layer between LIS UI and documented Lampa APIs/events.
- `docs/LAMPA-INTEGRATION.md` — integration checklist and risk register.

The layout is a target. At present, only the `vendor/lampa-source` Git submodule is connected; the LIS adapter, LIS visual shell, and Lampac backend are not implemented.

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
| Verify upstream Lampa source and license | BLOCKED | 🟡 | Source commit is pinned as a submodule; LICENSE is GPL-2.0 while package.json says ISC. Obtain owner clarification before redistribution/bundling. |
| Verify Lampac backend API and license | IN PROGRESS | 🟡 | Inspected LICENSE (AGPL-3.0), docker-compose (service exposes 9118), and Online/README (plugin /online.js; provider routes /lite/{provider}; externalids). |
| Map Lampa UI/runtime boundaries | IN PROGRESS | 🟡 | Lampa 3 migration guide documents modular classes via Lampa.Maker; identify safe theme/extension points before overriding UI. |
| Connect pinned upstream source | DONE | 🟢 | `vendor/lampa-source` submodule points to `4d0b666c6c6ce1523dc501939dcfe99b0e5b87e0`; source is fetched when cloning with submodules. It is not copied into LIS blobs. |
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
- The upstream source is connected as a Git submodule, not copied into LIS's own file tree. The exact upstream commit is recorded by the submodule gitlink; cloning with `--recurse-submodules` fetches the source and preserves its upstream history and notices.
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
- 🟢 Upstream source dependency connected as a Git submodule, pinned to the exact commit recorded below.
- 🟡 Next safe engineering step: clone with submodules, install upstream dependencies, and run the unmodified Lampa build in isolation before any LIS branding/customization.
- 🔴 Do not enable arbitrary plugin URLs, parser/torrent providers, or unauthenticated backend endpoints as part of the initial integration.


## Pinned upstream source dependency

- Added `vendor/lampa-source` as a Git submodule pointing to `https://github.com/yumata/lampa-source.git`.
- Pinned upstream commit: `4d0b666c6c6ce1523dc501939dcfe99b0e5b87e0` (upstream default branch `main`, observed 2026-11-15).
- The submodule preserves the upstream repository and its own history; it is not a copied/modified snapshot. Clone LIS with `git clone --recurse-submodules https://github.com/Kinolis/Lis.git` and checkout this experiment branch to populate the submodule working tree.
- The submodule pointer is committed only on `experiment/lampa-source`; LIS `main` and deployed site are unchanged.
- License gate remains open: upstream `LICENSE` is GPL-2.0 while `package.json` says ISC. The pinned source includes the upstream LICENSE; do not distribute a modified combined product until the maintainer clarifies the discrepancy and LIS distribution obligations are reviewed.
- Build has not yet been run. The upstream project requires Node/npm dependencies and its Gulp build; do not treat the submodule pointer as a verified runnable LIS build.


## Current experiment status

- LIS branch: `experiment/lampa-source`; production `main` remains unchanged.
- Upstream source is available through the pinned Git submodule at `vendor/lampa-source`.
- No local npm install, Gulp build, or browser playback test has been completed yet. The next gate is a clean, unmodified upstream run; only after that should LIS-owned UI integration begin.


## Local upstream runtime launcher

- Added `scripts/start-lampa-dev.sh` on the experiment branch.
- Run it from a clone of the experiment branch with: `bash scripts/start-lampa-dev.sh`.
- The script initializes the pinned submodule, checks for Node.js/npm, installs upstream npm dependencies if `node_modules` is absent, then runs the upstream `npm run start` command.
- Upstream `start` maps to Gulp's default task: file watching plus BrowserSync serving `build/web/`. This is a local development workflow, not a production build or deployment.
- The script does not modify upstream tracked source files or LIS `index.html`; npm may create local dependency artifacts inside the submodule working directory.
- This launcher has been added to GitHub but has not been executed in this environment. Successful startup and playback remain unverified.


## Automated upstream checks

- Added `.github/workflows/lampa-checks.yml` on `experiment/lampa-source`.
- The workflow checks out LIS with recursive submodules, installs the pinned Lampa source dependencies on Node.js 20, and runs the upstream Vitest suite with `npm test -- --run`.
- It runs on pushes and pull requests targeting the experiment branch, and can be started manually with GitHub Actions.
- This is a source test workflow, not a production build or browser playback test. Its first GitHub Actions run is still pending; record the actual result before treating the upstream runtime as verified.


## CI scope and current blockers

- The workflow now has two independent jobs: the pinned upstream Lampa Vitest suite, and LIS static-site build plus pinned-submodule and launcher syntax checks.
- The LIS build job verifies that the existing static Pages build still produces a non-empty `dist/index.html`; it does not bundle Lampa into LIS.
- GitHub Actions execution is not yet confirmed from the available commit-status response. Check the Actions tab for the run attached to the latest experiment-branch commit.
- A production-ready LIS/Lampa combined deployment is intentionally not created: the upstream license metadata conflict remains unresolved, no authorized playback backend has been selected and secured, and the actual browser playback path has not been validated.
- GitHub Pages publishing source is a repository setting outside the code tree. Keep it on `main` until the experiment is approved; this repository change does not alter that setting.


## First GitHub Actions result and test baseline

- First upstream test job installed dependencies successfully and ran 13 Vitest suites: 12 passed, 1 failed; 151 individual tests passed.
- The failing suite is `spec/torrent_preload.spec.js`. It searches `src/interaction/torrent.js` for `const TORRENT_PRELOAD_POLL_MS` and a `preload` implementation, but the pinned upstream source at `4d0b666c6c6ce1523dc501939dcfe99b0e5b87e0` does not contain that implementation. This is an upstream test/source mismatch, not a failure in LIS.
- The experiment workflow now runs the 12 compatible suites and packages the original Lampa GitHub web target using upstream Gulp task `pack_github`, verifying both `build/github/lampa/index.html` and `app.min.js` exist. The excluded suite is documented and must not be represented as passed.
- The LIS static build, submodule pin verification, and launcher shell syntax all passed in the first run.
- A green run of the revised workflow will verify the compatible tests and upstream packaging only. It does not prove playback/provider availability or browser/device compatibility.
