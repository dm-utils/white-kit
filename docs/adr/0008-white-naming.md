# 0008 White naming across the series

Status: accepted (2026-11-18), to be carried out (board cards whitecap #016 build, #017 test)

Scope: all repositories of the White series (white-cap, white-lie, white-glove, white-shift, white-tally, white-drift,
white-sum), white-kit, pulse, the private design folders, the local environment on the VM and the
public addresses under `steefbeest.nl`. White Kit holds this record because it is the shared base of the series.

## Context

The owner decided on 2026-11-18:

- Technical names are always lowercase `white-<name>`: repositories, local folders in `~/Git`, game ids, design
  folders and addresses.
- Player-facing titles are always `White <Name>` (space, two capitals). Whitecap becomes White Cap. The tagline
  "Survival of the driest!" stays.
- App ids stay `com.st33f.white<name>` without a hyphen.
- Play versions move to `play.white-<name>.steefbeest.nl`, promo sites to `white-<name>.steefbeest.nl`. Old addresses
  keep working through a permanent redirect (301).
- One VS Code workspace `~/Git/white.code-workspace` replaces the older workspace files.
- The series is in a test phase without real players; dev data may be renamed.

### Inventory (2026-11-18)

| Item | Now | Deviates |
|---|---|---|
| GitHub repos | `dm-utils/whitecap`, all others already `white-<name>` | whitecap |
| Local folders | `~/Git/whitecap`, others `white-<name>`; `~/Git/st33f-engine` is a symlink to `pulse` | whitecap |
| Game ids (Pulse, `project.godot [st33f] game`) | `whitecap`, `white-lie`, `white-glove`; puzzles have no Pulse id, their kit game id is the repo name | whitecap |
| Titles | `config/name` "Whitecap", others "White <Name>"; logo text `WHITECAP`, others `WHITE LIE`, `WHITE GLOVE` | whitecap |
| App ids | `com.st33f.whitecap`, `com.st33f.whitelie`, `com.st33f.whiteglove`; puzzles have no Android build | none |
| Play addresses (GitHub Pages, custom domain, CNAME in Cloudflare) | `play.whitecap.`, `play.whitelie.`, `play.whiteglove.`, `play.whiteshift.`, `play.whitetally.`, `play.whitedrift.`, `play.whitesum.steefbeest.nl` | all 7 |
| Promo sites (Workers static assets, `custom_domain` route) | `whitecap.`, `whitelie.`, `whiteglove.steefbeest.nl` in `pulse/apps/white{cap,lie,glove}-site`, workers `st33f-white{cap,lie,glove}-site` | all 3 |
| Design folders | `designs/Whitecap`, `WhiteLie`, `Rommelstrooiers` (= White Glove), `WhiteShift`, `Puzzels` | all 5 |

Where the old id is used in Pulse (all keyed by the game id string):

- `packages/origins`: `GAMES`, `GAME_NAMES`, dev `ORIGINS` (old play addresses).
- accounts D1: `login_codes.game`, `game_profiles`, `deleted_profiles`, `game_settings_defs`, `game_settings`,
  `game_settings_versions`, `game_settings_changes`; mail subject via `GAME_NAMES`; privacy page text.
- leaderboards D1: `game_rules`, `scores`, `players`, `friend_codes`, `friends`; the daily seed is
  `HMAC(secret, 'daily:<game>:<day>')`; run tokens carry `g: <game>`. The pseudonymous pid does not depend on the game.
- feedback D1: `feedback.game`, `crash_groups.game`; crash group ids are a fingerprint over the game id;
  `GITHUB_REPO_WHITECAP = dm-utils/whitecap` in `wrangler.jsonc` (3 envs), `triage.ts`.
- i18n D1: namespace `ns` in `strings`, `translations`, `glossary`; the portal default namespace in `public/app.js`.
- pvp: `CHARACTERS`, `FRIENDS_ONLY`, lobby Durable Object names `<game>[:mode][:v:<build>|:room:<code>]` (no
  persistent data).
- admin: no game id in code, only in tests.
- Godot SDK test project (`packages/godot-sdk/project.godot`, tests).
- Whitecap CI pushes setting declarations and score rules to `/v1/games/whitecap/...`, `verify-scores.yml` reads
  `/v1/games/whitecap`, `tools/i18n_sync.py` uses namespace `whitecap`.

No `.gitleaks.toml`, `.gitleaksignore` or `CNAME` file exists in any repo; Pages custom domains are repository
settings (Pages is deployed by Actions). `scan-ai-traces.sh` and `setup-agents.sh` contain no repo names.
`export-showcase.sh` keys its store on the basename of the working folder.

## Decision

### 1. Naming rules

| Kind | Rule | White Cap example |
|---|---|---|
| Repository, local folder, game id, design folder, i18n namespace, Pulse app folder and package, worker name part, workflow file | `white-<name>` lowercase | `white-cap`, `apps/white-cap-site`, `@st33f/white-cap-site`, `st33f-white-cap-site`, `white-cap-site.yml` |
| Addresses | `play.white-<name>.steefbeest.nl`, `white-<name>.steefbeest.nl` | `play.white-cap.steefbeest.nl` |
| Player title (running text, window title, Android label, Windows product name, sites, mail) | `White <Name>` | `White Cap` |
| Logo text (boot screen, web loader, `TITLE` key) | `WHITE <NAME>`, as White Lie and White Glove already do | `WHITE CAP` |
| App id | `com.st33f.white<name>`, unchanged | `com.st33f.whitecap` |
| Windows executable | `White<Name>.exe`, as White Lie and White Glove already do | `WhiteCap.exe` |
| Android debug artifact | `white-<name>-debug.apk` (CI only; served as `android.apk`) | `white-cap-debug.apk` |

Out of scope (unchanged on purpose): the Godot addon paths `addons/white_kit` and `addons/st33f`, class and autoload
names (`WhiteTileView`, `St33f`), the npm scope `@st33f/*`, the worker prefix `st33f-*` and the API hosts
(`*-dev.st33fd3v.workers.dev`, `api.steefbeest.nl`, ...), Cloudflare D1 database names, GitHub secret names and the
dm-utils/pulse repository.

### 2. Target names

| Game | Repo / folder / game id | Design folder | Play address (old -> new) | Promo site (old -> new) | Title | App id |
|---|---|---|---|---|---|---|
| White Cap | `whitecap` -> `white-cap` | `Whitecap` -> `white-cap` | `play.whitecap` -> `play.white-cap` | `whitecap` -> `white-cap` | Whitecap -> White Cap | `com.st33f.whitecap` |
| White Lie | `white-lie` | `WhiteLie` -> `white-lie` | `play.whitelie` -> `play.white-lie` | `whitelie` -> `white-lie` | White Lie | `com.st33f.whitelie` |
| White Glove | `white-glove` | `Rommelstrooiers` -> `white-glove` | `play.whiteglove` -> `play.white-glove` | `whiteglove` -> `white-glove` | White Glove | `com.st33f.whiteglove` |
| White Shift | `white-shift` | `WhiteShift` -> `white-shift` | `play.whiteshift` -> `play.white-shift` | - | White Shift | - |
| White Tally | `white-tally` | - | `play.whitetally` -> `play.white-tally` | - | White Tally | - |
| White Drift | `white-drift` | - | `play.whitedrift` -> `play.white-drift` | - | White Drift | - |
| White Sum | `white-sum` | - | `play.whitesum` -> `play.white-sum` | - | White Sum | - |
| (puzzle line) | - | `Puzzels` -> `white-puzzles` (pending owner answer, question Q1) | - | - | - | - |

All addresses end in `.steefbeest.nl`.

### 3. Game id transition in Pulse: alias plus data migration

`packages/origins/src/index.ts` becomes:

```ts
export const GAMES = ['white-cap', 'white-lie', 'white-glove'] as const;
export const GAME_NAMES: Record<Game, string> = { 'white-cap': 'White Cap', 'white-lie': 'White Lie', 'white-glove': 'White Glove' };
/** Old game ids still accepted from installed builds (ADR white-kit 0008). Removed in the cleanup step. */
export const GAME_ALIASES: Readonly<Record<string, Game>> = { whitecap: 'white-cap' };
/** The canonical game id for a raw value (a game id or an alias), or null. */
export function canonicalGame(value: unknown): Game | null;
```

- `isGame` stays strict (canonical ids only). Every entry point that reads a game id from a URL, body or query
  (accounts `auth.ts`, `profile.ts`, `settings.ts`; leaderboards `index.ts`; feedback `reports.ts`, `crashes.ts`;
  pvp `index.ts` and the game parsed in `lobby.ts`; i18n `ns`) calls `canonicalGame` and from then on uses only the
  canonical id: database reads and writes, Durable Object names, `CHARACTERS`, `FRIENDS_ONLY`, the daily seed, the
  feedback repository map, mail names. Unknown values keep their current error (`unknown_game`).
- `verifyRun` accepts a token when `canonicalGame(p.g) === game`, so run tokens handed out before the switch stay
  valid until they expire.
- Dev `ORIGINS` gets the three new play origins next to the three old ones; the old ones go in the cleanup step.
- feedback: `GITHUB_REPO_WHITECAP` becomes `GITHUB_REPO_WHITE_CAP = "dm-utils/white-cap"` (all three envs), and
  `triage.ts` matches `'white-cap'`.

Data migration, one new D1 migration per database (run by Pulse CI before the code deploys, on every env; acc and prod
hold no data, so there it is a no-op):

| Database | File | Statements |
|---|---|---|
| accounts | `migrations/0004_white_cap_id.sql` | `UPDATE OR IGNORE <t> SET game = 'white-cap' WHERE game = 'whitecap'` for `game_profiles`, `deleted_profiles`, `game_settings_defs`, `game_settings`, `game_settings_versions`; plain `UPDATE` for `game_settings_changes`, `login_codes` |
| leaderboards | `migrations/0006_white_cap_id.sql` | `UPDATE OR IGNORE` for `game_rules`, `players`, `friend_codes`, `friends`; plain `UPDATE` for `scores` |
| feedback | `migrations/0003_white_cap_id.sql` | `UPDATE` for `feedback`, `crash_groups`; `UPDATE feedback SET issue_url = REPLACE(issue_url, '/dm-utils/whitecap/', '/dm-utils/white-cap/')` and the same for `crash_groups.issue_url` |
| i18n | `migrations/0002_white_cap_ns.sql` | `UPDATE OR IGNORE` for `strings`, `translations`, `glossary` (`ns`); then for `ns = 'white-cap'`: `strings.en`, `translations.code_text` and `translations.text` through `REPLACE(REPLACE(x, 'Whitecap', 'White Cap'), 'WHITECAP', 'WHITE CAP')` |

`UPDATE OR IGNORE` leaves a row on the old id when a row with the new id already exists (possible only for writes in
the seconds between migration and deploy). The cleanup step adds one more migration per database that repeats the
updates and then deletes what is still on `whitecap`.

The i18n text update is required: CI pulls reviewed Final texts into the build, so without it the old title would come
back from the portal.

### 4. Whitecap's local daily seed salt becomes `white-cap-daily-`

`platform/daily.gd` hashes `"white-cap-daily-" + day` for the offline daily (was `whitecap-daily-`). Owner decision
2026-11-18 (question Q2, deviating from the first proposal to freeze the salt): the salt follows the name, so every offline
daily changes, the golden value `LOCAL_SEED_2026_11_10` in the tests is recomputed (FNV-1a over
`white-cap-daily-2026-11-10` gives 1706776782, computed independently in Python) and old and new builds have a different
offline daily on the same day. The online daily changes with the game id as well (server HMAC over `white-cap`). Both
are accepted in the test phase. This is part of the White Cap game repository (step P5).

### 5. Old addresses redirect through one Worker in Pulse

New app `pulse/apps/redirects` (worker `st33f-redirects`, no envs, `workers_dev: false`), deployed by hand with
`.github/workflows/redirects.yml` (`workflow_dispatch`, environment `dev` for the Cloudflare token, same pattern as the
site workflows), routes as `custom_domain` for the 10 old hosts:

| Old host | New host |
|---|---|
| `play.whitecap.steefbeest.nl` | `play.white-cap.steefbeest.nl` |
| `play.whitelie.steefbeest.nl` | `play.white-lie.steefbeest.nl` |
| `play.whiteglove.steefbeest.nl` | `play.white-glove.steefbeest.nl` |
| `play.whiteshift.steefbeest.nl` | `play.white-shift.steefbeest.nl` |
| `play.whitetally.steefbeest.nl` | `play.white-tally.steefbeest.nl` |
| `play.whitedrift.steefbeest.nl` | `play.white-drift.steefbeest.nl` |
| `play.whitesum.steefbeest.nl` | `play.white-sum.steefbeest.nl` |
| `whitecap.steefbeest.nl` | `white-cap.steefbeest.nl` |
| `whitelie.steefbeest.nl` | `white-lie.steefbeest.nl` |
| `whiteglove.steefbeest.nl` | `white-glove.steefbeest.nl` |

Behaviour:

- Any method, any path: `301` with `Location: https://<new host><path><query>` (path and query unchanged, so
  `/android.apk`, `/en/`, `/privacy/` keep working), `Cache-Control: public, max-age=86400`, empty body.
- Host not in the table: `404`. No other logic, no logging of visitors.
- The table lives in `src/hosts.ts` and is the single source for the code, the `routes` in `wrangler.jsonc` (a config
  check test asserts both list the same 10 hosts) and the live check in the workflow.
- Tests in `apps/redirects/test/` (same runner style as the other apps): every host maps correctly, path and query are
  kept, `http` and `https` inputs both give an `https` Location, unknown host gives 404.
- The workflow's live check runs `curl -sI` on every old host and asserts `301` and the expected `Location`.

The Worker stays permanently; it costs nothing on the free plan.

### 6. Promo sites move to new apps and workers

`apps/whitecap-site`, `apps/whitelie-site`, `apps/whiteglove-site` are renamed to `apps/white-cap-site`,
`apps/white-lie-site`, `apps/white-glove-site` (package `@st33f/white-<name>-site`, worker
`st33f-white-<name>-site`, route `white-<name>.steefbeest.nl`, workflow `.github/workflows/white-<name>-site.yml` with
the live check on the new host and `<title>White <Name>`). All absolute URLs in `build.mjs` (og:image, hreflang,
canonical, play link, privacy URL) use the new hosts; the White Cap site title becomes "White Cap — ...". The pages are
rebuilt with `build.mjs` and committed. The old workers are deleted (step P6), which frees the old hosts for the
redirect Worker.

`apps/steefbeest-site/build.mjs`: ids become `white-<name>`, names `White <Name>`, all `site` and `play` URLs the new
hosts; pages rebuilt. `apps/accounts/src/privacy_page.ts`: "Whitecap" becomes "White Cap" (both languages).

### 7. GitHub Pages: one custom domain per repository

Each of the 7 game repositories gets its new play host as its only Pages custom domain. DNS: a `CNAME`
`play.white-<name>` -> `dm-utils.github.io` in the `steefbeest.nl` zone, DNS only (grey cloud), the same as today's
records. After the switch GitHub no longer serves the old host; the redirect Worker takes it over (step P6).

### 8. Local environment

The workstation steps (folders, workspace, local tooling) are kept in the private team notes, not in this repository.

## Alternatives considered

- **Cloudflare Redirect Rules (Single Redirects) for the old hosts**: no code, but the free plan allows 10 rules and
  the move needs exactly 10, leaving no room for anything else on the zone; the old hosts also need placeholder
  proxied DNS records; the configuration lives only in the dashboard, untested and outside git. Rejected.
- **Cloudflare Bulk Redirects** (free plan: 20 URL redirects, subpath matching): fits, but again dashboard-only, needs
  a list, a rule and proxied placeholder records, and cannot be checked in CI. Rejected.
- **Stub GitHub Pages repositories on the old hosts** (one repo per old host with a meta refresh): 7 extra
  repositories, no real 301, and promo hosts are not on Pages. Rejected.
- **Big-bang game id change without alias** (migrate data and switch all clients at once): installed Android builds
  and cached web builds would get `unknown_game` until updated, and the migration would have to race the client
  deploy. Rejected in favour of an alias that is removed once all test devices are updated.
- **Keep `whitecap` as the game id and rename only what players see**: least work, but contradicts the owner's rule
  that game ids follow `white-<name>`, and leaves one exception in every Pulse table forever. Rejected.
- **Freeze the local daily salt `whitecap-daily-`**: keeps every offline daily and the golden test value, but leaves one
  old spelling in a technical name. Rejected by the owner (section 4).
- **Keep the promo workers' names (`st33f-whitecap-site`) and only change their routes**: one step less, but a
  technical name with the old spelling would remain, and the old hosts must be freed from these workers anyway.
  Rejected.
- **Custom user data folder for White Cap** (`use_custom_user_dir` to keep `app_userdata/Whitecap`): keeps desktop
  saves, but White Lie and White Glove use the default; dev data may go. Rejected.
- **Rename `addons/white_kit` to `addons/white-kit`**: a breaking kit change in four games for an internal Godot path.
  Out of scope.

## Rollout order

Gates: a step starts only when the previous one is done and checked. PL = project lead (with the owner's accounts),
Dev = developer, T = tester.

| Step | Who | What | Done when |
|---|---|---|---|
| P0 | PL | #014 merged and deployed; owner has answered the open questions; no agent session works in `~/Git/whitecap` during P1 and P7 | board shows #014 Done |
| P1 | PL | Rename GitHub repo `dm-utils/whitecap` -> `dm-utils/white-cap`; `git -C ~/Git/whitecap remote set-url origin https://github.com/dm-utils/white-cap`; in `git-push-policy.json` replace `dm-utils/whitecap` by `dm-utils/white-cap` in `repos` (allow) and `protected` (`main`); verify `steefbeest.nl` as a verified domain of the dm-utils organisation (Pages settings) if not done yet | `git ls-remote origin` works; policy has no `whitecap` |
| P2 | Dev | Pulse branch `chore/white-naming`: sections 3, 5, 6 and the Pulse checklist; tests green; merge to develop (CI runs migrations and deploys dev Workers) | Pulse CI green on develop; dev answers on `/v1/games/white-cap/...` and on the alias |
| P3 | PL | Run the three new site workflows (`white-cap-site`, `white-lie-site`, `white-glove-site`); wrangler creates the new hosts | new promo hosts answer 200 with the new titles |
| P4 | PL | Per game repo (7): Cloudflare `CNAME play.white-<name>` -> `dm-utils.github.io`, DNS only; repo Settings -> Pages -> Custom domain = new host; wait for the certificate; tick Enforce HTTPS | `https://play.white-<name>.steefbeest.nl/` serves the game with a valid certificate |
| P5 | Dev | Game repos, branch `chore/white-naming` each: checklists below; merge to develop; CI redeploys Pages; White Cap CI pushes settings and rules to `white-cap` | CI green in all 7 game repos and white-kit |
| P6 | PL | Delete the 7 old play CNAME records and the 3 old promo workers (`st33f-whitecap-site`, `st33f-whitelie-site`, `st33f-whiteglove-site`); run `redirects.yml`; run `steefbeest-site.yml` | live check of `redirects.yml` green; steefbeest.nl links only new hosts |
| P7 | PL with owner, no sessions running | Local environment, section 8 and the local checklist | checklist below |
| P8 | T | Card #017: acceptance criteria below | test report without blocking/high findings |
| P9 | Dev, right after #017 (owner decision Q4) | Cleanup: remove `GAME_ALIASES` entry and old dev origins; cleanup migrations (section 3); remove the `~/Git/whitecap` symlink when unused | Pulse CI green; no `whitecap` rows in dev D1 |

P3 and P4 may run in parallel; P5 may start when P2 is deployed (the game repos' CI talks to the new id). Between the
Pages switch (P4) and the redirect (P6) an old play host does not answer; keep that window short by doing P6 for a
game right after its P4 certificate is in place, or accept it (test phase).

## Checklists per repository

### pulse (Dev unless marked)

- [ ] `packages/origins/src/index.ts`: section 3 (`GAMES`, `GAME_NAMES`, `GAME_ALIASES`, `canonicalGame`, dev
      `ORIGINS` with old and new play hosts).
- [ ] All entry points use `canonicalGame` (accounts `auth.ts`, `profile.ts`, `settings.ts`, `mail.ts`;
      leaderboards `index.ts`, `runs.ts` `verifyRun`; feedback `reports.ts`, `crashes.ts`, `triage.ts`; pvp `index.ts`,
      `lobby.ts`, `env.ts` `CHARACTERS['white-cap']` and fallback; i18n `index.ts` namespace via `GAME_ALIASES`,
      `public/app.js` default `white-cap`). `lobby.ts` is touched by #014: start only after #014 is merged.
- [ ] Four D1 migrations (section 3).
- [ ] `apps/feedback/wrangler.jsonc` and `src/env.ts`: `GITHUB_REPO_WHITE_CAP = "dm-utils/white-cap"` (3 envs).
- [ ] `apps/accounts/src/privacy_page.ts`: White Cap in both languages.
- [ ] Promo sites renamed (section 6), pages rebuilt, `--check` passes; workflows renamed, live checks on new hosts.
- [ ] `apps/steefbeest-site/build.mjs`: new ids, names, hosts; pages rebuilt.
- [ ] `apps/redirects` and `.github/workflows/redirects.yml` (section 5) with tests.
- [ ] Tests: replace `whitecap` by `white-cap` in all app tests and in `packages/godot-sdk` (`project.godot`,
      `tests/run_tests.gd`, `tests/e2e.gd`; the User-Agent check becomes `White Cap/`, which is what
      Godot's `"white-cap".capitalize()` gives); add alias tests (old id reads and writes the same rows as the new id;
      `canonicalGame('whitecaps')` is null; a run token with `g: 'whitecap'` verifies for `white-cap`).
- [ ] `package-lock.json` regenerated (`npm install`) after the workspace renames.
- [ ] Root `README.md`: check for old names and hosts.
- [ ] PL: P3, P6 deletes and workflow runs.

### white-cap (was whitecap) (Dev unless marked)

- [ ] `project.godot`: `config/name="White Cap"`, `[st33f] game="white-cap"`.
- [ ] `export_presets.cfg`: Windows `export_path="build/windows/WhiteCap.exe"`, `product_name` and
      `file_description` "White Cap"; Android `export_path="build/android/white-cap-debug.apk"`,
      `package/name="White Cap"`, `package/unique_name` unchanged `com.st33f.whitecap`.
- [ ] `.github/workflows/ci.yml`: verify sample path `"$HOME/.local/share/godot/app_userdata/White Cap/verify_sample.json"`
      (quoted, space); settings and rules URLs `/v1/games/white-cap/...`; `WhiteCap.exe`; `white-cap-debug.apk`;
      contact sheet title "White Cap — ...".
- [ ] `.github/workflows/verify-scores.yml`: `BASE .../v1/games/white-cap`.
- [ ] `web/shell.html`: `<h1>WHITE CAP</h1>`, tagline unchanged.
- [ ] `i18n/strings.csv`: `TITLE` = `WHITE CAP` (en, nl); `PRIVACY_P1` "White Cap ..." (en, nl); no other
      "Whitecap" left; `tools/i18n_add_nl.py` `TITLE`; `tools/i18n_sync.py` `NS = "white-cap"`;
      `tools/test_i18n_sync.py`.
- [ ] `platform/my_data.gd`: `FILE_NAME := "white-cap-my-data.json"`, `"game": "white-cap"`; tests in
      `tests/run_tests.gd` (configure and my-data checks).
- [ ] `platform/daily.gd`: salt `"white-cap-daily-"`; `tests/run_tests.gd`: `LOCAL_SEED_2026_11_10 = 1706776782`.
- [ ] `tests/bot_damage_extra.gd`: expects `WHITE CAP`; `tests/online_dev_check.gd`: `/v1/games/white-cap/pvp`.
- [ ] `tools/contact_sheet.py`, `tools/fetch_ci_shots.sh`: "White Cap" titles.
- [ ] `README.md` "# White Cap" with new play and promo addresses; `docs/design.md`, `docs/glossary.md`,
      `docs/conventions.md`: current names and addresses (older ADRs stay as written).
- [ ] Boot screen and web loader screenshots: `WHITE CAP` with the tagline fits on phone and desktop.
- [ ] PL: P1, P4, P7.

### white-lie, white-glove (Dev unless marked)

- [ ] `export_presets.cfg` and `ci.yml`: `build/android/white-lie-debug.apk` / `white-glove-debug.apk`.
- [ ] No other changes needed in code (game id, title and app id already follow the rules); comments mentioning
      "Whitecap" (`white-lie/view/hide_view.gd`) become "White Cap".
- [ ] PL: P4 for `play.white-lie`, `play.white-glove`.

### white-shift, white-tally, white-drift, white-sum (Dev unless marked)

- [ ] `README.md`, `docs/design.md`, `docs/conventions.md`, `.github/workflows/ci.yml` header comment: play address
      `play.white-<name>.steefbeest.nl`.
- [ ] PL: P4.

### white-kit (Dev)

- [ ] `docs/design.md` 6.3: `play.white-<name>.steefbeest.nl`; `templates/ci.yml` header comment the same pattern.
- [ ] No release needed (documentation and template comment only); the games' submodule copies update with their next
      kit bump.

### Local environment (PL with owner, step P7, no sessions running)

See the private team notes.

## Acceptance criteria (tester, card #017)

Addresses and redirects:

1. For each of the 10 old hosts: `curl -sI https://<old>/a/b?x=1` gives `301` and
   `Location: https://<new>/a/b?x=1`; `curl -sI http://<old>/` ends at the new host over https.
2. For each of the 7 new play hosts: `curl -sfI https://play.white-<name>.steefbeest.nl/` is `200` with a valid
   certificate for that host; `http://` redirects to `https://`; the page title is `White <Name>`.
3. `https://play.white-cap|white-lie|white-glove.steefbeest.nl/android.apk` gives `200`;
   `https://play.whitecap.steefbeest.nl/android.apk` gives `301` to the new host.
4. The 3 new promo hosts answer `200` on `/`, `/en/`, `/privacy/`; the White Cap site shows "White Cap" and the tagline,
   its play button links `https://play.white-cap.steefbeest.nl/`.
5. `https://steefbeest.nl/` and `/en/` contain the 7 new play hosts and 3 new promo hosts and none of the old hosts
   (`grep -cE 'play\.white(cap|lie|glove|shift|tally|drift|sum)\.|//white(cap|lie|glove)\.'` gives 0).

Platform (dev):

6. `GET /v1/games/white-cap/settings` (accounts dev) returns the White Cap settings; the same call with `whitecap`
   returns the same body until the cleanup step, and `unknown_game` after it.
7. CORS preflight from `Origin: https://play.white-cap.steefbeest.nl` is allowed on accounts, leaderboards, feedback
   and pvp (dev); an unknown origin is refused.
8. A read-only query on the dev D1 databases (PL or tester with the token) shows no rows with `game = 'whitecap'` /
   `ns = 'whitecap'` after the cleanup step; before it, only rows that collided (expected none).

Games:

9. White Cap web build on the new host: loader shows `WHITE CAP` and "Survival of the driest!", tab title "White Cap",
   boot screen the same in en and nl; signing in with an existing test account restores the cloud profile; an online
   match between a web and a native client starts; a daily score is accepted and visible; a feedback report creates an
   issue in `dm-utils/white-cap`.
10. Android: the new `android.apk` installs over the installed test app without uninstalling (same app id and test
    key), the launcher shows "White Cap", local progress is kept. An old installed build (game id `whitecap`) can
    still sign in and play online while the alias exists.
11. Windows artifact contains `WhiteCap.exe` with product name "White Cap".
12. White Lie and White Glove online (friends room for White Glove) work from their new hosts.
13. Each puzzle game loads and plays on its new host.

Repositories and tooling:

14. CI green on develop in all 7 game repos, white-kit and pulse; `scan-ai-traces` 0 failures for every repo.
15. `grep -rIni --exclude-dir={.git,.godot,node_modules} -E 'whitecap|whitelie|whiteglove|whiteshift|whitetally|whitedrift|whitesum'`
    in each repo only hits the allowed exceptions: app ids `com.st33f.white*`, `White<Name>.exe`, `GAME_ALIASES` and its tests, the old hosts in `apps/redirects`, the migrations, the dev origins
    list until cleanup, and older ADRs / test reports.
16. Local: `~/Git/white-cap` is the repo, `~/Git/whitecap` a symlink; `git remote -v` shows `dm-utils/white-cap`;
    `docs/board.md` resolves to `projects/white-cap/board.md`; `~/Git/white.code-workspace` opens all 14 folders;
    `git-push-policy.json` has `dm-utils/white-cap` (allow, protected `main`) and no `whitecap`.

## Risks

| Risk | Mitigation |
|---|---|
| GitHub Pages certificate for a new host is not issued (record proxied, CAA record without Let's Encrypt, DNS not yet visible) | DNS only (grey cloud); check CAA; wait up to an hour, then remove and re-add the custom domain; Enforce HTTPS only after the certificate exists |
| Old play host dead between Pages switch and redirect | do P6 per game right after its P4; test phase, no real players |
| Dangling CNAME to `dm-utils.github.io` after the domain moves (subdomain takeover) | P6 deletes the old records before the redirect deploy; verified domain on the organisation |
| Worker custom domain cannot be created while a DNS record or another worker holds the host | P6 deletes old CNAMEs and old promo workers first |
| Data with the old game id: collisions, split crash groups (fingerprint includes the game id), daily seed changes mid-day, run tokens with the old id | `UPDATE OR IGNORE` plus cleanup migration; crash group split accepted; deploy outside the evening play window; `verifyRun` uses `canonicalGame` |
| i18n pull restores "Whitecap" from Final texts | i18n migration rewrites the texts in the namespace |
| Installed Android builds send `whitecap` | alias until right after #017 (P9, owner decision Q4) |
| Android update refused | same app id and the fixed test key (secret `ANDROID_DEBUG_KEYSTORE_B64`); `version/code` stays 1, equal codes install as an update; if a phone has a build signed with a throw-away key, uninstall once |
| Web progress and sign-in are per origin: players on the new host start without local progress and signed out | signed-in players get their cloud profile back after signing in; offline-only progress is lost (test phase, accepted) |
| Desktop user folder follows `config/name` (`app_userdata/White Cap`) | accepted; CI path updated |
| Running agent sessions and tools use `~/Git/whitecap` | symlink; local move only in P7 with no sessions running |
| Session store, memory and trust are keyed on the folder path | move the store and symlink the old name; accept trust once |
| A new repository named `dm-utils/whitecap` would break GitHub's redirect of the old name | never create one; remotes point at the new name |
| feedback creates issues with POST on the old repo name, which GitHub does not follow | variable renamed in P2, after the repo rename in P1 |
| Overlap with #014 (pvp `lobby.ts`) | Pulse work of #016 starts after #014 is merged |
| 301 cached by browsers makes a wrong mapping sticky | table tested in CI and checked live; `max-age=86400` |

## Consequences

- Every technical name in the series follows one rule, so new games, workflows and tools can derive names from the
  repo name. The White Kit glossary defines "game id" as the repository name for all games, not only puzzles.
- Pulse carries an alias table for one release cycle; the cleanup step removes it.
- One more Worker in Pulse that never changes once deployed; old links keep working permanently.
- The White Cap online daily of the switch day differs before and after the deploy, and every offline daily changes
  with the new salt.
- Owner and project lead do the account-bound steps (GitHub rename, Pages, DNS, worker deletes, manual deploys);
  everything in git is done by the developer and checked by the tester.

## Open questions for the owner

- Q1: name for the design folder `Puzzels` (proposal: `white-puzzles`), or keep it as is because it is not a game?
  Answered 2026-11-18: `white-puzzles` (local only).
- Q2: agree that the offline daily salt `whitecap-daily-` stays frozen (section 4)? Answered 2026-11-18: no, the salt
  is renamed to `white-cap-daily-` (section 4).
- Q3: agree that an old play host may be unreachable for the minutes to an hour between the Pages switch and the
  redirect? Answered 2026-11-18: yes.
- Q4: when may the alias go (P9): right after #017, or after you have updated the test phones? Answered 2026-11-18:
  right after #017.
- Q5: is there a showcase repository for Whitecap whose name or text should follow (the export store is keyed on the
  folder name and moves with P7)?
