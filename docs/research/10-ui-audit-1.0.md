# UI/UX audit — 1.0.0

A pre-1.0 pass over every SwiftUI surface in `Sources/HerminalApp`
(command palette, settings, the four sidebars, notes, status bar, tab
bar, search + welcome overlays, focus ring, divider). Goal: catch the
rough edges that read as "unfinished" before declaring 1.0.

## Verdict: the UI is already mature

The panels are consistently high quality and don't need rework. Spot
checks:

- **Design system in use.** `HerminalDesign` tokens (Palette,
  Typography, Spacing, Radius, Motion, Geometry) back the sidebars, notes,
  tab bar. Colours/spacing/radii are centralised, theme-aware (dark +
  light + follow-system).
- **States are designed.** List rows (Claude, SSH) have hover fills +
  accent-border affordance with an eased transition; buttons have hover
  states; the focused pane has its accent outline (v0.5.2).
- **Empty states exist** for every sidebar (agents / Claude / SSH) — not
  blank, with a one-line "what to do" hint.
- **Accessibility is present** — header traits, `accessibilityLabel` /
  `Hint` on icon-only buttons and combined row elements, status colours
  paired with text (not colour-only).

## Fixed in this pass

1. **Command palette had no "no results" state** — when the query matched
   nothing the list area went blank, reading as broken. Added a centred
   magnifying-glass + "No matching commands" placeholder.
2. **First-run welcome card was stale for 1.0** — it listed the basic
   shortcuts but never mentioned the two things that make herminal
   discoverable + distinctive: the **command palette** (`⌘⇧P` — now the
   lead line, "search every command") and **Claude session resume**
   (`⌘⇧C`). Also surfaces pane zoom (`⌘⇧Return`). Migrated its hardcoded
   fonts to the Typography tokens they already matched exactly (no visual
   change, less drift).

## Tracked, not changed (deliberate)

- **Some views still hardcode `.font(.system(size:))`** (StatusBar,
  SearchOverlay, parts of CommandPalette) at sizes/weights the Typography
  enum doesn't expose 1:1 (e.g. status-bar 10 pt, palette 15 pt field).
  Migrating blind would shift the tuned look, so left as-is; revisit by
  adding the two missing scale tokens if the drift ever bites.
- **Agent rows have no hover state** — intentional; they're not
  interactive (no click target), unlike the Claude/SSH rows.

Net: 1.0's UI is shippable. This pass closed the two genuine gaps a new
user would hit (an empty palette search, a welcome card that undersold
the product) without risking the existing visual tuning.
