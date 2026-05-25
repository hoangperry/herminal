# Demo video — script + shot list

Target: 90-second silent screen recording with overlaid text
captions. No voiceover (cleaner audio cross-platform; no accent
debates). Plays as the hero embed on the landing page + the
Product Hunt video field + the Twitter thread.

Format: 1920×1080 H.264 .mp4 for landing page, looped 4-second
GIF for Twitter / GitHub README. Owner produces in QuickTime
+ ffmpeg from the source recording.

---

## Storyboard

| Sec | Caption | Screen content |
|-----|---------|----------------|
| 0-3 | "macOS terminal cho dev người Việt sống trong Claude Code." | herminal launches; first tab opens; cursor blinks in `~/projects/herminal` directory; prompt visible. |
| 3-8 | "Type Vietnamese reliably." | User types `echo "tieesng vieejt"` → Vietnamese characters compose in real-time (Telex preview underlined, then committed). Enter; output `tieesng vieejt` literal echo. |
| 8-15 | "Run AI agents — see all of them at a glance." | User toggles agent dashboard (⌘⇧A). User types `claude` and presses Enter in tab 1. Dashboard updates within 2s: `● Claude Code · Tab 1 · running`. User opens a new tab (⌘T), types `codex`. Dashboard shows both. |
| 15-22 | "BEL detection promotes idle → needs input." | Tab 2 (codex) emits a BEL (`printf '\a'` typed deliberately). Dashboard flips Codex row from blue (running) to amber (needs input). Caption appears: "Bell heard → agent flagged." |
| 22-30 | "SSH manager — your ~/.ssh/config, ready to use." | User toggles SSH sidebar (⌘⇧S). Sidebar shows 6 imported hosts (`prod-web`, `staging-api`, etc). User clicks "Connect" on `staging-api`. New tab opens with `ssh deploy@staging.example.com:2222` running. Caption: "One click. Real ssh." |
| 30-40 | "Per-session notes — local SQLite, Markdown round-trip." | User toggles notes panel (⌘⇧N). Types a multi-line Markdown note with headers + a bullet list. Caption: "Notes never leave your machine." User triggers File → Export Note, save dialog flashes. |
| 40-55 | "Split panes, tmux, vim, fzf — works everywhere." | User splits the active pane (⌘D). Right pane: opens vim on a Markdown file. Left pane: runs `fzf` on a directory listing. Caption: "9/9 TUI compat tested." |
| 55-65 | "Light or dark theme." | User triggers ⌘⇧L to toggle to light theme. Whole window animates from dark → light. Caption: "⌘⇧L." User toggles back to dark. |
| 65-78 | "Performance you can feel — sub-5ms keystroke latency." | Side-by-side keystroke-to-render: herminal vs Warp (or similar Electron terminal — owner picks a fair competitor). Caption: "p95 < 5 ms. Native Metal." |
| 78-85 | "Local-first. No telemetry. No account. MIT." | Show the empty `~/Library/Application Support/herminal/` directory listing (notes.db + ssh-hosts.db + diary.log + WAL files — 3 visible files, all local). Caption fades in. |
| 85-90 | "github.com/hoangperry/herminal" | Logo + URL on a clean dark background. Pause for 5s so it's screenshot-friendly. |

---

## Caption styling

- Font: SF Pro Display (system) at the highest weight Apple has
  shipped. Tracking -2%. White text on a 60% black drop-shadow
  pill so it reads against any background.
- Caption duration: appears as the relevant shot begins; fades
  out 0.4 s before the next caption appears.
- Maximum 8 words per caption. If a section needs more text, it
  belongs on the landing page, not the video.

---

## Audio

No voiceover. Background music: a subtle bed of typing sounds
recorded from the actual mechanical keyboard the demo is shot on.
Public-domain or owner-licensed — do NOT use copyrighted music;
YouTube + Product Hunt will both flag it.

Sound effects:
- Soft click on every tab open / sidebar toggle
- Distinct chime when the agent dashboard flips an agent to
  "needs input" — that's the moment the value-prop lands

---

## Recording checklist (owner)

Before pressing record:

- [ ] macOS desktop is clean — no Dock or menu bar clutter, hide
      with `defaults write com.apple.dock autohide -bool true`
- [ ] herminal at v0.1.0 (signed bundle), not a dev build
- [ ] `~/.ssh/config` populated with 5-6 example hosts (could be
      fake but plausible — `prod-web`, `staging-api`, etc.)
- [ ] Claude Code + Codex + Aider installed and runnable
- [ ] Window position: dead-centred; QuickTime crops to the
      window only
- [ ] Display scale: 2× retina; export at 2× and let consumers
      down-scale to 1× as needed
- [ ] Network off (Wi-Fi disabled) during the recording —
      proves the "no telemetry" claim visually if anyone
      compares Activity Monitor

After recording:

- [ ] Trim to exactly 90 seconds. Anything longer loses retention.
- [ ] Export H.264 high-quality .mp4 for landing/PH
- [ ] Export 4-second GIF loop of seconds 8-12 (agent dashboard
      pickup) at 480px wide for Twitter / GitHub README
- [ ] Upload .mp4 to GitHub Releases as a separate asset for
      v0.1.0 — landing page references the GH-hosted URL so it
      works in markdown previews everywhere

---

## A/B angle for re-cuts

If the v0.1.0 launch underperforms, the most likely re-cut angle
is to lead with the agent dashboard instead of the Vietnamese IME.
The agent angle is universal; the Vietnamese angle resonates with
a smaller audience.

Re-cut storyboard:

- Sec 0-15: agent dashboard intro (same as 8-22 above)
- Sec 15-30: SSH manager (same as 22-30)
- Sec 30-45: split panes + tmux (same as 40-55)
- Sec 45-60: Vietnamese IME (same as 3-8, expanded)
- Sec 60-75: notes + theme toggle
- Sec 75-90: outro (same as 78-90)

Keep the underlying recording — re-cut is editing-only.
