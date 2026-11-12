FIRE("ADDON_LOADED", "WaterboyReimagined")
FIRE("PLAYER_LOGIN")
FIRE("SPELLS_CHANGED")
FIRE("PLAYER_ENTERING_WORLD")
print("db.version=" .. tostring(WaterboyReimaginedDB.version))
CALL("/wbr help", SlashCmdList.WATERBOYREIMAGINED, "help")
CALL("/wbr", SlashCmdList.WATERBOYREIMAGINED, "")
CALL("/wbr list", SlashCmdList.WATERBOYREIMAGINED, "list")
CALL("/wbr test priest", SlashCmdList.WATERBOYREIMAGINED, "test priest")
local cfg = WaterboyReimaginedConfig
CALL("config OnShow", rawget(cfg, "__s_OnShow"), cfg)
print("manual panel shown: " .. tostring(WaterboyReimaginedManualConjure:IsShown()))
print("manual 1 label: " .. tostring(WaterboyReimaginedManual1.label:GetText()))
CALL("manual tooltip", rawget(WaterboyReimaginedManual2, "__s_OnEnter"), WaterboyReimaginedManual2)
FIRE("BAG_UPDATE_DELAYED")
CALL("config drag stop", rawget(cfg, "__s_OnDragStop"), cfg)
CALL("config OnHide", rawget(cfg, "__s_OnHide"), cfg)
print("manual panel shown after hide: " .. tostring(WaterboyReimaginedManualConjure:IsShown()))
if cfg and rawget(cfg, "tabs") then
  for _, tab in ipairs(cfg.tabs) do CALL(tab.page .. " tab", rawget(tab, "__s_OnClick")) end
  CALL("trades tab again", rawget(cfg.tabs[2], "__s_OnClick"))
end
if NS.OpenConfig then CALL("OpenConfig priest", NS.OpenConfig, "classes", "PRIEST") end
if NS.PrintLoadout then CALL("/wbr loadout", SlashCmdList.WATERBOYREIMAGINED, "loadout")
CALL("/wbr macro", SlashCmdList.WATERBOYREIMAGINED, "macro") end
if WaterboyReimaginedConjure then CALL("conjure PreClick", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false) end
FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", NS.SPELLS.water[7])
FIRE("BAG_UPDATE_DELAYED")
FIRE("BAG_UPDATE_DELAYED")
CALL("/wbr off", SlashCmdList.WATERBOYREIMAGINED, "off")
FIRE("TRADE_SHOW")
FIRE("TRADE_CLOSED")
CALL("/wb toggles closed", SlashCmdList.WATERBOYREIMAGINED, "")
print("slash: " .. tostring(SLASH_WATERBOYREIMAGINED1) .. " " .. tostring(SLASH_WATERBOYREIMAGINED2) .. " " .. tostring(SLASH_WATERBOYREIMAGINED3))
-- loadout complete -> 3 presses -> prompt -> Temporary / Update loadout
CALL("/wbr on", SlashCmdList.WATERBOYREIMAGINED, "on")
local press = function(t, label)
  STUB_TIME = t
  CALL(label, rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false)
end
STUB_ITEMS = { [8079] = 40, [22895] = 20 } -- solo default: 2 stacks water, 1 food
press(10, "press 1 (complete)"); press(11, "press 2 (complete)"); press(12, "press 3 (prompt)")
print("prompt shown: " .. tostring(WaterboyReimaginedMorePrompt and WaterboyReimaginedMorePrompt:IsShown()))
CALL("Temporary", rawget(WaterboyReimaginedMorePrompt.temp, "__s_OnClick"))
print("timer shown: " .. tostring(WaterboyReimaginedExtraTimer:IsShown()))
STUB_TIME = 40
CALL("timer tick", rawget(WaterboyReimaginedExtraTimer, "__s_OnUpdate"), WaterboyReimaginedExtraTimer, 1)
print("timer label: " .. tostring(WaterboyReimaginedExtraTimer.label:GetText()))
CALL("timer drag stop", rawget(WaterboyReimaginedExtraTimer, "__s_OnDragStop"), WaterboyReimaginedExtraTimer)
press(13, "press (extra)")
STUB_ITEMS[8079] = 60
FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", NS.SPELLS.water[7]); FIRE("BAG_UPDATE_DELAYED")
CALL("/wbr loadout (extra)", SlashCmdList.WATERBOYREIMAGINED, "loadout")
STUB_TIME = 200
CALL("timer tick (expired)", rawget(WaterboyReimaginedExtraTimer, "__s_OnUpdate"), WaterboyReimaginedExtraTimer, 1)
print("timer shown after expiry: " .. tostring(WaterboyReimaginedExtraTimer:IsShown()))
press(200, "press after a quiet minute")
press(201, "press 2"); press(202, "press 3 (prompt)")
CALL("Update loadout", rawget(WaterboyReimaginedMorePrompt.raise, "__s_OnClick"))
print("config shown: " .. tostring(WaterboyReimaginedConfig:IsShown()))
press(203, "press (loadout unchanged)")
-- right-click stops extra early
press(300, "p1"); press(301, "p2"); press(302, "p3 (prompt)")
CALL("Temporary again", rawget(WaterboyReimaginedMorePrompt.temp, "__s_OnClick"))
CALL("right-click timer", rawget(WaterboyReimaginedExtraTimer, "__s_OnMouseUp"), WaterboyReimaginedExtraTimer, "RightButton")
print("timer shown after right-click: " .. tostring(WaterboyReimaginedExtraTimer:IsShown()))
-- character labels: full name, level, ruleset and faction (and an old record from another realm)
WaterboyReimaginedDB.mages["Oldmage-Longopaquerealm"] = { level = 42, water = 5, food = 5 }
print("mage record: " .. tostring(WaterboyReimaginedDB.mages[NS.CharKey()].name) .. " / " .. tostring(WaterboyReimaginedDB.mages[NS.CharKey()].where))
CALL("general tab", rawget(cfg.tabs[1], "__s_OnClick"))
print("general me: " .. tostring(cfg.general.me:GetText()))
print("general mages: " .. tostring(cfg.general.mages:GetText()))
CALL("/wbr list", SlashCmdList.WATERBOYREIMAGINED, "list")
-- player settings by full name, with first-name settings still matching
print("full name: " .. tostring(NS.UnitFullName("target")))
print("display: " .. NS.PlayerName("grimbold stonebrook"))
CALL("/wbr set Grimbold 1 1", SlashCmdList.WATERBOYREIMAGINED, "set Grimbold 1 1")
print("first-name match: " .. NS.FindPlayerKey("Grimbold Stonebrook") .. " / " .. select(2, NS.Want("Grimbold Stonebrook", "PRIEST")))
NS.Profile("default").players["grimbold stonebrook"] = { slots = {} }
print("full-name match: " .. NS.FindPlayerKey("Grimbold Stonebrook") .. " / " .. select(2, NS.Want("Grimbold Stonebrook", "PRIEST")))
FIRE("TRADE_SHOW")
FIRE("TRADE_CLOSED")
-- a player only this character has: the button says Delete player and removes it
NS.Profile("me", true).players["solo friend"] = { slots = {} }
NS.OpenLoadouts(NS.CharKey())
if NS.OpenConfig then NS.OpenConfig("players", "solo friend") end
print("char-only player button: " .. tostring(cfg.reset:GetText()))
NS.Profile("me").players["grimbold stonebrook"] = { slots = {} }
NS.OpenConfig("players", "grimbold stonebrook")
print("player also on default: " .. tostring(cfg.reset:GetText()))
-- each Conjure now button casts its own rank, even when the client has no rank text yet
CALL("config OnShow again", rawget(cfg, "__s_OnShow"), cfg)
for i = 1, 4 do local b = _G["WaterboyReimaginedManual" .. i]; print("manual " .. i .. " spell: " .. tostring(b:GetAttribute("spell"))) end
-- a level 1 mage that knows no conjure spells: buttons say not learned, the macro says so
STUB_KNOWN_MAX = 0
FIRE("SPELLS_CHANGED")
CALL("config OnShow (level 1)", rawget(cfg, "__s_OnShow"), cfg)
for i = 1, 4 do local b = _G["WaterboyReimaginedManual" .. i]; print("lvl1 manual " .. i .. ": " .. tostring(b.label:GetText()):gsub("\n", " ") .. " / " .. tostring(b:GetAttribute("spell"))) end
CALL("lvl1 tooltip", rawget(WaterboyReimaginedManual1, "__s_OnEnter"), WaterboyReimaginedManual1)
STUB_TIME = 9000
CALL("lvl1 macro press", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false)
-- only rank 1 water (5504): Water works, Water -1 isn't learned
STUB_KNOWN_MAX = 5504
FIRE("SPELLS_CHANGED")
CALL("config OnShow (rank 1)", rawget(cfg, "__s_OnShow"), cfg)
for i = 1, 2 do local b = _G["WaterboyReimaginedManual" .. i]; print("rank1 manual " .. i .. ": " .. tostring(b.label:GetText()):gsub("\n", " ") .. " / " .. tostring(b:GetAttribute("spell"))) end
STUB_KNOWN_MAX = nil
FIRE("SPELLS_CHANGED")
-- the X just hides the window (HideUIPanel is blocked in combat)
CALL("open config", NS.OpenConfig, "classes", "PRIEST")
print("open before X: " .. tostring(cfg:IsShown()))
CALL("X click", rawget(cfg.CloseButton, "__s_OnClick"), cfg.CloseButton)
print("open after X: " .. tostring(cfg:IsShown()))
-- the macro shows the next conjure (#showtooltip), its tooltip shows the loadout, combat presses explain themselves
STUB_ITEMS = {}
CALL("/wbr macro (create)", SlashCmdList.WATERBOYREIMAGINED, "macro")
FIRE("BAG_UPDATE_DELAYED")
print("macro icon: " .. tostring(STUB_MACRO_ICON))
print("macro body: " .. tostring(STUB_MACRO_BODY):gsub("\n", " | "))
local edits = STUB_MACRO_EDITS or 0
FIRE("BAG_UPDATE_DELAYED")
print("no edit when unchanged: " .. tostring((STUB_MACRO_EDITS or 0) == edits))
STUB_TT = {}
CALL("macro tooltip", GameTooltip.SetAction, GameTooltip, 1)
print("tooltip: " .. table.concat(STUB_TT, " | "))
STUB_COMBAT = true
STUB_TIME = 9500
CALL("combat press", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false)
STUB_TT = {}
CALL("combat tooltip", GameTooltip.SetAction, GameTooltip, 1)
print("combat tooltip: " .. table.concat(STUB_TT, " | "))
STUB_COMBAT = nil
STUB_TT = {}
CALL("other action tooltip", GameTooltip.SetAction, GameTooltip, 2)
print("other action lines: " .. #STUB_TT)
STUB_ITEMS = setmetatable({}, { __index = function() return 1000 end })
FIRE("BAG_UPDATE_DELAYED")
print("complete macro body: " .. tostring(STUB_MACRO_BODY):gsub("\n", " | "))
STUB_ITEMS = {}
-- bags full: the press casts nothing and says so; a cast that adds nothing says so too
STUB_ITEMS = {}
STUB_FREE = 0
STUB_TIME = 9800
CALL("full-bags press", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false)
print("full-bags button type: " .. tostring(WaterboyReimaginedConjure:GetAttribute("type")))
STUB_FREE = nil
STUB_TIME = 9900
CALL("press with room", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false)
print("button type with room: " .. tostring(WaterboyReimaginedConjure:GetAttribute("type")))
FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", NS.SPELLS.water[7])
FIRE("BAG_UPDATE_DELAYED")
print("after bag update, still waiting: " .. tostring(true))
CALL("fallback timer", STUB_TIMERS[#STUB_TIMERS])
-- a part stack only counts as room if the whole conjure fits (learned yield, else at most half full)
STUB_FREE = 0
STUB_ITEMS = { [8079] = 15 }  -- 15 of 20: room for 5
WaterboyReimaginedDB.yields = nil
STUB_TIME = 9950
CALL("part stack, yield unknown", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false)
print("type (unknown yield, 5 room: allowed): " .. tostring(WaterboyReimaginedConjure:GetAttribute("type")))
WaterboyReimaginedDB.yields = { [8079] = 4 }
STUB_TIME = 9960
CALL("part stack, yield 4", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false)
print("type (yield 4, 5 room): " .. tostring(WaterboyReimaginedConjure:GetAttribute("type")))
WaterboyReimaginedDB.yields = { [8079] = 20 }
STUB_TIME = 9970
CALL("part stack, yield 20", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false)
print("type (yield 20, 5 room): " .. tostring(WaterboyReimaginedConjure:GetAttribute("type")))
-- a conjure that lands records its yield
STUB_FREE = nil
WaterboyReimaginedDB.yields = nil
STUB_ITEMS = {}
STUB_TIME = 9980
CALL("press to learn yield", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false)
FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", NS.SPELLS.water[7])
STUB_ITEMS = { [8079] = 20 }
FIRE("BAG_UPDATE_DELAYED")
print("learned yield: " .. tostring(WaterboyReimaginedDB.yields and WaterboyReimaginedDB.yields[8079]))
STUB_ITEMS = {}
-- the spell's text says how many one conjure makes: room for exactly 4 is enough, 3 isn't
STUB_DESC = "Conjures 4 bottles of water, providing the mage and his allies with something to drink."
STUB_FREE = 0
WaterboyReimaginedDB.yields = { [8079] = 20 } -- the spell text wins over an old record
STUB_ITEMS = { [8079] = 16 }
STUB_TIME = 9990
CALL("room 4, makes 4", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false)
print("type (desc 4, room 4): " .. tostring(WaterboyReimaginedConjure:GetAttribute("type")))
STUB_ITEMS = { [8079] = 17 }
STUB_TIME = 9995
CALL("room 3, makes 4", rawget(WaterboyReimaginedConjure, "__s_PreClick"), WaterboyReimaginedConjure, "LeftButton", false)
print("type (desc 4, room 3): " .. tostring(WaterboyReimaginedConjure:GetAttribute("type")))
STUB_DESC, STUB_FREE, STUB_ITEMS = nil, nil, {}
-- the macro's icon is the addon's Icon file (by ID); without an ID it falls back to the question mark
STUB_MACRO_BODY, STUB_MACRO_ICON, STUB_MACRO_EDITS = nil, nil, 0
CALL("/wbr macro (icon by ID)", SlashCmdList.WATERBOYREIMAGINED, "macro")
print("macro icon by ID: " .. tostring(STUB_MACRO_ICON))
STUB_MACRO_ICON = 134400 -- as if the saved icon were lost: the next sync puts it back
FIRE("BAG_UPDATE_DELAYED")
print("icon restored by sync: " .. tostring(STUB_MACRO_ICON))
local e = STUB_MACRO_EDITS
FIRE("BAG_UPDATE_DELAYED"); FIRE("BAG_UPDATE_DELAYED")
print("no edits when icon and body match: " .. tostring(STUB_MACRO_EDITS == e))
STUB_NO_FILEID = true
CALL("/wbr macro (fallback)", SlashCmdList.WATERBOYREIMAGINED, "macro")
print("fallback icon: " .. tostring(STUB_MACRO_ICON))
STUB_MACRO_ICON = 134400 -- the game reports the question mark as an ID
e = STUB_MACRO_EDITS
FIRE("BAG_UPDATE_DELAYED"); FIRE("BAG_UPDATE_DELAYED")
print("fallback doesn't re-edit every update: " .. tostring(STUB_MACRO_EDITS == e))
STUB_NO_FILEID = nil
-- picking the macro icon: each image by its ID, the next conjure's spell as the question mark, no repeat edits
STUB_NO_FILEID = nil
CALL("/wbr macro (make it)", SlashCmdList.WATERBOYREIMAGINED, "macro")
for _, key in ipairs({ "cooler", "buckets", "spell", "drop" }) do
  CALL("icon " .. key, NS.SetMacroIcon, key)
  local e = STUB_MACRO_EDITS
  FIRE("BAG_UPDATE_DELAYED"); FIRE("BAG_UPDATE_DELAYED")
  print("icon " .. key .. ": " .. tostring(STUB_MACRO_ICON) .. ", saved " .. tostring(WaterboyReimaginedDB.macroIcon) .. ", steady " .. tostring(STUB_MACRO_EDITS == e))
end
-- the picker on the Loadouts tab: four buttons, clicking one picks it
local lp = cfg.loadouts
print("icon buttons: " .. tostring(lp and lp.iconButtons and #lp.iconButtons))
CALL("click buckets button", rawget(lp.iconButtons[3], "__s_OnClick"), lp.iconButtons[3])
CALL("hover buckets button", rawget(lp.iconButtons[3], "__s_OnEnter"), lp.iconButtons[3])
print("after click: " .. tostring(WaterboyReimaginedDB.macroIcon) .. " / " .. tostring(STUB_MACRO_ICON))
CALL("icon back to drop", NS.SetMacroIcon, "drop")
