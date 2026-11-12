# Changelog

## 1.0.0

First release.

- **Trades:** when someone opens a trade with your mage, it puts in the stacks of water and food their class wants, or their own player setting (e.g. a friend who only wants 1 water and 1 food).
- **Profiles:** a Default profile, plus one per mage on the account that overrides it setting by setting.
- **Relative ranks:** settings can say "highest water" or "2nd highest", so one default works for mages of any level.
- **Config window (`/mw`, `/mwb`, `/waterboy`):** General, Trades and Loadouts tabs. Trades are set up by dragging water and food onto a fake trade window.
- **Trade panel:** with auto-fill off, a panel next to the trade window shows what the player would get, with Add to trade.
- **Loadouts and macro:** how many stacks to keep for solo, party and raid (optionally plus the group's trades). The Waterboy macro restacks, then conjures one missing item per press. It says what it's casting, then reports your stacks once the cast finishes. Three presses after the loadout is complete ask whether to keep going: temporarily (until a minute without conjuring, with a countdown bar on screen), or by opening the Loadouts tab to change the loadout for good.
- **The macro on your bar:** the Waterboy icon, faded like the next conjure's spell when you can't cast it (out of mana, say); its tooltip shows the next press and your stacks. In combat it says each press repeats the last cast until combat ends, and with no bag space it says so instead of casting.
- **Conjure now:** buttons beside the config window for your highest and 2nd highest water and food, one cast per click. Ranks you haven't learned yet are greyed out.
- **Icon:** a glowing drop over a rune circle, in the AddOns list and on the macro.
- **WoW Forever names:** mages and players go by their full name (first name and surname), and mages show their ruleset and faction instead of the realm's long name.
