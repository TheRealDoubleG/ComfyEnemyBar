ComfyEnemyBar = ComfyEnemyBar or {}
local A = ComfyEnemyBar
A.plates = A.plates or setmetatable({}, {__mode = "k"})

local MAX_AURAS = 5
local AURA_GAP = 2

local function IsSecret(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok then return secret and true or false end
    end
    if type(canaccessvalue) == "function" then
        local ok, accessible = pcall(canaccessvalue, value)
        if ok then return not accessible end
    end
    return false
end

local function PlateFor(unit)
    if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok then return plate end
    end
end

local function GetUnitFrame(plate)
    if not plate then return nil end
    return plate.UnitFrame or plate.unitFrame
end

local function SafeObjectType(frame)
    if not frame or type(frame.GetObjectType) ~= "function" then return nil end
    local ok, objectType = pcall(frame.GetObjectType, frame)
    return ok and objectType or nil
end

local function FindBlizzardHealthBar(plate)
    local unitFrame = GetUnitFrame(plate)
    if not unitFrame then return nil end

    local candidates = {
        unitFrame.healthBar,
        unitFrame.HealthBar,
        unitFrame.healthbar,
        unitFrame.HealthBarContainer and unitFrame.HealthBarContainer.HealthBar,
    }

    for _, candidate in pairs(candidates) do
        if candidate and SafeObjectType(candidate) == "StatusBar" then
            return candidate
        end
    end

    if type(unitFrame.GetChildren) == "function" then
        local children = {unitFrame:GetChildren()}
        local best, bestWidth = nil, 0
        for _, child in ipairs(children) do
            if SafeObjectType(child) == "StatusBar" and type(child.GetWidth) == "function" then
                local ok, width = pcall(child.GetWidth, child)
                width = ok and tonumber(width) or 0
                if width and width > bestWidth then
                    best, bestWidth = child, width
                end
            end
        end
        return best
    end
end

local function RememberAndSetAlpha(frame, alpha)
    if not frame or type(frame.SetAlpha) ~= "function" then return end
    if frame.__ComfyEnemyBarOriginalAlpha == nil and type(frame.GetAlpha) == "function" then
        local ok, current = pcall(frame.GetAlpha, frame)
        frame.__ComfyEnemyBarOriginalAlpha = ok and current or 1
    end
    pcall(frame.SetAlpha, frame, alpha)
end

local function RestoreAlpha(frame)
    if not frame or type(frame.SetAlpha) ~= "function" then return end
    local alpha = frame.__ComfyEnemyBarOriginalAlpha
    if alpha ~= nil then
        pcall(frame.SetAlpha, frame, alpha)
        frame.__ComfyEnemyBarOriginalAlpha = nil
    end
end

local function SetDefaultAuraVisibility(plate, hidden)
    local unitFrame = GetUnitFrame(plate)
    if not unitFrame then return end

    local seen = {}
    local candidates = {
        unitFrame.BuffFrame,
        unitFrame.buffFrame,
        unitFrame.AuraFrame,
        unitFrame.auraFrame,
        unitFrame.DebuffFrame,
        unitFrame.debuffFrame,
    }

    for _, frame in pairs(candidates) do
        if frame and not seen[frame] then
            seen[frame] = true
            if hidden then RememberAndSetAlpha(frame, 0) else RestoreAlpha(frame) end
        end
    end
end

local function CompactNumber(value)
    value = tonumber(value)
    if not value then return "" end
    local absValue = math.abs(value)
    if absValue >= 1000000 then
        return string.format("%.1fm", value / 1000000)
    elseif absValue >= 1000 then
        return string.format("%.1fk", value / 1000)
    end
    return tostring(math.floor(value + 0.5))
end

local function ValueText(current, maximum, mode)
    mode = mode or "percent"
    current, maximum = tonumber(current), tonumber(maximum)
    if not current or not maximum or maximum <= 0 or mode == "none" then return "" end

    local percent = math.floor((current / maximum) * 100 + 0.5)
    if mode == "current" then
        return CompactNumber(current)
    elseif mode == "both" then
        return CompactNumber(current) .. " | " .. tostring(percent) .. "%"
    end
    return tostring(percent) .. "%"
end

local function PositionValueText(fontString, bar, position)
    if not fontString or not bar then return end
    fontString:ClearAllPoints()
    if position == "left" then
        fontString:SetPoint("RIGHT", bar, "LEFT", -4, 0)
        fontString:SetJustifyH("RIGHT")
    else
        fontString:SetPoint("CENTER", bar, "CENTER", 0, 0)
        fontString:SetJustifyH("CENTER")
    end
end

local function PowerColor(unit)
    local powerType, token
    if type(UnitPowerType) == "function" then
        local ok, pType, pToken = pcall(UnitPowerType, unit)
        if ok then powerType, token = pType, pToken end
    end

    local color
    if PowerBarColor then
        color = (token and PowerBarColor[token]) or (powerType ~= nil and PowerBarColor[powerType])
    end
    if color then return color.r or 0.15, color.g or 0.45, color.b or 1 end
    return 0.15, 0.45, 1
end

local function GetAuraData(unit, index, filter)
    if C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if ok and type(aura) == "table" then
            return {
                icon = aura.icon,
                count = aura.applications or aura.charges or 0,
                duration = aura.duration,
                expirationTime = aura.expirationTime,
            }
        end
    end

    local auraFunc = UnitAura
    if filter == "HELPFUL" and type(UnitBuff) == "function" then auraFunc = UnitBuff end
    if filter == "HARMFUL" and type(UnitDebuff) == "function" then auraFunc = UnitDebuff end
    if type(auraFunc) ~= "function" then return nil end

    local ok, name, icon, count, _, duration, expirationTime = pcall(auraFunc, unit, index, filter)
    if not ok or not name then return nil end
    return {
        icon = icon,
        count = count,
        duration = duration,
        expirationTime = expirationTime,
    }
end

local function CreateAuraIcon(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()

    frame.count = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    frame.count:SetPoint("BOTTOMRIGHT", -1, 1)
    frame:Hide()
    return frame
end

local function UpdateAuraIcon(frame, aura, size, harmful)
    if not frame or not aura or IsSecret(aura.icon) then
        if frame then frame:Hide() end
        return
    end

    frame:SetSize(size, size)
    frame.icon:SetTexture(aura.icon)
    frame:SetBackdropBorderColor(harmful and 1 or 0.2, harmful and 0.2 or 0.85, harmful and 0.2 or 0.25, 1)

    local count = aura.count
    if IsSecret(count) then
        frame.count:SetText("")
    else
        count = tonumber(count) or 0
        frame.count:SetText(count > 1 and tostring(count) or "")
    end

    if frame.cooldown and type(frame.cooldown.Clear) == "function" then pcall(frame.cooldown.Clear, frame.cooldown) end
    if frame.cooldown and aura.duration and aura.expirationTime and not IsSecret(aura.duration) and not IsSecret(aura.expirationTime) then
        local duration = tonumber(aura.duration) or 0
        local expiration = tonumber(aura.expirationTime) or 0
        if duration > 0 and expiration > 0 and type(frame.cooldown.SetCooldown) == "function" then
            pcall(frame.cooldown.SetCooldown, frame.cooldown, expiration - duration, duration)
        end
    end

    frame:Show()
end

local function HideAuraPool(pool)
    for _, frame in ipairs(pool or {}) do frame:Hide() end
end

function A:GetOverlay(unit)
    local plate = PlateFor(unit)
    if not plate then return nil end

    local o = plate.__ComfyEnemyBarOverlay
    if o then
        o.unit = unit
        self.plates[plate] = o
        return o
    end

    o = CreateFrame("StatusBar", nil, plate, "BackdropTemplate")
    o:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    if o:GetStatusBarTexture() then o:GetStatusBarTexture():SetAlpha(0) end
    o:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    o:SetBackdropColor(0, 0, 0, 0)
    o:SetBackdropBorderColor(0, 0, 0, 0)

    o.hp = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    o.level = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    o.level:SetPoint("LEFT", o, "RIGHT", 4, 0)

    o.resource = CreateFrame("StatusBar", nil, plate, "BackdropTemplate")
    o.resource:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    o.resource:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    o.resource:SetBackdropColor(0.02, 0.02, 0.02, 0.78)
    o.resource:SetBackdropBorderColor(0, 0, 0, 0.9)
    o.resourceText = o.resource:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

    o.debuffRow = CreateFrame("Frame", nil, plate)
    o.buffRow = CreateFrame("Frame", nil, plate)
    o.debuffIcons, o.buffIcons = {}, {}
    for i = 1, MAX_AURAS do
        o.debuffIcons[i] = CreateAuraIcon(o.debuffRow)
        o.buffIcons[i] = CreateAuraIcon(o.buffRow)
    end

    o.unit = unit
    plate.__ComfyEnemyBarOverlay = o
    self.plates[plate] = o
    return o
end

function A:RestorePlate(plate, overlay)
    if overlay then
        overlay:Hide()
        overlay.resource:Hide()
        overlay.debuffRow:Hide()
        overlay.buffRow:Hide()
        HideAuraPool(overlay.debuffIcons)
        HideAuraPool(overlay.buffIcons)
        RestoreAlpha(overlay.blizzardHealthBar)
        overlay.blizzardHealthBar = nil
    end
    SetDefaultAuraVisibility(plate, false)
end

function A:UpdateAuraRow(overlay, unit, filter, enabled, harmful, anchorFrame, rowIndex)
    local pool = harmful and overlay.debuffIcons or overlay.buffIcons
    local row = harmful and overlay.debuffRow or overlay.buffRow
    if not enabled then
        row:Hide()
        HideAuraPool(pool)
        return anchorFrame
    end

    local size = math.max(12, math.min(26, tonumber(self.db.plate.auraSize) or 16))
    local count = 0
    for i = 1, MAX_AURAS do
        local aura = GetAuraData(unit, i, filter)
        if aura and aura.icon then
            count = count + 1
            local icon = pool[count]
            UpdateAuraIcon(icon, aura, size, harmful)
            icon:ClearAllPoints()
            if count == 1 then
                icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            else
                icon:SetPoint("LEFT", pool[count - 1], "RIGHT", AURA_GAP, 0)
            end
        end
    end

    for i = count + 1, #pool do pool[i]:Hide() end

    if count == 0 then
        row:Hide()
        return anchorFrame
    end

    local width = count * size + math.max(0, count - 1) * AURA_GAP
    row:SetSize(width, size)
    row:ClearAllPoints()
    row:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -2)
    row:Show()
    return row
end

function A:UpdateOverlay(unit)
    if not self.db then return end

    local plate = PlateFor(unit)
    local o = self:GetOverlay(unit)
    if not plate or not o then return end

    local enemy = true
    if type(UnitCanAttack) == "function" then
        local ok, value = pcall(UnitCanAttack, "player", unit)
        if ok and not IsSecret(value) then enemy = value and true or false end
    end

    if not self.db.enabled or not enemy then
        self:RestorePlate(plate, o)
        return
    end

    local c = self.db.plate
    local blizzardHealthBar = FindBlizzardHealthBar(plate)
    if not blizzardHealthBar then
        self:RestorePlate(plate, o)
        return
    end

    if o.blizzardHealthBar and o.blizzardHealthBar ~= blizzardHealthBar then
        RestoreAlpha(o.blizzardHealthBar)
    end
    o.blizzardHealthBar = blizzardHealthBar
    RestoreAlpha(blizzardHealthBar)

    -- Blizzard's aura frame is hidden while ComfyEnemyBar is active so there is
    -- only one configurable buff/debuff presentation.
    SetDefaultAuraVisibility(plate, true)

    local barWidth = tonumber(c.width) or 130
    local barHeight = tonumber(c.height) or 10
    if type(blizzardHealthBar.SetSize) == "function" then
        pcall(blizzardHealthBar.SetSize, blizzardHealthBar, barWidth, barHeight)
    end

    o:ClearAllPoints()
    o:SetPoint("CENTER", blizzardHealthBar, "CENTER", 0, 0)
    o:SetSize(barWidth, barHeight)

    local hp, maxhp = UnitHealth(unit), UnitHealthMax(unit)
    if IsSecret(hp) or IsSecret(maxhp) then
        pcall(o.SetMinMaxValues, o, 0, maxhp)
        pcall(o.SetValue, o, hp)
        o.hp:SetText("")
    else
        hp, maxhp = tonumber(hp) or 0, tonumber(maxhp) or 1
        if maxhp <= 0 then maxhp = 1 end
        o:SetMinMaxValues(0, maxhp)
        o:SetValue(hp)
        o.hp:SetText(ValueText(hp, maxhp, c.healthTextMode))
    end
    PositionValueText(o.hp, o, c.healthTextPosition)

    if c.showLevel then
        local level = UnitLevel(unit)
        if IsSecret(level) then
            o.level:SetText("")
        else
            level = tonumber(level)
            local class = type(UnitClassification) == "function" and UnitClassification(unit) or "normal"
            local suffix = (class == "elite" and "+") or (class == "rareelite" and "R+") or (class == "rare" and "R") or ""
            o.level:SetText(level and level > 0 and (tostring(level) .. suffix) or suffix)
        end
    else
        o.level:SetText("")
    end

    local target = false
    if c.targetHighlight and type(UnitIsUnit) == "function" then
        local ok, value = pcall(UnitIsUnit, unit, "target")
        target = ok and not IsSecret(value) and value and true or false
    end
    if target then
        o:SetBackdropBorderColor(1, 0.82, 0, 1)
    else
        o:SetBackdropBorderColor(0, 0, 0, 0)
    end
    o:Show()

    local auraAnchor = o
    if c.showResource then
        local power, maxPower = UnitPower(unit), UnitPowerMax(unit)
        local showResource = true

        if not IsSecret(maxPower) then
            maxPower = tonumber(maxPower) or 0
            if maxPower <= 0 then showResource = false end
        end

        if showResource then
            o.resource:ClearAllPoints()
            o.resource:SetPoint("TOP", o, "BOTTOM", 0, -2)
            o.resource:SetSize(tonumber(c.width) or 130, tonumber(c.resourceHeight) or 5)

            local r, g, b = PowerColor(unit)
            o.resource:SetStatusBarColor(r, g, b, 0.95)

            if IsSecret(power) or IsSecret(maxPower) then
                pcall(o.resource.SetMinMaxValues, o.resource, 0, maxPower)
                pcall(o.resource.SetValue, o.resource, power)
                o.resourceText:SetText("")
            else
                power = tonumber(power) or 0
                maxPower = tonumber(maxPower) or 1
                o.resource:SetMinMaxValues(0, maxPower)
                o.resource:SetValue(power)
                o.resourceText:SetText(ValueText(power, maxPower, c.resourceTextMode))
            end

            PositionValueText(o.resourceText, o.resource, c.resourceTextPosition)
            o.resource:Show()
            auraAnchor = o.resource
        else
            o.resource:Hide()
        end
    else
        o.resource:Hide()
    end

    auraAnchor = self:UpdateAuraRow(o, unit, "HARMFUL", c.showDebuffs, true, auraAnchor, 1)
    self:UpdateAuraRow(o, unit, "HELPFUL", c.showBuffs, false, auraAnchor, 2)
end

function A:RefreshFeature()
    for plate, overlay in pairs(self.plates) do
        if overlay and overlay.unit then
            self:UpdateOverlay(overlay.unit)
        elseif plate then
            self:RestorePlate(plate, overlay)
        end
    end
end

function A:InitializeFeature()
    local f = CreateFrame("Frame")
    self.enemyEvents = f

    local events = {
        "NAME_PLATE_UNIT_ADDED",
        "NAME_PLATE_UNIT_REMOVED",
        "PLAYER_TARGET_CHANGED",
        "UNIT_HEALTH",
        "UNIT_MAXHEALTH",
        "UNIT_POWER_UPDATE",
        "UNIT_MAXPOWER",
        "UNIT_DISPLAYPOWER",
        "UNIT_AURA",
    }
    for _, event in ipairs(events) do pcall(f.RegisterEvent, f, event) end

    f:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            A:UpdateOverlay(unit)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            local restored = false
            for plate, overlay in pairs(A.plates) do
                if overlay and overlay.unit == unit then
                    A:RestorePlate(plate, overlay)
                    overlay.unit = nil
                    restored = true
                    break
                end
            end
            if not restored then
                local plate = PlateFor(unit)
                local overlay = plate and plate.__ComfyEnemyBarOverlay
                if plate then A:RestorePlate(plate, overlay) end
            end
        elseif event == "PLAYER_TARGET_CHANGED" then
            A:RefreshFeature()
        elseif unit then
            A:UpdateOverlay(unit)
        end
    end)
end

function A:BuildGeneralOptions(page, ui)
    ui.CreateCheck(page, self:T("SHOW_LEVEL"), 20, -90,
        function() return A.db.plate.showLevel end,
        function(v) A.db.plate.showLevel = v end)

    ui.CreateCheck(page, self:T("TARGET_HIGHLIGHT"), 20, -125,
        function() return A.db.plate.targetHighlight end,
        function(v) A.db.plate.targetHighlight = v end)

    ui.CreateCheck(page, self:T("SHOW_RESOURCE"), 20, -160,
        function() return A.db.plate.showResource end,
        function(v) A.db.plate.showResource = v end)

    ui.CreateCheck(page, self:T("SHOW_DEBUFFS"), 20, -195,
        function() return A.db.plate.showDebuffs end,
        function(v) A.db.plate.showDebuffs = v end)

    ui.CreateCheck(page, self:T("SHOW_BUFFS"), 20, -230,
        function() return A.db.plate.showBuffs end,
        function(v) A.db.plate.showBuffs = v end)

    local healthModeLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    healthModeLabel:SetPoint("TOPLEFT", 20, -282)
    healthModeLabel:SetText(self:T("HEALTH_TEXT"))

    ui.CreateDropdown(page, 5, -294, 180,
        function()
            return {
                {value = "none", text = A:T("TEXT_NONE")},
                {value = "percent", text = A:T("TEXT_PERCENT")},
                {value = "current", text = A:T("TEXT_CURRENT")},
                {value = "both", text = A:T("TEXT_BOTH")},
            }
        end,
        function() return A.db.plate.healthTextMode end,
        function(v) A.db.plate.healthTextMode = v end)

    local healthPosLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    healthPosLabel:SetPoint("TOPLEFT", 20, -350)
    healthPosLabel:SetText(self:T("TEXT_POSITION"))

    ui.CreateDropdown(page, 5, -362, 180,
        function()
            return {
                {value = "center", text = A:T("POSITION_CENTER")},
                {value = "left", text = A:T("POSITION_LEFT")},
            }
        end,
        function() return A.db.plate.healthTextPosition end,
        function(v) A.db.plate.healthTextPosition = v end)

    local resourceModeLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    resourceModeLabel:SetPoint("TOPLEFT", 350, -282)
    resourceModeLabel:SetText(self:T("RESOURCE_TEXT"))

    ui.CreateDropdown(page, 335, -294, 180,
        function()
            return {
                {value = "none", text = A:T("TEXT_NONE")},
                {value = "percent", text = A:T("TEXT_PERCENT")},
                {value = "current", text = A:T("TEXT_CURRENT")},
                {value = "both", text = A:T("TEXT_BOTH")},
            }
        end,
        function() return A.db.plate.resourceTextMode end,
        function(v) A.db.plate.resourceTextMode = v end)

    local resourcePosLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    resourcePosLabel:SetPoint("TOPLEFT", 350, -350)
    resourcePosLabel:SetText(self:T("TEXT_POSITION"))

    ui.CreateDropdown(page, 335, -362, 180,
        function()
            return {
                {value = "center", text = A:T("POSITION_CENTER")},
                {value = "left", text = A:T("POSITION_LEFT")},
            }
        end,
        function() return A.db.plate.resourceTextPosition end,
        function(v) A.db.plate.resourceTextPosition = v end)

    ui.CreateSlider(page, self:T("WIDTH"), 90, 220, 5, 35, -445,
        function() return A.db.plate.width end,
        function(v) A.db.plate.width = math.floor(v + 0.5) end,
        function(v) return math.floor(v + 0.5) .. " px" end)

    ui.CreateSlider(page, self:T("HEIGHT"), 6, 24, 1, 365, -445,
        function() return A.db.plate.height end,
        function(v) A.db.plate.height = math.floor(v + 0.5) end,
        function(v) return math.floor(v + 0.5) .. " px" end)

    ui.CreateSlider(page, self:T("AURA_SIZE"), 12, 26, 1, 35, -515,
        function() return A.db.plate.auraSize end,
        function(v) A.db.plate.auraSize = math.floor(v + 0.5) end,
        function(v) return math.floor(v + 0.5) .. " px" end)
end
