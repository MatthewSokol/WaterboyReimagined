-- Waterboy Reimagined
-- Mage water service. When someone opens trade with you (on a mage), the trade window is filled with the
-- stacks of conjured water and food set up for them. Each setting is a list of up to 6 trade slots, each
-- holding one conjured item (e.g. 3x Crystal Water + 1x Sweet Roll). If you have no stack of that rank,
-- the next rank down is used, then higher ranks.
--
-- Who gets what (first match wins):
--   1. this character's profile, player override   (e.g. Grimbold: 1 water, 1 food)
--   2. default profile, player override
--   3. this character's profile, class setting
--   4. default profile, class setting
--
-- Configuration works on any character; trades are only filled on mages.
--   /wbr            opens the config window (also /wbr config, settings, options)
--   /wbr help      lists the commands (/wb works too)

local ADDON_NAME, ns = ...

-- Conjured items by rank, lowest first.
local WATER = { 5350, 2288, 2136, 3772, 8077, 8078, 8079 }
local FOOD  = { 5349, 1113, 1114, 1487, 8075, 8076, 22895 }
local NAMES = {
    [5350] = "Conjured Water",       [5349] = "Conjured Muffin",
    [2288] = "Conjured Fresh Water", [1113] = "Conjured Bread",
    [2136] = "Conjured Purified Water", [1114] = "Conjured Rye",
    [3772] = "Conjured Spring Water", [1487] = "Conjured Pumpernickel",
    [8077] = "Conjured Mineral Water", [8075] = "Conjured Sourdough",
    [8078] = "Conjured Sparkling Water", [8076] = "Conjured Sweet Roll",
    [8079] = "Conjured Crystal Water", [22895] = "Conjured Cinnamon Roll",
}
local ITEMS = {} -- [itemID] = { kind = "water"|"food", rank = 1..7, name = }
for rank, id in ipairs(WATER) do ITEMS[id] = { kind = "water", rank = rank, name = NAMES[id] } end
for rank, id in ipairs(FOOD) do ITEMS[id] = { kind = "food", rank = rank, name = NAMES[id] } end
local TOP_WATER, TOP_FOOD = WATER[#WATER], FOOD[#FOOD]
local LISTS = { water = WATER, food = FOOD }

-- Conjure Water / Conjure Food spell IDs by rank, lowest first (to find the highest rank a mage knows).
local SPELLS = {
    water = { 5504, 5505, 5506, 6127, 10138, 10139, 10140 },
    food  = { 587, 597, 990, 6129, 10144, 10145, 28612 },
}

-- A slot is either an itemID (that exact rank) or a relative rank: "water1" = the highest rank of water
-- the mage knows, "water2" = 2nd highest, ... (same for "food1" etc.)
local RELATIVE_COUNT = 3 -- relative ranks offered in the config palette
local function ParseRelative(slot)
    if type(slot) ~= "string" then return end
    local kind, n = slot:match("^(%a+)(%d+)$")
    if LISTS[kind] then return kind, tonumber(n) end
end

local ORDINALS = { "Highest", "2nd highest", "3rd highest" }
local function RelativeName(kind, n)
    return (ORDINALS[n] or (n .. "th highest")) .. " " .. kind
end

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local TRADE_SLOTS = 6     -- slot 7 is "will not be traded"
local PLACE_DELAY = 0.15  -- seconds between placing stacks

-- an entry: { slots = { slot, ... } }  (stacks of the highest water, then of the highest food)
local function MakeEntry(water, food)
    local slots = {}
    for _ = 1, math.min(water, TRADE_SLOTS) do slots[#slots + 1] = "water1" end
    for _ = 1, math.min(food, TRADE_SLOTS - #slots) do slots[#slots + 1] = "food1" end
    return { slots = slots }
end

local DEFAULT_CLASSES = { -- stacks of water, food
    WARRIOR = { 0, 2 }, ROGUE = { 0, 2 }, HUNTER = { 2, 2 }, WARLOCK = { 2, 1 },
    PALADIN = { 3, 1 }, SHAMAN = { 3, 1 }, DRUID = { 3, 1 }, PRIEST = { 4, 0 }, MAGE = { 0, 0 },
}

local db, charKey
local isMage = false
local tradeToken = 0      -- bumps every trade so timers from an old trade stop

local function Print(msg) print("|cff69ccf0Waterboy Reimagined|r: " .. msg) end
local function Dbg(fmt, ...)
    if db and db.debug then print("|cff69ccf0Waterboy debug|r: " .. string.format(fmt, ...)) end
end

local function CopyEntry(e)
    local slots = {}
    for i, id in ipairs(e.slots) do slots[i] = id end
    return { slots = slots }
end

---------------------------------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------------------------------

local function DefaultClassEntry(class)
    local d = DEFAULT_CLASSES[class] or { 0, 0 }
    return MakeEntry(d[1], d[2])
end

-- v0.1 stored { water = N, food = N }; turn those into slot lists.
-- Before v3, "top rank" was stored as the rank-7 item; it now means the highest rank the mage knows.
local function Migrate(list, oldVersion)
    for key, e in pairs(list) do
        if not e.slots then list[key] = MakeEntry(e.water or 0, e.food or 0)
        elseif oldVersion < 3 then
            for i, slot in ipairs(e.slots) do
                if slot == TOP_WATER then e.slots[i] = "water1" elseif slot == TOP_FOOD then e.slots[i] = "food1" end
            end
        end
    end
end

local function InitDB()
    WaterboyReimaginedDB = WaterboyReimaginedDB or {}
    db = WaterboyReimaginedDB
    if db.enabled == nil then db.enabled = true end
    db.profiles = db.profiles or {}
    local def = db.profiles.default or {}
    db.profiles.default = def
    def.classes = def.classes or {}
    def.players = def.players or {}
    local oldVersion = db.version or 1
    for _, p in pairs(db.profiles) do
        p.classes, p.players = p.classes or {}, p.players or {}
        Migrate(p.classes, oldVersion)
        Migrate(p.players, oldVersion)
    end
    db.version = 3
    for _, class in ipairs(CLASSES) do
        if not def.classes[class] then def.classes[class] = DefaultClassEntry(class) end
    end
    db.mages = db.mages or {} -- [charKey] = { level =, water =, food = } (highest known ranks)
    -- Keyed by the full name: on Forever two characters can share a first name (different surnames).
    local first, surname = UnitName("player")
    charKey = first .. ((surname and surname ~= "") and (" " .. surname) or "") .. "-" .. GetRealmName()
    -- Older builds keyed by first name only: move this character's data to the new key (once).
    local oldKey = first .. "-" .. GetRealmName()
    if oldKey ~= charKey then
        for _, t in ipairs({ db.mages, db.profiles }) do
            if t[oldKey] ~= nil and t[charKey] == nil then t[charKey], t[oldKey] = t[oldKey], nil end
        end
    end
    if ns.InitLoadouts then ns.InitLoadouts(db) end
end

-- "Aldren Brightwater" on Forever (UnitName's second value is the surname there), else just the name.
local function FullName()
    local name, surname = UnitName("player")
    if surname and surname ~= "" then return name .. " " .. surname end
    return name
end

-- Where this character lives, readably: "PvP Horde" on Forever (realm names there are long and opaque, the
-- ruleset is what players know), "Realmname Horde" elsewhere.
local function WhereLabel()
    local where
    local rules = C_GameRules and C_GameRules.IsGameRuleActive and Enum and Enum.GameRule
    if rules then
        local parts = {}
        local function on(rule) return rule ~= nil and C_GameRules.IsGameRuleActive(rule) end
        if on(rules.HardcoreRuleset) then parts[#parts + 1] = "Hardcore" end
        if on(rules.RPRuleset) then parts[#parts + 1] = "RP" end
        if on(rules.PvPRuleset) then parts[#parts + 1] = "PvP" end
        where = #parts > 0 and table.concat(parts, "-") or "PvE"
    else
        where = GetRealmName()
    end
    local _, faction = UnitFactionGroup("player")
    if faction and faction ~= "" then where = where .. " " .. faction end
    return where
end

-- name, where ("PvP Horde") and level for a character key; live for this character, else as last recorded
-- (older records fall back to the name in the key and the realm when it isn't this one).
local function CharInfo(key)
    if key == charKey then return FullName(), WhereLabel(), UnitLevel("player") end
    local m = db.mages[key] or {}
    if m.name then return m.name, m.where, m.level end
    local name, realm = key:match("^(.-)%-(.*)$")
    if not name then return key end
    return name, realm ~= GetRealmName() and realm or nil, m.level
end

local function HighestKnown(kind)
    for rank = #SPELLS[kind], 1, -1 do
        local id = SPELLS[kind][rank]
        if (IsPlayerSpell and IsPlayerSpell(id)) or IsSpellKnown(id) then return rank end
    end
    return 0
end

-- Remember this character if it's a mage (and the highest ranks it can conjure), so its profile can be
-- edited from any character.
local function RecordMage()
    if not isMage then return end
    local m = db.mages[charKey] or {}
    db.mages[charKey] = m
    m.level = UnitLevel("player")
    m.name, m.where = FullName(), WhereLabel()
    m.water, m.food = HighestKnown("water"), HighestKnown("food")
end

-- Highest rank of `kind` the mage `key` knows (nil if unknown: not a recorded mage).
local function TopRank(kind, key)
    local m = db.mages[key or charKey]
    local r = m and m[kind]
    if r and r > 0 then return r end
end

-- The item a slot stands for, for mage `key` (default: this character). Relative ranks on a character that
-- isn't a known mage resolve against all 7 ranks.
local function Resolve(slot, key)
    local kind, n = ParseRelative(slot)
    if not kind then return slot end
    local list = LISTS[kind]
    local top = TopRank(kind, key) or #list
    return list[math.max(1, top - n + 1)]
end

local function SlotName(slot)
    local kind, n = ParseRelative(slot)
    if kind then return RelativeName(kind, n) end
    return NAMES[slot] or tostring(slot)
end

-- Known mages (and any character that has a profile), sorted.
local function KnownMages()
    local seen, list = {}, {}
    for key in pairs(db.mages) do seen[key] = true; list[#list + 1] = key end
    for key in pairs(db.profiles) do
        if key ~= "default" and not seen[key] then list[#list + 1] = key end
    end
    table.sort(list)
    return list
end

-- which: "default", "me" (this character) or a character key "Name-Realm". Created on first write.
local function Profile(which, create)
    if which == "default" then return db.profiles.default end
    local key = which == "me" and charKey or which
    local p = db.profiles[key]
    if not p and create then
        p = { classes = {}, players = {}, loadouts = {} }
        db.profiles[key] = p
    end
    return p
end

local function PlayerKey(name)
    return strtrim((name:match("^([^%-]+)") or name)):lower()
end

-- "grimbold brightwater" -> "Grimbold Brightwater", for showing a player key.
local function PlayerName(key)
    return (key:gsub("^(%l)", string.upper):gsub(" (%l)", function(c) return " " .. c:upper() end))
end

-- A unit's full name: "Grimbold Brightwater" on Forever (UnitName's second value is the surname there);
-- elsewhere the second value is a realm, which player settings ignore.
local function UnitFullName(unit)
    local name, second = UnitName(unit)
    if not name then return nil end
    local forever = RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled()
    if forever and second and second ~= "" then return name .. " " .. second end
    return name
end

-- The player-settings key that applies to `name`: the full name if it has a setting, else the first name
-- alone (settings typed by first name, or saved before full names), else the full name.
local function FindPlayerKey(name)
    local full = PlayerKey(name)
    local first = full:match("^(%S+) ")
    if first then
        local me, def = Profile("me"), Profile("default")
        local function has(k) return (me and me.players[k]) or def.players[k] end
        if not has(full) and has(first) then return first end
    end
    return full
end

local function Lookup(field, key)
    local me = Profile("me")
    if me and me[field][key] then return me[field][key], "this character" end
    local d = Profile("default")[field][key]
    if d then return d, "default" end
end

-- What does this player get? Returns entry, description of where it came from
local function Want(name, class)
    local want, src = Lookup("players", FindPlayerKey(name))
    if want then return want, src .. " profile, player " .. name end
    want, src = Lookup("classes", class)
    if want then return want, src .. " profile, class " .. class end
    return { slots = {} }, "nothing set"
end

-- "2x Highest water, 1x Conjured Sweet Roll"
local function Describe(entry)
    if not entry or #entry.slots == 0 then return "nothing" end
    local counts, order = {}, {}
    for _, id in ipairs(entry.slots) do
        if not counts[id] then order[#order + 1] = id end
        counts[id] = (counts[id] or 0) + 1
    end
    local parts = {}
    for _, id in ipairs(order) do parts[#parts + 1] = counts[id] .. "x " .. SlotName(id) end
    return table.concat(parts, ", ")
end

---------------------------------------------------------------------------------------------------
-- Bags
---------------------------------------------------------------------------------------------------

-- All unlocked stacks of conjured water/food in the bags.
local function FindStacks()
    local found = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and ITEMS[info.itemID] and not info.isLocked then
                found[#found + 1] = { bag = bag, slot = slot, id = info.itemID, count = info.stackCount }
            end
        end
    end
    return found
end

-- Best unused stack for itemID: that rank, else the nearest lower rank, else the nearest higher rank;
-- biggest stack on a tie.
local function PickStack(stacks, id, used)
    local want = ITEMS[id]
    local best, bestScore
    for i, s in ipairs(stacks) do
        local have = ITEMS[s.id]
        if not used[i] and have.kind == want.kind then
            local d = want.rank - have.rank
            local score = d >= 0 and d or (100 - d)
            if not best or score < bestScore or (score == bestScore and s.count > stacks[best].count) then
                best, bestScore = i, score
            end
        end
    end
    if best then
        used[best] = true
        return stacks[best]
    end
end

---------------------------------------------------------------------------------------------------
-- Trade
---------------------------------------------------------------------------------------------------

local function FreeTradeSlot()
    for i = 1, TRADE_SLOTS do
        if not GetTradePlayerItemInfo(i) then return i end
    end
end

local function PlaceNext(queue, idx, token)
    if token ~= tradeToken or idx > #queue then return end
    if CursorHasItem() then
        Dbg("cursor busy, waiting")
        C_Timer.After(PLACE_DELAY, function() PlaceNext(queue, idx, token) end)
        return
    end
    local tslot = FreeTradeSlot()
    if not tslot then Dbg("trade window full"); return end
    local s = queue[idx]
    local info = C_Container.GetContainerItemInfo(s.bag, s.slot)
    if info and info.itemID == s.id and not info.isLocked then
        Dbg("bag %d slot %d (%s x%d) -> trade slot %d", s.bag, s.slot, NAMES[s.id], info.stackCount, tslot)
        C_Container.PickupContainerItem(s.bag, s.slot)
        ClickTradeButton(tslot)
    else
        Dbg("bag %d slot %d changed, skipped", s.bag, s.slot)
    end
    C_Timer.After(PLACE_DELAY, function() PlaceNext(queue, idx + 1, token) end)
end

-- Put the stacks for `entry` into the open trade window (one every PLACE_DELAY seconds).
local function AddToTrade(entry, label)
    tradeToken = tradeToken + 1
    local stacks, used, queue, missing = FindStacks(), {}, {}, 0
    for i = 1, math.min(#entry.slots, TRADE_SLOTS) do
        local s = PickStack(stacks, Resolve(entry.slots[i]), used)
        if s then queue[#queue + 1] = s else missing = missing + 1 end
    end

    local msg = label .. ": " .. Describe(entry)
    if missing > 0 then msg = msg .. string.format(" - %d stack(s) short", missing) end
    Print(msg)

    if #queue == 0 then return end
    local token = tradeToken
    C_Timer.After(0.1, function() PlaceNext(queue, 1, token) end)
end

-- Trade opened: fill it right away, or (with "Fill trades automatically" off) show the trade popup.
local function OnTradeShow()
    tradeToken = tradeToken + 1
    if not isMage then Dbg("not a mage, trade left alone"); return end
    local name = UnitFullName("NPC")
    local _, class = UnitClass("NPC")
    if not name or not class then Dbg("no trade partner info"); return end
    local want, src = Want(name, class)
    if db.enabled then
        AddToTrade(want, string.format("%s (%s) [%s]", name, class:lower(), src))
    else
        Dbg("auto-fill off, showing the trade popup")
        ns.ShowTradePopup(name, class, want, src)
    end
end

---------------------------------------------------------------------------------------------------
-- Shared with Config.lua
---------------------------------------------------------------------------------------------------

ns.WATER, ns.FOOD, ns.ITEMS, ns.CLASSES, ns.TRADE_SLOTS = WATER, FOOD, ITEMS, CLASSES, TRADE_SLOTS
ns.PlayerName, ns.UnitFullName, ns.FindPlayerKey = PlayerName, UnitFullName, FindPlayerKey
ns.Profile, ns.PlayerKey, ns.CopyEntry, ns.DefaultClassEntry = Profile, PlayerKey, CopyEntry, DefaultClassEntry
ns.Describe, ns.Print, ns.Dbg, ns.Want, ns.SPELLS = Describe, Print, Dbg, Want, SPELLS
ns.Resolve, ns.SlotName, ns.ParseRelative, ns.TopRank = Resolve, SlotName, ParseRelative, TopRank
ns.RELATIVE_COUNT, ns.NAMES, ns.AddToTrade = RELATIVE_COUNT, NAMES, AddToTrade
function ns.DB() return db end
function ns.CharKey() return charKey end
function ns.IsMage() return isMage end
ns.KnownMages, ns.CharInfo = KnownMages, CharInfo

---------------------------------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------------------------------

local function ClassToken(word)
    local up = word:upper()
    for _, c in ipairs(CLASSES) do if c == up then return c end end
end

local function ListProfile(which)
    local p = Profile(which)
    local label = which == "default" and "Default profile" or ("This character (" .. FullName() .. ")")
    if not p or (not next(p.classes) and not next(p.players)) then
        Print(label .. ": no overrides")
        return
    end
    Print(label .. ":")
    for _, c in ipairs(CLASSES) do
        if p.classes[c] then print("   " .. c:lower() .. ": " .. Describe(p.classes[c])) end
    end
    for name, e in pairs(p.players) do print("   player " .. name .. ": " .. Describe(e)) end
end

local HELP = {
    "/wbr - open the config window (also /wbr config, settings, options)",
    "/wbr list - show the default profile and this character's overrides",
    "/wbr set [me] <class|player> <water> <food> - stacks of the highest rank to hand out (\"me\" = this character only)",
    "/wbr clear [me] <class|player> - remove a setting",
    "/wbr test <class|player> - show what a trade would get",
    "/wbr on | off - fill trades or not (now: %s)",
    "/wbr macro - put the Waterboy conjure macro on your cursor",
    "/wbr loadout - what the conjure macro is aiming for right now",
    "/wbr debug - toggle debug messages",
}

local OPEN = { [""] = true, config = true, settings = true, options = true, show = true }

local function Slash(input)
    local args = {}
    for w in (input or ""):gmatch("%S+") do args[#args + 1] = w end
    local cmd = (args[1] or ""):lower()
    local which = "default"
    if (cmd == "set" or cmd == "clear") and args[2] and args[2]:lower() == "me" then
        which = "me"
        table.remove(args, 2)
    end

    if OPEN[cmd] then
        ns.ToggleConfig()
    elseif cmd == "macro" then
        ns.MakeMacro()
    elseif cmd == "loadout" then
        ns.PrintLoadout()
    elseif cmd == "list" then
        ListProfile("default")
        ListProfile("me")
        if not isMage then Print("(not a mage: settings are saved but trades aren't filled here)") end
    elseif cmd == "set" and args[2] and tonumber(args[3]) and tonumber(args[4]) then
        local entry = MakeEntry(math.floor(tonumber(args[3])), math.floor(tonumber(args[4])))
        local p = Profile(which, true)
        local class = ClassToken(args[2])
        if class then p.classes[class] = entry else p.players[PlayerKey(args[2])] = entry end
        Print(string.format("%s %s: %s", which == "me" and "This character," or "Default,",
            class and class:lower() or ("player " .. PlayerKey(args[2])), Describe(entry)))
        if ns.RefreshConfig then ns.RefreshConfig() end
    elseif cmd == "clear" and args[2] then
        local p = Profile(which)
        local class = ClassToken(args[2])
        if p then
            if class then p.classes[class] = nil else p.players[PlayerKey(args[2])] = nil end
        end
        if class and which == "default" then p.classes[class] = DefaultClassEntry(class) end
        Print("Cleared " .. args[2] .. (which == "me" and " (this character)" or " (default)"))
        if ns.RefreshConfig then ns.RefreshConfig() end
    elseif cmd == "test" and args[2] then
        local class = ClassToken(args[2])
        local want, src
        if class then
            want, src = Lookup("classes", class)
            src = (src or "nothing set") .. " profile"
        else
            want, src = Want(args[2], "?")
        end
        Print(args[2] .. " gets " .. Describe(want) .. " [" .. src .. "]")
    elseif cmd == "on" or cmd == "off" then
        db.enabled = cmd == "on"
        Print("Trade filling " .. (db.enabled and "on" or "off"))
        if ns.RefreshConfig then ns.RefreshConfig() end
    elseif cmd == "debug" then
        db.debug = not db.debug
        Print("Debug " .. (db.debug and "on" or "off"))
    else
        for _, line in ipairs(HELP) do Print(line:format(db.enabled and "on" or "off")) end
    end
end

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------

-- Slash commands first, so they exist even if something below fails.
SLASH_WATERBOYREIMAGINED1 = "/wbr"
SLASH_WATERBOYREIMAGINED2 = "/wb"
SlashCmdList.WATERBOYREIMAGINED = Slash

-- RegisterEvent throws on an event this client doesn't have (e.g. LEARNED_SPELL_IN_TAB on Forever), which
-- would stop the whole file loading. Register through pcall and say which ones failed under /wbr debug.
function ns.RegisterEvents(frame, events)
    for _, event in ipairs(events) do
        if not pcall(frame.RegisterEvent, frame, event) then
            C_Timer.After(5, function() Dbg("this client has no %s event", event) end)
        end
    end
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitDB()
    elseif not db then
        return
    elseif event == "PLAYER_LOGIN" then
        isMage = select(2, UnitClass("player")) == "MAGE"
        RecordMage()
    elseif event == "SPELLS_CHANGED" then
        RecordMage() -- learned a new rank
    elseif event == "TRADE_SHOW" then
        OnTradeShow()
    elseif event == "TRADE_CLOSED" then
        tradeToken = tradeToken + 1
        if ns.HideTradePopup then ns.HideTradePopup() end
    end
end)
ns.RegisterEvents(f, { "ADDON_LOADED", "PLAYER_LOGIN", "TRADE_SHOW", "TRADE_CLOSED", "SPELLS_CHANGED" })
