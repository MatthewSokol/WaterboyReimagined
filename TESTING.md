# Release testing checklist

Run through this before each CurseForge release (see [RELEASING.md](RELEASING.md)). To check items off, open a
GitHub issue with this list as its body: GitHub makes the boxes clickable and remembers them. Every action here is
a click or key press of yours: nothing is automated.

Before you start: install the build (`install.ps1`), keep BugSack open, and have Mechanic enabled (`/mech` opens
it) unless a step says otherwise. You need a mage of level 40 or more (higher ranks to compare), a second
character, and someone to trade with (a friend or an alt on another account).

## 1. Install

- [ ] **Clean install:** with the game closed, delete `WTF\Account\<ACCOUNT>\SavedVariables\WaterboyReimagined.lua`,
      start the game, log in on the mage: no Lua errors, the minimap button is there
- [ ] `/wbr list` shows the default class settings; `/wbr test priest` says what a priest gets
- [ ] **Upgrade:** with the previous release's saved settings back in place, log in: settings, loadouts and the
      macro icon are kept
- [ ] **Without Mechanic:** disable `!Mechanic` and `Mechanic` at the character screen, log in: no Lua errors,
      everything below still works (spot-check a trade and a macro press), then enable them again
- [ ] `/reload` a few times: no errors

## 2. Trades (on the mage)

- [ ] A priest opens a trade with you: their default stacks go in, highest rank first
- [ ] A player override (`/wbr set <name> 1 1`) beats their class setting
- [ ] With too few stacks of a rank, the next rank down is used
- [ ] **Fill trades automatically** off (General tab, or `/wbr off`): a trade shows the panel beside the trade
      window instead; **Add to trade** fills it; right-click a slot leaves it out of this trade only
- [ ] **Edit setting** on the panel opens the config on that player or class
- [ ] On a non-mage character, a trade is left alone and `/wbr list` says settings still save

## 3. Config window (`/wbr`)

- [ ] Opens with `/wbr` and `/wb`, the minimap button (left-click) and Esc closes it
- [ ] Trades tab: drag a palette item onto a slot, click one to fill the next slot, drag slots to swap, drag one
      off or right-click it to remove it
- [ ] Profile dropdown lists Default and every mage on the account; a mage's overrides are marked `*`, Use default
      removes them
- [ ] Players: add by name, from your Target and from an open Trade; the list scrolls past five players
- [ ] Reset, Delete player and Give nothing do what they say

## 4. Conjuring (on the mage)

- [ ] **Put macro on cursor** (or `/wbr macro`) gives the Waterboy macro; drop it on a bar
- [ ] Each press restacks part stacks, then casts one conjure: water before food, highest rank first; chat says
      what it's casting, then your stack counts once the items land
- [ ] When the loadout is full a press says so; three more presses ask about making extra: Cancel, Temporary
      (countdown bar, ends after a minute without conjuring, right-click stops it) and Update loadout
- [ ] In a party with **+ group's trades**, the target grows by each member's trade setting
- [ ] With full bags, a press casts nothing and says why
- [ ] In combat, a press repeats the last cast and says so; the loadout is rechecked after combat
- [ ] Macro icon: each choice on the Loadouts tab shows on the bar (drop, cooler, buckets, next conjure); the
      macro fades when you can't cast (out of mana)
- [ ] **Conjure now** buttons cast one of each rank; unlearned ranks are greyed out
- [ ] After conjuring and trading, open the bank, the auction house and talents: no "AddOn has been blocked"

## 5. Minimap button

- [ ] Left-click opens the window, right-click the Loadouts tab, hover shows your loadout
- [ ] Drag it around the minimap; its spot is kept after `/reload`
- [ ] `/wbr minimap` (and the General tab box) hides and shows it

## 6. Mechanic (the in-game half of the green run)

- [ ] `/mech`, **Tests** tab, **Run all**: Waterboy Reimagined shows 7 tests, all passing (a warning such as "no
      macro yet" is fine)
- [ ] **Console** tab shows the addon's chat messages and debug lines from this session
- [ ] `/reload`, then tell Claude: it runs `node tools/mechanic-report.js` and it says **GREEN**

## 7. The upload

- [ ] `release.ps1` builds the zip; installed from that zip (restart the game), the addon loads with no errors
