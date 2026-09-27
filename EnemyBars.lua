ComfyEnemyBar = ComfyEnemyBar or {}
local A = ComfyEnemyBar
A.plates = A.plates or setmetatable({}, {__mode="k"})

local function IsSecret(v)
    if type(issecretvalue)=="function" then local ok,x=pcall(issecretvalue,v); if ok then return x and true or false end end
    if type(canaccessvalue)=="function" then local ok,x=pcall(canaccessvalue,v); if ok then return not x end end
    return false
end

local function PlateFor(unit)
    if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit)=="function" then
        local ok,p=pcall(C_NamePlate.GetNamePlateForUnit,unit)
        if ok then return p end
    end
end

function A:GetOverlay(unit)
    local plate=PlateFor(unit)
    if not plate then return nil end
    local o=plate.__ComfyEnemyBarOverlay
    if o then o.unit=unit; self.plates[plate]=o; return o end
    o=CreateFrame("StatusBar",nil,plate,"BackdropTemplate")
    o:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    o:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    o:SetBackdropColor(0.02,0.02,0.02,0.78); o:SetBackdropBorderColor(0,0,0,0.9)
    o:SetStatusBarColor(0.72,0.08,0.08,0.95)
    o.hp=o:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); o.hp:SetPoint("CENTER")
    o.level=o:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); o.level:SetPoint("LEFT",o,"RIGHT",4,0)
    o.unit=unit; plate.__ComfyEnemyBarOverlay=o; self.plates[plate]=o
    return o
end

function A:UpdateOverlay(unit)
    if not self.db then return end
    local o=self:GetOverlay(unit); if not o then return end
    if not self.db.enabled then o:Hide(); return end
    if type(UnitCanAttack)=="function" then
        local ok,enemy=pcall(UnitCanAttack,"player",unit)
        if ok and not IsSecret(enemy) and not enemy then o:Hide(); return end
    end
    local c=self.db.plate
    o:ClearAllPoints(); o:SetPoint("BOTTOM",o:GetParent(),"TOP",0,tonumber(c.yOffset) or 14)
    o:SetSize(tonumber(c.width) or 130,tonumber(c.height) or 10)
    local hp,maxhp=UnitHealth(unit),UnitHealthMax(unit)
    if IsSecret(hp) or IsSecret(maxhp) then
        pcall(o.SetMinMaxValues,o,0,maxhp); pcall(o.SetValue,o,hp); o.hp:SetText("")
    else
        hp,maxhp=tonumber(hp) or 0,tonumber(maxhp) or 1; if maxhp<=0 then maxhp=1 end
        o:SetMinMaxValues(0,maxhp); o:SetValue(hp)
        o.hp:SetText(c.showHealthPercent and string.format("%d%%",math.floor((hp/maxhp)*100+0.5)) or "")
    end
    if c.showLevel then
        local level=UnitLevel(unit)
        if IsSecret(level) then
            o.level:SetText("")
        else
            level=tonumber(level)
            local class=type(UnitClassification)=="function" and UnitClassification(unit) or "normal"
            local suffix=(class=="elite" and "+") or (class=="rareelite" and "R+") or (class=="rare" and "R") or ""
            o.level:SetText(level and level>0 and (tostring(level)..suffix) or suffix)
        end
    else o.level:SetText("") end
    local target=false
    if c.targetHighlight and type(UnitIsUnit)=="function" then
        local ok,v=pcall(UnitIsUnit,unit,"target")
        target=ok and not IsSecret(v) and v and true or false
    end
    if target then o:SetBackdropBorderColor(1,0.82,0,1); o:SetStatusBarColor(1,0.18,0.08,1)
    else o:SetBackdropBorderColor(0,0,0,0.9); o:SetStatusBarColor(0.72,0.08,0.08,0.95) end
    o:Show()
end

function A:RefreshFeature()
    for _,o in pairs(self.plates) do if o and o.unit then self:UpdateOverlay(o.unit) end end
end

function A:InitializeFeature()
    local f=CreateFrame("Frame"); self.enemyEvents=f
    for _,e in ipairs({"NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","PLAYER_TARGET_CHANGED","UNIT_HEALTH","UNIT_MAXHEALTH"}) do pcall(f.RegisterEvent,f,e) end
    f:SetScript("OnEvent",function(_,event,unit)
        if event=="NAME_PLATE_UNIT_ADDED" then A:UpdateOverlay(unit)
        elseif event=="NAME_PLATE_UNIT_REMOVED" then local p=PlateFor(unit); local o=p and p.__ComfyEnemyBarOverlay; if o then o:Hide() end
        elseif event=="PLAYER_TARGET_CHANGED" then A:RefreshFeature()
        elseif unit then A:UpdateOverlay(unit) end
    end)
end

function A:BuildGeneralOptions(page,ui)
    ui.CreateCheck(page,self:T("SHOW_HP"),20,-90,function() return A.db.plate.showHealthPercent end,function(v) A.db.plate.showHealthPercent=v end)
    ui.CreateCheck(page,self:T("SHOW_LEVEL"),20,-125,function() return A.db.plate.showLevel end,function(v) A.db.plate.showLevel=v end)
    ui.CreateCheck(page,self:T("TARGET_HIGHLIGHT"),20,-160,function() return A.db.plate.targetHighlight end,function(v) A.db.plate.targetHighlight=v end)
    ui.CreateSlider(page,self:T("WIDTH"),80,220,5,35,-230,function() return A.db.plate.width end,function(v) A.db.plate.width=math.floor(v+0.5) end,function(v) return math.floor(v+0.5).." px" end)
    ui.CreateSlider(page,self:T("HEIGHT"),6,24,1,35,-300,function() return A.db.plate.height end,function(v) A.db.plate.height=math.floor(v+0.5) end,function(v) return math.floor(v+0.5).." px" end)
    ui.CreateSlider(page,self:T("Y_OFFSET"),-20,50,1,35,-370,function() return A.db.plate.yOffset end,function(v) A.db.plate.yOffset=math.floor(v+0.5) end,function(v) return math.floor(v+0.5).." px" end)
    local n=page:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); n:SetPoint("TOPLEFT",20,-450); n:SetWidth(680); n:SetJustifyH("LEFT"); n:SetText(self:T("FOREVER_NOTE"))
end
