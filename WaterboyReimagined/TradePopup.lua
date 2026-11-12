-- Waterboy Reimagined: trade popup.
-- With "Fill trades automatically" off, opening a trade on a mage shows this panel next to the trade window:
-- who you're trading with, where their setting comes from, and the 6 slots they'd get.
--   Add to trade: puts those stacks in the trade window.
--   Right-click a slot: leave it out of this trade (doesn't change the saved setting).
--   Edit setting: opens the config window on the setting this trade uses (player override or class).
--   Vend: placeholder for the vending machine (not built yet).

local ADDON_NAME, ns = ...

local SLOT_SIZE = 37
local popup
local current -- { name =, class =, entry = (a copy, for this trade only), src = }

local function ClassName(class)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

local function Refresh()
    if not current then return end
    popup.heading:SetText(current.name)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[current.class]
    if c then popup.heading:SetTextColor(c.r, c.g, c.b) end
    popup.source:SetText(ClassName(current.class) .. " - " .. current.src)
    local slots = current.entry.slots
    for i, b in ipairs(popup.slots) do
        local slot = slots[i]
        b.slot = slot
        b.icon:SetTexture(ns.SlotIcon(slot))
        b.name:SetText(slot and ns.SlotText(slot) or "")
    end
    popup.add:SetEnabled(#slots > 0)
end

local function Build()
    popup = CreateFrame("Frame", "WaterboyReimaginedTradePopup", UIParent, "BasicFrameTemplateWithInset")
    popup:SetSize(240, 420)
    popup:SetFrameStrata("DIALOG")
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:Hide()
    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.title:SetPoint("TOP", 0, -5)
    popup.title:SetText("Waterboy Reimagined")

    popup.heading = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.heading:SetPoint("TOP", 0, -32)
    popup.source = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    popup.source:SetPoint("TOP", popup.heading, "BOTTOM", 0, -2)
    popup.source:SetWidth(220)

    popup.slots = {}
    for i = 1, ns.TRADE_SLOTS do
        local b = CreateFrame("Button", nil, popup)
        b:SetSize(SLOT_SIZE, SLOT_SIZE)
        b:SetPoint("TOPLEFT", 18, -70 - (i - 1) * (SLOT_SIZE + 9))
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:RegisterForClicks("RightButtonUp")
        b.num = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.num:SetPoint("BOTTOMRIGHT", -2, 2)
        b.num:SetText(i)
        b.name = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.name:SetPoint("LEFT", b, "RIGHT", 8, 0)
        b.name:SetWidth(160)
        b.name:SetJustifyH("LEFT")
        b:SetScript("OnClick", function(self)
            if self.slot then table.remove(current.entry.slots, i); Refresh() end
        end)
        b:SetScript("OnEnter", function(self)
            if not self.slot then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. ns.Resolve(self.slot))
            GameTooltip:AddLine("Right-click: leave out of this trade", 0.6, 0.8, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        popup.slots[i] = b
    end

    local add = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    add:SetSize(104, 24)
    add:SetPoint("BOTTOMLEFT", 12, 38)
    add:SetText("Add to trade")
    add:SetScript("OnClick", function()
        ns.AddToTrade(current.entry, current.name)
    end)
    popup.add = add

    local vend = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    vend:SetSize(104, 24)
    vend:SetPoint("BOTTOMRIGHT", -12, 38)
    vend:SetText("Vend")
    vend:SetEnabled(false)
    vend:SetMotionScriptsWhileDisabled(true)
    vend:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Vending machine")
        GameTooltip:AddLine("Coming soon: hands the stacks over for a minimum tip.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    vend:SetScript("OnLeave", GameTooltip_Hide)

    local edit = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    edit:SetSize(104, 22)
    edit:SetPoint("BOTTOM", 0, 12)
    edit:SetText("Edit setting")
    edit:SetScript("OnClick", function()
        if current.src:find(", player ") then ns.OpenConfig("players", ns.FindPlayerKey(current.name))
        else ns.OpenConfig("classes", current.class) end
    end)
end

function ns.ShowTradePopup(name, class, entry, src)
    if not popup then Build() end
    current = { name = name, class = class, entry = ns.CopyEntry(entry), src = src }
    popup:ClearAllPoints()
    if TradeFrame and TradeFrame:IsShown() then
        popup:SetPoint("TOPLEFT", TradeFrame, "TOPRIGHT", 4, 0)
    else
        popup:SetPoint("CENTER")
    end
    popup:Show()
    Refresh()
end

function ns.HideTradePopup()
    if popup then popup:Hide() end
    current = nil
end
