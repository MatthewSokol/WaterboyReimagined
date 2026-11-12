KNOWN_EVENTS = { ADDON_LOADED = true, PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, TRADE_SHOW = true, TRADE_CLOSED = true, SPELLS_CHANGED = true, PLAYER_REGEN_ENABLED = true, GROUP_ROSTER_UPDATE = true, BAG_UPDATE_DELAYED = true, TRADE_PLAYER_ITEM_CHANGED = true, TRADE_MONEY_CHANGED = true, TRADE_ACCEPT_UPDATE = true, UNIT_SPELLCAST_SUCCEEDED = true, UNIT_SPELLCAST_INTERRUPTED = true }
-- Minimal WoW API stubs to load the addon and click through it.
local frames = {}
local function stub(name)
  local o = { __name = name }
  return setmetatable(o, { __index = function(t, k)
    return function(self, ...)
      local a = { ... }
      if k == "CreateTexture" or k == "CreateFontString" then return stub(name .. "." .. k) end
      if k == "GetFrameLevel" then return 1 end
      if k == "GetText" then return rawget(t, "__text") or "" end
      if k == "SetText" then rawset(t, "__text", a[1]); return end
      if k == "IsShown" or k == "IsVisible" then return rawget(t, "__shown") or false end
      if k == "Show" then rawset(t, "__shown", true); return end
      if k == "Hide" then rawset(t, "__shown", false); return end
      if k == "SetShown" then rawset(t, "__shown", a[1] and true or false); return end
      if k == "SetScript" then rawset(t, "__s_" .. a[1], a[2]); return end
      if k == "GetScript" then return rawget(t, "__s_" .. a[1]) end
      if k == "RegisterEvent" then if not KNOWN_EVENTS[a[1]] then error("Frame:RegisterEvent(): Attempt to register unknown event \"" .. tostring(a[1]) .. "\"", 2) end local ev = rawget(t, "__ev") or {}; ev[a[1]] = true; rawset(t, "__ev", ev); return end
      if k == "GetChecked" or k == "HasFocus" or k == "IsMouseOver" then return false end
      if k == "GetEffectiveScale" then return 1 end
      if k == "SetAttribute" then rawset(t, "__a_" .. a[1], a[2]); return end
      if k == "GetAttribute" then return rawget(t, "__a_" .. a[1]) end
      return nil
    end
  end })
end
function CreateFrame(kind, name, parent, template)
  local f = stub(name or kind)
  frames[#frames + 1] = f
  if name then _G[name] = f end
  if template == "BasicFrameTemplateWithInset" or template == "PortraitFrameTemplate" then
    rawset(f, "CloseButton", stub((name or kind) .. ".CloseButton"))
  end
  if template == "PortraitFrameTemplate" then
    -- remember what the portrait was set to, and the title, so tests can check them
    rawset(f, "SetPortraitTextureRaw", function(self, tex) rawset(self, "__portrait", tex) end)
    rawset(f, "SetTitle", function(self, text) rawset(self, "__title", text) end)
  end
  return f
end
-- like modern clients (and Forever): the portrait frame template exists
PortraitFrameMixin = {}
function FIRE(event, ...)
  for _, f in ipairs(frames) do
    local ev = rawget(f, "__ev")
    local fn = rawget(f, "__s_OnEvent")
    if ev and ev[event] and fn then
      local ok, err = xpcall(fn, debug.traceback, f, event, ...)
      if not ok then print("ERROR in " .. event .. ": " .. err) end
    end
  end
end
function CALL(label, fn, ...)
  local ok, err = xpcall(fn, debug.traceback, ...)
  print((ok and "ok    " or "ERROR ") .. label .. (ok and "" or (": " .. err)))
end
local function needNumber(fn) return function(id, ...) if type(id) ~= "number" then error("bad argument #1 to '" .. fn .. "' (number expected, got " .. type(id) .. ")", 2) end return 134000 end end
C_Item = { GetItemIconByID = needNumber("GetItemIconByID"), GetItemInfo = function() return nil end, GetItemCount = function(id) return (STUB_ITEMS or {})[id] or 0 end }
GetItemIcon = needNumber("GetItemIcon")
GetItemInfo = function() return nil end
GetItemCount = function(id) return (STUB_ITEMS or {})[id] or 0 end
C_Container = { GetContainerNumFreeSlots = function(bag) return bag == 0 and (STUB_FREE or 10) or 0, 0 end, GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() return nil end, PickupContainerItem = function() end }
C_Timer = { After = function(t, f) if t == 0 then f() else STUB_TIMERS = STUB_TIMERS or {}; STUB_TIMERS[#STUB_TIMERS + 1] = f end end } -- next-frame callbacks run right away; later ones wait in STUB_TIMERS
UnitName = function(u) if u == "player" then return "Aldren", "Brightwater" end if u == "NPC" or u == "target" then return "Grimbold", "Stonebrook" end end
UnitClass = function(u) if u == "NPC" then return "Priest", "PRIEST" end return "Mage", "MAGE" end
UnitLevel = function() return 60 end
UnitExists = function() return true end
UnitIsPlayer = function() return true end
UnitIsUnit = function() return false end
GetRealmName = function() return "Forever" end
IsPlayerSpell = function(id) return not (STUB_KNOWN_MAX and id > STUB_KNOWN_MAX) end
IsSpellKnown = function(id) return not (STUB_KNOWN_MAX and id > STUB_KNOWN_MAX) end
GetSpellInfo = function() return "Conjure Water" end
GetSpellSubtext = function() return nil end -- rank text not loaded yet: the addon must still name the rank
IsInRaid = function() return false end
IsInGroup = function() return false end
GetNumGroupMembers = function() return 0 end
GetNumSubgroupMembers = function() return 0 end
InCombatLockdown = function() return STUB_COMBAT or false end
GetTime = function() return STUB_TIME or 1 end
GetCVarBool = function() return false end
CursorHasItem = function() return false end
GetCursorInfo = function() return nil end
ClearCursor = function() end
ClickTradeButton = function() end
GetTradePlayerItemInfo = function() return nil end
GetCursorPosition = function() return 0, 0 end
GetMacroIndexByName = function() return STUB_MACRO_BODY and 1 or 0 end
GetMacroInfo = function() if STUB_MACRO_BODY then return "Waterboy", STUB_MACRO_ICON, STUB_MACRO_BODY end end
GetActionText = function(slot) if slot == 1 and STUB_MACRO_BODY then return "Waterboy" end end
GetNumMacros = function() return 0, 0 end
-- like the game: an icon given by name is stored (and reported by GetMacroInfo) as its file ID
local function StubIconID(icon) if icon == "INV_Misc_QuestionMark" then return 134400 end return icon end
CreateMacro = function(n, icon, body) STUB_MACRO_ICON, STUB_MACRO_BODY = StubIconID(icon), body; return 1 end
EditMacro = function(i, n, icon, body) STUB_MACRO_EDITS = (STUB_MACRO_EDITS or 0) + 1; STUB_MACRO_ICON, STUB_MACRO_BODY = StubIconID(icon) or STUB_MACRO_ICON, body end
PickupMacro = function() end
UIDropDownMenu_SetWidth = function() end
UIDropDownMenu_Initialize = function(dd, fn) rawset(dd, "__init", fn) end
UIDropDownMenu_SetText = function() end
UIDropDownMenu_CreateInfo = function() return {} end
UIDropDownMenu_AddButton = function() end
CloseDropDownMenus = function() end
UISpecialFrames = {}
tinsert = table.insert
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
RAID_CLASS_COLORS = {}
GameTooltip = stub("GameTooltip")
GameTooltip_Hide = function() end
SlashCmdList = {}
NUM_BAG_SLOTS = 4
ChatFontNormal = {}
UIParent = stub("UIParent")
TradeFrame = stub("TradeFrame")
MAX_ACCOUNT_MACROS = 120
setmetatable(_G, { __index = function(_, k) print("UNDEFINED GLOBAL read: " .. tostring(k)) end })
NS = {}
function LOADFILE(src, name)
  local f, err = load(src, "@" .. name)
  if not f then print("COMPILE ERROR " .. err); return end
  local ok, e = xpcall(f, debug.traceback, "WaterboyReimagined", NS)
  print((ok and "loaded " or "LOAD ERROR ") .. name .. (ok and "" or (": " .. e)))
end
-- Forever: ruleset game rules and faction
Enum = Enum or {}
Enum.GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 }
C_GameRules = { IsGameRuleActive = function(r) return r == 3 end }
UnitFactionGroup = function() return "Horde", "Horde" end
RegionalUniqueNamesEnabled = function() return true end
hooksecurefunc = function(t, name, fn)
  local orig = t[name]
  rawset(t, name, function(...) local r = { orig(...) }; fn(...); return (table.unpack or unpack)(r) end)
end
-- tooltip lines, so tests can read what was added
rawset(GameTooltip, "AddLine", function(self, text) STUB_TT = STUB_TT or {}; STUB_TT[#STUB_TT + 1] = text end)
GetSpellDescription = function() return STUB_DESC end
-- each of the addon's images gets its own (session) file ID
local STUB_FILE_IDS = { Icon = -4242, IconCooler = -4243, IconBuckets = -4244 }
GetFileIDFromPath = function(p)
  if STUB_NO_FILEID then return nil end
  local name = p:match("WaterboyReimagined\\(%a+)")
  return name and STUB_FILE_IDS[name]
end
-- a 140x140 minimap centred at (1000, 600), and a cursor the tests can move (STUB_CURSOR = { x, y })
Minimap = CreateFrame("Frame", "Minimap")
rawset(Minimap, "GetWidth", function() return 140 end)
rawset(Minimap, "GetHeight", function() return 140 end)
rawset(Minimap, "GetCenter", function() return 1000, 600 end)
rawset(Minimap, "GetEffectiveScale", function() return 1 end)
GetCursorPosition = function() local c = STUB_CURSOR or { 0, 0 }; return c[1], c[2] end
