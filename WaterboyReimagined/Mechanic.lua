-- Waterboy Reimagined: optional hooks for Mechanic (https://github.com/Falkicon/Mechanic), an addon developer
-- tool. Players won't have it, and without it this file returns straight away and nothing below runs.
--
-- With Mechanic installed:
--   * chat messages and debug lines (even with /wbr debug off) go to Mechanic's Console;
--   * self-tests show in Mechanic's Tests tab (Run all). Mechanic also runs them and saves the results, with the
--     last 50 log lines, on every /reload and logout; tools/release-check.js reads that file for the release
--     check (RELEASING.md);
--   * "Debug messages" and "Fill trades automatically" appear in Mechanic's settings.
-- MechanicLib comes from the !Mechanic addon (## OptionalDeps: !Mechanic loads it first). It isn't embedded here.

local ADDON_NAME, ns = ...

local LibStub = rawget(_G, "LibStub")
local MechanicLib = LibStub and LibStub("MechanicLib-1.0", true)
if not MechanicLib then return end

---------------------------------------------------------------------------------------------------
-- Log: everything the addon says, for Mechanic's Console and its saved log
---------------------------------------------------------------------------------------------------

local LOG_MAX = 200
local log = {}

local function Plain(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

function ns.LogSink(kind, msg)
    msg = Plain(msg)
    log[#log + 1] = string.format("%.1f [%s] %s", GetTime(), kind, msg)
    if #log > LOG_MAX then table.remove(log, 1) end
    local cat = MechanicLib.Categories
    MechanicLib:Log(ADDON_NAME, msg, kind == "debug" and cat.EVENT or cat.CORE)
end

---------------------------------------------------------------------------------------------------
-- Self-tests: read-only checks of the live game state. Each returns passed, message, details.
-- passed = true with a "warn" detail means "fine, but look" (e.g. not a mage, no macro yet).
---------------------------------------------------------------------------------------------------

local function Detail(details, label, value, status)
    details[#details + 1] = { label = label, value = tostring(value), status = status }
end

local function CountStatus(details, status)
    local n = 0
    for _, d in ipairs(details) do if d.status == status then n = n + 1 end end
    return n
end

-- passed unless a detail failed; the message counts failures and warnings
local function Summary(details, okText)
    local fails, warns = CountStatus(details, "fail"), CountStatus(details, "warn")
    if fails > 0 then return false, fails .. " problem" .. (fails > 1 and "s" or "") end
    if warns > 0 then return true, okText .. " (" .. warns .. " to look at)" end
    return true, okText
end

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or rawget(_G, "GetAddOnMetadata")
local ItemInstant = (C_Item and C_Item.GetItemInfoInstant) or rawget(_G, "GetItemInfoInstant")
local function SpellName(id)
    local C = rawget(_G, "C_Spell")
    if C and C.GetSpellName then return C.GetSpellName(id) end
    return (GetSpellInfo(id))
end
local function Knows(id)
    return (IsPlayerSpell and IsPlayerSpell(id)) or IsSpellKnown(id)
end

local TESTS = {
    {
        id = "load", name = "Addon loaded", category = "Load",
        description = "Every file ran to the end, the slash commands exist and the saved settings are set up.",
        run = function(d)
            Detail(d, "Version", GetMeta and GetMeta(ADDON_NAME, "Version") or "?", "pass")
            local parts = {
                ["WaterboyReimagined.lua"] = ns.DB ~= nil, ["Conjure.lua"] = ns.MakeMacro ~= nil,
                ["Config.lua"] = ns.ToggleConfig ~= nil, ["TradePopup.lua"] = ns.ShowTradePopup ~= nil,
                ["Journal.lua"] = ns.Journal ~= nil,
            }
            for file, ok in pairs(parts) do Detail(d, file, ok and "loaded" or "didn't finish loading", ok and "pass" or "fail") end
            local slash = SlashCmdList.WATERBOYREIMAGINED ~= nil and SLASH_WATERBOYREIMAGINED1 == "/wbr"
            Detail(d, "/wbr and /wb", slash and "registered" or "missing", slash and "pass" or "fail")
            local db = ns.DB()
            Detail(d, "Saved settings", db and ("version " .. tostring(db.version)) or "not set up",
                (db and db.version == 3) and "pass" or "fail")
            return Summary(d, "Loaded")
        end,
    },
    {
        id = "data", name = "Item and spell data", category = "Data",
        description = "Every conjured item and Conjure spell rank the addon knows about exists in this client.",
        run = function(d)
            local items, spells = 0, 0
            for _, list in ipairs({ ns.WATER, ns.FOOD }) do
                for rank, id in ipairs(list) do
                    local ok = not ItemInstant or ItemInstant(id) ~= nil
                    items = items + 1
                    Detail(d, ns.NAMES[id] .. " (" .. id .. ")", ok and ("rank " .. rank) or "unknown item", ok and "pass" or "fail")
                end
            end
            local english = not GetLocale or GetLocale() == "enUS" or GetLocale() == "enGB"
            for kind, ids in pairs(ns.SPELLS) do
                for rank, id in ipairs(ids) do
                    local name = SpellName(id)
                    spells = spells + 1
                    -- names are localized; only an English client can check the wording
                    local status = not name and "fail" or (name:find("^Conjure") or not english) and "pass" or "warn"
                    Detail(d, "Conjure " .. kind .. " rank " .. rank .. " (" .. id .. ")", name or "unknown spell", status)
                end
            end
            return Summary(d, items .. " items and " .. spells .. " spells found")
        end,
    },
    {
        id = "mage", name = "This character", category = "Character",
        description = "On a mage: the conjure ranks it knows match what the addon recorded (used by relative ranks).",
        run = function(d)
            if not ns.IsMage() then
                Detail(d, "Class", "not a mage: trades and conjuring are off here, settings still work", "warn")
                return Summary(d, "Not a mage")
            end
            local m = ns.DB().mages[ns.CharKey()]
            Detail(d, "Recorded", m and "yes" or "no", m and "pass" or "fail")
            for kind, ids in pairs(ns.SPELLS) do
                local known = 0
                for rank = #ids, 1, -1 do if Knows(ids[rank]) then known = rank; break end end
                local saved = m and m[kind] or 0
                Detail(d, "Highest " .. kind .. " rank", known .. " known, " .. saved .. " recorded",
                    known == saved and "pass" or "fail")
            end
            return Summary(d, "Ranks match")
        end,
    },
    {
        id = "settings", name = "Trade settings", category = "Settings",
        description = "Every class and player setting in every profile has at most 6 slots of real water or food, "
            .. "and every class has a default.",
        run = function(d)
            local db = ns.DB()
            local entries, bad, profiles = 0, 0, 0
            for pkey, p in pairs(db.profiles) do
                profiles = profiles + 1
                for _, field in ipairs({ "classes", "players" }) do
                    for key, e in pairs(p[field] or {}) do
                        entries = entries + 1
                        local problem
                        if type(e) ~= "table" or type(e.slots) ~= "table" then problem = "no slot list"
                        elseif #e.slots > ns.TRADE_SLOTS then problem = #e.slots .. " slots"
                        else
                            for _, slot in ipairs(e.slots) do
                                if not ns.ITEMS[slot] and not ns.ParseRelative(slot) then problem = "unknown slot " .. tostring(slot) end
                            end
                        end
                        if problem then
                            bad = bad + 1
                            Detail(d, pkey .. " / " .. field .. " / " .. tostring(key), problem, "fail")
                        end
                    end
                end
            end
            for _, class in ipairs(ns.CLASSES) do
                local e = ns.Profile("default").classes[class]
                if not e then Detail(d, "Default " .. class:lower(), "missing", "fail") end
                -- what a trade would hand over right now resolves to real items
                for _, slot in ipairs(ns.Want("Nobody", class).slots) do
                    if not ns.ITEMS[ns.Resolve(slot)] then
                        Detail(d, class:lower() .. " trade", "slot " .. tostring(slot) .. " doesn't resolve", "fail")
                    end
                end
            end
            Detail(d, "Settings checked", entries .. " in " .. profiles .. " profiles", bad == 0 and "pass" or nil)
            return Summary(d, entries .. " settings OK")
        end,
    },
    {
        id = "loadouts", name = "Loadouts", category = "Conjure",
        description = "Solo, party and raid loadouts are well formed, and the macro's current target can be worked out.",
        run = function(d)
            for _, group in ipairs(ns.LOADOUT_GROUPS) do
                local lo = ns.Loadout(group)
                local problem
                if type(lo) ~= "table" or type(lo.counts) ~= "table" then problem = "missing"
                else
                    for slot, n in pairs(lo.counts) do
                        if not ns.ParseRelative(slot) then problem = "unknown slot " .. tostring(slot)
                        elseif type(n) ~= "number" or n < 0 or n ~= math.floor(n) then problem = slot .. " = " .. tostring(n) end
                    end
                end
                Detail(d, group, problem or "OK", problem and "fail" or "pass")
            end
            local ok, lines = pcall(ns.LoadoutStatus)
            Detail(d, "Current target", ok and lines[1] or ("error: " .. tostring(lines)), ok and "pass" or "fail")
            return Summary(d, "Loadouts OK")
        end,
    },
    {
        id = "macro", name = "Conjure macro", category = "Conjure",
        description = "The Waterboy macro (if made) still clicks the addon's button, the button exists, and the "
            .. "macro icon images load.",
        run = function(d)
            local button = _G.WaterboyReimaginedConjure
            Detail(d, "Conjure button", button and "exists" or "missing", button and "pass" or "fail")
            local idx = GetMacroIndexByName("Waterboy")
            if idx == 0 then
                Detail(d, "Waterboy macro", "not made yet (/wbr macro)", "warn")
            else
                local _, _, body = GetMacroInfo(idx)
                local ok = body and body:find(ns.MacroText(), 1, true)
                Detail(d, "Waterboy macro", ok and "clicks the conjure button" or "text changed", ok and "pass" or "fail")
            end
            for _, opt in ipairs(ns.MACRO_ICONS) do
                if opt.file then
                    local path = ns.MacroIconTexture(opt)
                    local id = GetFileIDFromPath and (GetFileIDFromPath(path .. ".tga") or GetFileIDFromPath(path))
                    Detail(d, "Icon " .. opt.key, id and ("file ID " .. id) or "no file ID (macro shows the question mark)",
                        id and "pass" or "warn")
                end
            end
            return Summary(d, "Macro OK")
        end,
    },
    {
        id = "ui", name = "Minimap button", category = "UI",
        description = "The minimap button exists and is shown or hidden as set.",
        run = function(d)
            local b = _G.WaterboyReimaginedMinimapButton
            Detail(d, "Button", b and "exists" or "missing", b and "pass" or "fail")
            if b then
                local want = ns.MinimapButtonShown()
                Detail(d, "Shown", tostring(b:IsShown()) .. " (setting: " .. tostring(want) .. ")",
                    b:IsShown() == want and "pass" or "fail")
            end
            return Summary(d, "Minimap button OK")
        end,
    },
}

local byID, results = {}, {}
for _, t in ipairs(TESTS) do byID[t.id] = t; t.type = "auto" end

local function Run(id)
    local t = byID[id]
    if not t then return { passed = false, message = "Unknown test " .. tostring(id) } end
    local details = {}
    local start = debugprofilestop and debugprofilestop()
    local ok, passed, message = pcall(t.run, details)
    local result = ok and { passed = passed, message = message, details = details }
        or { passed = false, message = "Test error: " .. Plain(passed), details = details }
    result.id = id
    if start then result.duration = (debugprofilestop() - start) / 1000 end
    results[id] = result
    return result
end

local function RunAll()
    local passed = 0
    for _, t in ipairs(TESTS) do if Run(t.id).passed then passed = passed + 1 end end
    return passed, #TESTS
end

---------------------------------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------------------------------

local function Register()
    MechanicLib:Register(ADDON_NAME, {
        version = GetMeta and GetMeta(ADDON_NAME, "Version"),
        getDebugBuffer = function() return log end,
        clearDebugBuffer = function() for i = #log, 1, -1 do log[i] = nil end end,
        tests = {
            getAll = function() return TESTS end,
            getCategories = function() return { "Load", "Data", "Character", "Settings", "Conjure", "UI" } end,
            run = Run,
            runAll = RunAll,
            -- Mechanic saves getResult for every test on /reload and logout: run it then, so the saved
            -- results are always this session's.
            getResult = Run,
        },
        settings = {
            debug = {
                type = "toggle", name = "Debug messages", order = 1,
                get = function() return ns.DB().debug and true or false end,
                set = function(_, v) ns.DB().debug = v end,
            },
            enabled = {
                type = "toggle", name = "Fill trades automatically", order = 2,
                get = function() return ns.DB().enabled and true or false end,
                set = function(_, v) ns.DB().enabled = v; if ns.RefreshConfig then ns.RefreshConfig() end end,
            },
        },
    })
    ns.Dbg("registered with Mechanic: %d self-tests", #TESTS)
    local passed, total = RunAll()
    ns.Journal("selftest", passed == total, passed .. "/" .. total)
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function()
    f:UnregisterAllEvents()
    Register()
end)
ns.RegisterEvents(f, { "PLAYER_LOGIN" })
ns.MechanicResults = results -- for the offline smoke test
