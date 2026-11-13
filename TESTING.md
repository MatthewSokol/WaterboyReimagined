# Release testing checklist

Run through this before each CurseForge release (see [RELEASING.md](RELEASING.md)). Claude puts it on the
Waterboy Release Checklist page with the build filled in, and you tick rows and note problems there. Every
in-game action here is a click or key press of yours: nothing is automated.

**Build under test:** `<commit>` (`<git describe>`), stamped `<date>`. A fix restamps it: untick stage 1, the
smoke rows and every row the fix touches, and start again from stage 1.

## Who does a row, and who ticks it

- **auto executed · trigger:** Claude runs the row without being asked as soon as the trigger is met, and ticks it
  when the run succeeds.
- **auto validated · proof:** a check proves the row (the test journal, the gate, a script), not anyone's word.
  You can't tick it: Claude ticks it when the proof passes. If the proof fails or can't run, you can press
  **Override** with a note; the row then shows "overridden: known issue" and the note goes into the release
  notes' known issues. Only you override.
- **Both tags:** a row Claude runs that proves itself, such as the gate.
- **No tag:** yours to do and tick, because it needs eyes in game.

`wow-env` is `node <wow-mod-dev>/scripts/wow-env.js ... --client _forever_`, run only with the game fully closed
(it snapshots first; `wow-env restore` undoes a pass).

## Problems

Every row starts with an outline id (`3.2`), so you can say "3.2 is in trouble". The page uses the same ids;
Fix and Re-test rows go under their step as `3.2.fix` and `3.2.retest`. Ids only need to hold for the pass under way.

Press **Problem** on any row and note what happened: that's a failed test. Claude triages every open problem the
next time it reads the page (when you finish a pass, or ask):

- **Blocks the release (the default):** Claude adds a **Fix** row (find the cause with wow-mod-debug, fix it on a
  branch, restamp the build) and **Re-test** rows for you: that row, the smoke rows and every row the fix touches,
  unticked. The problem clears only when the re-test passes.
- **Deferred, only on your word:** it goes to `BACKLOG.md` or a GitHub issue with your note, and into the release
  notes' known issues.
- **The row was wrong:** Claude fixes the row's text and you re-check that row.

The gate needs zero open problems.

You need a mage of level 40 or more (higher ranks to compare), a second character, and someone to trade with (a
friend or an alt on another account). Keep BugSack and Mechanic (`/mech`) enabled unless a row says otherwise.

## 1 Stage 1: automated

- [ ] 1.1 `pipeline.js prep x.y.z` passed, and `node tools/verify.js --release` is GREEN
      `[auto executed · when you say you're ready]` `[auto validated · verify.js]`
- [ ] 1.2 `install.ps1`, and the installed copy matches (`pipeline.js run tryout verify`)
      `[auto executed · after prep passes]` `[auto validated · install.js --verify]`
- [ ] 1.3 `wow-env snapshot pre-smoke` `[auto executed · game closed, before the smoke pass]`
- [ ] 1.4 The listing draft (`docs/listing.md`) matches the TOC and README and lints clean (wow-mod-seo)
      `[auto executed · after prep passes]` `[auto validated · lint-listing.js]`

## 2 Stage 2: smoke

- [ ] 2.1 **Clean install:** `wow-env profile clean --addon WaterboyReimagined` (Claude, game closed); start the
      game, log in on the mage: no Lua errors, the minimap button is there `[auto validated · journal: install-clean]`
- [ ] 2.2 Self-tests pass at login `[auto validated · journal: selftest]`
- [ ] 2.3 `/mech`, **Tests**, **Run all** shows 7 passing (a warning such as "no macro yet" is fine)
- [ ] 2.4 `/wbr list` shows the default class settings; `/wbr test priest` says what a priest gets
- [ ] 2.5 **Without Mechanic:** exit the game; Claude runs `wow-env profile disable !Mechanic Mechanic`; log in: no
      Lua errors, spot-check a trade and a macro press `[auto validated · journal: install-no-mechanic]`
- [ ] 2.6 Gate without Mechanic: `release-check.js --no-mechanic` is GREEN
      `[auto executed · when the game exits]` `[auto validated · gate]`
- [ ] 2.7 **Upgrade:** Claude runs `wow-env restore`, then `wow-env profile upgrade --addon WaterboyReimagined --from
      v<previous>`; log in: settings, loadouts and the macro icon are kept `[auto validated · journal: install-upgrade]`
- [ ] 2.8 `/reload` a few times: no errors
- [ ] 2.9 At the character screen, **AddOns** lists "Waterboy Reimagined (Mage Water & Food)" with the drop icon,
      and hovering it shows the one-sentence summary
- [ ] 2.10 `wow-env restore` `[auto executed · when you say the smoke pass is done]`

## Stage 2: acceptance

### 3 Trades (on the mage)

- [ ] 3.1 A priest opens a trade with you: their default stacks go in, highest rank first
      `[auto validated · journal: trade-auto]`
- [ ] 3.2 A player override (`/wbr set <name> 1 1`) beats their class setting `[auto validated · journal: trade-override]`
- [ ] 3.3 With too few stacks of a rank, the next rank down is used
- [ ] 3.4 **Fill trades automatically** off (General tab, or `/wbr off`): a trade shows the panel beside the trade
      window instead; **Add to trade** fills it `[auto validated · journal: trade-panel]`
- [ ] 3.5 On the panel, right-click a slot: it's left out of this trade only
- [ ] 3.6 **Edit setting** on the panel opens the config on that player or class
- [ ] 3.7 On a non-mage character, a trade is left alone and `/wbr list` says settings still save

### 4 Config window (`/wbr`)

- [ ] 4.1 Opens with `/wbr` and `/wb`, the minimap button (left-click) and Esc closes it
- [ ] 4.2 Trades tab: drag a palette item onto a slot, click one to fill the next slot, drag slots to swap, drag one
      off or right-click it to remove it
- [ ] 4.3 Profile dropdown lists Default and every mage on the account; a mage's overrides are marked `*`, Use default
      removes them
- [ ] 4.4 Players: add by name, from your Target and from an open Trade; the list scrolls past five players
- [ ] 4.5 Reset, Delete player and Give nothing do what they say

### 5 Conjuring (on the mage)

- [ ] 5.1 **Put macro on cursor** (or `/wbr macro`) gives the Waterboy macro; drop it on a bar
- [ ] 5.2 Each press restacks part stacks, then casts one conjure: water before food, highest rank first; chat says
      what it's casting, then your stack counts once the items land `[auto validated · journal: conjure-cast]`
- [ ] 5.3 When the loadout is full a press says so `[auto validated · journal: loadout-complete]`
- [ ] 5.4 Three more presses ask about making extra: Cancel, Temporary (countdown bar, ends after a minute without
      conjuring, right-click stops it) and Update loadout
- [ ] 5.5 In a party with **+ group's trades**, the target grows by each member's trade setting
- [ ] 5.6 With full bags, a press casts nothing and says why
- [ ] 5.7 In combat, a press repeats the last cast and says so; the loadout is rechecked after combat
- [ ] 5.8 Macro icon: each choice on the Loadouts tab shows on the bar (drop, cooler, buckets, next conjure); the
      macro fades when you can't cast (out of mana)
- [ ] 5.9 **Conjure now** buttons cast one of each rank; unlearned ranks are greyed out
- [ ] 5.10 After conjuring and trading, open the bank, the auction house and talents: no "AddOn has been blocked"
      `[auto validated · journal: no-taint]`

### 6 Minimap button and Mechanic console

- [ ] 6.1 Left-click opens the window, right-click the Loadouts tab, hover shows your loadout
- [ ] 6.2 Drag it around the minimap; its spot is kept after `/reload`
- [ ] 6.3 `/wbr minimap` (and the General tab box) hides and shows it

- [ ] 6.4 **Console** tab shows the addon's chat messages and debug lines from this session

### 7 Gate

- [ ] 7.1 `node tools/release-check.js` is GREEN `[auto executed · when the game exits]` `[auto validated · gate]`
- [ ] 7.2 No row is still flagged as a Problem `[auto validated · checklist page]`

## 8 Stage 3: the upload

- [ ] 8.1 `release.ps1` builds the zip from the tag, and `tools/check-zip.js` passes
      `[auto executed · after you OK the release and the tag]` `[auto validated · check-zip.js]`
- [ ] 8.2 `wow-env profile zip dist\WaterboyReimagined-x.y.z.zip` (Claude, game closed); log in once: no errors,
      self-tests pass `[auto validated · journal: selftest]`
- [ ] 8.3 `wow-env restore` `[auto executed · when the game exits after the zip test]`
- [ ] 8.4 Record a 5–15 second GIF of a trade filling itself (open a trade, the stacks go in), every name hidden
- [ ] 8.5 Upload to CurseForge (RELEASING.md)
- [ ] 8.6 Update the CurseForge listing from `docs/listing.md`: name, summary, description (paste the README),
      the screenshots' titles, and the GIF
- [ ] 8.7 The GitHub repo's description and topics match `docs/listing.md`
      `[auto executed · after you OK the listing update]`
