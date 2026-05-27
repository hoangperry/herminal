// herminal site — minimal interaction layer.
//
// The site is intentionally static; the only JS is a smooth-scroll
// polyfill for in-page nav anchors on browsers that disabled the
// CSS-level smooth scrolling, and a tiny reveal that swaps the
// hero CTA's version label if a newer release is detected on the
// GitHub releases JSON endpoint (best-effort, no spinner — silent
// on failure so a cold cache or offline visit shows the stale
// label rather than a broken UI).

(function () {
  "use strict";

  // ────────────────────────────────────────────────── In-page nav
  for (const link of document.querySelectorAll('a[href^="#"]')) {
    link.addEventListener("click", (evt) => {
      const id = link.getAttribute("href").slice(1);
      if (!id) return;
      const target = document.getElementById(id);
      if (!target) return;
      evt.preventDefault();
      target.scrollIntoView({ behavior: "smooth", block: "start" });
      // Update the URL so a refresh / share lands on the same section.
      history.replaceState(null, "", "#" + id);
    });
  }

  // ────────────────────────────────────────────────── Latest version
  // Refreshes the CTA label if GitHub reports a newer release tag.
  // 12-hour client cache via sessionStorage so we don't hammer the API.
  const cacheKey = "herminal:latest";
  const cacheTtlMs = 12 * 60 * 60 * 1000;
  const ctaLabels = document.querySelectorAll('a.cta.primary');
  if (ctaLabels.length === 0) return;

  let cached;
  try { cached = JSON.parse(sessionStorage.getItem(cacheKey) || "null"); } catch (_) { /* ignore */ }
  if (cached && (Date.now() - cached.at) < cacheTtlMs) {
    applyTag(cached.tag);
    return;
  }

  fetch("https://api.github.com/repos/hoangperry/herminal/releases/latest", {
    headers: { Accept: "application/vnd.github+json" },
    // Best-effort — silently no-op on cold cache + offline.
    cache: "force-cache",
  })
    .then((r) => (r.ok ? r.json() : null))
    .then((j) => {
      if (!j || !j.tag_name) return;
      try { sessionStorage.setItem(cacheKey, JSON.stringify({ tag: j.tag_name, at: Date.now() })); } catch (_) {}
      applyTag(j.tag_name);
    })
    .catch(() => { /* offline / rate-limited / blocked — keep static label */ });

  function applyTag(tag) {
    for (const cta of ctaLabels) {
      // Only mutate the "Download X" CTA, not the "View source" / ghost ones.
      const text = (cta.firstChild && cta.firstChild.textContent) || "";
      if (!text.toLowerCase().includes("download")) continue;
      cta.firstChild.textContent = "Download " + tag + " ";
      // Rewrite the href so the button always points at the matching
      // tag's release page (not just /latest, in case of cache mismatch).
      const href = cta.getAttribute("href") || "";
      if (href.includes("/releases/latest")) {
        cta.setAttribute(
          "href",
          "https://github.com/hoangperry/herminal/releases/tag/" + tag
        );
      }
    }
  }
})();
