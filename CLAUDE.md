# Waterboy Reimagined

WoW **Forever** addon (interface 16001, modern `C_Container` API) for mages: hands out conjured water and food over trade, and conjures the right loadout. The addon lives in `WaterboyReimagined/`; `README.md` documents its features.

## Workflow after every edit (always, without being asked)

Keep every change small: one feature request = one branch = one PR.

1. **Check** (there's no Lua interpreter on this machine):
   - `node tools/check.js WaterboyReimagined/<file>.lua` for every Lua file (blocks and brackets balance).
   - **Smoke test:** `node tools/harness.js WaterboyReimagined "" tools/smoke.lua` loads the addon in a Lua VM
     (fengari; `cd tools && npm install` once) with stubbed WoW API, fires login/trade events and runs the
     slash commands. Every line must be `loaded`/`ok`; extend `tools/smoke.lua` and `tools/wowstub.lua` when
     adding features. Pass the real SavedVariables file as the 2nd argument to test migrations.
   - **Migration test:** `node tools/harness.js WaterboyReimagined "" tools/smoke-migrate.lua` checks that data
     saved under an old first-name-only character key moves to the full-name key.
   - Only register events that exist on Forever (add them to `KNOWN_EVENTS` in the stub only after
     checking), and register through `ns.RegisterEvents` (an unknown event throws and stops the file loading).
2. **Install:** `powershell -ExecutionPolicy Bypass -File ./install.ps1` installs into `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\WaterboyReimagined`. Then verify each installed file with `diff --strip-trailing-cr -q`.
3. **Commit** on a feature/fix branch (not `main`), push, and open a PR or add to the open one. Update the PR title and description when its scope grows.
4. **Don't merge** until the user has tested in game and says it's good. Then merge, switch to `main`, pull, and confirm the installed copy matches.
5. **End every reply that changed the addon with "How to test"**: `/reload`, then concrete in-game steps and what should happen. Mention `/waterboy debug` where it helps.

## Release

`release.ps1` builds `dist/WaterboyReimagined-<version>.zip` (version from the .toc, LICENSE included, entries dated
00:00 UTC). Bump the .toc version and `CHANGELOG.md` together.

## Notes

- Configuration works on any character; actions (trading, conjuring) only happen on mages.
- Profiles are layered: this character's profile overrides the "default" profile key by key. Per-player overrides (e.g. a friend who wants 1 water + 1 food) beat class settings.
- Amounts are in **stacks**. Hand out the highest rank first, then lower ranks.
- Casting spells needs a hardware event: conjuring must go through a secure action button (`/click`), never automated casting.
