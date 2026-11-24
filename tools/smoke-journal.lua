-- The test journal (Journal.lua): which checklist steps get proven, and that no names are stored.
FIRE("ADDON_LOADED", "WaterboyReimagined")
FIRE("PLAYER_LOGIN")
-- these flows predate mana gems: no gems in the loadouts (smoke-gems.lua covers them)
for _, g in ipairs(NS.LOADOUT_GROUPS) do NS.Profile("default").loadouts[g].counts.gem1 = 0; NS.Profile("default").loadouts[g].counts.gem2 = 0 end
FIRE("SPELLS_CHANGED")
FIRE("PLAYER_ENTERING_WORLD")
FIRE("TRADE_SHOW")                                   -- auto-fill on: trade-auto
FIRE("TRADE_CLOSED")
CALL("/wbr set", SlashCmdList.WATERBOYREIMAGINED, "set Grimbold 1 1")
FIRE("TRADE_SHOW")                                   -- the partner's own setting: trade-override
FIRE("TRADE_CLOSED")
STUB_ITEMS = {}                                      -- a conjure that adds a stack: conjure-cast
CALL("press", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false)
FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", NS.SPELLS.water[7])
STUB_ITEMS = { [8079] = 20 }
FIRE("BAG_UPDATE_DELAYED")
FIRE("ADDON_ACTION_BLOCKED", "SomeOtherAddon", "CastSpellByName") -- not ours: ignored
FIRE("ADDON_ACTION_FORBIDDEN", "WaterboyReimagined", "UseAction")
local j = WaterboyReimaginedDB.journal or {}
local seen = {}
for _, e in ipairs(j) do
  seen[e.step] = seen[e.step] or (e.ok and "ok" or "FAIL")
  print("journal " .. e.step .. " " .. (e.ok and "ok" or "FAIL") .. " v=" .. tostring(e.v) .. " - " .. tostring(e.info))
  for _, name in ipairs({ "Grimbold", "Stonebrook", "Aldren", "Brightwater" }) do
    if tostring(e.info):find(name, 1, true) then print("ERROR: a name in the journal: " .. e.step) end
  end
  if type(e.t) ~= "number" then print("ERROR: no time on " .. e.step) end
end
for _, step in ipairs({ "install-clean", "install-no-mechanic", "trade-auto", "trade-override", "conjure-cast" }) do
  if seen[step] ~= "ok" then print("ERROR: journal step " .. step .. " " .. tostring(seen[step])) end
end
if seen["no-taint"] ~= "FAIL" then print("ERROR: our blocked action wasn't journaled") end
local others = 0
for _, e in ipairs(j) do if tostring(e.info):find("CastSpellByName", 1, true) then others = others + 1 end end
if others > 0 then print("ERROR: another addon's blocked action was journaled") end
for i = 1, 250 do NS.Journal("cap", true, i) end
print("journal capped: " .. #WaterboyReimaginedDB.journal)
if #WaterboyReimaginedDB.journal ~= 200 then print("ERROR: journal not capped at 200") end

-- the trade panel: leave a slot out by right-click, Shift-click or its x (the saved setting stays)
NS.ShowTradePopup("Tester", "PRIEST", { slots = { "water1", "water1", "water1", "water1" } }, "class default")
local pop = WaterboyReimaginedTradePopup
local function left() local n = 0; for _, b in ipairs(pop.slots) do if rawget(b, "slot") then n = n + 1 end end; return n end
CALL("right-click slot 1", rawget(pop.slots[1], "__s_OnClick"), pop.slots[1], "RightButton")
CALL("plain left-click slot 1", rawget(pop.slots[1], "__s_OnClick"), pop.slots[1], "LeftButton")
STUB_SHIFT = true
CALL("shift-click slot 1", rawget(pop.slots[1], "__s_OnClick"), pop.slots[1], "LeftButton")
STUB_SHIFT = nil
CALL("x on slot 1", rawget(pop.slots[1].x, "__s_OnClick"), pop.slots[1].x)
print((left() == 1 and "ok " or "ERROR: ") .. "4 slots, 3 left out (a plain click does nothing): " .. left() .. " left")
print((#NS.Profile("default").classes.PRIEST.slots == 4 and "ok " or "ERROR: ") .. "the saved priest setting keeps 4")

-- check a trade: /wbr test and the Trades tab's Test button say what it gets and whether the bags have it
local said2, realPrint2 = {}, print
print = function(...) said2[#said2 + 1] = table.concat({ ... }, " "); realPrint2(...) end
CALL("/wbr test priest", SlashCmdList.WATERBOYREIMAGINED, "test priest")
NS.OpenConfig("classes", "WARRIOR")
CALL("Test button (warrior selected)", rawget(WaterboyReimaginedConfig.testTrade, "__s_OnClick"), WaterboyReimaginedConfig.testTrade)
print = realPrint2
local a, b = "", ""
for _, s in ipairs(said2) do
  if s:find("[Pp]riest gets") then a = s elseif s:find("[Ww]arrior gets") or s:find("WARRIOR gets", 1, true) then b = s end
end
print((a ~= "" and "ok " or "ERROR: ") .. "/wbr test: " .. a)
print((b ~= "" and "ok " or "ERROR: ") .. "Test button: " .. b)
