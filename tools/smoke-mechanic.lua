-- The optional Mechanic integration (run with tools/stub-mechanic.lua as the harness's 2nd argument).
FIRE("ADDON_LOADED", "WaterboyReimagined")
FIRE("PLAYER_LOGIN")
local caps = MECH_REG.WaterboyReimagined
print("registered: " .. tostring(caps ~= nil))
if not caps then return end
-- every self-test passes on a level 60 mage with default settings
local tests = caps.tests
local fails = 0
for _, t in ipairs(tests.getAll()) do
  local r = tests.run(t.id)
  if not r.passed then fails = fails + 1 end
  print("test " .. t.id .. " [" .. t.category .. "]: " .. (r.passed and "PASS" or "FAIL") .. " - " .. tostring(r.message))
  for _, d in ipairs(r.details) do
    if d.status ~= "pass" then print("   " .. d.status .. ": " .. d.label .. " = " .. d.value) end
  end
end
local passed, total = tests.runAll()
print("runAll: " .. passed .. "/" .. total .. ", fails " .. fails)
print("getResult runs it fresh: " .. tostring(tests.getResult("load").passed))
-- a broken setting is caught
NS.Profile("default").players["broken"] = { slots = { "water1", 99999 } }
local r = tests.run("settings")
print("broken setting caught: " .. tostring(r.passed == false) .. " - " .. r.message)
NS.Profile("default").players["broken"] = nil
-- a test that throws is reported, not raised
local saved = NS.LoadoutStatus
NS.LoadoutStatus = function() error("boom") end
print("throwing helper: " .. tostring(tests.run("loadouts").passed == false))
NS.LoadoutStatus = saved
-- not a mage: passes with a warning
local realClass = UnitClass
UnitClass = function() return "Priest", "PRIEST" end
FIRE("PLAYER_LOGIN")
UnitClass = realClass
-- (isMage is set at PLAYER_LOGIN by the core; the Mechanic frame unregistered itself, so no double register)
local m = tests.run("mage")
print("non-mage: " .. tostring(m.passed) .. " - " .. m.message)
FIRE("PLAYER_LOGIN")
-- debug lines reach Mechanic even with /wbr debug off; chat messages too; colour codes stripped
WaterboyReimaginedDB.debug = false
NS.Dbg("trade with %s", "Grimbold")
NS.Dbg("bad format %d", "not a number")
NS.Print("|cff40ff40Loadout complete|r (solo).")
local buf = caps.getDebugBuffer()
print("buffer lines: " .. #buf .. ", last: " .. tostring(buf[#buf]))
print("mechanic log has debug: " .. tostring(MECH_LOG[#MECH_LOG - 2] ~= nil and MECH_LOG[#MECH_LOG - 2]:find("trade with Grimbold", 1, true) ~= nil))
print("bad format kept: " .. tostring(buf[#buf - 1]))
caps.clearDebugBuffer()
print("cleared: " .. #caps.getDebugBuffer())
-- settings toggles
caps.settings.debug.set(nil, true)
print("debug via settings: " .. tostring(WaterboyReimaginedDB.debug) .. " / " .. tostring(caps.settings.debug.get()))
caps.settings.enabled.set(nil, false)
print("fill trades via settings: " .. tostring(WaterboyReimaginedDB.enabled))
caps.settings.enabled.set(nil, true)
