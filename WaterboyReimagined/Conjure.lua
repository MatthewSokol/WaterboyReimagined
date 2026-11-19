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
-- casts ONE conjure for the next item you're short of, picked by the loadout's order (below). When nothing is
-- missing it does nothing and says the loadout is complete. One press = one cast (hardware event).
--
-- Order (per loadout row, default "ratio"):
--   ratio     - whatever keeps the bags closest to the loadout's mix: the item with the lowest share of its
--               target (items in the bags / items wanted). Counted in items, not casts, since a conjure makes
--               more as the mage levels.
--   category  - all the water, then all the food (highest rank first). The original behaviour.
--   character - party and raid with "+ group's trades": your own stacks first, then each healer's, then each
--               tank's, then everyone else's. Roles are guessed (see GuessRole).

local ADDON_NAME, ns = ...

local GROUPS = { "solo", "party", "raid" }
local SLOTS = { "water1", "water2", "food1", "food2", "gem1", "gem2" }
-- Mana gems ("gem1" = the highest gem you can conjure, "gem2" = one rank down) are 0 or 1: a mage can only carry
-- one of each. Every loadout keeps your top gem by default.
local DEFAULT_LOADOUTS = {
    solo  = { makeup = false, order = "ratio", counts = { water1 = 2, food1 = 1, gem1 = 1 } },
    party = { makeup = true,  order = "ratio", counts = { water1 = 2, food1 = 1, gem1 = 1 } },
    raid  = { makeup = false, order = "ratio", counts = { water1 = 8, water2 = 4, food1 = 2, gem1 = 1 } },
}
-- Where mana gems go in the macro's order (per profile, default "first"). They stay out of the ratio: you can
-- only hold one of each, so there's no mix to keep, and each is a single cast.
--   first - before any water or food: one or two quick casts, and a gem in your bags can refill your mana
--           during a long conjuring session
--   last  - once the water and food are done
local GEM_ORDERS = { "first", "last" }
local GEM_ORDER_NAMES = { first = "Before water and food", last = "After water and food" }
ns.GEM_ORDERS, ns.GEM_ORDER_NAMES = GEM_ORDERS, GEM_ORDER_NAMES

-- The gem order for profile `key` ("default", a character key, or nil = this character), and whether it's
-- inherited from the default profile.
function ns.GemOrder(key)
    if key ~= "default" then
        local p = ns.Profile(key or "me")
        if p and p.gemOrder then return p.gemOrder, false end
    end
    return ns.Profile("default").gemOrder or "first", key ~= "default"
end
-- Orders each loadout row offers, the first being the default.
local ORDERS = {
    solo = { "ratio", "category" },
    party = { "ratio", "category", "character" },
    raid = { "ratio", "category", "character" },
}
local ORDER_NAMES = { ratio = "By ratio", category = "By category", character = "By character" }
ns.LOADOUT_ORDERS, ns.ORDER_NAMES = ORDERS, ORDER_NAMES

-- The order a loadout row uses: its own if this group offers it, else the default (ratio).
function ns.LoadoutOrder(lo, group)
    for _, o in ipairs(ORDERS[group] or ORDERS.solo) do if lo and lo.order == o then return o end end
    return "ratio"
end
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
    return { makeup = lo.makeup, order = lo.order, counts = counts }
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
    -- Loadouts saved before mana gems existed keep your top gem from now on (a 0 you set stays 0).
    for _, p in pairs(db.profiles) do
        for _, lo in pairs(p.loadouts) do
            if type(lo) == "table" and type(lo.counts) == "table" and lo.counts.gem1 == nil then lo.counts.gem1 = 1 end
        end
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
    if ns.ITEMS[id] and ns.ITEMS[id].kind == "gem" then return 1 end -- one of each gem, never stacked
    if not stackSizes[id] then
        local size = select(8, GetItemInfoFn(id))
        if not size then return 20 end
        stackSizes[id] = size
    end
    return stackSizes[id]
end

-- A group member's role, for the "by character" order: "HEALER", "TANK" or "DAMAGER". Forever's group tools
-- rarely set one, so after any role the game knows (the role picker, a raid's main tank) it guesses by class:
-- bear-form druids tank, warriors tank in a party (in a raid only the assigned main tanks count, since most
-- raid warriors deal damage), and priests, other druids, paladins and shamans heal.
local function GuessRole(unit, inRaid)
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if role == "HEALER" or role == "TANK" then return role end
    if GetPartyAssignment and (GetPartyAssignment("MAINTANK", unit) or GetPartyAssignment("MAINTANK", unit, true)) then
        return "TANK"
    end
    local _, class = UnitClass(unit)
    if class == "WARRIOR" then return inRaid and "DAMAGER" or "TANK" end
    if class == "DRUID" then
        if UnitPowerType and UnitPowerType(unit) == 1 then return "TANK" end -- rage: bear form
        return "HEALER"
    end
    if class == "PRIEST" or class == "PALADIN" or class == "SHAMAN" then return "HEALER" end
    return "DAMAGER"
end
ns.GuessRole = GuessRole
local ROLE_ORDER = { HEALER = 1, TANK = 2, DAMAGER = 3 }

-- Stacks per slot -> items per itemID, added into `need`.
local function AddItems(need, slot, stacks)
    local id = ns.Resolve(slot)
    need[id] = (need[id] or 0) + stacks * StackSize(id)
end

-- What to keep in the bags right now: { [itemID] = items }, group, number of group members counted, and the
-- shares behind it (your own first, then each member's, healers before tanks before the rest) for the
-- "by character" order.
local function Targets()
    local group = GroupType()
    local lo = ns.Loadout(group)
    local need, own = {}, {}
    for slot, n in pairs(lo.counts) do
        if slot:sub(1, 3) == "gem" then n = math.min(n, 1) end -- one of each gem at most
        if n > 0 then AddItems(need, slot, n); AddItems(own, slot, n) end
    end
    local shares, members = { { role = "SELF", need = own } }, {}
    if lo.makeup and group ~= "solo" then
        local prefix = group == "raid" and "raid" or "party"
        local count = group == "raid" and GetNumGroupMembers() or GetNumSubgroupMembers()
        for i = 1, count do
            local u = prefix .. i
            if UnitExists(u) and not UnitIsUnit(u, "player") then
                local name = ns.UnitFullName(u)
                local _, class = UnitClass(u)
                if name and class then
                    local share = { role = GuessRole(u, group == "raid"), index = i, need = {} }
                    for _, slot in ipairs(ns.Want(name, class).slots) do
                        AddItems(need, slot, 1); AddItems(share.need, slot, 1)
                    end
                    members[#members + 1] = share
                end
            end
        end
        table.sort(members, function(a, b)
            if a.role ~= b.role then return ROLE_ORDER[a.role] < ROLE_ORDER[b.role] end
            return a.index < b.index
        end)
        for _, s in ipairs(members) do shares[#shares + 1] = s end
    end
    return need, group, #members, shares, ns.LoadoutOrder(lo, group), ns.GemOrder()
end

local function IsGem(id) return ns.ITEMS[id] and ns.ITEMS[id].kind == "gem" end

-- Conjures cast or casting whose items aren't in the bags yet, oldest first:
-- { guid, id, n = items expected, before = bag count to beat, at, succeeded, macro = from a macro press }.
-- The server adds conjured items a moment after the cast ends, and a press in the spell queue window comes
-- before the cast even ends; counting these keeps the next pick from repeating the last one.
local casts = {}

-- Items of `id` in the bags plus those on the way. Picks use this; messages show the bags.
local function Have(id)
    local n = ItemCount(id)
    for _, c in ipairs(casts) do if c.id == id then n = n + c.n end end
    return n
end
-- The water and food in `t`, or (with `gems`) only the gems.
local function Only(t, gems)
    local r = {}
    for id, n in pairs(t) do if (IsGem(id) and true or false) == (gems and true or false) then r[id] = n end end
    return r
end

-- First item we're short of: water before food, highest rank first. Returns itemID, have, need.
-- Does this mage know the spell for item `id`? (A level 1 mage knows neither conjure yet.)
local function Learned(id)
    local item = ns.ITEMS[id]
    local top = item and ns.TopRank(item.kind)
    return top ~= nil and item.rank <= top
end

-- Water before food, higher rank first (the "category" order, and the tie-break for the others).
local function CategoryScore(id)
    local item = ns.ITEMS[id]
    return (item.kind == "water" and 100 or 0) + item.rank
end

-- Among items short of `want` (itemID -> items), the one `better(a, b)` puts first. Returns itemID or nil.
local function Pick(want, better)
    local best
    for id, n in pairs(want) do
        if Have(id) < n and Learned(id) and (not best or better(id, best)) then best = id end
    end
    return best
end

local function ByCategory(a, b) return CategoryScore(a) > CategoryScore(b) end

-- The next water or food conjure for `ctx` by its order (gems aren't in it). Returns itemID or nil.
local function NextFood(ctx)
    local need = Only(ctx.need, false)
    if ctx.order == "category" then return Pick(need, ByCategory) end
    if ctx.order == "character" and ctx.shares then
        -- everyone's share in turn: the first share the bags don't cover yet gets the next conjure
        local cum = {}
        for _, share in ipairs(ctx.shares) do
            for i, n in pairs(Only(share.need, false)) do cum[i] = (cum[i] or 0) + n end
            local id = Pick(cum, ByCategory)
            if id then return id end
        end
        return Pick(need, ByCategory)
    end
    -- ratio: the item furthest behind its target, counted in items
    local function share(i) return Have(i) / need[i] end
    return Pick(need, function(a, b)
        local x, y = share(a), share(b)
        if x ~= y then return x < y end
        return ByCategory(a, b)
    end)
end

-- The next conjure for `ctx` = { need, shares, order, gemOrder } (from CurrentNeed). Mana gems go before or
-- after the water and food (gemOrder), highest first; the order only sorts the water and food.
-- Returns itemID, have, need.
local function NextConjure(ctx)
    local id
    local function gem() return Pick(Only(ctx.need, true), ByCategory) end
    if ctx.gemOrder ~= "last" then id = gem() end
    if not id then id = NextFood(ctx) end
    if not id and ctx.gemOrder == "last" then id = gem() end
    if id then return id, Have(id), ctx.need[id] end
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
-- Returns need, group, members, rounds (0 = no extra), ctx (for NextConjure: need, shares, order).
local function CurrentNeed(advance)
    local need, group, members, shares, order, gemOrder = Targets()
    if not extra then
        return need, group, members, 0, { need = need, shares = shares, order = order, gemOrder = gemOrder }
    end
    local function scale(t) -- extra rounds make more water and food; you still only carry one of each gem
        local s = {}
        for id, n in pairs(t) do s[id] = IsGem(id) and n or n * (1 + extra.rounds) end
        return s
    end
    local function scaled()
        local sh = {}
        for i, share in ipairs(shares) do sh[i] = { role = share.role, need = scale(share.need) } end
        return { need = scale(need), shares = sh, order = order, gemOrder = gemOrder }
    end
    local ctx = scaled()
    if advance and next(ctx.need) and not NextConjure(ctx) then
        extra.rounds = extra.rounds + 1
        ctx = scaled()
    end
    return ctx.need, group, members, extra.rounds, ctx
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
    local _, group, members, rounds, ctx = CurrentNeed(advance)
    local id, have, total = NextConjure(ctx)
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
        prompt = ns.CreateWindow("WaterboyReimaginedMorePrompt", 380, 132, "Waterboy Reimagined")
        prompt:SetPoint("CENTER", 0, 180)
        prompt:SetFrameStrata("DIALOG")
        prompt:EnableMouse(true)
        prompt:SetMovable(true)
        prompt:RegisterForDrag("LeftButton")
        prompt:SetScript("OnDragStart", prompt.StartMoving)
        prompt:SetScript("OnDragStop", prompt.StopMovingOrSizing)
        tinsert(UISpecialFrames, "WaterboyReimaginedMorePrompt") -- Esc = Cancel
        prompt.text = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        -- the question starts right of the portrait logo
        prompt.text:SetPoint("TOPLEFT", prompt.portrait and 44 or 18, -36)
        prompt.text:SetWidth(prompt.portrait and 318 or 344)
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

-- The last macro press that aimed at a conjure: { id, at }. The cast it starts (now, or queued) reports
-- its progress line when its items land.
local lastPress

local function Casting()
    return UnitCastingInfo and UnitCastingInfo("player") ~= nil
end

-- Is the current cast close enough to its end that the game queues the next press (SpellQueueWindow, in
-- ms, 400 unless changed)? Earlier presses the game refuses.
local function InQueueWindow()
    local _, _, _, _, endMS = UnitCastingInfo("player")
    if not endMS then return false end
    local window = tonumber(GetCVar and GetCVar("SpellQueueWindow")) or 400
    return endMS / 1000 - GetTime() <= window / 1000
end

-- Take `c` off the in-flight list. `landed`: its items are in, so later casts of the same item count from
-- the bags as they are now.
local function Drop(c, landed)
    for i, o in ipairs(casts) do if o == c then table.remove(casts, i); break end end
    if landed then
        for _, o in ipairs(casts) do if o.id == c.id then o.before = ItemCount(o.id) end end
    end
end

-- "water (rank 7)"
local function Describe(id)
    local item = ns.ITEMS[id]
    if item.kind == "gem" then return "a " .. ns.NAMES[id] end -- "a Mana Ruby"
    return string.format("%s (rank %d)", item.kind, item.rank)
end

-- A finished cast `p` (from `casts`): once its items are in, drop it and, for a macro press, print the
-- progress line. `final`: the fallback timer, so a cast that added nothing gets dropped and reported; a bag
-- update that comes before the conjured items (some other bag change) waits for a later one.
local function ReportConjured(p, final)
    local gained = ItemCount(p.id) - p.before
    if gained > 0 and ns.DB() then
        ns.DB().yields = ns.DB().yields or {}
        ns.DB().yields[p.id] = math.max(ns.DB().yields[p.id] or 0, gained) -- a full bag can cut one short
    end
    if gained <= 0 then
        if not final then return end
        Drop(p)
        if p.macro then ns.Print("The " .. Describe(p.id) .. " conjure didn't add anything: are your bags full?") end
        return
    end
    Drop(p, true)
    if not p.macro then return end
    local need, group, _, rounds, ctx = CurrentNeed(false)
    local item = ns.ITEMS[p.id]
    local size = StackSize(p.id)
    local msg = string.format("Conjured %s (rank %d): %d / %d stacks", item.kind, item.rank,
        math.floor(ItemCount(p.id) / size), math.ceil((need[p.id] or 0) / size))
    if item.kind == "gem" then
        msg = "Conjured " .. Describe(p.id) .. "."
        ns.Journal("conjure-gem", true, "rank " .. item.rank .. ", " .. (ctx.gemOrder or "first"))
    end
    if rounds > 0 then msg = msg .. " (extra round " .. rounds .. ")" end
    ns.Journal("conjure-cast", true, string.format("%s rank %d, %s", item.kind, item.rank, ctx.order))
    if not NextConjure(ctx) then
        if rounds > 0 then msg = msg .. ". Extra round " .. rounds .. " done: press again for another."
        else msg = msg .. ". Loadout complete (" .. group .. ")."; ns.Journal("loadout-complete", true, group) end
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
    local partial = Have(id) % size
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
    -- Pressed mid-cast: near the end the game queues the press, so aim it past the current cast (whose items
    -- count as on the way); earlier the game refuses it, so say nothing.
    local queued = Casting()
    if queued and not InQueueWindow() then return end
    if not ns.TopRank("water") and not ns.TopRank("food") then
        ns.Print("You haven't learned Conjure Water or Conjure Food yet.")
        return
    end
    local merged = queued and 0 or Restack()
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
        lastPress = { id = id, at = now }
        ns.Print(string.format("%s %s...%s", queued and "Next:" or "Casting", Describe(id),
            rounds > 0 and " (extra)" or ""))
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

-- What the next macro press would conjure right now (itemID, have, need), without pressing it. For tests.
function ns.NextConjureNow()
    local _, _, _, _, ctx = CurrentNeed(false)
    return NextConjure(ctx)
end

-- Lines describing what the macro aims for right now (for /wbr loadout and the config window).
function ns.LoadoutStatus()
    local need, group, members, rounds, ctx = CurrentNeed(false)
    local lines = { "Now: " .. group .. ", " .. ORDER_NAMES[ctx.order]:lower() .. ", gems "
        .. (ctx.gemOrder == "last" and "last" or "first")
        .. (members > 0 and (" (" .. members .. " players' trade settings added)") or "") }
    if rounds > 0 then
        lines[#lines + 1] = string.format("|cff69ccf0Making extra: round %d, ends in %ds without a conjure|r",
            rounds, math.ceil(ExtraLeft()))
    end
    local ids = {}
    for id in pairs(need) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b)
        local x, y = ns.ITEMS[a], ns.ITEMS[b]
        local rank = { water = 1, food = 2, gem = 3 }
        if x.kind ~= y.kind then return rank[x.kind] < rank[y.kind] end
        return x.rank > y.rank
    end)
    for _, id in ipairs(ids) do
        local size = StackSize(id)
        local have = ItemCount(id)
        local color = have >= need[id] and "|cff40ff40" or "|cffffd040"
        if IsGem(id) then
            lines[#lines + 1] = string.format("%s%s: %d / %d|r", color, ns.NAMES[id], math.min(have, 1), need[id])
        else
            lines[#lines + 1] = string.format("%s%s: %d / %d stacks|r", color, ns.NAMES[id],
                math.floor(have / size), math.ceil(need[id] / size))
        end
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

-- itemID a conjure spell makes, or nil.
local spellItems
local function ItemForSpell(spellID)
    if not spellItems then
        spellItems = {}
        for id, item in pairs(ns.ITEMS) do
            local s = ns.SPELLS[item.kind] and ns.SPELLS[item.kind][item.rank]
            if s then spellItems[s] = id end
        end
    end
    return spellID and spellItems[spellID]
end

local function FindCast(guid)
    for _, c in ipairs(casts) do if c.guid == guid then return c end end
end

local function InList(c)
    for _, o in ipairs(casts) do if o == c then return true end end
end

-- Every conjure (macro, Conjure now or spellbook): its items count as on the way from cast start until they
-- land, and the button re-aims past it, so a press in the spell queue window queues the right spell.
-- UNIT_SPELLCAST_* args on Forever: unit, castGUID, spellID.
local castFrame = CreateFrame("Frame")
ns.RegisterEvents(castFrame, { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED", "BAG_UPDATE_DELAYED" })
castFrame:SetScript("OnEvent", function(_, event, unit, guid, spellID)
    local now = GetTime()
    for i = #casts, 1, -1 do -- a cast that never finished
        if not casts[i].succeeded and now - casts[i].at > 30 then table.remove(casts, i) end
    end
    if event == "BAG_UPDATE_DELAYED" then
        local seen, list = {}, {}
        for i, c in ipairs(casts) do list[i] = c end -- ReportConjured takes casts off the list
        for _, c in ipairs(list) do -- oldest finished cast of each item first
            if c.succeeded and not seen[c.id] then seen[c.id] = true; ReportConjured(c) end
        end
        Update()
        return
    end
    local id = unit == "player" and ItemForSpell(spellID)
    if not id then return end
    local c = FindCast(guid)
    if not c and (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED") then
        c = { guid = guid, id = id, n = Yield(id) or 1, before = ItemCount(id), at = now,
            macro = lastPress ~= nil and lastPress.id == id and now - lastPress.at < 1.5 }
        if c.macro then lastPress = nil end
        casts[#casts + 1] = c
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        c.succeeded, c.at = true, now
        if c.macro and extra then extra.last = now; WatchExtraIdle(); RefreshExtraTimer() end
        -- in case the bags updated before this event, or never do (bags full)
        C_Timer.After(2, function() if InList(c) then ReportConjured(c, true); Update() end end)
    elseif c and (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED") then
        Drop(c)
        if c.macro and event == "UNIT_SPELLCAST_INTERRUPTED" then ns.Print("Conjure interrupted.") end
    end
    Update() -- aim past the casts on the way (no-op in combat)
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
timer.logo = timer:CreateTexture(nil, "OVERLAY")
timer.logo:SetSize(22, 22)
timer.logo:SetTexture(ns.ICON)
timer.logo:SetPoint("LEFT", 4, 0)
timer.label = timer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
timer.label:SetPoint("TOPLEFT", 30, -3)
timer.label:SetPoint("TOPRIGHT", -6, -3)
timer.label:SetJustifyH("LEFT")
timer.bar = CreateFrame("StatusBar", nil, timer)
timer.bar:SetPoint("BOTTOMLEFT", 30, 4)
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
-- Manual conjure buttons: highest and 2nd highest water and food, then every mana gem rank (highest first),
-- beside the config window on a mage.
-- Each is a secure spell button: one click = one cast. The panel is its own frame (not a child of the
-- config window) so opening and closing the config never gets blocked in combat; in combat it keeps its
-- spells and position, and shows or hides once combat ends.
---------------------------------------------------------------------------------------------------

local MANUAL = {
    { slot = "water1", label = "Water" }, { slot = "water2", label = "Water -1" },
    { slot = "food1", label = "Food" }, { slot = "food2", label = "Food -1" },
}
for rank = #ns.GEMS, 1, -1 do -- every gem rank, highest first: { gem = rank }
    MANUAL[#MANUAL + 1] = { gem = rank, label = ns.NAMES[ns.GEMS[rank]] }
end
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
manual.logo = ns.AddLogo(manual, mtitle, 22)
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
    b.slot, b.gem, b.name = m.slot or false, m.gem or false, m.label
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local item = self.id and ns.ITEMS[self.id]
        if item and item.kind == "gem" then
            GameTooltip:SetText("Conjure " .. ns.NAMES[self.id])
            GameTooltip:AddLine(ItemCount(self.id) > 0 and "In your bags: yes (you can only carry one)"
                or "In your bags: no", 1, 1, 1)
            GameTooltip:AddLine("Click to cast once.", 0.6, 0.8, 1, true)
        elseif item then
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
        local id, learned
        if b.gem then -- an exact gem rank
            id = ns.GEMS[b.gem]
            local top = ns.TopRank("gem")
            learned = top ~= nil and b.gem <= top
        else
            id = ns.Resolve(b.slot)
            -- "Water -1" needs a rank below the top one; with only rank 1 (or none) there isn't one
            local kind, n = ns.ParseRelative(b.slot)
            local top = ns.TopRank(kind)
            learned = top ~= nil and top - n + 1 >= 1
        end
        local item = ns.ITEMS[id]
        b.id = learned and id or nil
        b.icon:SetTexture(ns.SlotIcon and ns.SlotIcon(b.slot or id) or nil)
        b.icon:SetDesaturated(not learned)
        b.icon:SetAlpha(learned and 1 or 0.4)
        b.count:SetText(learned and tostring(ItemCount(id)) or "")
        local sub = not learned and "not learned"
            or b.gem and (ItemCount(id) > 0 and "in your bags" or "not in your bags")
            or ("rank " .. item.rank)
        b.label:SetText(b.name .. "\n|cff888888" .. sub .. "|r")
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
