-- Conjure order: by ratio, by category, by character (and the role guess behind it).
-- Stacks are 20 in the stub (no item info), the mage knows every rank: water1 = 8079, food1 = 22895.
FIRE("ADDON_LOADED", "WaterboyReimagined")
FIRE("PLAYER_LOGIN")
FIRE("SPELLS_CHANGED")
local W, F = 8079, 22895
local function expect(label, want)
  local got = NS.NextConjureNow()
  print((got == want and "ok " or "ERROR: ") .. label .. ": next " .. tostring(got) .. ", expected " .. tostring(want))
end
local solo = NS.Profile("default").loadouts.solo -- 2 water, 1 food: 40 and 20 items
-- mana gems have their own test (smoke-gems.lua): none here
for _, g in ipairs(NS.LOADOUT_GROUPS) do NS.Profile("default").loadouts[g].counts.gem1 = 0; NS.Profile("default").loadouts[g].counts.gem2 = 0 end

-- default is by ratio
print("solo order: " .. NS.LoadoutOrder(solo, "solo"))
STUB_ITEMS = {}
expect("ratio, empty bags: water first on a tie", W)
STUB_ITEMS = { [W] = 20 }
expect("ratio, half the water and no food: food", F)
STUB_ITEMS = { [W] = 20, [F] = 20 }
expect("ratio, half the water and all the food: water", W)
STUB_ITEMS = { [W] = 30, [F] = 10 }
expect("ratio, 3/4 water and 1/2 food: food", F)
STUB_ITEMS = { [W] = 40, [F] = 20 }
expect("ratio, all there: nothing", nil)

-- by category: all the water first
solo.order = "category"
STUB_ITEMS = { [W] = 20 }
expect("category, half the water and no food: water", W)
STUB_ITEMS = { [W] = 40 }
expect("category, water done: food", F)

-- solo doesn't offer by character: falls back to ratio
solo.order = "character"
print("solo with character falls back to: " .. NS.LoadoutOrder(solo, "solo"))
solo.order = nil

-- a party of a warrior (party1) and a priest (party2): own 2 water + 1 food, priest 4 water, warrior 2 food
IsInGroup = function() return true end
GetNumSubgroupMembers = function() return 2 end
local CLASS = { party1 = { "Warrior", "WARRIOR" }, party2 = { "Priest", "PRIEST" } }
local realClass, realName = UnitClass, UnitName
UnitClass = function(u) if CLASS[u] then return CLASS[u][1], CLASS[u][2] end return realClass(u) end
UnitName = function(u)
  if u == "party1" then return "Brannor", "Ironhide" end
  if u == "party2" then return "Elisande", "Moonwell" end
  return realName(u)
end
print("role party1: " .. NS.GuessRole("party1") .. ", party2: " .. NS.GuessRole("party2"))
local party = NS.Profile("default").loadouts.party
party.order = "character"
party.counts.water1 = 2 -- the self share these cases count on: 2 water (40), 1 food (20)
STUB_ITEMS = { [W] = 20 }
expect("character, own water short: water (self first)", W)
STUB_ITEMS = { [W] = 40 }
expect("character, own water done, own food short: food", F)
STUB_ITEMS = { [W] = 40, [F] = 20 }
expect("character, self done: the healer's water", W)
STUB_ITEMS = { [W] = 120, [F] = 20 }
expect("character, healer done: the tank's food", F)
STUB_ITEMS = { [W] = 120, [F] = 60 }
expect("character, everyone done: nothing", nil)
party.order = "ratio"
STUB_ITEMS = { [W] = 60, [F] = 20 }
expect("party ratio, 60/120 water and 20/60 food: food", F)

-- role guesses
UnitPowerType = function() return 1 end
CLASS.party1 = { "Druid", "DRUID" }
local b1, b2 = NS.GuessRole("party1"), NS.GuessRole("party1", true)
print(((b1 == "TANK" and b2 == "TANK") and "ok " or "ERROR: ") .. "bear druid tanks in a party and a raid: " .. b1 .. ", " .. b2)
UnitPowerType = function() return 0 end
print("caster druid: " .. NS.GuessRole("party1"))
CLASS.party1 = { "Warrior", "WARRIOR" }
print("raid warrior: " .. NS.GuessRole("party1", true))
GetPartyAssignment = function(what, u) return what == "MAINTANK" and u == "party1" end
print("raid main tank warrior: " .. NS.GuessRole("party1", true))
CLASS.party1 = { "Rogue", "ROGUE" }
GetPartyAssignment = nil
print("rogue: " .. NS.GuessRole("party1"))
local ok, lines = pcall(NS.LoadoutStatus)
print("status: " .. (ok and lines[1] or ("ERROR: " .. tostring(lines))))
-- the Loadouts tab draws every row with its order button, on the default and on a character profile
CALL("/wbr", SlashCmdList.WATERBOYREIMAGINED, "")
NS.Profile("default").loadouts.raid.order = "character"
CALL("Loadouts tab, default profile", NS.OpenLoadouts, "default")
CALL("Loadouts tab, this character", NS.OpenLoadouts, NS.CharKey())
print("raid order after drawing: " .. NS.LoadoutOrder(NS.Profile("default").loadouts.raid, "raid"))

-- the Loadouts tab's dropdowns: open one, see the orders its group offers, pick one
CALL("Loadouts tab", NS.OpenLoadouts, "default")
local function open(name)
  STUB_MENU = {}
  local dd = _G[name]
  if not dd then print("ERROR: no dropdown " .. name); return {} end
  rawget(dd, "__init")(dd, 1)
  local texts = {}
  for _, info in ipairs(STUB_MENU) do texts[#texts + 1] = info.text .. (info.checked and "*" or "") end
  print(name .. ": " .. table.concat(texts, ", ") .. " (shows " .. tostring(rawget(dd, "__text")) .. ")")
  return STUB_MENU
end
local soloMenu = open("WaterboyReimaginedOrderDropDown_solo")
print((#soloMenu == 2 and "ok " or "ERROR: ") .. "solo offers 2 orders")
local raidMenu = open("WaterboyReimaginedOrderDropDown_raid")
print((#raidMenu == 3 and "ok " or "ERROR: ") .. "raid offers 3 orders")
for _, info in ipairs(soloMenu) do if info.arg1 == "category" then info.func(nil, info.arg1) end end
print((NS.Profile("default").loadouts.solo.order == "category" and "ok " or "ERROR: ") .. "picked By category for solo")
open("WaterboyReimaginedOrderDropDown_solo")
local gemMenu = open("WaterboyReimaginedGemOrderDropDown")
for _, info in ipairs(gemMenu) do if info.arg1 == "last" then info.func(nil, info.arg1) end end
print((NS.GemOrder("default") == "last" and "ok " or "ERROR: ") .. "picked gems after")
