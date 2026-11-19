# Changelog

Newest first. Each release is `## [version] - date` (the format Mechanic's `changelog.add` and `tools/verify.js --release` expect); `release.ps1` copies the top entry into `dist/` as the CurseForge release notes.

## [Unreleased]

### Added

- **Optional Mechanic support:** with the Mechanic developer addon installed, Waterboy Reimagined logs to its
  console and adds 7 self-tests to its Tests tab. Nothing changes without it.
- **Conjure order:** each loadout row's Order dropdown picks what the macro conjures next. **By ratio** (the new default) keeps
  your bags at the loadout's mix, counting what's in them, so 2 water to 1 food stays 2:1 at any level. **By
  category** is the old order: all the water, then the food. **By character** (party and raid, with + group's
  trades) makes your own stacks first, then the healers', then the tanks', then everyone else's.
- **Mana gems:** loadouts keep your top two mana gems (Gem and Gem -1 columns, 0 or 1 each), conjured before the water
  and food by default or after them (the Mana gems dropdown). Conjure now has a button for every gem rank.

### Changed

- **Loadout defaults:** party makes 3 water to 1 food, and raid 4 water to 2 food with + group's trades on (it
  was 8 + 4 water and 2 food without them). Loadouts you saved stay as they are; Reset brings the new ones.
- **Loadouts tab:** each group fits on one line again, so the window is back to about its 1.0.0 size.
- **AddOn list:** the addon shows as "Waterboy Reimagined (Mage Water & Food)", its tooltip says what it does in
  one sentence, and it links to its CurseForge page.

### Fixed

- **Fast presses:** pressing the conjure macro right as a cast ends (or in the game's spell queue window) no
  longer conjures the same thing again; the items still on their way to your bags now count.

## [1.0.0] - 2026-11-12

First release.

- **Trades:** when someone opens a trade with your mage, it puts in the stacks of water and food their class wants, or their own player setting (e.g. a friend who only wants 1 water and 1 food).
- **Profiles:** a Default profile, plus one per mage on the account that overrides it setting by setting.
- **Relative ranks:** settings can say "highest water" or "2nd highest", so one default works for mages of any level.
- **Config window (`/wbr`, `/wb`):** General, Trades and Loadouts tabs. Trades are set up by dragging water and food onto a fake trade window.
- **Trade panel:** with auto-fill off, a panel next to the trade window shows what the player would get, with Add to trade.
- **Loadouts and macro:** how many stacks to keep for solo, party and raid (optionally plus the group's trades). The Waterboy macro restacks, then conjures one missing item per press. It says what it's casting, then reports your stacks once the cast finishes. Three presses after the loadout is complete ask whether to keep going: temporarily (until a minute without conjuring, with a countdown bar on screen), or by opening the Loadouts tab to change the loadout for good.
- **The macro on your bar:** your pick of icon (Loadouts tab: the glowing drop, an arcane water cooler, water buckets, or the next conjure's own spell icon), faded like the next conjure's spell when you can't cast it (out of mana, say); its tooltip shows the next press and your stacks. In combat it says each press repeats the last cast until combat ends, and with no bag space it says so instead of casting.
- **Conjure now:** buttons beside the config window for your highest and 2nd highest water and food, one cast per click. Ranks you haven't learned yet are greyed out.
- **Icon:** a glowing drop over a rune circle, in the AddOns list and in each window's corner.
- **Minimap button:** left-click opens the window, right-click the Loadouts tab, hover for your loadout; drag it around the minimap, or hide it (General tab, `/wbr minimap`).
- **WoW Forever names:** mages and players go by their full name (first name and surname), and mages show their ruleset and faction instead of the realm's long name.
