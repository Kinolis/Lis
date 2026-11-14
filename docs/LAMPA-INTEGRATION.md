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
3. Lampa source repository contains a GPL-2.0 LICENSE file, while its package.json currently says ISC. This is a license metadata conflict; do not import or distribute the source until the upstream owner clarifies which terms apply. Review the complete license and distribution obligations before bundling or modifying it.
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
| Verify upstream Lampa source and license | BLOCKED | 🟡 | Inspected LICENSE (GPL-2.0) and package.json (license: ISC); these conflict. Obtain clarification from upstream and pin an exact commit before import. |
| Verify Lampac backend API and license | IN PROGRESS | 🟡 | Inspected LICENSE (AGPL-3.0), docker-compose (service exposes 9118), and Online/README (plugin /online.js; provider routes /lite/{provider}; externalids). |
| Map Lampa UI/runtime boundaries | IN PROGRESS | 🟡 | Lampa 3 migration guide documents modular classes via Lampa.Maker; identify safe theme/extension points before overriding UI. |
| Import immutable upstream snapshot | TODO | 🟡 | Only after license review; preserve upstream tree and attribution. |
| Build LIS adapter against documented interfaces | TODO | 🟡 | Avoid monkey-patching core or depending on private internals. |
| Add LIS visual shell | TODO | 🟢 | Must remain separate from upstream runtime. |
| Validate plugins, search, detail pages, playback, subtitles and audio tracks | TODO | 🟡 | Use test sources that are authorized for embedding. |
| Security review of third-party plugins | TODO | 🔴 | Plugins can execute code; do not grant unrestricted access to LIS credentials or user data. |
| Production deployment | TODO | 🟡 | Requires a separately hosted backend for Lampac; static Pages alone cannot run its .NET service. |

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
