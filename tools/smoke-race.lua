-- Presses that race the last conjure: right as the cast ends (items not in the bags yet) and inside the
-- spell queue window (still casting). Both must pick past the cast on the way, not repeat it.
-- Stub: stacks of 20, the mage knows every rank, one conjure makes STUB_DESC's number (10 here).
FIRE("ADDON_LOADED", "WaterboyReimagined")
FIRE("PLAYER_LOGIN")
FIRE("SPELLS_CHANGED")
local W, F = 8079, 22895
local SW, SF = NS.SPELLS.water[NS.ITEMS[W].rank], NS.SPELLS.food[NS.ITEMS[F].rank]
STUB_DESC = "Conjures 10 drinks."
local function expect(label, want)
  local got = NS.NextConjureNow()
  print((got == want and "ok " or "ERROR: ") .. label .. ": next " .. tostring(got) .. ", expected " .. tostring(want))
end
local function press() CALL("press", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false); STUB_TIME = STUB_TIME + 0.01 end
for _, g in ipairs(NS.LOADOUT_GROUPS) do NS.Profile("default").loadouts[g].counts.gem1 = 0 end
STUB_TIME = 100

-- solo 2 water : 1 food = 40 : 20, by ratio. Bags 30 water, 10 food -> food is behind.
STUB_ITEMS = { [W] = 30, [F] = 10 }
expect("start: food is behind", F)
press()
FIRE("UNIT_SPELLCAST_START", "player", "g1", SF)
expect("food casting (10 on the way): food full, water next", W)
FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "g1", SF)
expect("food cast done, bags not updated yet: still water", W)
STUB_ITEMS = { [W] = 30, [F] = 20 }
FIRE("BAG_UPDATE_DELAYED")
expect("food landed: water", W)
print("button aims at: " .. tostring(WaterboyReimaginedConjure:GetAttribute("spell")))

-- spell queue window: still casting water with 0.3 s left, the press must queue the next pick
STUB_ITEMS = { [W] = 20, [F] = 0 }
NS.Profile("default").loadouts.solo.order = "category"
expect("category, 20 water: water", W)
press()
FIRE("UNIT_SPELLCAST_START", "player", "g2", SW)
STUB_CAST = { "Conjure Water", (STUB_TIME + 0.3) * 1000 }
expect("water casting, 10 on the way: still water (30 of 40)", W)
press()
FIRE("UNIT_SPELLCAST_START", "player", "g3", SW) -- a 2nd start can't happen mid-cast; stands for the queued one
expect("two water casts on the way (40 of 40): food", F)
STUB_CAST = nil
FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "g2", SW)
STUB_ITEMS = { [W] = 30, [F] = 0 }
FIRE("BAG_UPDATE_DELAYED")
expect("1st water landed, 2nd still on the way: food", F)
FIRE("UNIT_SPELLCAST_INTERRUPTED", "player", "g3", SW)
expect("2nd water interrupted: water again", W)

-- early in a cast (outside the queue window) a press does nothing: the game refuses it
STUB_CAST = { "Conjure Water", (STUB_TIME + 2) * 1000 }
local before = #(WaterboyReimaginedDB.journal or {})
press()
print("press early in a cast: " .. (WaterboyReimaginedConjure:GetAttribute("spell") and "button unchanged" or "ERROR: button cleared"))
STUB_CAST = nil

-- a cast that never lands (bags full) stops counting after the 2 s fallback
FIRE("UNIT_SPELLCAST_START", "player", "g4", SW)
FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "g4", SW)
expect("water on the way: food", F)
for _, f in ipairs(STUB_TIMERS or {}) do f() end
STUB_TIMERS = {}
expect("never landed, fallback ran: water again", W)
