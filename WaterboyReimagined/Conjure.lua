-- Waterboy Reimagined: conjure loadouts and the conjure macro.
--
-- A loadout says how many STACKS of water and food to keep in your bags:
--   solo, party, raid  - picked by your current group
--   counts             - stacks of the highest / 2nd highest water and food you know
--   makeup (party/raid) - also add up the trade setting of everyone in the group (by class, or their player
--                        override), so a party of 2 priests + a warrior gets their water/food on top of counts
-- Loadouts live in the profiles like trade settings: a mage's own loadout overrides the default's.
--
-- The macro is "/click WaterboyReimaginedConjure": a secure button. Each press restacks partial stacks, then
-- casts ONE conjure for the first item you're short of (water before food, highest rank first). When
-- nothing is missing it does nothing and says the loadout is complete. One press = one cast (hardware event).

local ADDON_NAME, ns = ...

local GROUPS = { "solo", "party", "raid" }
local SLOTS = { "water1", "water2", "food1", "food2" }
local DEFAULT_LOADOUTS = {
    solo  = { makeup = false, counts = { water1 = 2, food1 = 1 } },
    party = { makeup = true,  counts = { water1 = 2, food1 = 1 } },
    raid  = { makeup = false, counts = { water1 = 8, water2 = 4, food1 = 2 } },
}
local MACRO_NAME = "Waterboy"
local BUTTON_NAME = "WaterboyReimaginedConjure"
-- Two lines so it works with "cast on key down" on or off: the button only acts on the one that matches.
local MACRO_BODY = "/click " .. BUTTON_NAME .. " LeftButton 1\n/click " .. BUTTON_NAME
-- The macro's icon, picked on the Loadouts tab (saved account-wide, like the macro): one of the addon's own images,
-- or "spell", the question mark, which lets #showtooltip show the next conjure's own icon. Either way #showtooltip
-- drives the tooltip and the fading (out of mana, say). If the game can't give an image an icon ID, it falls back
-- to the question mark.
local ICON_DIR = "Interface\\AddOns\\WaterboyReimagined\\"
local MACRO_ICONS = {
    { key = "drop", file = "Icon", label = "Glowing drop" },
    { key = "cooler", file = "IconCooler", label = "Arcane water cooler" },
    { key = "buckets", file = "IconBuckets", label = "Water buckets" },
    { key = "spell", label = "Next conjure", tip = "Shows the spell the next press casts, water or food." },
}
local QUESTION_MARK, QUESTION_MARK_ID = "INV_Misc_QuestionMark", 134400
ns.MACRO_ICONS = MACRO_ICONS

local function IconChoice()
    local key = ns.DB() and ns.DB().macroIcon
    for _, opt in ipairs(MACRO_ICONS) do if opt.key == key then return opt end end
    return MACRO_ICONS[1]
end
function ns.MacroIconChoice() return IconChoice().key end
function ns.MacroIconTexture(opt) return opt.file and (ICON_DIR .. opt.file) or ("Interface\\Icons\\" .. QUESTION_MARK) end

-- What to pass to CreateMacro/EditMacro, and the ID GetMacroInfo reports for it.
local function MacroIcon()
    local opt = IconChoice()
    if opt.file and GetFileIDFromPath then
        local id = GetFileIDFromPath(ICON_DIR .. opt.file .. ".tga") or GetFileIDFromPath(ICON_DIR .. opt.file)
        if id then return id, id end
    end
    return QUESTION_MARK, QUESTION_MARK_ID
end

ns.LOADOUT_GROUPS, ns.LOADOUT_SLOTS = GROUPS, SLOTS

local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local ItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount
local function GetSpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return (GetSpellInfo(id))
end

local function CopyLoadout(lo)
    local counts = {}
    for k, v in pairs(lo.counts) do counts[k] = v end
    return { makeup = lo.makeup, counts = counts }
end
ns.CopyLoadout = CopyLoadout

function ns.DefaultLoadout(group) return CopyLoadout(DEFAULT_LOADOUTS[group]) end

-- called from InitDB
function ns.InitLoadouts(db)
    for _, p in pairs(db.profiles) do p.loadouts = p.loadouts or {} end
    local def = db.profiles.default.loadouts
    for _, g in ipairs(GROUPS) do
        if not def[g] then def[g] = ns.DefaultLoadout(g) end
    end
end

-- Loadout for `group` on profile `key` ("default", a character key, or nil = this character).
-- Returns loadout, inherited (true when it comes from the default profile).
function ns.Loadout(group, key)
    if key ~= "default" then
        local p = ns.Profile(key or "me")
        if p and p.loadouts and p.loadouts[group] then return p.loadouts[group], false end
        return ns.Profile("default").loadouts[group], true
    end
    return ns.Profile("default").loadouts[group], false
end

local function GroupType()
    if IsInRaid() then return "raid" end
    if IsInGroup() then return "party" end
    return "solo"
end

local stackSizes = {}
local function StackSize(id)
    if not stackSizes[id] then
        local size = select(8, GetItemInfoFn(id))
        if not size then return 20 end
        stackSizes[id] = size
    end
    return stackSizes[id]
end

-- What to keep in the bags right now: { [itemID] = items }, group, number of group members counted
local function Targets()
    local group = GroupType()
    local lo = ns.Loadout(group)
    local stacks = {}
    local function add(slot, n) stacks[slot] = (stacks[slot] or 0) + n end
    for slot, n in pairs(lo.counts) do
        if n > 0 then add(slot, n) end
    end
    local members = 0
    if lo.makeup and group ~= "solo" then
        local prefix = group == "raid" and "raid" or "party"
        local count = group == "raid" and GetNumGroupMembers() or GetNumSubgroupMembers()
        for i = 1, count do
            local u = prefix .. i
            if UnitExists(u) and not UnitIsUnit(u, "player") then
                local name = ns.UnitFullName(u)
                local _, class = UnitClass(u)
                if name and class then
                    for _, slot in ipairs(ns.Want(name, class).slots) do add(slot, 1) end
                    members = members + 1
                end
            end
        end
    end
    local need = {}
    for slot, n in pairs(stacks) do
        local id = ns.Resolve(slot)
        need[id] = (need[id] or 0) + n * StackSize(id)
    end
    return need, group, members
end

-- First item we're short of: water before food, highest rank first. Returns itemID, have, need.
-- Does this mage know the spell for item `id`? (A level 1 mage knows neither conjure yet.)
local function Learned(id)
    local item = ns.ITEMS[id]
    local top = item and ns.TopRank(item.kind)
    return top ~= nil and item.rank <= top
end

local function NextConjure(need)
    local best
    for id, n in pairs(need) do
        local have = ItemCount(id)
        if have < n and Learned(id) then
            local item = ns.ITEMS[id]
            local score = (item.kind == "water" and 100 or 0) + item.rank
            if not best or score > best.score then best = { id = id, have = have, need = n, score = score } end
        end
    end
    if best then return best.id, best.have, best.need end
end

local function SpellFor(id)
    local item = ns.ITEMS[id]
    local spellID = ns.SPELLS[item.kind][item.rank]
    local name = GetSpellName(spellID)
    if not name then return end
    -- Always name the rank: a bare spell name casts the highest rank you know. The rank text can be
    -- missing before the client has loaded the spell's data, so fall back to building "Rank N" ourselves.
    local rank = (C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID))
        or (GetSpellSubtext and GetSpellSubtext(spellID))
    if not rank or rank == "" then rank = (RANK or "Rank") .. " " .. item.rank end
    return name .. "(" .. rank .. ")"
end

-- Merge one pair of partial stacks per item. Returns how many merges were started.
local function Restack()
    local partial, merged = {}, 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and ns.ITEMS[id] and not info.isLocked and info.stackCount < StackSize(id) then
                local p = partial[id]
                if p then
                    C_Container.PickupContainerItem(bag, slot)
                    C_Container.PickupContainerItem(p.bag, p.slot)
                    if CursorHasItem() then ClearCursor() end
                    partial[id] = nil
                    merged = merged + 1
                else
                    partial[id] = { bag = bag, slot = slot }
                end
            end
        end
    end
    return merged
end

---------------------------------------------------------------------------------------------------
-- Secure button (/click WaterboyReimaginedConjure)
---------------------------------------------------------------------------------------------------

local btn = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
btn:RegisterForClicks("AnyUp", "AnyDown")

-- Extra rounds (Temporary in the "keep making more?" prompt): keep conjuring past the loadout in the same
-- ratio. The target is loadout x (1 + rounds); when a press finds it met, the next round starts. Ends once
-- the mage goes a minute without conjuring, so the allowance to make too much doesn't linger.
local EXTRA_IDLE = 60
local extra -- nil, or { rounds = n, last = GetTime() of the last conjure }
local RefreshExtraTimer -- the on-screen countdown (below); set once it's built

local function SetExtra(v)
    extra = v
    if RefreshExtraTimer then RefreshExtraTimer() end
end

-- Seconds left before extra mode ends without another conjure.
local function ExtraLeft()
    return extra and math.max(0, EXTRA_IDLE - (GetTime() - extra.last)) or 0
end

local function EndExtraIfIdle(quiet)
    if extra and GetTime() - extra.last > EXTRA_IDLE then
        SetExtra(nil)
        if not quiet then ns.Print("Stopped making extra: no conjures for a minute. Back to your loadout.") end
    end
end

local function WatchExtraIdle()
    C_Timer.After(EXTRA_IDLE + 1, function() EndExtraIfIdle() end)
end

-- What to keep right now, scaled for extra rounds. With `advance`, a finished extra round starts the next.
-- Returns need, group, members, rounds (0 = no extra).
local function CurrentNeed(advance)
    local need, group, members = Targets()
    if not extra then return need, group, members, 0 end
    local function scaled()
        local t = {}
        for id, n in pairs(need) do t[id] = n * (1 + extra.rounds) end
        return t
    end
    local s = scaled()
    if advance and next(s) and not NextConjure(s) then
        extra.rounds = extra.rounds + 1
        s = scaled()
    end
    return s, group, members, extra.rounds
end

-- Point the button at the next conjure (out of combat only). `advance`: this is a macro press.
-- Returns id, have, total, group, members, spell, rounds.
-- What the button casts right now (it can't change in combat): itemID or nil.
local armedID

-- The macro's text: a #showtooltip line for what the next press casts, then the /click lines.
local function MacroBody()
    local show
    if armedID then show = SpellFor(armedID)
    else
        local top = ns.TopRank("water") and ns.Resolve("water1")
        show = top and ("item:" .. top)
    end
    return "#showtooltip" .. (show and (" " .. show) or "") .. "\n" .. MACRO_BODY
end

-- Keep the Waterboy macro's #showtooltip on the next conjure (out of combat only; macros can't be edited in
-- combat). Deferred a frame so a macro press never edits the macro while it's running.
local function SyncMacro()
    C_Timer.After(0, function()
        if InCombatLockdown() or not ns.IsMage() then return end
        local idx = GetMacroIndexByName(MACRO_NAME)
        if not idx or idx == 0 then return end
        local _, icon, body = GetMacroInfo(idx)
        local want = MacroBody()
        local wantIcon, wantID = MacroIcon()
        -- the game reports icons as IDs, so compare the ID (the question mark is passed by name)
        if body ~= want or icon ~= wantID then EditMacro(idx, MACRO_NAME, wantIcon, want) end
    end)
end

-- Pick the macro's icon (a key from MACRO_ICONS). Applied now, or when combat ends.
function ns.SetMacroIcon(key)
    if not ns.DB() then return end
    ns.DB().macroIcon = key
    SyncMacro()
    local msg = "Macro icon: " .. IconChoice().label .. "."
    if InCombatLockdown() then msg = msg .. " It changes when combat ends." end
    if GetMacroIndexByName(MACRO_NAME) == 0 then msg = msg .. " Use Put macro on cursor to make the macro." end
    ns.Print(msg)
end

local function Update(advance)
    if InCombatLockdown() then return end
    if not ns.IsMage() then btn:SetAttribute("type", nil); armedID = nil; return end
    EndExtraIfIdle(not advance)
    local need, group, members, rounds = CurrentNeed(advance)
    local id, have, total = NextConjure(need)
    local spell = id and SpellFor(id)
    if spell then
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", spell)
    else
        btn:SetAttribute("type", nil)
    end
    armedID = spell and id or nil
    SyncMacro()
    return id, have, total, group, members, spell, rounds
end

-- "Update loadout": open the Loadouts tab on this character's profile, so the change is made there by hand.
local function EditLoadout(group)
    if ns.OpenLoadouts then ns.OpenLoadouts(ns.CharKey()) end
    ns.Print("Edit your " .. group .. " row on the Loadouts tab. That's a permanent change for this character; "
        .. "Use default undoes it.")
end

local prompt
local function ShowMorePrompt(group)
    if not prompt then
        prompt = CreateFrame("Frame", "WaterboyReimaginedMorePrompt", UIParent, "BasicFrameTemplateWithInset")
        prompt:SetSize(380, 132)
        prompt:SetPoint("CENTER", 0, 180)
        prompt:SetFrameStrata("DIALOG")
        prompt:EnableMouse(true)
        prompt:SetMovable(true)
        prompt:RegisterForDrag("LeftButton")
        prompt:SetScript("OnDragStart", prompt.StartMoving)
        prompt:SetScript("OnDragStop", prompt.StopMovingOrSizing)
        tinsert(UISpecialFrames, "WaterboyReimaginedMorePrompt") -- Esc = Cancel
        local title = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
        title:SetText("Waterboy Reimagined")
        prompt.text = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        prompt.text:SetPoint("TOPLEFT", 18, -36)
        prompt.text:SetWidth(344)
        prompt.text:SetJustifyH("LEFT")
        local function Button(label, x, onClick, tipTitle, tip)
            local b = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
            b:SetSize(112, 22)
            b:SetPoint("BOTTOM", x, 14)
            b:SetText(label)
            b:SetScript("OnClick", function() prompt:Hide(); onClick(prompt.group); Update() end)
            if tip then
                b:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(tipTitle)
                    GameTooltip:AddLine(tip, 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                b:SetScript("OnLeave", GameTooltip_Hide)
            end
            return b
        end
        prompt.cancel = Button("Cancel", -120, function() end)
        prompt.temp = Button("Temporary", 0, function()
            SetExtra({ rounds = 1, last = GetTime() })
            WatchExtraIdle()
            ns.Print("Making extra in the same ratio until you go a minute without conjuring. Press the macro to go on.")
        end, "Temporary", "Keep pressing the macro to make more rounds in the same ratio. Stops once you go a "
            .. "minute without conjuring.")
        prompt.raise = Button("Update loadout", 120, EditLoadout, "Update loadout",
            "Opens the Loadouts tab on this character's profile. What you change there is permanent "
            .. "(Use default undoes it).")
    end
    prompt.group = group
    prompt.text:SetText(string.format("Your %s loadout is complete. Do you want to keep making stuff in the "
        .. "same ratio? (Update loadout is a permanent change.)", group))
    prompt:Show()
end

-- The conjure we just asked for: { id, spellID, at, succeeded }. The progress line waits for the cast to
-- finish and the items to land in the bags.
local pending

local function Casting()
    return UnitCastingInfo and UnitCastingInfo("player") ~= nil
end

-- "water (rank 7)"
local function Describe(id)
    local item = ns.ITEMS[id]
    return string.format("%s (rank %d)", item.kind, item.rank)
end

-- `final`: the fallback timer, so a cast that added nothing gets reported; a bag update that comes before
-- the conjured items (some other bag change) waits for a later one.
local function ReportConjured(final)
    local p = pending
    if not p or p.reported then return end
    p.reported = true
    pending = nil
    local gained = p.before and (ItemCount(p.id) - p.before)
    if gained and gained > 0 and ns.DB() then
        ns.DB().yields = ns.DB().yields or {}
        ns.DB().yields[p.id] = math.max(ns.DB().yields[p.id] or 0, gained) -- a full bag can cut one short
    end
    if p.before and ItemCount(p.id) <= p.before then
        if not final then p.reported = nil; pending = p; return end
        ns.Print("The " .. Describe(p.id) .. " conjure didn't add anything: are your bags full?")
        return
    end
    local need, group, _, rounds = CurrentNeed(false)
    local item = ns.ITEMS[p.id]
    local size = StackSize(p.id)
    local msg = string.format("Conjured %s (rank %d): %d / %d stacks", item.kind, item.rank,
        math.floor(ItemCount(p.id) / size), math.ceil((need[p.id] or 0) / size))
    if rounds > 0 then msg = msg .. " (extra round " .. rounds .. ")" end
    if not NextConjure(need) then
        if rounds > 0 then msg = msg .. ". Extra round " .. rounds .. " done: press again for another."
        else msg = msg .. ". Loadout complete (" .. group .. ")." end
    end
    ns.Print(msg)
end

-- Presses that found nothing to conjure; the 3rd in a row asks whether to keep going.
local completePresses, lastCompletePress = 0, 0

local lastClick = 0

-- How many items one conjure of `id` makes: from the spell's text ("Conjures 4 bottles of water..."), else
-- as seen last time (saved per item), else nil.
local function Yield(id)
    local item = ns.ITEMS[id]
    local spellID = item and ns.SPELLS[item.kind][item.rank]
    local describe = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    local text = spellID and describe and describe(spellID)
    local n = text and tonumber(text:match("(%d+)"))
    if n and n > 0 then return n end
    local y = ns.DB() and ns.DB().yields
    return y and y[id]
end

-- Is there somewhere for a conjure of `id` to go: a free slot in a normal bag (not a quiver or soul bag), or
-- a part-filled stack of it with room for the whole conjure? If we can't tell how many one conjure makes, any
-- part stack counts (the game decides). Returns ok, room left in the part stack.
local function HasRoom(id)
    local free = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
    if not free then return true end -- can't tell: let the game decide
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local n, family = free(bag)
        if n and n > 0 and (family == nil or family == 0) then return true end
    end
    local size = StackSize(id)
    local partial = ItemCount(id) % size
    if partial == 0 then return false, 0 end
    local room = size - partial
    local y = Yield(id)
    ns.Dbg("room check %s: %d of %d in the part stack, room %d, one conjure makes %s", Describe(id), partial, size,
        room, tostring(y))
    return y == nil or room >= y, room
end

btn:SetScript("PreClick", function()
    local now = GetTime()
    if now == lastClick then return end -- the macro's 2nd /click line in the same press
    lastClick = now
    if InCombatLockdown() then
        -- the button can't be re-aimed in combat: it repeats whatever it was set to when combat started
        if armedID then
            ns.Print("In combat: casting " .. Describe(armedID) .. " again. The loadout isn't rechecked until "
                .. "combat ends, so every press repeats this cast.")
        else
            ns.Print("In combat: nothing to cast. The loadout isn't rechecked until combat ends.")
        end
        return
    end
    if not ns.IsMage() then ns.Print("Conjuring only works on a mage."); return end
    if Casting() then return end -- pressed again mid-cast: the game refuses it, say nothing
    if not ns.TopRank("water") and not ns.TopRank("food") then
        ns.Print("You haven't learned Conjure Water or Conjure Food yet.")
        return
    end
    local merged = Restack()
    local id, _, _, group, _, _, rounds = Update(true)
    local roomOK, room = true, 0
    if id then roomOK, room = HasRoom(id) end
    if id and not roomOK then
        btn:SetAttribute("type", nil) -- this press casts nothing; the next one re-checks
        if room and room > 0 then
            local y = Yield(id)
            ns.Print(string.format("Bags full: your %s stack only has room for %d more%s. Free a bag slot and press again.",
                Describe(id), room, y and (" and one conjure makes " .. y) or ""))
        else
            ns.Print("Bags full: no room for " .. Describe(id) .. ". Free a bag slot and press again.")
        end
    elseif id then
        completePresses = 0
        local item = ns.ITEMS[id]
        pending = { id = id, spellID = ns.SPELLS[item.kind][item.rank], at = now, before = ItemCount(id) }
        ns.Print(string.format("Casting %s (rank %d)...%s", item.kind, item.rank, rounds > 0 and " (extra)" or ""))
    elseif merged > 0 then
        ns.Print("Restacking...")
    else
        if now - lastCompletePress > 30 then completePresses = 0 end
        lastCompletePress = now
        completePresses = completePresses + 1
        if not next((Targets())) then
            completePresses = 0
            ns.Print("Loadout complete (" .. group .. ").") -- an empty loadout: nothing to make more of
        elseif completePresses >= 3 then
            completePresses = 0
            ShowMorePrompt(group)
        else
            ns.Print(string.format("Loadout complete (%s). Keep pressing to override %d/3", group, completePresses))
        end
    end
end)

---------------------------------------------------------------------------------------------------
-- Macro, status
---------------------------------------------------------------------------------------------------

function ns.MakeMacro()
    if InCombatLockdown() then ns.Print("Can't make macros in combat."); return end
    local idx = GetMacroIndexByName(MACRO_NAME)
    if idx == 0 then
        if GetNumMacros() >= (MAX_ACCOUNT_MACROS or 120) then
            ns.Print("No free account macro slots.")
            return
        end
        idx = CreateMacro(MACRO_NAME, (MacroIcon()), MacroBody(), nil)
    else
        EditMacro(idx, MACRO_NAME, (MacroIcon()), MacroBody())
    end
    PickupMacro(idx)
    ns.Print("The \"" .. MACRO_NAME .. "\" macro is on your cursor: drop it on an action bar. "
        .. "It's also under Esc > Macros (General).")
end

function ns.MacroText() return MACRO_BODY end -- the copyable part; the made macro adds #showtooltip

-- Lines describing what the macro aims for right now (for /wbr loadout and the config window).
function ns.LoadoutStatus()
    local need, group, members, rounds = CurrentNeed(false)
    local lines = { "Now: " .. group .. (members > 0 and (" (" .. members .. " players' trade settings added)") or "") }
    if rounds > 0 then
        lines[#lines + 1] = string.format("|cff69ccf0Making extra: round %d, ends in %ds without a conjure|r",
            rounds, math.ceil(ExtraLeft()))
    end
    local ids = {}
    for id in pairs(need) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b)
        local x, y = ns.ITEMS[a], ns.ITEMS[b]
        if x.kind ~= y.kind then return x.kind == "water" end
        return x.rank > y.rank
    end)
    for _, id in ipairs(ids) do
        local size = StackSize(id)
        local have = ItemCount(id)
        local color = have >= need[id] and "|cff40ff40" or "|cffffd040"
        lines[#lines + 1] = string.format("%s%s: %d / %d stacks|r", color, ns.NAMES[id],
            math.floor(have / size), math.ceil(need[id] / size))
    end
    if #ids == 0 then lines[#lines + 1] = "nothing to conjure" end
    return lines
end

-- Hovering the Waterboy macro on an action bar: add the loadout state under the spell's tooltip.
local function AddMacroTooltip(tooltip, slot)
    if not ns.IsMage() or not GetActionText or GetActionText(slot) ~= MACRO_NAME then return end
    tooltip:AddLine(" ")
    tooltip:AddLine("Waterboy Reimagined", 0.41, 0.8, 0.94)
    if armedID then
        tooltip:AddLine("Next press: " .. Describe(armedID), 1, 1, 1)
    else
        tooltip:AddLine("Next press: nothing, loadout complete", 1, 1, 1)
    end
    if InCombatLockdown() then
        tooltip:AddLine("In combat: every press repeats this until combat ends.", 1, 0.5, 0.25, true)
    end
    for _, line in ipairs(ns.LoadoutStatus()) do tooltip:AddLine(line, 0.85, 0.85, 0.85) end
    tooltip:Show()
end
if hooksecurefunc and GameTooltip and GameTooltip.SetAction then
    hooksecurefunc(GameTooltip, "SetAction", AddMacroTooltip)
end

function ns.PrintLoadout()
    for i, line in ipairs(ns.LoadoutStatus()) do
        if i == 1 then ns.Print(line) else print("   " .. line) end
    end
end

-- After a macro press: the cast finishing (or being interrupted), then the conjured items arriving.
-- UNIT_SPELLCAST_* args on Forever: unit, castGUID, spellID. A cast that never starts (moving, no mana, the
-- macro's 2nd /click line) only gets the game's own error; its pending entry expires.
local castFrame = CreateFrame("Frame")
ns.RegisterEvents(castFrame, { "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "BAG_UPDATE_DELAYED" })
castFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
    local p = pending
    if not p then return end
    if GetTime() - p.at > 30 then pending = nil; return end -- the cast never started
    if event == "BAG_UPDATE_DELAYED" then
        if p.succeeded then ReportConjured() end
        return
    end
    if unit ~= "player" or (spellID and spellID ~= p.spellID) then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        p.succeeded = true
        if extra then extra.last = GetTime(); WatchExtraIdle(); RefreshExtraTimer() end
        -- in case the bags updated before this event; only for this cast, not a newer press
        C_Timer.After(2, function() if pending == p then ReportConjured(true) end end)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        pending = nil
        ns.Print("Conjure interrupted.")
    end
end)

---------------------------------------------------------------------------------------------------
-- Extra-mode countdown: a small bar on screen while Temporary is on. It refills on every conjure and
-- runs out after a minute without one. Drag to move (saved); right-click to stop early.
---------------------------------------------------------------------------------------------------

local timer = CreateFrame("Frame", "WaterboyReimaginedExtraTimer", UIParent)
timer:SetSize(200, 30)
timer:SetFrameStrata("MEDIUM")
timer:SetClampedToScreen(true)
timer:EnableMouse(true)
timer:SetMovable(true)
timer:RegisterForDrag("LeftButton")
timer:Hide()
local tbg = timer:CreateTexture(nil, "BACKGROUND")
tbg:SetAllPoints()
tbg:SetColorTexture(0, 0, 0, 0.6)
timer.label = timer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
timer.label:SetPoint("TOPLEFT", 6, -3)
timer.label:SetPoint("TOPRIGHT", -6, -3)
timer.label:SetJustifyH("LEFT")
timer.bar = CreateFrame("StatusBar", nil, timer)
timer.bar:SetPoint("BOTTOMLEFT", 4, 4)
timer.bar:SetPoint("BOTTOMRIGHT", -4, 4)
timer.bar:SetHeight(8)
timer.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
timer.bar:SetStatusBarColor(0.25, 0.6, 1)
timer.bar:SetMinMaxValues(0, EXTRA_IDLE)

local function PlaceTimer()
    local pos = ns.DB() and ns.DB().extraTimerPos
    timer:ClearAllPoints()
    if pos then timer:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3])
    else timer:SetPoint("CENTER", UIParent, "CENTER", 0, -160) end
end

timer:SetScript("OnDragStart", timer.StartMoving)
timer:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    if point and ns.DB() then ns.DB().extraTimerPos = { point, x, y } end
end)
timer:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" and extra then
        SetExtra(nil)
        ns.Print("Stopped making extra. Back to your loadout.")
        Update()
    end
end)
timer:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Making extra")
    GameTooltip:AddLine("Each conjure refills the timer. When it runs out, the macro goes back to your loadout.",
        1, 1, 1, true)
    GameTooltip:AddLine("Drag to move. Right-click to stop now.", 0.6, 0.8, 1)
    GameTooltip:Show()
end)
timer:SetScript("OnLeave", GameTooltip_Hide)

local sinceTick = 0
local function Tick()
    if not extra then timer:Hide(); return end
    local left = ExtraLeft()
    timer.bar:SetValue(left)
    local s = math.ceil(left)
    timer.label:SetText(string.format("Making extra (round %d): %d:%02d", extra.rounds, math.floor(s / 60), s % 60))
    if left <= 0 then EndExtraIfIdle(); Update() end
end
timer:SetScript("OnUpdate", function(_, elapsed)
    sinceTick = sinceTick + elapsed
    if sinceTick < 0.2 then return end
    sinceTick = 0
    Tick()
end)

RefreshExtraTimer = function()
    if extra then
        if not timer:IsShown() then PlaceTimer(); timer:Show() end
        Tick()
    else
        timer:Hide()
    end
end

---------------------------------------------------------------------------------------------------
-- Manual conjure buttons: highest and 2nd highest water and food, beside the config window on a mage.
-- Each is a secure spell button: one click = one cast. The panel is its own frame (not a child of the
-- config window) so opening and closing the config never gets blocked in combat; in combat it keeps its
-- spells and position, and shows or hides once combat ends.
---------------------------------------------------------------------------------------------------

local MANUAL = {
    { slot = "water1", label = "Water" }, { slot = "water2", label = "Water -1" },
    { slot = "food1", label = "Food" }, { slot = "food2", label = "Food -1" },
}
local manual = CreateFrame("Frame", "WaterboyReimaginedManualConjure", UIParent)
manual:SetSize(132, 34 + #MANUAL * 42)
manual:SetFrameStrata("DIALOG")
manual:Hide()
local mbg = manual:CreateTexture(nil, "BACKGROUND")
mbg:SetAllPoints()
mbg:SetColorTexture(0.05, 0.05, 0.07, 0.92)
local mtitle = manual:CreateFontString(nil, "OVERLAY", "GameFontNormal")
mtitle:SetPoint("TOP", 0, -8)
mtitle:SetText("Conjure now")
manual.buttons = {}
for i, m in ipairs(MANUAL) do
    local b = CreateFrame("Button", "WaterboyReimaginedManual" .. i, manual, "SecureActionButtonTemplate")
    b:SetSize(36, 36)
    b:SetPoint("TOPLEFT", 10, -28 - (i - 1) * 42)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    b.label = manual:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("LEFT", b, "RIGHT", 8, 0)
    b.label:SetJustifyH("LEFT")
    b.slot, b.name = m.slot, m.label
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local item = self.id and ns.ITEMS[self.id]
        if item then
            GameTooltip:SetText(string.format("Conjure %s (rank %d)", ns.NAMES[self.id], item.rank))
            local have = ItemCount(self.id)
            GameTooltip:AddLine(string.format("In your bags: %d (%d stacks)", have,
                math.floor(have / StackSize(self.id))), 1, 1, 1)
            GameTooltip:AddLine("Click to cast once. Ignores loadout limits.", 0.6, 0.8, 1, true)
        else
            GameTooltip:SetText(self.name)
            GameTooltip:AddLine("You don't know this rank yet.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    manual.buttons[i] = b
end

local function RefreshManual()
    for _, b in ipairs(manual.buttons) do
        local id = ns.Resolve(b.slot)
        local item = ns.ITEMS[id]
        -- "Water -1" needs a rank below the top one; with only rank 1 (or none) there isn't one
        local kind, n = ns.ParseRelative(b.slot)
        local top = ns.TopRank(kind)
        local learned = top ~= nil and top - n + 1 >= 1
        b.id = learned and id or nil
        b.icon:SetTexture(ns.SlotIcon and ns.SlotIcon(b.slot) or nil)
        b.icon:SetDesaturated(not learned)
        b.icon:SetAlpha(learned and 1 or 0.4)
        b.count:SetText(learned and tostring(ItemCount(id)) or "")
        b.label:SetText(b.name .. "\n|cff888888" .. (learned and ("rank " .. item.rank) or "not learned") .. "|r")
        if not InCombatLockdown() then
            local spell = learned and SpellFor(id) or nil
            b:SetAttribute("type", spell and "spell" or nil)
            b:SetAttribute("spell", spell)
            ns.Dbg("%s casts %s", b.name, tostring(spell))
        end
    end
end

local manualWanted, manualAnchor = false, nil
-- Show (beside `manualAnchor`) or hide the panel; out of combat only, otherwise when combat ends.
local function ApplyManual()
    if InCombatLockdown() then return end
    if manualWanted and ns.IsMage() and manualAnchor then
        local right, top = manualAnchor:GetRight(), manualAnchor:GetTop()
        manual:ClearAllPoints()
        if right and top then manual:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right + 2, top)
        else manual:SetPoint("CENTER", UIParent, "CENTER", 360, 0) end
        RefreshManual()
        manual:Show()
    else
        manual:Hide()
    end
end

function ns.ShowManualConjure(anchor) manualWanted, manualAnchor = true, anchor; ApplyManual() end
function ns.HideManualConjure() manualWanted = false; ApplyManual() end
function ns.PlaceManualConjure() ApplyManual() end -- the config window moved

local mf = CreateFrame("Frame")
ns.RegisterEvents(mf, { "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED" })
mf:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then ApplyManual()
    elseif manual:IsShown() then RefreshManual() end
end)

local f = CreateFrame("Frame")
ns.RegisterEvents(f, { "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" })
f:SetScript("OnEvent", function()
    Update()
    if ns.RefreshConfig then ns.RefreshConfig() end
end)
