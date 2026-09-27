local ADDON_NAME = ...

ComfyEnemyBar = ComfyEnemyBar or {}
local A = ComfyEnemyBar

A.name = ADDON_NAME or "ComfyEnemyBar"
A.version = "0.1"
A.buildDate = "27.09.2026"
A.status = "Beta"
A.gameVersion = "WoW Forever 1.60.1"
A.targetBuild = "70009"
A.interface = 16001
A.author = "TheRealDoubleG"
A.discord = "the.real.double.g"
A.github = "https://github.com/TheRealDoubleG/ComfyEnemyBar"

local defaults = {
    enabled = true,
    plate = {
        width = 130,
        height = 10,
        yOffset = 14,
        showHealthPercent = true,
        showLevel = true,
        targetHighlight = true,
    },
    optionsWindow = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 20,
    },
    ui = {
        windowLocked = false,
        windowOpacity = 100,
        showWindowBorder = true,
        backgroundAlpha = 92,
    },
}

local function CopyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do dst[k] = CopyTable(v) end
    return dst
end

local function ApplyDefaults(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ApplyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function A:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200ComfyEnemyBar:|r " .. tostring(msg))
    end
end

function A:GetClientBuildInfo()
    if type(GetBuildInfo) ~= "function" then return "?", "?", "?", nil end
    local version, build, buildDate, interface = GetBuildInfo()
    return tostring(version or "?"), tostring(build or "?"), tostring(buildDate or "?"), tonumber(interface)
end

function A:GetCompatibilityStatus()
    local _, _, _, current = self:GetClientBuildInfo()
    if current and tonumber(current) == tonumber(self.interface) then
        return true, self:T("COMPAT_MATCH")
    end
    return false, self:T("COMPAT_UPDATE_REQUIRED")
end

function A:InitializeDB()
    if self.InitializeProfileStorage then
        self:InitializeProfileStorage(defaults, "ComfyEnemyBarDB")
    else
        if type(_G["ComfyEnemyBarDB"]) ~= "table" then
            _G["ComfyEnemyBarDB"] = CopyTable(defaults)
        else
            ApplyDefaults(_G["ComfyEnemyBarDB"], defaults)
        end
        self.db = _G["ComfyEnemyBarDB"]
    end
end

function A:SetEnabled(value)
    if not self.db then return false end
    self.db.enabled = value and true or false
    if self.RefreshFeature then self:RefreshFeature() end
    if self.RefreshOptions then self:RefreshOptions() end
    return true
end

function A:GetComfyProfileProvider()
    return self
end

function A:OpenOptions()
    if self.ShowOptions then self:ShowOptions() end
end

SLASH_COMFYENEMYBAR1 = "/comfyenemybar"
SLASH_COMFYENEMYBAR2 = "/ceb"
SlashCmdList.COMFYENEMYBAR = function(msg)
    msg = tostring(msg or ""):lower():match("^%s*(.-)%s*$")
    if A.HandleSlash and A:HandleSlash(msg) then return end
    A:OpenOptions()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == A.name then
        A:InitializeDB()
        if A.InitializeFeature then A:InitializeFeature() end
        if A.InitializeOptions then A:InitializeOptions() end
    elseif event == "PLAYER_LOGIN" then
        if A.RefreshFeature then A:RefreshFeature() end
    end
end)
