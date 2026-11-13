-- The test journal (Journal.lua): which checklist steps get proven, and that no names are stored.
FIRE("ADDON_LOADED", "WaterboyReimagined")
FIRE("PLAYER_LOGIN")
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
