# Releasing

How a version of Waterboy Reimagined goes from "ready" to CurseForge. Claude runs this with you; the steps are
written so either of you can follow them.

1. **You say you're ready to release** (and which version, if you have one in mind).
2. **Claude applies the lessons** below, plus anything new from your other addons' releases.
3. **Claude gives you a task list**: this file's checklist with the version, the changes and anything new filled in.
4. **Claude reads Mechanic's output** (`node tools/mechanic-report.js`) after your in-game run, and explains
   anything that isn't green.
5. **Green run**: repeat until every check below passes on the same build.
6. **Claude gives you the deploy steps** for CurseForge (and any other site you pick).

## The green run

A build is green when all three pass, with no code change in between:

| Check | How | Green means |
|---|---|---|
| Offline | `node tools/verify.js --release` | Every line `ok` (the .toc's files, brackets, the smoke, migration and Mechanic tests in a Lua VM, the changelog entry, a clean `main`, a free tag) |
| In game, by hand | [TESTING.md](TESTING.md), as a GitHub issue so the boxes can be ticked | Every box ticked |
| In game, Mechanic | `/reload` after the checklist, then `node tools/mechanic-report.js` | `GREEN`: results newer than the code, installed copy matches, all 7 self-tests pass, no Waterboy Reimagined Lua errors in BugGrabber |

**Mechanic is a dev tool, never a dependency.** Players don't have it: `Mechanic.lua` returns at once without it,
the `.toc` only lists it under `## OptionalDeps`, and CurseForge must not list it as a related project. Your own
game needs `!Mechanic`, `Mechanic` and `!BugGrabber` (with BugSack) enabled for the report. Mechanic's desktop
CLI (`mech`, Python 3.10+) isn't needed: the report reads the saved files directly. If you install the CLI later,
`mech call addon.output` shows the same data. Don't use `mech release`: its tag is annotated (real time).

## Lessons from earlier releases

From Waterboy Reimagined 1.0.0, SellAll, Faves and Azeroth Idle Cup:

- **Test a clean install, not just an upgrade.** Delete `WTF\Account\<ACCOUNT>\SavedVariables\WaterboyReimagined.lua`
  and log in. A brand-new addon folder needs a full game restart, not `/reload`.
- **Test the zip you upload.** Install from the built zip (one `WaterboyReimagined\` folder, LICENSE inside, no
  `tools\`, docs or dev files) and log in once.
- **One version, from the tag:** the .toc says `## Version: @project-version@`, filled in from the `vx.y.z` tag by
  `release.ps1` (and by `install.ps1` from `git describe`). Versions follow the dev-routine skill: every merged
  change is its own candidate (`candidate/vx.y.z`, kept local) with its own `## [x.y.z]` CHANGELOG entry, and a release
  promotes one candidate by pushing its `vx.y.z` tag. Tag after merging. Never move a published tag: README-only changes after a release
  don't need a new tag, because the README isn't in the zip.
- **Neutral timestamps:** merge by fast-forward only (never GitHub's merge button); tag with a lightweight tag
  (annotated tags record the real time); `release.ps1` dates zip entries 00:00 UTC.
- **No character or player names in anything public:** screenshots get names pixelated, and examples use
  made-up names.
- **Taint:** after conjuring and trading, open the bank, the auction house and talents. There must be no "AddOn
  has been blocked" messages.
- **CurseForge:**
  - Moderators review new projects in 1–3 days, and files stay "Under Review" until then.
  - The description is pasted separately: keep it in step with the README, including the thanks to Gello.
  - Upload as **Release** (Beta and Alpha don't reach players unless they opt in), for the **WoW Forever** game
    version.
  - Mechanic isn't a related project.
- **Checklist gaps you've found before:** a step missing from TESTING.md (as the clean install once was) gets added
  there, so the next release has it.

## Task list template

Claude fills this in for each release:

- [ ] Candidate picked: `x.y.z` (dev-routine `pipeline.js candidates`; default the newest). Everything for it is merged,
      so its `## [x.y.z]` CHANGELOG entry already exists
- [ ] Release prep passed (`pipeline.js prep x.y.z`), and `node tools/verify.js` passes
- [ ] On `main` at the candidate's commit, pulled; `install.ps1`
- [ ] TESTING.md run in game, as a GitHub issue; every box ticked
- [ ] `/reload`, then `node tools/mechanic-report.js` is GREEN
- [ ] `node tools/verify.js --release` is GREEN
- [ ] Deploy (below)

## Deploy

### CurseForge (project 1799428)

1. Tag and push, after your go-ahead: `pipeline.js released x.y.z` (or `git tag vx.y.z`), then `git push origin vx.y.z`. Use a lightweight tag: an annotated one
   (`git tag -a`, or `mech release`) records the real time.
2. Build: `powershell -ExecutionPolicy Bypass -File ./release.ps1`. It writes `dist\WaterboyReimagined-x.y.z.zip`
   and `dist\WaterboyReimagined-x.y.z-changelog.md`, which holds every candidate's entry since the last release.
3. Install from the zip once (see Lessons) and log in.
4. CurseForge, project, **Files**, **Upload file**:
   - File: the zip.
   - Display name: `Waterboy Reimagined x.y.z`.
   - Release type: **Release**.
   - Game version: **WoW Forever**.
   - Changelog: the changelog `.md` file's text. If the box doesn't take Markdown, drop the `**` marks.
   - Related projects: none.
5. If features changed, update the description (README "What it does" and Coming soon) and the screenshots
   (names pixelated).
6. Check the file goes from "Under Review" to approved, then install it with the CurseForge app on a clean
   profile.

### GitHub (optional)

Make a release from the tag (`gh release create vx.y.z dist/WaterboyReimagined-x.y.z.zip --notes-file dist/WaterboyReimagined-x.y.z-changelog.md`).
GitHub stamps releases with the real time, so skip it if that matters.

### Other sites

Not set up yet. When you pick one (Wago, WoWInterface), Claude adds its steps here: account, project page, the same
zip and changelog.
