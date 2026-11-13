# Release testing checklist

Run through this before each CurseForge release (see [RELEASING.md](RELEASING.md)). Claude opens it as a GitHub
issue with the build filled in, so the boxes can be ticked. Every in-game action here is a click or key press of
yours: nothing is automated.

**Build under test:** `<commit>` (`<git describe>`), stamped `<date>`. A fix restamps it: untick stage 1, the
smoke rows and every row the fix touches, and start again from stage 1.

**Who ticks a row:** `[Claude]` rows Claude runs; `[journal: id]` rows the addon's test journal proves and
`[gate]` rows `tools/release-check.js` proves, which Claude ticks after reading the saved files; untagged rows need
your eyes. `wow-env` is `node <wow-mod-dev>/scripts/wow-env.js ... --client _forever_`, run only with the game
fully closed (it snapshots first; `wow-env restore` undoes a pass).

You need a mage of level 40 or more (higher ranks to compare), a second character, and someone to trade with (a
friend or an alt on another account). Keep BugSack and Mechanic (`/mech`) enabled unless a row says otherwise.

## Stage 1: automated

- [ ] `pipeline.js prep x.y.z` passed, and `node tools/verify.js --release` is GREEN `[Claude]`
- [ ] `install.ps1`, and the installed copy matches (`pipeline.js run tryout verify`) `[Claude]`
- [ ] `wow-env snapshot pre-smoke` `[Claude]`

## Stage 2: smoke

- [ ] **Clean install:** `wow-env profile clean --addon WaterboyReimagined`; start the game, log in on the mage: no
      Lua errors, the minimap button is there `[journal: install-clean]`
- [ ] Self-tests pass at login `[journal: selftest]`; `/mech`, **Tests**, **Run all** shows 7 passing (a warning
      such as "no macro yet" is fine)
- [ ] `/wbr list` shows the default class settings; `/wbr test priest` says what a priest gets
- [ ] Exit the game. **Without Mechanic:** `wow-env profile disable !Mechanic Mechanic`; log in: no Lua errors,
      spot-check a trade and a macro press `[journal: install-no-mechanic]`; exit, then Claude runs
      `release-check.js --no-mechanic` `[gate]`
- [ ] `wow-env restore`, then **upgrade:** `wow-env profile upgrade --addon WaterboyReimagined --from v<previous>`;
      log in: settings, loadouts and the macro icon are kept `[journal: install-upgrade]`
- [ ] `/reload` a few times: no errors
- [ ] `wow-env restore` `[Claude]`

## Stage 2: acceptance

### Trades (on the mage)

- [ ] A priest opens a trade with you: their default stacks go in, highest rank first `[journal: trade-auto]`
- [ ] A player override (`/wbr set <name> 1 1`) beats their class setting `[journal: trade-override]`
- [ ] With too few stacks of a rank, the next rank down is used
- [ ] **Fill trades automatically** off (General tab, or `/wbr off`): a trade shows the panel beside the trade
      window instead; **Add to trade** fills it `[journal: trade-panel]`; right-click a slot leaves it out of this
      trade only
- [ ] **Edit setting** on the panel opens the config on that player or class
- [ ] On a non-mage character, a trade is left alone and `/wbr list` says settings still save

### Config window (`/wbr`)

- [ ] Opens with `/wbr` and `/wb`, the minimap button (left-click) and Esc closes it
- [ ] Trades tab: drag a palette item onto a slot, click one to fill the next slot, drag slots to swap, drag one
      off or right-click it to remove it
- [ ] Profile dropdown lists Default and every mage on the account; a mage's overrides are marked `*`, Use default
      removes them
- [ ] Players: add by name, from your Target and from an open Trade; the list scrolls past five players
- [ ] Reset, Delete player and Give nothing do what they say

### Conjuring (on the mage)

- [ ] **Put macro on cursor** (or `/wbr macro`) gives the Waterboy macro; drop it on a bar
- [ ] Each press restacks part stacks, then casts one conjure: water before food, highest rank first; chat says
      what it's casting, then your stack counts once the items land `[journal: conjure-cast]`
- [ ] When the loadout is full a press says so `[journal: loadout-complete]`; three more presses ask about making
      extra: Cancel, Temporary (countdown bar, ends after a minute without conjuring, right-click stops it) and
      Update loadout
- [ ] In a party with **+ group's trades**, the target grows by each member's trade setting
- [ ] With full bags, a press casts nothing and says why
- [ ] In combat, a press repeats the last cast and says so; the loadout is rechecked after combat
- [ ] Macro icon: each choice on the Loadouts tab shows on the bar (drop, cooler, buckets, next conjure); the
      macro fades when you can't cast (out of mana)
- [ ] **Conjure now** buttons cast one of each rank; unlearned ranks are greyed out
- [ ] After conjuring and trading, open the bank, the auction house and talents: no "AddOn has been blocked"
      `[journal: no-taint]`

### Minimap button

- [ ] Left-click opens the window, right-click the Loadouts tab, hover shows your loadout
- [ ] Drag it around the minimap; its spot is kept after `/reload`
- [ ] `/wbr minimap` (and the General tab box) hides and shows it

### Mechanic console

- [ ] **Console** tab shows the addon's chat messages and debug lines from this session

### Gate

- [ ] Exit the game: Claude had `wow-env watch -- node tools/release-check.js` running, and it says **GREEN**
      `[gate]`

## Stage 3: the upload

- [ ] `release.ps1` builds the zip from the tag, and `tools/check-zip.js` passes `[Claude]`
- [ ] `wow-env profile zip dist\WaterboyReimagined-x.y.z.zip`; log in once: no errors, self-tests pass
      `[journal: selftest]`
- [ ] `wow-env restore` `[Claude]`
- [ ] Deploy (RELEASING.md)
