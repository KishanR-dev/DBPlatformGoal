# Hyperframes Composition Brief: DBPlatformGoal (ServicePulse)

## Objective
Create a short launch-style brag video for DBPlatformGoal (ServicePulse).

## Output
- Composition directory: `brag-output/composition/`
- Rendered video: `brag-output/brag.mp4`
- Format: landscape — 1920x1080
- Duration: 20 seconds

## Source Material
- Project root: `.`
- Primary files read: `README.md`, `docs/PORTFOLIO_BRIEF.md`, `src/servicepulse/pyproject.toml`, `.gitlab-ci.yml`, `charts/servicepulse/Chart.yaml`
- Product name: DBPlatformGoal / ServicePulse
- Tagline / strongest claim: "Evidence-First Platform Engineering"
- Key UI or visual moment to recreate: Terminal test execution showing 78 tests passed in 5.25s, 7-stage GitLab pipeline architecture, and Kubernetes PSA security controls.
- Copy that must appear verbatim:
  - "78 passed in 5.25s"
  - "2,000+ lines of robust Bash scripts — 100% ShellCheck compliance"
  - "Kubernetes Pod Security Admission: restricted enforced"
  - "0 CVEs | 0 bandit issues"

## Creative Direction
- Tone preset: polished
- Creative direction: serious premium platform engineering portfolio film with real test validation and infrastructure evidence
- Interpretation: Restrained motion, high typographic clarity, dark-mode terminal & dashboard design, confident presentation of verifiable engineering evidence.
- Angle: An evidence-first platform engineering showcase centered around ServicePulse — presenting verifiable local validation, from passing test suites and ShellCheck-compliant Bash to automated GitLab CI pipelines and Kubernetes security controls.
- Hook: A terminal view rapidly executing pytest across API, failure simulation, and regression suites, resolving in `78 passed in 5.25s`.
- Outro / punchline: "DBPlatformGoal: Production-grade platform engineering, locally verified."
- Avoid:
  - Generic SaaS language
  - Abstract filler visuals
  - Unrelated visual redesign

## Visual Identity
- Background: #0f172a (Slate 900)
- Surface/Card: #1e293b (Slate 800)
- Border: #334155 (Slate 700)
- Text Primary: #f8fafc (Slate 50)
- Text Muted: #94a3b8 (Slate 400)
- Accent: #38bdf8 (Sky 400)
- Success: #34d399 (Emerald 400)
- Display font: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, monospace
- Body font: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif
- Visual references from the project: Terminal CLI output, GitLab pipeline stage indicators, Kubernetes architecture cards.

## Storyboard
Use the storyboard in `brag-output/brag-plan.md` as the creative contract.

Scene summary:
1. Hook (0.0s - 3.5s) — Terminal test execution: `pytest src/servicepulse` -> `78 passed in 5.25s`
2. Pipeline & Compliance (3.5s - 9.0s) — GitLab 7-stage pipeline card, Bandit security scan (0 issues), Pip-audit (0 CVEs)
3. Infrastructure & Security (9.0s - 15.0s) — Kubernetes Pod Security Admission (`restricted`), Helm atomic upgrades, nftables network boundary enforcement
4. Outro (15.0s - 20.0s) — Final verdict: "DBPlatformGoal — Evidence-First Platform Engineering"

## Audio
- Audio role: sparse professional accents / warm tech bed
- Audio arc: subtle rhythmic start under terminal hook, building confidence through pipeline and Kubernetes security, ending with clean chord.
- Music: happy-beats-business-moves-vol-1-by-ende-dot-app.mp3
- Music treatment: moderate volume, clean fade-out at end.
- Audio files: copied to `brag-output/composition/assets/music/`
