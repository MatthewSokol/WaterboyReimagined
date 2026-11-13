# Waterboy Reimagined

WoW **Forever** addon (interface 16001, modern `C_Container` API) for mages: hands out conjured water and food over trade, and conjures the right loadout. The addon lives in `WaterboyReimagined/`; `README.md` documents its features.

## Workflow after every edit (always, without being asked)

Pipeline: `.devroutine/pipeline.json`, run with the dev-routine skill (`pipeline.js loop` runs steps 1–2 below:
bracket check, `tools/verify.js`, `install.ps1`, and the installed copy checked by wow-mod-dev's `install.js --verify`).
Requests to pick from live in GitHub issues and `BACKLOG.md`.

Keep every change small: about 100 changed lines per PR, 500 at most (`pipeline.js size`). One request is one unit
of work: one candidate version, often several stacked PRs.

1. **Check** (there's no Lua interpreter on this machine): `node tools/verify.js` runs everything below and must
   say GREEN.
   - `node tools/check.js WaterboyReimagined/<file>.lua` for every Lua file (blocks and brackets balance).
   - **Smoke test:** `node tools/harness.js WaterboyReimagined "" tools/smoke.lua` loads the addon in a Lua VM
     (fengari; `cd tools && npm install` once) with stubbed WoW API, fires login/trade events and runs the
     slash commands. Every line must be `loaded`/`ok`; extend `tools/smoke.lua` and `tools/wowstub.lua` when
     adding features. Pass the real SavedVariables file as the 2nd argument to test migrations.
   - **Migration test:** `node tools/harness.js WaterboyReimagined "" tools/smoke-migrate.lua` checks that data
     saved under an old first-name-only character key moves to the full-name key.
   - **Mechanic test:** `node tools/harness.js WaterboyReimagined tools/stub-mechanic.lua tools/smoke-mechanic.lua`
     runs the optional Mechanic hooks against a fake MechanicLib. New features get a self-test in `Mechanic.lua`
     when they have state worth checking in game.
   - Only register events that exist on Forever (add them to `KNOWN_EVENTS` in the stub only after
     checking), and register through `ns.RegisterEvents` (an unknown event throws and stops the file loading).
2. **Install:** `powershell -ExecutionPolicy Bypass -File ./install.ps1` installs into `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\WaterboyReimagined`. Then verify each installed file with `diff -r --strip-trailing-cr -q -I '^## Version:'` (the install fills in the .toc's version).
3. **Commit** on a feature/fix branch (not `main`), push, and open a PR or add to the open one. Update the PR title and description when its scope grows.
4. **Don't merge** until the user has tested in game and says it's good. Then merge, switch to `main`, pull, and confirm the installed copy matches.
5. **End every reply that changed the addon with "How to test"**: `/reload`, then concrete in-game steps and what should happen. Mention `/wbr debug` where it helps.

## Release

Follow [RELEASING.md](RELEASING.md) when the user says they're ready to release: apply its lessons (and any new
ones from the user's other addons), give the task list, read `node tools/mechanic-report.js` after their in-game
run, repeat until the green run, then give the deploy steps. Add new lessons to RELEASING.md and missing checks to
TESTING.md. `release.ps1` builds `dist/WaterboyReimagined-<version>.zip` (version from the `vX.Y.Z` release tag on HEAD,
LICENSE included, entries dated 00:00 UTC; the .toc says `@project-version@`) and the release notes from the matching `## [version]` CHANGELOG entry.

## Mechanic (dev tool, optional)

`Mechanic.lua` hooks into [Mechanic](https://github.com/Falkicon/Mechanic) when the user has it installed: chat and
debug lines go to its Console, and 7 self-tests show in its Tests tab and are saved on every `/reload`. It must
never become a dependency: it returns at once without `LibStub("MechanicLib-1.0", true)`, isn't embedded (GPL),
and is only an `## OptionalDeps`. After the user reloads, `node tools/mechanic-report.js` reads the saved
results and BugGrabber's errors (no Python or `mech` CLI needed).

## Notes

- Configuration works on any character; actions (trading, conjuring) only happen on mages.
- Profiles are layered: this character's profile overrides the "default" profile key by key. Per-player overrides (e.g. a friend who wants 1 water + 1 food) beat class settings.
- Amounts are in **stacks**. Hand out the highest rank first, then lower ranks.
- Casting spells needs a hardware event: conjuring must go through a secure action button (`/click`), never automated casting.
