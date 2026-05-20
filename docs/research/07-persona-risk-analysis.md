# Herminal: AI-Native macOS Terminal Analysis (Vietnamese Market)

## A. User Persona Deep-Dive

### Persona 1: Bảo Nguyễn (The Agile Soloist)
- **Age:** 28
- **Role:** Senior Frontend Engineer & Indie Hacker (building a local SaaS for SMEs).
- **Tech Stack:** Next.js, Tailwind, Supabase, Claude Code, Cursor, Bun.
- **Pain Points:** 
    - Claude Code sessions in iTerm2 feel "dumb"—streaming output is fast but lacks context linkage to his task notes.
    - Constant context switching between the terminal and Obsidian to log what the agent did.
    - Occasional Vietnamese Telex input glitches in Warp's custom UI framework.
- **Switch Trigger:** A terminal that "remembers" what the agent was doing in a side panel and lets him type `tiếng Việt` without a single flickering glyph.
- **Resistance Point:** If `libghostty` feels even slightly "less native" than Ghostty/iTerm2 in terms of window snapping or keyboard shortcuts.
- **Estimated TAM:** ~15,000 - 20,000 (Solo/Indie devs in VN).

### Persona 2: Linh Trần (The Infrastructure Guardian)
- **Age:** 34
- **Role:** DevOps Lead at a major Vietnamese Fintech startup.
- **Tech Stack:** Go, Kubernetes, Terraform, tmux, SSH, lazygit, Aider.
- **Pain Points:** 
    - Privacy: Cannot use Warp because company policy forbids terminal telemetry and cloud-based shell history.
    - Lives in `tmux` but needs to monitor 3 parallel Claude Code agents fixing bugs in different microservices.
    - Notes for incidents are scattered across Markdown files; hard to prove "which command led to this state" 3 hours later.
- **Switch Trigger:** A dashboard that shows his 3 active agents as first-class citizens while keeping his `tmux` workflow 100% intact and local-only.
- **Resistance Point:** Any lack of stability in `ssh` or `tmux` behavior. If it breaks her "safe" environment, she's out.
- **Estimated TAM:** ~5,000 - 8,000 (SRE/DevOps/Security leads in VN).

### Persona 3: Khoa Đặng (The Academic Innovator)
- **Age:** 22
- **Role:** Final-year CS Student & AI Research Intern.
- **Tech Stack:** Python, PyTorch, Jupyter, Ollama, local LLMs, Ghostty.
- **Pain Points:** 
    - High cognitive load when running local model experiments; hard to keep track of which prompt/agent version produced which result.
    - Needs to write technical documentation in Vietnamese and English simultaneously.
    - Ghostty is fast but "too minimal" for managing the chaos of research terminal sessions.
- **Switch Trigger:** The "Persistent Notes" feature. Being able to attach a scratchpad directly to a local AI experiment session is a game-changer for his thesis.
- **Resistance Point:** Performance. If adding "features" like notes and dashboards makes the terminal slower than Ghostty, he will revert to the faster tool.
- **Estimated TAM:** ~10,000 - 15,000 (Students and AI researchers in VN).

---

## B. Top 12 Risks (Ranked by Severity x Probability)

| Rank | Risk Statement | Sev (1-5) | Prob (1-5) | Score | Mitigation Strategy | Early Warning Signal |
| :--- | :--- | :---: | :---: | :---: | :--- | :--- |
| 1 | **IME Corruption** | 5 | 4 | 20 | Use `NSTextInputClient` directly on AppKit layer; weekly regression tests for Telex/VNI. | First report of "ghost characters" or cursor misalignment during Vietnamese typing. |
| 2 | **libghostty ABI Drift** | 4 | 4 | 16 | Wrap `libghostty` in a thin, versioned C-bridge; track upstream changes daily. | Upstream Ghostty refactors the PTY or rendering bridge, breaking the Swift wrapper. |
| 3 | **Solo Developer Burnout** | 4 | 4 | 16 | Freeze MVP scope at 7 features; 1-month "tech-only" spike; strictly part-time schedule. | Skipping more than 3 consecutive weekly "Owner-as-Daily-Driver" tests. |
| 4 | **Scope Creep (Warp Clone)** | 3 | 5 | 15 | Strict "No Cloud/No Account" policy; reject all features not in MoSCoW. | Planning an "AI Chat Sidebar" instead of improving the "Agent Dashboard." |
| 5 | **tmux Performance Stalls** | 4 | 3 | 12 | Test with complex tmux layouts (6+ panes) early; optimize PTY throughput. | Noticeable lag in `btop` or `lazygit` when running inside a tmux session in Herminal. |
| 6 | **SQLite Data Loss** | 5 | 2 | 10 | Use SQLite WAL mode; atomic saves; backup-on-launch for the `notes.db`. | User reports a note "disappeared" after a macOS forced restart/crash. |
| 7 | **Market Saturation (cmux)** | 3 | 3 | 9 | Focus on the "Vietnamese First" niche (IME + local notes); avoid generic features. | cmux (or similar) adds first-class support for Vietnamese input methods. |
| 8 | **macOS API Changes** | 4 | 2 | 8 | Target the latest stable macOS; avoid private APIs; use Metal for rendering. | New macOS beta breaks AppKit/SwiftUI interoperability for the terminal view. |
| 9 | **Agent Status False Positives** | 2 | 4 | 8 | Allow manual status overrides; use transparent "Unknown" state; show raw PID state. | Dashboard says an agent is "Done" but the shell process is still spinning CPU. |
| 10 | **Memory Leaks (Metal/Swift)** | 3 | 2 | 6 | Use Instruments for monthly leaks audit; profile long-running Claude Code streams. | Herminal RAM usage exceeds 500MB after a 4-hour coding session. |
| 11 | **Notarization/Distribution Gate** | 3 | 2 | 6 | Start `notarytool` setup in Month 2; avoid App Store; use Homebrew Cask. | "App is damaged" macOS warning on a clean install during beta. |
| 12 | **No Monetization Path** | 1 | 4 | 4 | Accept this as a pet-project first; define "Success" by usage, not revenue. | Anxiety about "competitors with funding" slows down actual coding. |

---

## C. Success Metrics Reality Check

For a solo pet project, standard VC metrics are delusional. We need **Honest Success Criteria**:

1. **Owner Dogfooding (The "Daily Driver" Test):** The developer uses Herminal as their primary terminal for 30 consecutive workdays without falling back to Ghostty/iTerm2 for more than 10 minutes.
2. **The "Vietnamese Trust" Metric:** Zero reported IME bugs in the `notes.db` or terminal prompt for 14 consecutive days of active use.
3. **Task Linkage Utility:** 100% of the developer's "Claude Code" sessions in a specific repo have a corresponding non-empty note in the sidebar.
4. **Performance Parity:** p95 latency for key-to-render stays under 16ms (60fps baseline) even during heavy agent streaming.
5. **Community Pulse:** 5 unrelated Vietnamese developers provide 1 piece of constructive feedback that isn't just "it crashed."
6. **Survival Metric:** The project reaches Month 4 with a stable build and no feature-list expansion from the original MVP scope.
7. **The "Why" Factor:** At least one beta user says: "I switched because the notes panel is exactly what I needed for my agent tasks."
