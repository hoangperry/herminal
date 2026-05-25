# CJK IME Smoke Checklists (M9/D)

> **Status:** Owner-manual smoke tests. The Swift `NSTextInputClient`
> bridge that handles all IMEs is automated-tested in
> `Tests/HerminalAppTests/IMEBridgeTests.swift` (8 cases). These
> checklists exist for the things only a human typing through a real
> system IME can verify: candidate-window placement, composition
> popups, multi-keystroke conversion, and the visual feel of preedit
> underline for languages with vastly different IME shapes than the
> Latin-alphabet path Vietnamese Telex uses.

The Vietnamese checklist lives separately at
[`vietnamese-ime-checklist.md`](vietnamese-ime-checklist.md) — it's
the highest-priority for the PRD audience. These three target the
likely-second-largest non-Latin user populations.

---

## Setup (common)

1. macOS System Settings → Keyboard → Input Sources → add the
   relevant IME.
2. Build + launch: `Scripts/make-app-bundle.sh && open .build/herminal.app`.
3. Switch IME via the menu-bar flag or ⌃Space.

### Pass criteria (apply to every checklist below)

- **≥18/20 phrases ✅** for a pass.
- **0 ❌ of severity DROP or DUP** (data-loss class).
- Any **CURSOR** defect (candidate window mis-placed) documented as a
  separate issue.

### Defect taxonomy

- **PREEDIT** — underlined preview is wrong.
- **COMMIT** — final text after candidate selection is wrong.
- **DROP** — characters missing from commit.
- **DUP** — characters doubled.
- **CURSOR** — candidate window appears at wrong position.

---

## 1. Korean — Hangul 2-set (한국어)

Most common Korean IME on macOS. Each Hangul syllable composes from
a leading consonant + vowel + optional trailing consonant; the IME
combines successive keystrokes until the syllable is "closed."

### Setup-specific
- System Settings → Keyboard → Input Sources → Korean → 2-Set Korean.

### Run-the-list

For each row, type the **input** column. The result should match the
**expected** column.

| # | Input | Expected | Result | Defect |
|---|-------|----------|--------|--------|
| 1 | `dkssudgktpdy` | `안녕하세요` (Hello) | | |
| 2 | `gks rmf` | `한 글` | | |
| 3 | `wkdek ekfak` (with space) | `자다 달마` | | |
| 4 | `tjdrh` | `섥` (compound trailing) | | |
| 5 | `wkdrnsek` | `장군다` | | |
| 6 | `sosk` | `너나` | | |
| 7 | `dkfk` | `안` (verifies trailing consonant binding) | | |
| 8 | `dkfak` | `달마` | | |
| 9 | `tprl wnstp` | `세기 줘서` | | |
| 10 | `gktp` | `해서` | | |
| 11 | `dygd` | `아햏` (compound vowel) | | |
| 12 | `dndnd` | `우우우` (repeated syllables) | | |
| 13 | `rmflrh tlfgwlx` | `그리고 실패지` | | |
| 14 | `qhrh wkdguq` | `보고 자행` | | |
| 15 | `wkdkrhrlsek` | `자아고기다` (long compose) | | |
| 16 | `xosqltm` | `텐비스` (consonant cluster) | | |
| 17 | `dlsx` | `인트` | | |
| 18 | `vkdltlf` | `파이실` | | |
| 19 | (rapid type) `gks gks gks gks` | `한 한 한 한` | | |
| 20 | (mixed Latin + KR) `git commit -m "rmflrh"` | `git commit -m "그리고"` | | |

---

## 2. Japanese — Romaji → Hiragana → Kanji (日本語)

Japanese IME on macOS goes Romaji input → Hiragana preview → Kanji
candidate window on Space. The candidate-window placement is the
test surface most likely to surface a bug — it lands at the cursor,
needs to track in tmux, and needs to render across the libghostty
surface boundary cleanly.

### Setup-specific
- System Settings → Keyboard → Input Sources → Japanese → Japanese
  (Romaji input).

### Run-the-list

`Space` after Romaji opens the candidate window — try the first
candidate (Enter or another Space) unless noted.

| # | Input | Expected | Result | Defect |
|---|-------|----------|--------|--------|
| 1 | `konnichiwa` + Enter | `こんにちは` (Hiragana) | | |
| 2 | `konnichiwa` + Space + Enter | `今日は` (Kanji candidate) | | |
| 3 | `arigatou` + Enter | `ありがとう` | | |
| 4 | `arigatou` + Space + Enter | `有難う` (or first candidate) | | |
| 5 | `nihongo` + Space + Enter | `日本語` | | |
| 6 | `tokyo` + Space + Enter | `東京` | | |
| 7 | `gomennasai` + Enter | `ごめんなさい` | | |
| 8 | `sumimasen` + Enter | `すみません` | | |
| 9 | `watashi` + Space + Enter | `私` | | |
| 10 | `desu` + Enter | `です` | | |
| 11 | `kantan` + Space + Enter | `簡単` | | |
| 12 | `prog ramu` (with space) + Enter | `プログラ ム` (Katakana via space split) | | |
| 13 | `kompyu-ta-` + Enter (Katakana mode) | `コンピューター` | | |
| 14 | `e-meeru` + Enter | `イーメール` | | |
| 15 | (long sentence) `kyouhaiitenkidesune` + Space + Enter | `今日はいい天気ですね` | | |
| 16 | `q` (verifies `q` doesn't compose) | `q` | | |
| 17 | (rapid type) `aaaa` + Enter | `ああああ` | | |
| 18 | (mixed Latin) `git commit -m "konnichiwa"` + Enter twice | `git commit -m "こんにちは"` | | |
| 19 | Cycle candidates: `nihongo` + Space + Space + Space + Enter | second/third candidate selected | | |
| 20 | Cancel mid-compose: `konni` + Esc | nothing committed; preedit cleared | | |

---

## 3. Chinese — Pinyin (Simplified) (简体中文)

Chinese Pinyin IME is the candidate-window stress test — many Pinyin
strings have dozens of candidates and the user scrolls or types a
number to select. The PageUp/PageDown / number-key path is the one
most prone to subtle bugs.

### Setup-specific
- System Settings → Keyboard → Input Sources → Chinese (Simplified)
  → Pinyin – Simplified.

### Run-the-list

`Space` selects the first candidate; number keys (`1` `2` `3`...)
select that-numbered candidate; PageDown / PageUp scrolls.

| # | Input | Expected | Result | Defect |
|---|-------|----------|--------|--------|
| 1 | `nihao` + Space | `你好` | | |
| 2 | `xiexie` + Space | `谢谢` | | |
| 3 | `zhongguo` + Space | `中国` | | |
| 4 | `beijing` + Space | `北京` | | |
| 5 | `women` + Space | `我们` | | |
| 6 | `shijie` + Space | `世界` | | |
| 7 | `pinyin` + Space | `拼音` | | |
| 8 | `shouji` + Space | `手机` | | |
| 9 | `diannao` + Space | `电脑` | | |
| 10 | `wenti` + Space | `问题` | | |
| 11 | `nihao` + `2` | second candidate selected (not `你好`) | | |
| 12 | `kafei` + Space | `咖啡` | | |
| 13 | `yueliang` + Space | `月亮` | | |
| 14 | `taiyang` + Space | `太阳` | | |
| 15 | `pengyou` + Space | `朋友` | | |
| 16 | (long compose) `wodepengyou` + Space | `我的朋友` (multi-character commit) | | |
| 17 | (verify scroll) `de` + PageDown + Space | second-page first candidate | | |
| 18 | (cancel mid-compose) `nih` + Esc | nothing committed; preedit cleared | | |
| 19 | (rapid type) `hao hao hao` + Space + Space + Space | `好 好 好` | | |
| 20 | (mixed Latin) `git commit -m "nihao"` + Space + Enter | `git commit -m "你好"` | | |

---

## After running

1. File any ❌ rows as issues under
   [`docs/backlog/`](../backlog/) using the bug-report template.
2. Capture the filled-in checklist as
   `docs/QA/cjk-ime-checklist-YYYY-MM-DD-<lang>.md` per language per
   run so historical results live in git.
3. The Vietnamese checklist is the priority gate per the PRD; CJK
   passes are a beta-readiness signal but don't gate v0.1.0.

## Why this exists

CJK input methods stretch the `NSTextInputClient` surface in ways
Vietnamese Telex doesn't:

- **Korean**: composition combines successive keystrokes WITHOUT a
  candidate window — pure preedit. If `setMarkedText` doesn't
  replace the entire previous preview each call, characters double.
- **Japanese**: explicit candidate window driven by `Space`. The
  IME asks libghostty for `firstRect(forCharacterRange:)` to position
  it — if our implementation returns the wrong rect, the popup
  lands at the top-left of the screen instead of the cursor.
- **Chinese**: same candidate-window surface as Japanese, plus
  number-key shortcuts that fire as keyDown events. Our keyDown
  must NOT consume these when an IME composition is active —
  `interpretKeyEvents` handles the routing.

Each language exercises a different combination of `setMarkedText`,
`insertText`, `firstRect`, and the IME's interaction with `keyDown`.
If one passes and another fails, the failing path identifies the bug
class without needing kernel-level diagnostics.
