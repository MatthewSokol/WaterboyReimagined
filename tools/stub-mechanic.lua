-- A stand-in for the Mechanic dev tool's MechanicLib, loaded before the addon (the harness's 2nd argument):
--   node tools/harness.js WaterboyReimagined tools/stub-mechanic.lua tools/smoke-mechanic.lua
-- Records what the addon registers and logs, like !Mechanic would.
MECH_REG, MECH_LOG = {}, {}
local MechanicLib = {
  Categories = { TRIGGER = "[Trigger]", REGION = "[Region]", API = "[API]", COOLDOWN = "[Cooldown]",
    EVENT = "[Event]", VALIDATION = "[Validation]", SECRET = "[Secret]", PERF = "[Perf]", LOAD = "[Load]", CORE = "[Core]" },
}
function MechanicLib:Register(name, caps) MECH_REG[name] = caps end
function MechanicLib:Log(name, msg, cat) MECH_LOG[#MECH_LOG + 1] = name .. " " .. tostring(cat) .. " " .. msg end
LibStub = function(major, silent)
  if major == "MechanicLib-1.0" then return MechanicLib end
  if not silent then error("Cannot find a library instance of " .. tostring(major)) end
end
