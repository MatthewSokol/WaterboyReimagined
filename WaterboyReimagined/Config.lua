-- Waterboy Reimagined: config window (/wbr). Three tabs along the bottom:
--   General  - addon-wide options (fill trades automatically, debug), this character and the known mages
--   Trades   - what each class or player gets in a trade (below)
--   Loadouts - how many stacks to keep in your bags (solo / party / raid) and the macro
-- The profile dropdown (top left) applies to Trades and Loadouts.
--
-- Trades tab:
-- Left: pick a profile (Default, or any mage on this account), then a class or player to edit.
-- Middle: a fake trade window with 6 slots: what that class or player gets.
-- Right: palette of every rank of conjured water and food.
--   Drag from the palette (or a real conjured item from your bags) onto a slot, or click a palette item
--   to add it to the next empty slot. Drag a slot onto another slot to swap, or off the window to remove it.
--   Right-click a slot to remove it.
-- On a mage's profile, anything without an override shows the default's setting dimmed; changing a slot
-- makes that mage's own copy. "Use default" drops the override again.

local ADDON_NAME, ns = ...

local GetIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local SLOT_SIZE = 37
local MAX_PLAYERS = 5

local PAGES = { "general", "trades", "loadouts" }
local PAGE_NAMES = { general = "General", trades = "Trades", loadouts = "Loadouts" }

local frame
-- playerOffset: how far the Players list is scrolled (rows hidden above the first visible one)
local state = { page = "trades", profile = "default", field = "classes", key = "WARRIOR", playerOffset = 0 }
local revealedKey -- the player last scrolled into view, so scrolling by hand doesn't snap back to them
local slotButtons, classButtons, playerButtons = {}, {}, {}
local dragIcon, drag -- drag = { id = itemID, from = slot index or nil }

local function ClassName(class)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

-- Short: "Aldren Brightwater", plus "(you)" for the current character.
local function ProfileLabel(key)
    if key == "default" then return "Default" end
    local label = ns.CharInfo(key)
    if key == ns.CharKey() then label = label .. " (you)" end
    return label
end

-- Long, for lists: "Aldren Brightwater, level 60 - PvP Horde (you)".
local function CharLabel(key)
    if key == "default" then return "Default" end
    local name, where, level = ns.CharInfo(key)
    local label = name
    if level then label = label .. ", level " .. level end
    if where then label = label .. " - " .. where end
    if key == ns.CharKey() then label = label .. " (you)" end
    return label
end

local function ClassColor(class)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

---------------------------------------------------------------------------------------------------
-- Model
---------------------------------------------------------------------------------------------------

-- Returns the entry shown for the current selection and whether it is inherited from the default profile.
local function CurrentEntry()
    local p = ns.Profile(state.profile)
    local e = p and p[state.field][state.key]
    if e then return e, false end
    if state.profile ~= "default" then
        local d = ns.Profile("default")[state.field][state.key]
        if d then return d, true end
    end
    return nil, false
end

-- The entry to change: makes this profile's own copy first if needed.
local function EditableEntry()
    local p = ns.Profile(state.profile, true)
    local e = p[state.field][state.key]
    if not e then
        local shown = CurrentEntry()
        e = shown and ns.CopyEntry(shown) or { slots = {} }
        p[state.field][state.key] = e
    end
    return e
end

local Refresh

local function SetSlot(i, id)
    local slots = EditableEntry().slots
    if i > #slots then i = #slots + 1 end
    if i > ns.TRADE_SLOTS then return end
    slots[i] = id
    Refresh()
end

local function RemoveSlot(i)
    local slots = EditableEntry().slots
    if slots[i] then table.remove(slots, i) end
    Refresh()
end

local function MoveSlot(from, to)
    local slots = EditableEntry().slots
    if to > #slots then
        local id = table.remove(slots, from)
        slots[#slots + 1] = id
    else
        slots[from], slots[to] = slots[to], slots[from]
    end
    Refresh()
end

local function AddToNextSlot(id)
    local shown = CurrentEntry()
    SetSlot(shown and #shown.slots + 1 or 1, id)
end

local function Reset()
    local p = ns.Profile(state.profile)
    if p then p[state.field][state.key] = nil end
    if state.profile == "default" and state.field == "classes" then
        p.classes[state.key] = ns.DefaultClassEntry(state.key)
    end
    if state.field == "players" and not CurrentEntry() then
        state.field, state.key = "classes", "WARRIOR"
    end
    Refresh()
end

local function Select(field, key)
    state.field, state.key = field, key
    Refresh()
end

-- Players shown in the list: this profile's, plus the default's when editing this character.
local function PlayerList()
    local seen, list = {}, {}
    local function add(p)
        if not p then return end
        for name in pairs(p.players) do
            if not seen[name] then seen[name] = true; list[#list + 1] = name end
        end
    end
    add(ns.Profile(state.profile))
    if state.profile ~= "default" then add(ns.Profile("default")) end
    table.sort(list)
    return list
end

---------------------------------------------------------------------------------------------------
-- Dragging
---------------------------------------------------------------------------------------------------

-- The mage whose ranks relative slots resolve against: the selected mage, or this character for Default.
local function ViewMage()
    return state.profile ~= "default" and state.profile or nil
end

-- Icon for a slot, as mage `key` would hand it out (nil key: this character). Shared with TradePopup.lua.
function ns.SlotIcon(slot, key)
    return slot and GetIcon(ns.Resolve(slot, key)) or nil
end

-- "Highest water (Conjured Crystal Water)" or "Conjured Sweet Roll (rank 6)", with a warning when the mage
-- doesn't know that rank
function ns.SlotText(slot, key)
    local item = ns.Resolve(slot, key)
    local info = ns.ITEMS[item]
    if ns.ParseRelative(slot) then
        return ns.SlotName(slot) .. " |cff888888(" .. info.name .. ")|r"
    end
    local text = info.name .. " |cff888888(rank " .. info.rank .. ")|r"
    local top = ns.TopRank(info.kind, key)
    if top and top < info.rank then text = text .. " |cffff8800not known: uses rank " .. top .. "|r" end
    return text
end

local function SlotIcon(slot) return ns.SlotIcon(slot, ViewMage()) end
local function SlotText(slot) return ns.SlotText(slot, ViewMage()) end

local function StartDrag(id, from)
    if not id then return end
    drag = { id = id, from = from }
    dragIcon.tex:SetTexture(SlotIcon(id))
    dragIcon:Show()
end

local function StopDrag()
    if not drag then return end
    local d = drag
    drag = nil
    dragIcon:Hide()
    local target
    for i, b in ipairs(slotButtons) do
        if b:IsMouseOver() then target = i end
    end
    if target then
        if d.from then
            if target ~= d.from then MoveSlot(d.from, target) end
        else
            SetSlot(target, d.id)
        end
    elseif d.from and not frame:IsMouseOver() then
        RemoveSlot(d.from)
    end
end

-- a real conjured item on the cursor (picked up from the bags)
local function CursorConjured()
    local kind, id = GetCursorInfo()
    if kind == "item" and ns.ITEMS[id] then return id end
end

---------------------------------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------------------------------

local function ItemTooltip(self, id, ...)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if ns.ParseRelative(id) then
        local item = ns.Resolve(id, ViewMage())
        GameTooltip:SetText(ns.SlotName(id))
        GameTooltip:AddLine("The highest ranks the mage knows, counting down.", 1, 1, 1, true)
        GameTooltip:AddLine("Now: " .. ns.NAMES[item] .. " (rank " .. ns.ITEMS[item].rank .. ")", 1, 1, 1)
    elseif id then
        GameTooltip:SetHyperlink("item:" .. id)
    end
    for _, line in ipairs({ ... }) do GameTooltip:AddLine(line, 0.6, 0.8, 1) end
    GameTooltip:Show()
end

local function MakeIconButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:RegisterForDrag("LeftButton")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    return b
end

local function MakeListButton(parent, width)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 18)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", 6, 0)
    b.text:SetJustifyH("LEFT")
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints()
    b.sel:SetColorTexture(0.3, 0.6, 1, 0.3)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    return b
end

local function Label(parent, text, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetText(text)
    return fs
end

---------------------------------------------------------------------------------------------------
-- General tab: addon-wide options and who's who
---------------------------------------------------------------------------------------------------

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

local function BuildGeneralPage()
    local page = CreateFrame("Frame", nil, frame)
    page:SetPoint("TOPLEFT", 6, -26)
    page:SetPoint("BOTTOMRIGHT", -6, 6)
    page:Hide()
    frame.general = page

    Label(page, "General settings", "GameFontNormalLarge"):SetPoint("TOPLEFT", frame.portrait and 36 or 14, -10)

    page.checks = {}
    local function Check(y, text, help, get, set)
        local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", 14, y)
        cb.label = Label(cb, text, "GameFontHighlight")
        cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        local h = Label(page, help, "GameFontDisableSmall")
        h:SetPoint("TOPLEFT", 42, y - 24)
        h:SetWidth(470)
        h:SetJustifyH("LEFT")
        cb.get = get
        cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); Refresh() end)
        page.checks[#page.checks + 1] = cb
    end
    Check(-40, "Fill trades automatically",
        "On a mage, when someone opens a trade, put in their stacks right away. When off, a panel next to "
            .. "the trade window shows what they'd get, with Add to trade.",
        function() return ns.DB().enabled end, function(v) ns.DB().enabled = v end)
    Check(-96, "Debug messages", "Print what the addon is doing in chat (same as /wbr debug).",
        function() return ns.DB().debug end, function(v) ns.DB().debug = v end)

    Label(page, "This character"):SetPoint("TOPLEFT", 14, -146)
    page.me = Label(page, "", "GameFontHighlightSmall")
    page.me:SetPoint("TOPLEFT", 18, -164)
    page.me:SetWidth(490)
    page.me:SetJustifyH("LEFT")

    Label(page, "Mages on this account"):SetPoint("TOPLEFT", 14, -196)
    page.mages = Label(page, "", "GameFontHighlightSmall")
    page.mages:SetPoint("TOPLEFT", 18, -214)
    page.mages:SetWidth(490)
    page.mages:SetJustifyH("LEFT")
    page.mages:SetSpacing(2)

    Label(page, "Commands"):SetPoint("TOPLEFT", 14, -322)
    local cmds = Label(page, "/wbr or /wb opens this window. /wbr help lists the rest, "
        .. "e.g. /wbr set Grimbold 1 1.", "GameFontHighlightSmall")
    cmds:SetPoint("TOPLEFT", 18, -340)
    cmds:SetWidth(490)
    cmds:SetJustifyH("LEFT")

    local version = GetMeta and GetMeta(ADDON_NAME, "Version")
    if version then Label(page, "Version " .. version, "GameFontDisableSmall"):SetPoint("BOTTOMRIGHT", -10, 10) end
end

local function MageLine(key)
    local m = ns.DB().mages[key] or {}
    return string.format("%s: water rank %s, food rank %s", CharLabel(key), tostring(m.water or "?"),
        tostring(m.food or "?"))
end

local function RefreshGeneralPage()
    local page = frame.general
    for _, cb in ipairs(page.checks) do cb:SetChecked(cb.get()) end
    if ns.IsMage() then
        page.me:SetText(MageLine(ns.CharKey()))
    else
        page.me:SetText(CharLabel(ns.CharKey()) .. " is not a mage: settings you change save, "
            .. "but only mages fill trades and conjure.")
    end
    local lines = {}
    for _, key in ipairs(ns.KnownMages()) do lines[#lines + 1] = MageLine(key) end
    page.mages:SetText(#lines > 0 and table.concat(lines, "\n")
        or "None yet: each mage is added the first time it logs in with the addon.")
end

---------------------------------------------------------------------------------------------------
-- Loadouts tab: stacks to keep in your bags (solo / party / raid) and the macro.
---------------------------------------------------------------------------------------------------

local GROUP_NAMES = { solo = "Solo", party = "Party", raid = "Raid" }
local SLOT_HEADERS = { water1 = "Water", water2 = "Water -1", food1 = "Food", food2 = "Food -1" }
local COL_X = { water1 = 216, water2 = 272, food1 = 328, food2 = 384 }

local function EditableLoadout(group)
    local p = ns.Profile(state.profile, true)
    p.loadouts = p.loadouts or {}
    if not p.loadouts[group] then p.loadouts[group] = ns.CopyLoadout(ns.Loadout(group, state.profile)) end
    return p.loadouts[group]
end

local function BuildLoadoutsPage()
    local page = CreateFrame("Frame", nil, frame)
    page:SetPoint("TOPLEFT", 6, -26)
    page:SetPoint("BOTTOMRIGHT", -6, 6)
    page:Hide()
    frame.loadouts = page

    local title = Label(page, "Loadouts", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 200, -10)
    local sub = Label(page, "Stacks to keep in your bags. The macro conjures what's missing.", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", 200, -30)
    sub:SetWidth(320)
    sub:SetJustifyH("LEFT")

    page.headers = {}
    for _, slot in ipairs(ns.LOADOUT_SLOTS) do
        local icon = page:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("TOPLEFT", COL_X[slot] + 10, -62)
        local text = Label(page, SLOT_HEADERS[slot], "GameFontHighlightSmall")
        text:SetPoint("TOP", icon, "BOTTOM", 0, -1)
        page.headers[slot] = icon
    end

    page.rows = {}
    for i, group in ipairs(ns.LOADOUT_GROUPS) do
        local y = -104 - (i - 1) * 34
        local row = { boxes = {} }
        row.name = Label(page, GROUP_NAMES[group])
        row.name:SetPoint("TOPLEFT", 14, y - 4)
        if group ~= "solo" then
            local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
            cb:SetSize(24, 24)
            cb:SetPoint("TOPLEFT", 64, y + 2)
            cb.label = Label(cb, "+ group's trades", "GameFontHighlightSmall")
            cb.label:SetPoint("LEFT", cb, "RIGHT", 0, 0)
            cb:SetScript("OnClick", function(self)
                EditableLoadout(group).makeup = self:GetChecked() and true or false
                Refresh()
            end)
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Add the group's trade settings")
                GameTooltip:AddLine("Adds up what everyone in your " .. group .. " would get in a trade (their "
                    .. "class or player setting), on top of the stacks in this row.", 1, 1, 1, true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", GameTooltip_Hide)
            row.makeup = cb
        end
        for _, slot in ipairs(ns.LOADOUT_SLOTS) do
            local box = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
            box:SetSize(34, 20)
            box:SetPoint("TOPLEFT", COL_X[slot] + 6, y)
            box:SetAutoFocus(false)
            box:SetNumeric(true)
            box:SetMaxLetters(3)
            box:SetJustifyH("CENTER")
            box:SetScript("OnTextChanged", function(self, userInput)
                if userInput then EditableLoadout(group).counts[slot] = tonumber(self:GetText()) or 0 end
            end)
            box:SetScript("OnEnterPressed", box.ClearFocus)
            box:SetScript("OnEscapePressed", box.ClearFocus)
            box:SetScript("OnEditFocusLost", function() Refresh() end)
            row.boxes[slot] = box
        end
        local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        reset:SetSize(84, 22)
        reset:SetPoint("TOPLEFT", 440, y + 1)
        reset:SetScript("OnClick", function()
            local p = ns.Profile(state.profile)
            if state.profile == "default" then p.loadouts[group] = ns.DefaultLoadout(group)
            elseif p and p.loadouts then p.loadouts[group] = nil end
            Refresh()
        end)
        row.reset = reset
        page.rows[group] = row
    end

    local now = Label(page, "Right now (this character)")
    now:SetPoint("TOPLEFT", 14, -214)
    page.status = Label(page, "", "GameFontHighlightSmall")
    page.status:SetPoint("TOPLEFT", 18, -232)
    page.status:SetWidth(500)
    page.status:SetJustifyH("LEFT")
    page.status:SetSpacing(2)

    local macroLabel = Label(page, "Macro")
    macroLabel:SetPoint("TOPLEFT", 14, -312)
    local make = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    make:SetSize(150, 24)
    make:SetPoint("TOPLEFT", 14, -330)
    make:SetText("Put macro on cursor")
    make:SetScript("OnClick", function() ns.MakeMacro() end)

    -- the macro's icon: the addon's images, or the next conjure's own icon; the chosen one has a gold border
    local iconLabel = Label(page, "Macro icon", "GameFontHighlightSmall")
    iconLabel:SetPoint("TOPLEFT", 262, -306)
    page.iconButtons = {}
    for i, opt in ipairs(ns.MACRO_ICONS) do
        local b = CreateFrame("Button", nil, page)
        b:SetSize(24, 24)
        b:SetPoint("TOPLEFT", 330 + (i - 1) * 28, -300)
        b.border = b:CreateTexture(nil, "BACKGROUND")
        b.border:SetAllPoints()
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 2, -2)
        b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.icon:SetTexture(ns.MacroIconTexture(opt))
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b.key = opt.key
        b:SetScript("OnClick", function() ns.SetMacroIcon(opt.key); Refresh() end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(opt.label)
            GameTooltip:AddLine(opt.tip or "Use this picture as the Waterboy macro's icon.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        page.iconButtons[i] = b
    end

    local text = CreateFrame("EditBox", nil, page)
    text:SetMultiLine(true)
    text:SetFontObject(ChatFontNormal)
    text:SetSize(330, 36)
    text:SetPoint("TOPLEFT", 180, -326)
    text:SetAutoFocus(false)
    local tbg = text:CreateTexture(nil, "BACKGROUND")
    tbg:SetPoint("TOPLEFT", -4, 4)
    tbg:SetPoint("BOTTOMRIGHT", 4, -4)
    tbg:SetColorTexture(0, 0, 0, 0.6)
    text:SetText(ns.MacroText())
    text:SetScript("OnTextChanged", function(self, userInput) if userInput then self:SetText(ns.MacroText()) end end)
    text:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    text:SetScript("OnEscapePressed", text.ClearFocus)
    local hint = Label(page, "Creates the account macro \"Waterboy\" (or click the text and Ctrl+C to copy it). "
        .. "Each press restacks, then conjures one thing that's missing. The made macro fades when you can't "
        .. "cast the next conjure (no mana, say) and shows the loadout in its tooltip.", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 14, -362)
    hint:SetWidth(500)
    hint:SetJustifyH("LEFT")
end

local function RefreshLoadoutsPage()
    local page = frame.loadouts
    for slot, icon in pairs(page.headers) do icon:SetTexture(SlotIcon(slot)) end
    for group, row in pairs(page.rows) do
        local lo, inherited = ns.Loadout(group, state.profile)
        local alpha = inherited and 0.5 or 1
        row.name:SetAlpha(alpha)
        if row.makeup then
            row.makeup:SetChecked(lo.makeup)
            row.makeup:SetAlpha(alpha)
        end
        for slot, box in pairs(row.boxes) do
            if not box:HasFocus() then box:SetText(tostring(lo.counts[slot] or 0)) end
            box:SetAlpha(alpha)
        end
        if state.profile == "default" then
            row.reset:SetText("Reset")
            row.reset:SetEnabled(true)
        else
            row.reset:SetText("Use default")
            row.reset:SetEnabled(not inherited)
        end
    end
    page.status:SetText(ns.IsMage() and table.concat(ns.LoadoutStatus(), "\n")
        or "Not a mage: loadouts save, but only a mage conjures.")
    local chosen = ns.MacroIconChoice()
    for _, b in ipairs(page.iconButtons) do
        if b.key == chosen then b.border:SetColorTexture(1, 0.82, 0) else b.border:SetColorTexture(0.15, 0.15, 0.15) end
    end
end

local function Build()
    frame = ns.CreateWindow("WaterboyReimaginedConfig", 540, 450, "Waterboy Reimagined")
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ns.PlaceManualConjure then ns.PlaceManualConjure() end
    end)
    -- the manual conjure buttons (Conjure.lua) sit beside this window on a mage
    frame:SetScript("OnShow", function(self) if ns.ShowManualConjure then ns.ShowManualConjure(self) end end)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    tinsert(UISpecialFrames, "WaterboyReimaginedConfig")

    -- profile: Default or one of the mages on this account (the label sits right of the portrait logo)
    local prof = Label(frame, "Profile")
    prof:SetPoint("TOPLEFT", frame.portrait and 40 or 16, -34)
    frame.profileLabel = prof
    local dd = CreateFrame("Frame", "WaterboyReimaginedProfileDropDown", frame, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", 0, -46)
    UIDropDownMenu_SetWidth(dd, 140)
    UIDropDownMenu_Initialize(dd, function(_, level)
        local function add(text, value)
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.arg1, info.checked = text, value, state.profile == value
            info.func = function(_, v) state.profile = v; CloseDropDownMenus(); Refresh() end
            UIDropDownMenu_AddButton(info, level)
        end
        add("Default", "default")
        for _, key in ipairs(ns.KnownMages()) do add(CharLabel(key), key) end
    end)
    frame.profileDD = dd

    -- Trades tab: everything below lives on this page
    local tp = CreateFrame("Frame", nil, frame)
    tp:SetAllPoints()
    tp:Hide()
    frame.trades = tp

    -- classes
    local cl = Label(tp, "Classes")
    cl:SetPoint("TOPLEFT", 16, -80)
    for i, class in ipairs(ns.CLASSES) do
        local b = MakeListButton(tp, 160)
        b:SetPoint("TOPLEFT", 12, -94 - (i - 1) * 18)
        b.text:SetText(ClassName(class))
        b.text:SetTextColor(ClassColor(class))
        b:SetScript("OnClick", function() Select("classes", class) end)
        classButtons[class] = b
    end

    -- players
    local pl = Label(tp, "Players")
    pl:SetPoint("TOPLEFT", 16, -264)
    local box = CreateFrame("EditBox", nil, tp, "InputBoxTemplate")
    box:SetSize(104, 20)
    box:SetPoint("TOPLEFT", 20, -278)
    box:SetAutoFocus(false)
    local add = CreateFrame("Button", nil, tp, "UIPanelButtonTemplate")
    add:SetSize(50, 22)
    add:SetPoint("LEFT", box, "RIGHT", 4, 0)
    add:SetText("Add")
    -- The key of a player who already has a setting on the profile being edited (or, on a mage's profile, the
    -- default's): their full name, else their first name alone (settings typed by first name).
    local function ExistingPlayerKey(name)
        local full = ns.PlayerKey(name)
        local first = full:match("^(%S+) ")
        local own = ns.Profile(state.profile)
        local function has(k)
            return (own and own.players[k]) or (state.profile ~= "default" and ns.Profile("default").players[k])
        end
        if has(full) then return full end
        if first and has(first) then return first end
    end
    -- Add / Target / Trade: a player who already has a setting is just selected (nothing is copied; editing a
    -- slot is what gives a mage its own copy). Only a new name gets a new, empty setting.
    local function AddPlayer(name)
        name = strtrim(name or "")
        if name == "" then return end
        local key = ExistingPlayerKey(name)
        state.field, state.key = "players", key or ns.PlayerKey(name)
        if not key then EditableEntry() end
        Refresh()
    end
    frame.addPlayer = AddPlayer -- also used by the smoke test
    local function AddTyped()
        local name = box:GetText()
        box:SetText("")
        box:ClearFocus()
        AddPlayer(name)
    end
    add:SetScript("OnClick", AddTyped)
    box:SetScript("OnEnterPressed", AddTyped)
    box:SetScript("OnEscapePressed", box.ClearFocus)

    local fromTarget = CreateFrame("Button", nil, tp, "UIPanelButtonTemplate")
    fromTarget:SetSize(78, 22)
    fromTarget:SetPoint("TOPLEFT", 14, -302)
    fromTarget:SetText("Target")
    fromTarget:SetScript("OnClick", function()
        if UnitExists("target") and UnitIsPlayer("target") then AddPlayer(ns.UnitFullName("target"))
        else ns.Print("Target a player first.") end
    end)
    local fromTrade = CreateFrame("Button", nil, tp, "UIPanelButtonTemplate")
    fromTrade:SetSize(78, 22)
    fromTrade:SetPoint("LEFT", fromTarget, "RIGHT", 2, 0)
    fromTrade:SetText("Trade")
    fromTrade:SetScript("OnClick", function()
        local name = TradeFrame and TradeFrame:IsShown() and ns.UnitFullName("NPC")
        if name then AddPlayer(name) else ns.Print("No trade open.") end
    end)
    for _, b in ipairs({ fromTarget, fromTrade }) do
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self == fromTarget and "Add your current target" or "Add who you're trading with")
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
    end

    -- the Players list: MAX_PLAYERS rows that scroll (mouse wheel over the list, or the arrows beside it)
    local function ScrollPlayers(rows)
        state.playerOffset = state.playerOffset + rows
        Refresh()
    end
    local function Wheel(_, delta) ScrollPlayers(-delta) end
    for i = 1, MAX_PLAYERS do
        local b = MakeListButton(tp, 150)
        b:SetPoint("TOPLEFT", 12, -328 - (i - 1) * 18)
        b:SetScript("OnClick", function(self) Select("players", self.key) end)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", Wheel)
        playerButtons[i] = b
    end
    local function Arrow(dir, y)
        local b = CreateFrame("Button", nil, tp)
        b:SetSize(16, 16)
        b:SetPoint("TOPLEFT", 166, y)
        local base = "Interface\\Buttons\\UI-ScrollBar-Scroll" .. (dir < 0 and "Up" or "Down") .. "Button-"
        b:SetNormalTexture(base .. "Up")
        b:SetPushedTexture(base .. "Down")
        b:SetDisabledTexture(base .. "Disabled")
        b:SetHighlightTexture(base .. "Highlight", "ADD")
        b:SetScript("OnClick", function() ScrollPlayers(dir * (MAX_PLAYERS - 1)) end)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", Wheel)
        return b
    end
    frame.playersUp = Arrow(-1, -329)
    frame.playersDown = Arrow(1, -401)
    frame.playerButtons = playerButtons
    frame.morePlayers = Label(tp, "", "GameFontDisableSmall")
    frame.morePlayers:SetPoint("TOPLEFT", 18, -420)

    -- fake trade window
    local trade = CreateFrame("Frame", nil, tp, "InsetFrameTemplate")
    trade:SetSize(220, 366)
    trade:SetPoint("TOPLEFT", 190, -34)
    frame.heading = Label(trade, "", "GameFontNormalLarge")
    frame.heading:SetPoint("TOP", 0, -8)
    frame.source = Label(trade, "", "GameFontDisableSmall")
    frame.source:SetPoint("TOP", frame.heading, "BOTTOM", 0, -2)
    for i = 1, ns.TRADE_SLOTS do
        local b = MakeIconButton(trade, SLOT_SIZE)
        b:SetPoint("TOPLEFT", 12, -48 - (i - 1) * (SLOT_SIZE + 9))
        b.num = Label(b, tostring(i), "NumberFontNormalSmall")
        b.num:SetPoint("BOTTOMRIGHT", -2, 2)
        b.name = Label(trade, "", "GameFontHighlightSmall")
        b.name:SetPoint("LEFT", b, "RIGHT", 8, 0)
        b.name:SetWidth(150)
        b.name:SetJustifyH("LEFT")
        b:SetScript("OnDragStart", function(self) StartDrag(self.id, i) end)
        b:SetScript("OnDragStop", StopDrag)
        b:SetScript("OnReceiveDrag", function()
            local id = CursorConjured()
            if id then ClearCursor(); SetSlot(i, id) end
        end)
        b:SetScript("OnClick", function(self, button)
            local id = CursorConjured()
            if id then ClearCursor(); SetSlot(i, id)
            elseif button == "RightButton" and self.id then RemoveSlot(i) end
        end)
        b:SetScript("OnEnter", function(self)
            ItemTooltip(self, self.id, self.id and "Drag to move, drag off the window or right-click to remove"
                or "Drag water or food here")
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        slotButtons[i] = b
    end

    local reset = CreateFrame("Button", nil, trade, "UIPanelButtonTemplate")
    reset:SetSize(96, 22)
    reset:SetPoint("BOTTOMLEFT", 10, 8)
    reset:SetScript("OnClick", Reset)
    frame.reset = reset
    local clear = CreateFrame("Button", nil, trade, "UIPanelButtonTemplate")
    clear:SetSize(96, 22)
    clear:SetPoint("BOTTOMRIGHT", -10, 8)
    clear:SetText("Give nothing")
    clear:SetScript("OnClick", function() EditableEntry().slots = {}; Refresh() end)

    -- palette
    local pal = Label(tp, "Drag to a slot")
    pal:SetPoint("TOPLEFT", 432, -34)
    -- top: relative ranks (highest, 2nd highest, ...) - good for the default profile, since mages of
    -- different levels know different ranks; below: each exact rank, 7 down to 1
    frame.relativeButtons = {}
    local function PaletteButton(id, col, y, badge, hint)
        local b = MakeIconButton(tp, 30)
        b:SetPoint("TOPLEFT", 434 + col * 44, y)
        b.icon:SetTexture(SlotIcon(id))
        b.id = id
        b.badge = Label(b, badge, "NumberFontNormalSmall")
        b.badge:SetPoint("BOTTOMRIGHT", -2, 2)
        b:SetScript("OnDragStart", function() StartDrag(id) end)
        b:SetScript("OnDragStop", StopDrag)
        b:SetScript("OnClick", function() AddToNextSlot(id) end)
        b:SetScript("OnEnter", function(self) ItemTooltip(self, id, hint, "Drag to a slot, or click to add") end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        return b
    end
    for col, kind in ipairs({ "water", "food" }) do
        local list = kind == "water" and ns.WATER or ns.FOOD
        for n = 1, ns.RELATIVE_COUNT do
            local slot = kind .. n
            local b = PaletteButton(slot, col - 1, -54 - (n - 1) * 34, n == 1 and "top" or ("-" .. (n - 1)), nil)
            frame.relativeButtons[#frame.relativeButtons + 1] = b
        end
        for r = #list, 1, -1 do
            PaletteButton(list[r], col - 1, -54 - ns.RELATIVE_COUNT * 34 - 8 - (#list - r) * 34, tostring(r), "Rank " .. r)
        end
    end

    -- under the fake trade window: whether trades get filled (the option itself is on the General tab)
    frame.tradeNote = Label(tp, "", "GameFontDisableSmall")
    frame.tradeNote:SetPoint("TOPLEFT", 194, -406)
    frame.tradeNote:SetWidth(330)
    frame.tradeNote:SetJustifyH("LEFT")

    -- drag icon follows the cursor
    dragIcon = CreateFrame("Frame", nil, UIParent)
    dragIcon:SetSize(32, 32)
    dragIcon:SetFrameStrata("TOOLTIP")
    dragIcon.tex = dragIcon:CreateTexture(nil, "OVERLAY")
    dragIcon.tex:SetAllPoints()
    dragIcon:Hide()
    dragIcon:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
    end)

    frame:SetScript("OnHide", function()
        if drag then drag = nil; dragIcon:Hide() end
        if ns.HideManualConjure then ns.HideManualConjure() end
    end)

    BuildGeneralPage()
    BuildLoadoutsPage()

    -- tabs hanging off the bottom edge, like the character window's. Falls back to plain buttons if this
    -- client lacks the tab template.
    local useTabs = PanelTemplates_TabResize and PanelTemplates_SelectTab and PanelTemplates_DeselectTab
    frame.tabs = {}
    for i, page in ipairs(PAGES) do
        local name = "WaterboyReimaginedConfigTab" .. i
        local tab
        if useTabs then
            tab = CreateFrame("Button", name, frame, "PanelTabButtonTemplate")
            if not (tab.Text or _G[name .. "Text"]) then useTabs = false; tab:Hide(); tab = nil end
        end
        if tab then
            tab:SetText(PAGE_NAMES[page])
            pcall(PanelTemplates_TabResize, tab, 0)
            if i == 1 then
                tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 8, 2)
            else
                -- newer tab art sits side by side, the older art overlaps
                tab:SetPoint("TOPLEFT", frame.tabs[i - 1], "TOPRIGHT", tab.LeftActive and 3 or -15, 0)
            end
        else
            tab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            tab:SetSize(84, 22)
            tab:SetText(PAGE_NAMES[page])
            tab.plain = true
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 8 + (i - 1) * 88, -2)
        end
        tab:SetScript("OnClick", function() state.page = page; Refresh() end)
        tab.page = page
        frame.tabs[i] = tab
    end
end

local function RefreshTabs()
    for _, tab in ipairs(frame.tabs) do
        local selected = tab.page == state.page
        if tab.plain then
            tab:SetEnabled(not selected)
        else
            pcall(selected and PanelTemplates_SelectTab or PanelTemplates_DeselectTab, tab)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------------------------------

local function RefreshTradesPage()
    local isChar = state.profile ~= "default"
    for class, b in pairs(classButtons) do
        b.sel:SetShown(state.field == "classes" and state.key == class)
        local own = ns.Profile(state.profile)
        local mark = (isChar and own and own.classes[class]) and " *" or ""
        b.text:SetText(ClassName(class) .. mark)
    end

    local players = PlayerList()
    local own = ns.Profile(state.profile)
    -- a newly selected player (Add, Target, Trade, Edit setting) is scrolled into view
    if state.field == "players" and state.key ~= revealedKey then
        for i, name in ipairs(players) do
            if name == state.key then
                if i <= state.playerOffset then state.playerOffset = i - 1
                elseif i > state.playerOffset + MAX_PLAYERS then state.playerOffset = i - MAX_PLAYERS end
                break
            end
        end
    end
    revealedKey = state.field == "players" and state.key or nil
    local maxOffset = math.max(0, #players - MAX_PLAYERS)
    state.playerOffset = math.min(math.max(state.playerOffset, 0), maxOffset)
    for i, b in ipairs(playerButtons) do
        local name = players[state.playerOffset + i]
        b.key = name
        b:SetShown(name ~= nil)
        if name then
            local mark = (isChar and own and own.players[name]) and " *" or ""
            b.text:SetText(ns.PlayerName(name) .. mark)
            b.sel:SetShown(state.field == "players" and state.key == name)
        end
    end
    local scrolls = #players > MAX_PLAYERS
    frame.playersUp:SetShown(scrolls)
    frame.playersDown:SetShown(scrolls)
    frame.playersUp:SetEnabled(state.playerOffset > 0)
    frame.playersDown:SetEnabled(state.playerOffset < maxOffset)
    frame.morePlayers:SetText(scrolls and string.format("%d-%d of %d (scroll for more)", state.playerOffset + 1,
        math.min(state.playerOffset + MAX_PLAYERS, #players), #players) or "")

    local entry, inherited = CurrentEntry()
    if state.field == "classes" then
        frame.heading:SetText(ClassName(state.key))
        frame.heading:SetTextColor(ClassColor(state.key))
    else
        frame.heading:SetText(ns.PlayerName(state.key))
        frame.heading:SetTextColor(1, 0.82, 0)
    end
    local where = isChar and (ProfileLabel(state.profile) .. "'s profile") or "default profile"
    if inherited then
        frame.source:SetText("from the default profile - change a slot to override")
    elseif entry then
        frame.source:SetText(where)
    else
        frame.source:SetText("not set")
    end

    local slots = entry and entry.slots or {}
    for i, b in ipairs(slotButtons) do
        local id = slots[i]
        b.id = id
        b.icon:SetTexture(SlotIcon(id))
        b.icon:SetDesaturated(inherited)
        b.icon:SetAlpha(inherited and 0.5 or 1)
        b.name:SetText(id and SlotText(id) or "")
        b.name:SetAlpha(inherited and 0.5 or 1)
    end
    for _, b in ipairs(frame.relativeButtons) do b.icon:SetTexture(SlotIcon(b.id)) end

    local p = ns.Profile(state.profile)
    local hasOwn = p and p[state.field][state.key]
    if isChar and state.field == "players" and not ns.Profile("default").players[state.key] then
        -- a player only this character has: removing it deletes the player, there's no default to fall back on
        frame.reset:SetText("Delete player")
        frame.reset:SetEnabled(hasOwn ~= nil)
    elseif isChar then
        frame.reset:SetText("Use default")
        frame.reset:SetEnabled(hasOwn ~= nil)
    elseif state.field == "classes" then
        frame.reset:SetText("Reset")
        frame.reset:SetEnabled(true)
    else
        frame.reset:SetText("Delete player")
        frame.reset:SetEnabled(hasOwn ~= nil)
    end

    if not ns.IsMage() then
        frame.tradeNote:SetText("Not a mage: settings save, but trades are only filled on a mage.")
    elseif ns.DB().enabled then
        frame.tradeNote:SetText("Trades are filled automatically (General tab).")
    else
        frame.tradeNote:SetText("Trades aren't filled automatically: a panel offers Add to trade (General tab).")
    end
end

function Refresh()
    if not frame or not frame:IsShown() then return end
    local hasProfile = state.page ~= "general"
    frame.profileLabel:SetShown(hasProfile)
    frame.profileDD:SetShown(hasProfile)
    UIDropDownMenu_SetText(frame.profileDD, ProfileLabel(state.profile))
    frame.general:SetShown(state.page == "general")
    frame.trades:SetShown(state.page == "trades")
    frame.loadouts:SetShown(state.page == "loadouts")
    RefreshTabs()
    if state.page == "general" then RefreshGeneralPage()
    elseif state.page == "trades" then RefreshTradesPage()
    else RefreshLoadoutsPage() end
end

function ns.RefreshConfig() Refresh() end

function ns.ToggleConfig()
    if not frame then Build() end
    if frame:IsShown() then frame:Hide() else frame:Show(); Refresh() end
end

-- Open on one setting: field "classes" or "players", key = class token or player key.
function ns.OpenConfig(field, key)
    if not frame then Build() end
    state.page, state.field, state.key = "trades", field, key
    frame:Show()
    Refresh()
end

-- Open the Loadouts tab on profile `key` (a character key, or "default").
function ns.OpenLoadouts(key)
    if not frame then Build() end
    state.page, state.profile = "loadouts", key or "default"
    frame:Show()
    Refresh()
end
