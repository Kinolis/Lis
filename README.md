# LIS

LIS starts from the **unmodified original Lampa client**. The current stage is deliberately a clean baseline: no LIS theme overrides, no custom interface, no automatic plugin injection, and no custom TMDB proxy.

## Original source

- Upstream: https://github.com/yumata/lampa-source
- Pinned upstream revision: `4d0b666c6c6ce1523dc501939dcfe99b0e5b87e0`
- Local submodule: `vendor/lampa-source`

The upstream source is kept as a Git submodule and is not patched during builds.

## Build

Requirements: Node.js 20+ and Git.

Clone with the submodule:

```bash
git clone --recurse-submodules https://github.com/Kinolis/Lis.git
cd Lis
npm run build
```

The original Lampa web package is generated in `dist/`.

## Run the original Lampa locally

```bash
git submodule update --init --recursive
cd vendor/lampa-source
npm install
npm run start
```

Open the local URL printed by the upstream development server (normally `http://localhost:3000`).

## Development sequence

1. Verify the untouched upstream Lampa build and runtime.
2. Only after the baseline is confirmed, add LIS changes in small, isolated steps.
3. Test each step before continuing.
4. Publish the finished version to the primary Cloudflare Pages site only after explicit approval.

Cloudflare production deployment is intentionally kept separate from GitHub development.
