# Vietnamese IME Smoke Test — 20 Phrases (M1-11)

**Status:** Owner manual test. Carry from Month 1 — 4 months old as of M5.
**Estimated time:** ~10 minutes.
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

1. macOS System Settings → Keyboard → Input Sources → add **Vietnamese
   Telex** (or VNI — both should be tested).
2. Build + launch herminal: `Scripts/make-app-bundle.sh && open .build/herminal.app`.
3. Switch IME to Vietnamese Telex (⌃Space or the menu bar flag).

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

## Pass criteria

- **≥18/20 phrases ✅** for the matrix to count as a pass.
- **0 ❌** of severity **DROP** or **DUP** (those are data-loss class).
- Any **CURSOR** defect documented for a follow-up bug.

## After running

1. File any ❌ rows as issues in `docs/backlog/` under the relevant month.
2. Tick `M1-11` complete in `docs/backlog/month-1.md` (and remove from
   carry-over in subsequent months).
3. Commit the filled-in checklist as
   `docs/QA/vietnamese-ime-checklist-YYYY-MM-DD.md` so the result is
   captured per-run rather than overwriting the template.

## Why this exists

Vietnamese is the second-largest population of Claude Code users in the
PRD personas, and Telex composition is the moment of truth for "is this
terminal usable by a Vietnamese developer." The Month-1 spike got the
NSTextInputClient pipe wired and verified one phrase by hand. A 20-phrase
smoke catches:

- Single-keystroke diacritics that only fire on the SECOND character of
  a syllable (`ow` → `ơ`, `oo` → `ô`, `aw` → `ă`).
- Tone marks that attach to the wrong vowel when multiple are present
  (`oai` clusters love to mis-place `?`/`~`).
- Race conditions between `setMarkedText` and `keyDown` when the user
  types faster than 60Hz tick.
- IME candidate window positioning (firstRect must follow the cursor).

None of these can be unit-tested through the system IME — only by typing.
