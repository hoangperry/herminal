# Vietnamese IME Smoke Test — 20 Phrases

**Status:** Open manual compatibility check — owner or external macOS tester.
Tracked in [issue #2](https://github.com/hoangperry/herminal/issues/2).
**Estimated time:** ~10–15 minutes. No code changes are required.
**Goal:** Confirm Telex + VNI composition flows from macOS IME → herminal
NSTextInputClient → libghostty → PTY without dropped characters, mis-placed
diacritics, or doubled letters.

> **Note:** The Swift IME bridge (markedText state machine, accumulator
> behaviour, NSTextInputClient conformance) is covered by automated unit
> tests at `Tests/HerminalAppTests/IMEBridgeTests.swift` — that test suite
> runs in CI. This checklist exists for the things only a human typing
> through the real system IME can verify: composition popups, diacritic
> placement, and the visual feel of preedit underline.

## Setup

1. Use an Apple Silicon Mac running macOS Sonoma or later.
2. Install the signed public
   [`v1.0.0`](https://github.com/hoangperry/herminal/releases/tag/v1.0.0)
   DMG or `brew install --cask hoangperry/herminal/herminal`. To test current
   `main` instead, record the commit and launch a local build with
   `Scripts/make-app-bundle.sh && open .build/herminal.app`.
3. macOS System Settings → Keyboard → Input Sources → add both **Vietnamese
   Telex** and **Vietnamese VNI**.
4. Switch to Vietnamese Telex (⌃Space or the menu bar input menu). Use only the
   temporary filenames below; do not type private shell history or credentials.

## Run-the-list

For each phrase below, type the **input** column. The **expected** column
shows what should appear in the herminal terminal. Mark ✅ or ❌ in the
**result** column.

If the result is ❌, note in the **defect** column whether the issue is:
- **PREEDIT** (underlined preview is wrong)
- **COMMIT** (final text is wrong)
- **DROP** (characters missing)
- **DUP** (characters doubled)
- **CURSOR** (cursor mis-placed)

### Telex (`tieesng vieejt` → `tiếng việt`)

| # | Input | Expected | Result | Defect |
|---|-------|----------|--------|--------|
| 1 | `tieesng Vieejt` | `tiếng Việt` | | |
| 2 | `Phowr boif` | `Phở bò` | | |
| 3 | `Haf Nooji` | `Hà Nội` | | |
| 4 | `Camr own` | `Cảm ơn` | | |
| 5 | `Xin chaof` | `Xin chào` | | |
| 6 | `Moojt hai ba boons nawm` | `Một hai ba bốn năm` | | |
| 7 | `Hojc sinh` | `Học sinh` | | |
| 8 | `DDajj hojc` | `Đại học` | | |
| 9 | `Bunsr char` | `Bún chả` | | |
| 10 | `Banshs mif` | `Bánh mì` | | |
| 11 | `Truowngf hojc` | `Trường học` | | |
| 12 | `Laajp trinhf vieen` | `Lập trình viên` | | |
| 13 | `Phaanf meemf` | `Phần mềm` | | |
| 14 | `Maays tinhs` | `Máy tính` | | |
| 15 | `Mangj Internet` | `Mạng Internet` | | |

### Stress

| # | Input | Expected | Result | Defect |
|---|-------|----------|--------|--------|
| 16 | `Coongj hoaf xax hooji chur nghiax Vieejt Nam` | `Cộng hòa xã hội chủ nghĩa Việt Nam` | | |
| 17 | `Muaf thu Haf Nooji owr Vieejt Nam` | `Mùa thu Hà Nội ở Việt Nam` | | |
| 18 | `mef nuowng phuf phuf` | `mè nương phù phù` | | |
| 19 | (mix latin + vi) `git commit -m "thay ddooir font tieesng vieejt"` | `git commit -m "thay đổi font tiếng việt"` | | |
| 20 | (rapid type) `aaa bbb ccc ddd` then immediately `eeef ffff gggj` | `aaa bbb ccc ddd êê ff ggg` | | |

## Shell completion while preedit is active (manual compatibility gate)

Run these cases in an empty temporary directory whose filenames make the
expected completion unambiguous. Confirm the partial Vietnamese text is still
underlined immediately before pressing Tab.

```sh
mkdir -p /tmp/herminal-ime-tab && cd /tmp/herminal-ime-tab
mkdir 'tiếng-việt-project'
touch 'kiểm-thử.txt'
```

| # | Input source / shell | Action | Expected | Result | Defect |
|---|---|---|---|---|---|
| T1 | Telex / zsh | Type an underlined unique prefix of `tiếng-việt-project`, then press Tab once | Preedit commits once and path completes | | |
| T2 | VNI / zsh | Same as T1 using VNI | Preedit commits once and path completes | | |
| T3 | Telex / bash | Same as T1 | Preedit commits once and path completes | | |
| T4 | Telex / fish (if installed) | Same as T1 | Preedit commits once and path completes | | |
| T5 | Telex / zsh | With underlined preedit, press Shift-Tab | Text commits once; terminal receives Shift-Tab without duplicated text | | |
| T6 | US input / zsh | Type an ordinary ASCII unique prefix, press Tab | Existing non-IME completion remains unchanged | | |
| T7 | Telex / zsh | Repeat T1 rapidly 10 times on fresh prompts | No dropped or duplicated characters | | |

If T1 or T2 fails, keep the compatibility gate open and file a regression
before the next release. Record whether the underlined text remained visible,
committed without completion, disappeared, or duplicated.

## Pass criteria

- **≥18/20 phrases ✅** for the phrase matrix to count as a pass.
- **T1, T2, T5, T6, and T7 must pass**; T3/T4 pass when those shells are available.
- **0 ❌** of severity **DROP** or **DUP** (those are data-loss class).
- Any **CURSOR** defect documented for a follow-up bug.

## Privacy-safe result record

For T1–T7, the interactive recorder accepts only pass/fail/skipped and a bounded
defect class; it never asks for terminal history or typed content:

```sh
Scripts/record-vietnamese-ime-gate.sh
```

It writes a timestamped file under `docs/QA/results/` and exits non-zero unless
T1/T2/T5/T6/T7 pass with no DROP/DUP defect. Review the generated file before
committing it.

## Share the result

1. Run `Scripts/record-vietnamese-ime-gate.sh` from a repository clone and
   review the generated bounded result file before sharing it.
2. Open a small PR adding that timestamped file under `docs/QA/results/`, or
   paste its privacy-safe pass/fail matrix into
   [issue #2](https://github.com/hoangperry/herminal/issues/2). Do not overwrite
   this reusable checklist.
3. For any failure, open a separate bug with macOS version, Herminal release or
   commit, input source, case ID, and defect class. Never attach terminal
   history, usernames, filesystem paths, or credentials.

## Why this exists

Vietnamese-first input is a core Herminal promise, and Telex composition is the
moment of truth for "is this terminal usable by a Vietnamese developer." The
`NSTextInputClient` bridge has automated coverage, while this 20-phrase smoke
check catches real system-IME behavior such as:

- Single-keystroke diacritics that only fire on the SECOND character of
  a syllable (`ow` → `ơ`, `oo` → `ô`, `aw` → `ă`).
- Tone marks that attach to the wrong vowel when multiple are present
  (`oai` clusters love to mis-place `?`/`~`).
- Race conditions between `setMarkedText` and `keyDown` when the user
  types faster than 60Hz tick.
- IME candidate window positioning (firstRect must follow the cursor).

None of these can be unit-tested through the system IME — only by typing.
