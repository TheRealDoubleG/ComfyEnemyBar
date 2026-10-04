ComfyEnemyBar = ComfyEnemyBar or {}
local A = ComfyEnemyBar

A.version = "0.6"
A.buildDate = "04.10.2026"
A.tickSamples = A.tickSamples or {}

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

local function Now()
    if type(GetTimePreciseSec) == "function" then local ok,v=pcall(GetTimePreciseSec); if ok and tonumber(v) then return tonumber(v) end end
    if type(GetTime) == "function" then local ok,v=pcall(GetTime); if ok and tonumber(v) then return tonumber(v) end end
    return 0
end

local function EnsureDefaults()
    if not A.db then return end
    A.db.plate = A.db.plate or {}
    local c = A.db.plate
    local defaults = {
        targetArrow = true,
        targetArrowSize = 16,
        targetArrowOffset = 8,
        targetArrowR = 1.00,
        targetArrowG = 0.25,
        targetArrowB = 0.18,
        targetHealthGlow = false,
        interruptIndicator = true,
        interruptText = false,
        interruptLock = true,
        tickBar = true,
        tickText = true,
        tickValue = true,
        tickHeight = 4,
        showXPNameplate = false,
        showXPTooltip = true,
    }
    for k,v in pairs(defaults) do if c[k] == nil then c[k] = v end end
end

local originalInitializeDB = A.InitializeDB
function A:InitializeDB(...)
    local result
    if originalInitializeDB then result = originalInitializeDB(self, ...) end
    EnsureDefaults()
    return result
end

local function PlateFor(unit)
    if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok then return plate end
    end
end

local function UnitFrameForPlate(plate)
    return plate and (plate.UnitFrame or plate.unitFrame) or nil
end

local function UnitIsTarget(unit)
    if type(UnitIsUnit) ~= "function" then return false end
    local ok, value = pcall(UnitIsUnit, unit, "target")
    if not ok or IsSecret(value) then return false end
    return value and true or false
end

local function EnsureTargetMarker(o)
    if o.targetArrow then return end
    o.targetArrow = o:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    o.targetArrow:SetText("▼")
    o.targetGlow = o:CreateTexture(nil, "OVERLAY")
    o.targetGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    o.targetGlow:SetBlendMode("ADD")
    o.targetGlow:SetPoint("TOPLEFT", o, "TOPLEFT", -1, 1)
    o.targetGlow:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 1, -1)
    o.targetGlow:SetAlpha(0.18)
    o.targetGlow:Hide()
end

local function FindCastBar(plate)
    local uf = UnitFrameForPlate(plate)
    if not uf then return nil end
    local candidates = {
        uf.castBar, uf.CastBar, uf.castbar, uf.CastingBar, uf.castingBar,
        uf.SpellCastBar, uf.spellCastBar,
    }
    for _,bar in pairs(candidates) do
        if bar and type(bar.SetStatusBarColor) == "function" then return bar end
    end
    return nil
end

local function ReadInterruptibility(unit)
    local funcs = {UnitCastingInfo, UnitChannelInfo}
    for _,fn in ipairs(funcs) do
        if type(fn) == "function" then
            local values = {pcall(fn, unit)}
            if values[1] and values[2] then
                -- Classic-style API: notInterruptible is the 8th return value
                -- after the pcall success flag it is usually at index 9.
                local candidate = values[9]
                if type(candidate) ~= "boolean" and values[10] ~= nil then candidate = values[10] end
                if candidate ~= nil and not IsSecret(candidate) and type(candidate) == "boolean" then
                    return candidate and false or true
                end
                return nil
            end
        end
    end
    return nil
end

local function EnsureCastExtras(o, castBar)
    if o.castLock and o.castLock:GetParent() == castBar then return end
    if o.castLock then o.castLock:Hide() end
    if o.castInterruptText then o.castInterruptText:Hide() end
    o.castLock = castBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    o.castLock:SetPoint("LEFT", castBar, "RIGHT", 3, 0)
    o.castLock:SetText("🔒")
    o.castInterruptText = castBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    o.castInterruptText:SetPoint("BOTTOM", castBar, "TOP", 0, 2)
end

local function ApplyCastState(o, unit, plate)
    EnsureDefaults()
    local c = A.db.plate
    local castBar = FindCastBar(plate)
    if not castBar or not c.interruptIndicator then
        if o.castLock then o.castLock:Hide() end
        if o.castInterruptText then o.castInterruptText:Hide() end
        return
    end
    EnsureCastExtras(o, castBar)
    local kickable = ReadInterruptibility(unit)
    if kickable == nil then
        o.castLock:Hide(); o.castInterruptText:Hide(); return
    end
    if kickable then
        pcall(castBar.SetStatusBarColor, castBar, 1.00, 0.68, 0.05, 1)
        o.castLock:Hide()
        if c.interruptText then o.castInterruptText:SetText("Unterbrechbar"); o.castInterruptText:SetTextColor(0.35,1,0.35); o.castInterruptText:Show() else o.castInterruptText:Hide() end
    else
        pcall(castBar.SetStatusBarColor, castBar, 0.55, 0.55, 0.60, 1)
        if c.interruptLock then o.castLock:Show() else o.castLock:Hide() end
        if c.interruptText then o.castInterruptText:SetText("Nicht unterbrechbar"); o.castInterruptText:SetTextColor(1,.35,.25); o.castInterruptText:Show() else o.castInterruptText:Hide() end
    end
end

local function NPCIDFromGUID(guid)
    if type(guid) ~= "string" then return nil end
    return tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
end

local function GetKillRecordForUnit(unit)
    if type(ComfyData) ~= "table" or type(ComfyData.GetKillKey) ~= "function" or type(ComfyData.GetKillRecord) ~= "function" then return nil end
    local guid = type(UnitGUID)=="function" and UnitGUID(unit) or nil
    local name = type(UnitName)=="function" and UnitName(unit) or nil
    local key = ComfyData:GetKillKey({npcID=NPCIDFromGUID(guid),name=name})
    return key and ComfyData:GetKillRecord(key) or nil
end

local function XPPreview(unit)
    local record = GetKillRecordForUnit(unit)
    local avg = record and tonumber(record.averageXP) or nil
    if not avg or avg <= 0 then return nil end
    local current = type(UnitXP)=="function" and tonumber(UnitXP("player")) or nil
    local maximum = type(UnitXPMax)=="function" and tonumber(UnitXPMax("player")) or nil
    local remaining = current and maximum and math.max(0, maximum-current) or nil
    local kills = remaining and avg>0 and math.ceil(remaining/avg) or nil
    return avg, remaining, kills, record
end

local function EnsureXPText(o)
    if o.xpText then return end
    o.xpText = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    o.xpText:SetPoint("TOP", o, "BOTTOM", 0, -9)
    o.xpText:SetTextColor(0.55, 0.85, 1)
end

local function EnsureTickBar(o)
    if o.tickBar then return end
    o.tickBar = CreateFrame("StatusBar", nil, o, "BackdropTemplate")
    o.tickBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    o.tickBar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    o.tickBar:SetBackdropColor(.02,.02,.02,.8); o.tickBar:SetBackdropBorderColor(0,0,0,.9)
    o.tickBar:SetStatusBarColor(.85,.18,.55,.95)
    o.tickText = o.tickBar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    o.tickText:SetPoint("CENTER")
    o.tickBar:Hide()
end

local function BestTickForUnit(unit)
    local guid=type(UnitGUID)=="function" and UnitGUID(unit) or nil
    local spells=guid and A.tickSamples[guid]
    if not spells then return nil end
    local now=Now(); local best,bestRemain
    for spellID,s in pairs(spells) do
        local interval=tonumber(s.intervalAvg)
        if interval and interval>0 and interval<30 and tonumber(s.lastAt) then
            local nextAt=s.lastAt+interval
            local remain=nextAt-now
            if remain>=-0.25 and remain<=interval+0.5 and (not bestRemain or remain<bestRemain) then best=s; best.spellID=spellID; bestRemain=math.max(0,remain) end
        end
    end
    return best,bestRemain
end

local function UpdateTickPreview(o, unit)
    EnsureDefaults(); EnsureTickBar(o)
    local c=A.db.plate
    if not c.tickBar then o.tickBar:Hide(); return end
    local s,remain=BestTickForUnit(unit)
    if not s then o.tickBar:Hide(); return end
    local interval=tonumber(s.intervalAvg) or 1
    o.tickBar:ClearAllPoints(); o.tickBar:SetPoint("BOTTOM",o,"TOP",0,2); o.tickBar:SetSize(tonumber(c.width) or 130,math.max(2,tonumber(c.tickHeight) or 4))
    o.tickBar:SetMinMaxValues(0,interval); o.tickBar:SetValue(math.max(0,math.min(interval,interval-(remain or 0))))
    local parts={}
    if c.tickText then parts[#parts+1]=string.format("%.1fs",remain or 0) end
    if c.tickValue and tonumber(s.amountAvg) then parts[#parts+1]="-"..tostring(math.floor(s.amountAvg+0.5)) end
    o.tickText:SetText(table.concat(parts," | ")); o.tickBar:Show()
    if o.threat and o.threat:IsShown() and c.showThreat and c.threatPosition=="above" then
        o.threat:ClearAllPoints(); o.threat:SetPoint("BOTTOM",o.tickBar,"TOP",0,2)
    end
end

local originalUpdateOverlay = A.UpdateOverlay
function A:UpdateOverlay(unit)
    if originalUpdateOverlay then originalUpdateOverlay(self, unit) end
    if not self.db or not unit then return end
    EnsureDefaults()
    local plate=PlateFor(unit); local o=plate and plate.__ComfyEnemyBarOverlay
    if not plate or not o or not self.db.enabled then return end
    local c=self.db.plate

    -- Replace the thick gold target frame with a small configurable arrow.
    o:SetBackdropBorderColor(0,0,0,0)
    EnsureTargetMarker(o)
    local targeted=UnitIsTarget(unit)
    if targeted and c.targetHighlight and c.targetArrow then
        local font,_,flags=o.targetArrow:GetFont(); o.targetArrow:SetFont(font or STANDARD_TEXT_FONT,math.max(10,tonumber(c.targetArrowSize) or 16),flags)
        o.targetArrow:SetTextColor(tonumber(c.targetArrowR) or 1,tonumber(c.targetArrowG) or .25,tonumber(c.targetArrowB) or .18)
        o.targetArrow:ClearAllPoints(); o.targetArrow:SetPoint("BOTTOM",o,"TOP",0,tonumber(c.targetArrowOffset) or 8); o.targetArrow:Show()
    else o.targetArrow:Hide() end
    if o.targetGlow then o.targetGlow:SetShown(targeted and c.targetHealthGlow==true) end

    EnsureXPText(o)
    if c.showXPNameplate then
        local avg,remaining,kills=XPPreview(unit)
        if avg then
            local text=string.format("ØXP %.0f",avg)
            if kills then text=text.." · ~"..tostring(kills).." Kills" end
            o.xpText:SetText(text); o.xpText:Show()
        else o.xpText:Hide() end
    else o.xpText:Hide() end

    ApplyCastState(o,unit,plate)
    UpdateTickPreview(o,unit)
end

local function RecordPeriodicTick()
    if type(CombatLogGetCurrentEventInfo)~="function" then return end
    local data={CombatLogGetCurrentEventInfo()}
    local subevent=data[2]
    if subevent~="SPELL_PERIODIC_DAMAGE" then return end
    local sourceGUID,destGUID=data[4],data[8]
    local playerGUID=type(UnitGUID)=="function" and UnitGUID("player") or nil
    local petGUID=type(UnitGUID)=="function" and UnitGUID("pet") or nil
    if sourceGUID~=playerGUID and sourceGUID~=petGUID then return end
    local spellID,spellName,amount=tonumber(data[12]),data[13],tonumber(data[15])
    if not destGUID or not spellID or not amount or amount<=0 then return end
    local byGuid=A.tickSamples[destGUID]; if not byGuid then byGuid={}; A.tickSamples[destGUID]=byGuid end
    local s=byGuid[spellID]; if not s then s={samples=0}; byGuid[spellID]=s end
    local now=Now(); local previous=s.lastAt
    s.samples=(tonumber(s.samples) or 0)+1
    s.amountAvg=s.amountAvg and ((s.amountAvg*(s.samples-1)+amount)/s.samples) or amount
    if previous and now>previous then
        local interval=now-previous
        if interval>0.25 and interval<30 then s.intervalAvg=s.intervalAvg and (s.intervalAvg*.65+interval*.35) or interval end
    end
    s.lastAt=now; s.spellName=spellName; s.lastAmount=amount
end

local function HookUnitTooltip()
    if A.__xpTooltipHooked then return end
    A.__xpTooltipHooked=true
    local function add(t)
        if not A.db or not A.db.enabled or not A.db.plate.showXPTooltip or not t or type(t.GetUnit)~="function" then return end
        local _,unit=t:GetUnit(); if not unit then return end
        local avg,remaining,kills,record=XPPreview(unit); if not avg then return end
        t:AddLine(" "); t:AddLine("ComfyEnemyBar XP",.45,.75,1)
        t:AddDoubleLine("Ø beobachtete XP",string.format("%.1f",avg),1,1,1,1,.82,0)
        if remaining then t:AddDoubleLine("Bis Level",tostring(math.floor(remaining+0.5)).." XP",1,1,1,1,1,1) end
        if kills then t:AddDoubleLine("Geschätzt",tostring(kills).." Kills",1,1,1,.45,.85,1) end
        if record and record.xpSamples then t:AddDoubleLine("Messungen",tostring(record.xpSamples),.65,.65,.65,.65,.65,.65) end
        t:Show()
    end
    if TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall)=="function" and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit,function(t) add(t) end)
    elseif GameTooltip and type(GameTooltip.HookScript)=="function" then
        pcall(GameTooltip.HookScript,GameTooltip,"OnTooltipSetUnit",function(t) add(t) end)
    end
end

local originalInitializeFeature=A.InitializeFeature
function A:InitializeFeature(...)
    if originalInitializeFeature then originalInitializeFeature(self,...) end
    EnsureDefaults(); HookUnitTooltip()
    local f=CreateFrame("Frame"); self.enhancementEvents=f
    for _,ev in ipairs({"COMBAT_LOG_EVENT_UNFILTERED","UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_STOP","UNIT_SPELLCAST_INTERRUPTIBLE","UNIT_SPELLCAST_NOT_INTERRUPTIBLE","PLAYER_TARGET_CHANGED"}) do pcall(f.RegisterEvent,f,ev) end
    f:SetScript("OnEvent",function(_,ev,unit)
        if ev=="COMBAT_LOG_EVENT_UNFILTERED" then RecordPeriodicTick(); A:RefreshFeature()
        elseif ev=="PLAYER_TARGET_CHANGED" then A:RefreshFeature()
        elseif unit then A:UpdateOverlay(unit) end
    end)
    f:SetScript("OnUpdate",function(self,elapsed)
        self.elapsed=(self.elapsed or 0)+(tonumber(elapsed) or 0); if self.elapsed<0.10 then return end; self.elapsed=0
        for _,o in pairs(A.plates or {}) do if o and o.unit and o.tickBar and o.tickBar:IsShown() then UpdateTickPreview(o,o.unit) end end
    end)
end

local function Check(parent,text,x,y,get,set)
    local c=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate"); c:SetPoint("TOPLEFT",x,y); local t=c.Text or c.text; if t then t:SetText(text) end; c:SetChecked(get() and true or false)
    c:SetScript("OnClick",function(self) set(self:GetChecked() and true or false); A:RefreshFeature() end); return c
end
local function Slider(parent,name,label,minv,maxv,step,x,y,get,set)
    local s=CreateFrame("Slider",name,parent,"OptionsSliderTemplate"); s:SetPoint("TOPLEFT",x,y); s:SetWidth(210); s:SetMinMaxValues(minv,maxv); s:SetValueStep(step); s:SetObeyStepOnDrag(true)
    _G[name.."Low"]:SetText(tostring(minv)); _G[name.."High"]:SetText(tostring(maxv)); _G[name.."Text"]:SetText(label); s:SetValue(tonumber(get()) or minv)
    s:SetScript("OnValueChanged",function(_,v) set(math.floor((tonumber(v) or minv)+.5)); A:RefreshFeature() end); return s
end

local originalInitializeOptions=A.InitializeOptions
function A:InitializeOptions(...)
    if originalInitializeOptions then originalInitializeOptions(self,...) end
    if self.__enhancementOptions or not self.optionsFrame then return end
    self.__enhancementOptions=true; EnsureDefaults()
    local page=self.optionsFrame.pages and self.optionsFrame.pages[1]; if not page then return end
    local c=self.db.plate
    local title=page:CreateFontString(nil,"ARTWORK","GameFontNormalLarge"); title:SetPoint("TOPLEFT",390,-12); title:SetText("Ziel / Kampf")
    Check(page,"Zielpfeil",390,-48,function() return c.targetArrow end,function(v) c.targetArrow=v end)
    Check(page,"HP subtil hervorheben",535,-48,function() return c.targetHealthGlow end,function(v) c.targetHealthGlow=v end)
    Check(page,"Unterbrechbarkeit färben",390,-82,function() return c.interruptIndicator end,function(v) c.interruptIndicator=v end)
    Check(page,"Schloss wenn nicht kickbar",390,-114,function() return c.interruptLock end,function(v) c.interruptLock=v end)
    Check(page,"Text zur Unterbrechbarkeit",390,-146,function() return c.interruptText end,function(v) c.interruptText=v end)
    Check(page,"DoT-Tick-Balken",390,-190,function() return c.tickBar end,function(v) c.tickBar=v end)
    Check(page,"Zeit anzeigen",390,-222,function() return c.tickText end,function(v) c.tickText=v end)
    Check(page,"Tick-Schaden anzeigen",535,-222,function() return c.tickValue end,function(v) c.tickValue=v end)
    Check(page,"Gelernte XP auf Nameplate",390,-264,function() return c.showXPNameplate end,function(v) c.showXPNameplate=v end)
    Check(page,"Gelernte XP im Tooltip",390,-296,function() return c.showXPTooltip end,function(v) c.showXPTooltip=v end)
    Slider(page,"ComfyEnemyArrowSize","Pfeilgröße",10,28,1,405,-365,function() return c.targetArrowSize end,function(v) c.targetArrowSize=v end)
    Slider(page,"ComfyEnemyTickHeight","Tick-Balkenhöhe",2,8,1,405,-440,function() return c.tickHeight end,function(v) c.tickHeight=v end)
end
