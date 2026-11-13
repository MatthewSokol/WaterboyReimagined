-- Test journal: a short log in WaterboyReimaginedDB.journal of things that prove release-checklist steps
-- (TESTING.md's step ids), each with the build version. tools/release-check.js reads it after the game exits, so
-- those steps are ticked without anyone's word. Harmless if it ships: capped, and it never stores names.
local ADDON_NAME, ns = ...

local MAX = 200
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or rawget(_G, "GetAddOnMetadata")
local now = rawget(_G, "time") or (os and os.time)

-- step: a TESTING.md step id; ok: whether it went right; info: counts, ranks, results (never player names).
function ns.Journal(step, ok, info)
    local db = rawget(_G, "WaterboyReimaginedDB")
    if not db then return end
    local version = GetMeta and GetMeta(ADDON_NAME, "Version") or "dev"
    db.journal = db.journal or {}
    local j = db.journal
    j[#j + 1] = { t = now and now() or 0, v = version, step = step, ok = ok and true or false, info = info }
    while #j > MAX do table.remove(j, 1) end
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, event, addon, func)
    if event == "PLAYER_LOGIN" then
        local LibStub = rawget(_G, "LibStub")
        if not (LibStub and LibStub("MechanicLib-1.0", true)) then
            ns.Journal("install-no-mechanic", true, "logged in without Mechanic")
        end
    elseif addon == ADDON_NAME then -- ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN: taint
        ns.Journal("no-taint", false, event .. " " .. tostring(func))
    end
end)
ns.RegisterEvents(f, { "PLAYER_LOGIN", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" })
