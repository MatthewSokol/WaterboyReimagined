-- Mana gems: in the loadout (0 or 1 of the top gem and the one below), before or after the water and food,
-- out of the ratio and of extra rounds, and every rank on the Conjure now panel.
FIRE("ADDON_LOADED", "WaterboyReimagined")
FIRE("PLAYER_LOGIN")
FIRE("SPELLS_CHANGED")
local W, F, RUBY, CITRINE = 8079, 22895, 8008, 8007
local function expect(label, want)
  local got = NS.NextConjureNow()
  print((got == want and "ok " or "ERROR: ") .. label .. ": next " .. tostring(got) .. ", expected " .. tostring(want))
end
local solo = NS.Profile("default").loadouts.solo
print("default solo gems: " .. tostring(solo.counts.gem1) .. " top, " .. tostring(solo.counts.gem2 or 0) .. " one down; order " .. NS.GemOrder("default"))
print("mage records gem rank: " .. tostring(NS.DB().mages[NS.CharKey()].gem))

STUB_ITEMS = {}
expect("gems first (default): the top gem before any water", RUBY)
solo.counts.gem2 = 0 -- the top gem only, until "with Gem -1 too"
STUB_ITEMS = { [RUBY] = 1 }
expect("top gem in the bags: on to water", W)
solo.counts.gem2 = 1
STUB_ITEMS = { [RUBY] = 1 }
expect("with Gem -1 too: the citrine next", CITRINE)
solo.counts.gem2 = 0
solo.counts.gem1 = 5
STUB_ITEMS = { [RUBY] = 1 }
expect("a gem count over 1 still means one gem", W)
solo.counts.gem1 = 1

NS.Profile("default").gemOrder = "last"
STUB_ITEMS = {}
expect("gems last: water first", W)
STUB_ITEMS = { [W] = 40, [F] = 20 }
expect("gems last, water and food done: the gem", RUBY)
NS.Profile("default").gemOrder = nil

-- a character profile can set its own gem order; it inherits the default's otherwise
local me = NS.Profile(NS.CharKey(), true)
local o, inherited = NS.GemOrder(NS.CharKey())
print("this character inherits: " .. o .. " " .. tostring(inherited))
me.gemOrder = "last"
STUB_ITEMS = {}
expect("this character's own gem order (last)", W)
me.gemOrder = nil

-- extra rounds scale water and food, not gems
STUB_ITEMS = { [RUBY] = 1, [W] = 40, [F] = 20 }
expect("loadout complete", nil)

-- loadouts saved before gems get the top gem (a 0 you set stays 0)
local saved = { solo = { counts = { water1 = 2, food1 = 1 } }, party = { counts = { water1 = 1, gem1 = 0 } } }
NS.DB().profiles.default.loadouts.solo = saved.solo
NS.DB().profiles.default.loadouts.party = saved.party
NS.InitLoadouts(NS.DB())
print("migrated: solo gem1 " .. tostring(saved.solo.counts.gem1) .. ", party kept " .. tostring(saved.party.counts.gem1))

-- the Conjure now panel: water, water -1, food, food -1, then every gem rank
local names = {}
for i = 1, 8 do local b = _G["WaterboyReimaginedManual" .. i]; names[#names + 1] = b and b.name or "missing" end
print("conjure now: " .. table.concat(names, ", "))
CALL("/wbr", SlashCmdList.WATERBOYREIMAGINED, "")
CALL("Loadouts tab", NS.OpenLoadouts, "default")
CALL("manual tooltip, top gem", rawget(WaterboyReimaginedManual8, "__s_OnEnter"), WaterboyReimaginedManual8)
-- gems never go into a trade setting by drag
local status = NS.LoadoutStatus()
print("status: " .. status[1] .. " / last line: " .. status[#status])
-- a gem conjure reaches the journal as conjure-gem
for _, g in ipairs(NS.LOADOUT_GROUPS) do NS.Profile("default").loadouts[g].counts.gem1 = 1 end
NS.Profile("default").gemOrder = nil
STUB_ITEMS = {}
CALL("press for the gem", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false)
FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", NS.SPELLS.gem[4])
STUB_ITEMS = { [RUBY] = 1 }
FIRE("BAG_UPDATE_DELAYED")
local found
for _, e in ipairs(WaterboyReimaginedDB.journal or {}) do if e.step == "conjure-gem" then found = e end end
print((found and "ok " or "ERROR: ") .. "journal conjure-gem: " .. tostring(found and found.info))
-- the loadouts self-test flags a gem count over 1
NS.Profile("default").loadouts.solo.counts.gem1 = 2
local r = (MECH_REG and MECH_REG.WaterboyReimagined) and MECH_REG.WaterboyReimagined.tests.run("loadouts")
print("loadouts self-test with gem1 = 2: " .. (r and tostring(r.passed) or "no Mechanic in this run"))
NS.Profile("default").loadouts.solo.counts.gem1 = 1

-- Conjure now buttons are armed at login, panel shown or not: /click and keybindings work
NS.HideManualConjure()
WaterboyReimaginedManual1:SetAttribute("spell", nil) -- prove the login event sets it, not the earlier panel
FIRE("PLAYER_ENTERING_WORLD")
local b1 = WaterboyReimaginedManual1
print((b1:GetAttribute("spell") and "ok " or "ERROR: ") .. "panel hidden, Water button armed: " .. tostring(b1:GetAttribute("spell")))
print((_G["BINDING_NAME_CLICK WaterboyReimaginedManual8:LeftButton"] and "ok " or "ERROR: ") .. "binding name 8: "
  .. tostring(_G["BINDING_NAME_CLICK WaterboyReimaginedManual8:LeftButton"]))
