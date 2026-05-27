# docs/site — herminal landing page

Static site served by GitHub Pages at
<https://hoangperry.github.io/herminal/>.

No build step. The source IS the deployable: `index.html`,
`style.css`, `script.js`, `favicon.svg`. The static-site
content here is intentionally lock-step with the marketing copy
in [`../launch/landing-page.md`](../launch/landing-page.md) —
when one changes, update the other in the same commit.

## Enable GitHub Pages (one-time, owner action)

GitHub Pages' built-in branch picker only allows `/` or `/docs`
as a source — not nested subdirectories. We use GitHub Actions
to deploy from `docs/site/` instead (`.github/workflows/pages.yml`),
which means the owner needs to flip Pages to "GitHub Actions"
mode once:

1. Repository → Settings → Pages
2. Source: **GitHub Actions**
3. Save.

The next push that touches `docs/site/**` (or a manual
`workflow_dispatch`) deploys to
`https://hoangperry.github.io/herminal/` in ~30 seconds.

The `.nojekyll` file in this directory tells GitHub Pages to
skip Jekyll's underscore-file filtering — important so
`script.js` doesn't get accidentally hidden under any future
filename refactor.

## Local preview

```sh
cd docs/site
python3 -m http.server 4000
# → http://localhost:4000
```

## Design notes

- Style direction: **Swiss / editorial dark luxury.** Mono
  headlines reinforce the terminal identity; sans body keeps
  long copy readable.
- Colour ladder mirrors `Sources/HerminalApp/Design/DesignTokens.swift`
  so the website and the app feel like the same product.
- Single accent (`oklch(78% 0.13 178)` ≈ teal) — matches
  `HerminalDesign.Palette.accent` in dark mode.
- Animations: only the blinking cursor in the brand mark. No
  scroll-driven choreography — terminals don't need it.
- Mobile cutoff at 800 px stacks the two-column features; below
  640 px the nav links collapse, leaving only the GitHub link.
- `prefers-reduced-motion: reduce` kills the cursor blink.

## What's deliberately absent

- No build tooling. No bundler. No CMS. The site is small and
  the markdown source already tracks the marketing copy — adding
  Astro / Eleventy would be over-engineering.
- No tracking, no analytics, no CDN-pinned third-party fonts.
  Matches the in-app `SECURITY.md` no-telemetry promise.
- No newsletter signup / mailing list. The "no account" promise
  on the page extends to the page itself.
