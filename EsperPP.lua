-----------------------------------------------------------------------------------------------
-- EsperPP
-- Not so basic Esper helper by Caleb - calebzor@gmail.com
-----------------------------------------------------------------------------------------------

--[[
    TODO:
        play sound when reahing 5 pp
        more CB customization
        font customization
        psi charge tracking through buff window container
        move EVERYTHING to GeminiGUI
        localization
        move options to it's own file
]]--

local sVersion = "8.1.0.36"

require "Window"
require "GameLib"
require "CColor"
require "ActionSetLib"
require "AbilityBook"

-----------------------------------------------------------------------------------------------
-- Upvalues
-----------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local tonumber = tonumber
local string = string
local ipairs = ipairs
local table = table
local GameLib = GameLib
local Apollo = Apollo
local CColor = CColor
local ActionSetLib = ActionSetLib
local AbilityBook = AbilityBook
local Print = Print
local unpack = unpack
local math = math

-----------------------------------------------------------------------------------------------
-- Package loading
-----------------------------------------------------------------------------------------------
local addon = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("EsperPP", false, {}, "Gemini:Timer-1.0")
local GeminiColor = Apollo.GetPackage("GeminiColor").tPackage
local GeminiGUI = Apollo.GetPackage("Gemini:GUI-1.0").tPackage
local GeminiConfig = Apollo.GetPackage("Gemini:Config-1.0").tPackage
local GeminiColor = Apollo.GetPackage("GeminiColor").tPackage
--local GeminiCmd = Apollo.GetPackage("Gemini:ConfigCmd-1.0").tPackage
local L = Apollo.GetPackage("Gemini:Locale-1.0").tPackage:GetLocale("EsperPP", true)

-----------------------------------------------------------------------------------------------
-- Locals and defaults
-----------------------------------------------------------------------------------------------
local uPlayer = nil

--local function hexToCColor(color, a)
--  if not a then a = 1 end
--  local r = tonumber(string.sub(color,1,2), 16) / 255
--  local g = tonumber(string.sub(color,3,4), 16) / 255
--  local b = tonumber(string.sub(color,5,6), 16) / 255
--  return CColor.new(r,g,b,a)
--end
--
--local tColor = {
--  xkcdAquaBlue = hexToCColor("02d8e9"),
--  xkcdAlgaeGreen = hexToCColor("21c36f"),
--  yellow = hexToCColor("fff600"),
--  orange = hexToCColor("feb408"),
--  red = hexToCColor("c6002a"),
--  green = hexToCColor("01a825"),
--  blue = hexToCColor("00b0d8"),
--}

local defaults = {
    profile = {
        tPos = {},
        tFocusPos = {},
        focusBarColor = {0.13,0.76,0.44,1},
        focusBarBackgroundColor = {0.78,0,0.16,1},
        focusFontStyle = 6,
        focusTextStyle = 1,
        focusTextColor = {1,1,1,1},
        nFocusOpacity = 0.7,
        bReactiveFocusColor = false,
        reactiveFocusBarColorOver75Percent = {0,0.63,0.77,1},
        reactiveFocusBarColorOver50Below75Percent = {1,0.96,0,1},
        reactiveFocusBarColorOver25Below50Percent =  {1,0.71,0.03,1},
        reactiveFocusBarColorBelow25Percent = {0.78,0,0.16,1},
        bShow0pp = false,
        bShowFullEffect = true,
        ppColor0 = {0.01,0.85,0.91,1},
        ppColor1 = {0.01,0.85,0.91,1},
        ppColor2 = {0.01,0.85,0.91,1},
        ppColor3 = {0.01,0.85,0.91,1},
        ppColor4 = {1,0.96,0,1},
        ppColor5 = {0.78,0,0.16,1},
        ppColorOOC = {0.13,0.76,0.44,1},
        bShowCB = true,
    }
}

-----------------------------------------------------------------------------------------------
-- Options tables
-----------------------------------------------------------------------------------------------

local tMyFontTable = {}
for nIndex,font in ipairs(Apollo.GetGameFonts()) do
    tMyFontTable[nIndex] = font.name
end

local tFocusTextStyle = {
    "None",
    "Percentage",
    "Default",
    "Current",
}

local tFocusTextStyleFormat = {
    none = "",
    perc = "%d%%",
    def = "%d/%d",
    currOnly = "%d",
}

local function formatFocusText(formatType, nCurr, nMax)
    if not nCurr or not nMax then return "" end
    if formatType == "def" then
        return tFocusTextStyleFormat[formatType]:format(nCurr, nMax)
    elseif formatType == "perc" then
        return tFocusTextStyleFormat[formatType]:format(math.floor(nCurr/nMax*100))
    elseif formatType == "currOnly" then
        return tFocusTextStyleFormat[formatType]:format(nCurr)
    elseif formatType == "none" then
        return ""
    end
end

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function addon:OnInitialize()
    self.db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(self, defaults)

    self.myOptionsTable = {
        type = "group",
        args = {
            locked = {
                order = 1,
                name = "Lock/Unlock all anchors",
                type = "toggle",
                width = "full",
                get = function(info) return self.db.profile[info[#info]] end,
                set = function(info, v) self.db.profile[info[#info]] = v; addon:LockUnlock(v) end,
            },
            focusBar = {
                order = 10,
                name = "Focus bar",
                type = "group",
                args={
                    focusHeader = {
                        order = 1,
                        name = "Focus bar settings",
                        type = "header",
                    },
                    nFocusOpacity = {
                        order = 5,
                        name = "Focus opacity",
                        type = "range",
                        min = 0,
                        max = 1,
                        step = 0.01,
                        width = "full",
                        get = function(info) return self.db.profile[info[#info]] end,
                        set = function(info, v) self.db.profile[info[#info]] = v;
                            local r,g,b = unpack(self.db.profile.focusBarColor)
                            self.wFocus:FindChild("FocusProgress"):SetBarColor(CColor.new(r,g,b,v))
                            r,g,b = unpack(self.db.profile.focusBarBackgroundColor)
                            self.wFocus:FindChild("FocusProgress"):SetBGColor(CColor.new(r,g,b,v))
                        end,
                    },
                    focusBarColor = {
                        order = 10,
                        name = "Fill color",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a}; self.wFocus:FindChild("FocusProgress"):SetBarColor(CColor.new(r,g,b,self.db.profile.nFocusOpacity)) end,
                    },
                    focusBarBackgroundColor = {
                        order = 20,
                        name = "Background color",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a}; self.wFocus:FindChild("FocusProgress"):SetBGColor(CColor.new(r,g,b,self.db.profile.nFocusOpacity)) end,
                    },
                    focusTextColor = {
                        order = 25,
                        name = "Text color",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a}; self.wFocus:FindChild("FocusProgress"):SetTextColor(CColor.new(r,g,b,a)) end,
                    },
                    --focusFontStyle = {
                    --  order = 30,
                    --  width = "full",
                    --  name = "Font style",
                    --  type = "select",
                    --  values = tMyFontTable,
                    --  style = "dropdown",
                    --  get = function(info) return self.db.profile[info[#info]] end,
                    --  set = function(info, v) self.db.profile[info[#info]] = v; self.wFocus:FindChild("FocusProgress"):SetFont(v) end,
                    --},
                    --focusTextStyle = {
                    --  order = 50,
                    --  width = "full",
                    --  name = "Text style",
                    --  type = "select",
                    --  values = tFocusTextStyle,
                    --  style = "dropdown",
                    --  get = function(info) return self.db.profile[info[#info]] end,
                    --  set = function(info, v) self.db.profile[info[#info]] = v end,
                    --},
                    reactiveFocusColorsHeader = {
                        order = 100,
                        name = "Reactive coloring",
                        type = "header",
                    },
                    bReactiveFocusColor = {
                        order = 110,
                        name = "Reactive focus color",
                        desc = "Color the focus bar's background based on how much focus you have currently.",
                        type = "toggle",
                        width = "full",
                        get = function(info) return self.db.profile[info[#info]] end,
                        set = function(info, v) self.db.profile[info[#info]] = v end,
                    },
                    reactiveFocusBarColorOver75Percent = {
                        width = "full",
                        order = 120,
                        name = "Reactive focus bar color over 75%",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a} end,
                    },
                    reactiveFocusBarColorOver50Below75Percent = {
                        width = "full",
                        order = 130,
                        name = "Reactive focus bar color over 50% below 75%",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a} end,
                    },
                    reactiveFocusBarColorOver25Below50Percent = {
                        width = "full",
                        order = 140,
                        name = "Reactive focus bar color over 25% below 50%",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a} end,
                    },
                    reactiveFocusBarColorBelow25Percent = {
                        width = "full",
                        order = 150,
                        name = "Reactive focus bar color below 25%",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a} end,
                    },
                }
            },
            psiPoints = {
                order = 20,
                name = "Psi points",
                type = "group",
                args={
                    bShow0pp = {
                        order = 1,
                        name = "Show 0 psi point",
                        desc = "Show 0 psi point too.",
                        type = "toggle",
                        width = "full",
                        get = function(info) return self.db.profile[info[#info]] end,
                        set = function(info, v) self.db.profile[info[#info]] = v end,
                    },
                    bShowFullEffect = {
                        order = 1,
                        name = "Show full effect",
                        desc = "Show extra effect when you have the maximum possible psi points.",
                        type = "toggle",
                        width = "full",
                        get = function(info) return self.db.profile[info[#info]] end,
                        set = function(info, v) self.db.profile[info[#info]] = v end,
                    },
                    psiPointColoringHeader = {
                        order = 4,
                        name = "Psi point coloring",
                        type = "header",
                    },
                    ppColor0 = {
                        width = "full",
                        order = 5,
                        name = "Color for 0 psi point",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a} end,
                    },
                    ppColor1 = {
                        width = "full",
                        order = 10,
                        name = "Color for 1 psi point",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a} end,
                    },
                    ppColor2 = {
                        width = "full",
                        order = 20,
                        name = "Color for 2 psi point",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a} end,
                    },
                    ppColor3 = {
                        width = "full",
                        order = 30,
                        name = "Color for 3 psi point",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a} end,
                    },
                    ppColor4 = {
                        width = "full",
                        order = 40,
                        name = "Color for 4 psi point",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a} end,
                    },
                    ppColor5 = {
                        width = "full",
                        order = 50,
                        name = "Color for 5 psi point",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a} end,
                    },
                    ppColorOOC = {
                        width = "full",
                        order = 50,
                        name = "Color for psi points while out of combat",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a} end,
                    },
                },
            },
            CB = {
                order = 30,
                name = "Concentrated Blade",
                type = "group",
                args={
                    concentratedBladeHeader = {
                        order = 1,
                        name = "Concentrated Blade options",
                        type = "header",
                    },
                    bShowCB = {
                        order = 1,
                        name = "Show concentrated blade timers",
                        type = "toggle",
                        width = "full",
                        get = function(info) return self.db.profile[info[#info]] end,
                        set = function(info, v) self.db.profile[info[#info]] = v end,
                    },
                },
            },
        }
    }
end

function addon:OnEnable()
    if GameLib.GetPlayerUnit():GetClassId() ~= GameLib.CodeEnumClass.Esper then return end -- not esper

    GeminiConfig:RegisterOptionsTable("EsperPP", self.myOptionsTable)

    Apollo.RegisterSlashCommand("EsperPP", "OpenMenu", self)
    Apollo.RegisterSlashCommand("esperpp", "OpenMenu", self)
    Apollo.RegisterSlashCommand("epp", "OpenMenu", self)

    self.wAnchor = Apollo.LoadForm("EsperPP.xml", "Anchor", nil, self)

    self.wFocus = Apollo.LoadForm("EsperPP.xml", "Focus", nil, self)
    self.wFocus:Show(true)
    local r,g,b = unpack(self.db.profile.focusBarColor)
    self.wFocus:FindChild("FocusProgress"):SetBarColor(CColor.new(r,g,b,self.db.profile.nFocusOpacity))
    r,b,g = unpack(self.db.profile.focusBarBackgroundColor)
    self.wFocus:FindChild("FocusProgress"):SetBGColor(CColor.new(r,g,b,self.db.profile.nFocusOpacity))
    self.wFocus:FindChild("FocusProgress"):SetTextColor(CColor.new(unpack(self.db.profile.focusTextColor)))
    --self.wFocus:FindChild("FocusProgress"):SetFont(self.db.proifle.focusFont)

    self.wDisplay = Apollo.LoadForm("EsperPP.xml", "Display", nil, self)
    self.wDisplay:Show(true)

    Apollo.RegisterEventHandler("AbilityBookChange", "OnAbilityBookChange", self)
    Apollo.RegisterEventHandler("VarChange_FrameCount", "OnUpdate", self)

    self.splCB = nil
    self.tCBChargeData = nil
    self.tCBTracker = {}


    self.nMyTime = 1
    self.fastTimer = self:ScheduleRepeatingTimer("FastTimer", 0.1)
    --Apollo.RegisterTimerHandler("FastTimer", "FastTimer", self)
    --Apollo.CreateTimer("FastTimer", 0.1, true)

    self.abilityBookTimer = self:ScheduleRepeatingTimer("DelayedAbilityBookCheck", 1)

    if self.db.profile.tPos then
        if self.db.profile.tPos.anchor then
            self.wAnchor:SetAnchorOffsets(self.db.profile.tPos.anchor.l, self.db.profile.tPos.anchor.t, self.db.profile.tPos.anchor.r, self.db.profile.tPos.anchor.b)
            self:RepositionDisplay()
        end
    end
    self.wAnchor:Show(self.db.profile.locked)

    self.wFocus:FindChild("Header"):Show(not self.db.profile.bFocusLocked)
    self.wFocus:SetStyle("Moveable", not self.db.profile.bFocusLocked)
    self.wFocus:SetStyle("Sizable", not self.db.profile.bFocusLocked)

    if self.db.profile.tFocusPos then
        if self.db.profile.tFocusPos then
            self.wFocus:SetAnchorOffsets(self.db.profile.tFocusPos.l, self.db.profile.tFocusPos.t, self.db.profile.tFocusPos.r, self.db.profile.tFocusPos.b)
        end
    end
    self.wFocus:Show(self.db.profile.bFocusShown)




    --Apollo.GetPackage("Gemini:ConfigDialog-1.0").tPackage:Open("EsperPP")
end

-----------------------------------------------------------------------------------------------
-- Ability related functions
-----------------------------------------------------------------------------------------------

function addon:getCBSpellIds()
    local tList = AbilityBook.GetAbilitiesList()
    for nIndex, tData in ipairs(tList) do
        if tData.nId == 28756 then
            for nTier, tTierData in ipairs(tData.tTiers) do
                Print(("Tier: %d - nSpellId: %d"):format(nTier, tTierData.splObject:GetId()))
            end
        end
    end
end

do
    local tTempAbilityWindowDef = {
        Class = "AbilityItemWindow",
        ListItem = false,
        IgnoreMouse = true,
        Name = "TempAbilityWindow",
        SwallowMouseClicks = true,
        Visible = false,
    }
    -- utility function that gets the spellId from abilityId
    function addon:GetTieredSpellIdFromLasAbilityId(nAbilityId)
        -- this only works for abilities the player can cast
        --local wAbility = Apollo.LoadForm("EsperPP.xml", "TempAbilityWindow", nil, self)
        -- this should be faster than loading xmls
        local wAbility = GeminiGUI:Create("AbilityItemWindow", tTempAbilityWindowDef):GetInstance()
        wAbility:SetAbilityId(nAbilityId)
        local sSpellId = wAbility:GetAbilityTierId()
        wAbility:Destroy()
        return sSpellId
    end
end

function addon:DelayedAbilityBookCheck()
    local tCurrLAS = ActionSetLib.GetCurrentActionSet()
    local nSpellId
    if tCurrLAS then
        for nIndex, nAbilityId in ipairs(tCurrLAS) do
            if nAbilityId == 28756 then -- Concentrated Blades
                nSpellId = self:GetTieredSpellIdFromLasAbilityId(nAbilityId)
                if self.abilityBookTimer then
                    self:CancelTimer(self.abilityBookTimer)
                    self.abilityBookTimer = nil
                end
            end
        end
    else
        if not self.abilityBookTimer then
            self.abilityBookTimer = self:ScheduleRepeatingTimer("DelayedAbilityBookCheck", 1)
        end
        --Apollo.CreateTimer("DelayedAbilityBookCheck", 1, false)
    end
    if nSpellId then
        self.splCB = GameLib.GetSpell(nSpellId)
        if self.splCB then
            self.tCBChargeData = self.splCB:GetAbilityCharges()
        end
    else
        self.splCB = nil
        self.tCBChargeData = nil
        for i=1, 3 do
            local bar = self.wDisplay:FindChild(("ProgressBar%d"):format(i))
            bar:Show(false)
        end
    end
end

function addon:OnAbilityBookChange()
    -- have to do this because if you get ability list at this event then it will return what you had not what you have right now.
    --Apollo.CreateTimer("DelayedAbilityBookCheck", 0.2, false)
    self:ScheduleTimer("DelayedAbilityBookCheck", 0.2)
end

-----------------------------------------------------------------------------------------------
-- Updaters
-----------------------------------------------------------------------------------------------

function addon:FastTimer()
    self.nMyTime = self.nMyTime + 1
end

function addon:OnUpdate()
    local uPlayer = GameLib.GetPlayerUnit()
    if not uPlayer then return end
    if uPlayer:GetClassId() ~= GameLib.CodeEnumClass.Esper then self.wDisplay:Show(false) self.wAnchor:Show(false) return end -- not esper
    self.wDisplay:Show(true)
    local nPP = uPlayer:GetResource(1)
    self.wDisplay:FindChild("Text"):SetText((self.db.profile.bShow0pp or nPP > 0) and nPP or "")
    self.wDisplay:GetName()
    self.wDisplay:FindChild("Full"):Show((self.db.profile.bShowFullEffect and nPP == uPlayer:GetMaxResource(1)) and true or false)

    -- PP tracking
    if uPlayer:IsInCombat() then
        self.wDisplay:FindChild("Text"):SetTextColor(CColor.new(unpack(self.db.profile["ppColor"..nPP])))
    else
        self.wDisplay:FindChild("Text"):SetTextColor(CColor.new(unpack(self.db.profile.ppColorOOC)))
    end

    -- T8 builder stack tracking
    -- buff or API is bugged and does not show up among the return values
    --local tBuffs = uPlayer:GetBuffs().arBeneficial
    --if tBuffs then
    --  if
    --  /eval for index, tData in pairs(GameLib.GetPlayerUnit():GetBuffs().arBeneficial) do Print(tData.splEffect:GetName() .. " " .. tData.splEffect:GetId()) end
    --  /eval Print(#GameLib.GetPlayerUnit():GetBuffs().arBeneficial)
    --else
    --  self.wDisplay:FindChild("T8stack"):Show(false)
    --end
    -- CB tracking
    if self.db.profile.bShowCB and self.splCB and self.tCBChargeData and self.nMyTime then -- this also works as a check if CB is even on the LAS because if it is not then this is nil
        -- clean up the tracking data before adding a new entry
        if self.tCBTracker[1] and self.nMyTime > self.tCBTracker[1].nEndTime then table.remove(self.tCBTracker, 1) end
        if self.tCBTracker[2] and self.nMyTime > self.tCBTracker[2].nEndTime then table.remove(self.tCBTracker, 2) end
        if self.tCBTracker[3] and self.nMyTime > self.tCBTracker[3].nEndTime then table.remove(self.tCBTracker, 3) end

        local tChargeData = self.splCB:GetAbilityCharges()
        if tChargeData.nChargesRemaining < self.tCBChargeData.nChargesRemaining then
            local tTrackingData = {}
            tTrackingData.nStartTime = self.nMyTime
            -- tier 4 or higher so it hits after 3.4 sec not 4.4
            tTrackingData.nEndTime = (self.splCB:GetId() > 52023) and self.nMyTime+3.4*10 or self.nMyTime+4.4*10

            self.tCBTracker[#self.tCBTracker+1] = tTrackingData
        end
        self.tCBChargeData = tChargeData

        for i=1, 3 do
            local bar = self.wDisplay:FindChild(("ProgressBar%d"):format(i))
            if self.tCBTracker[i] then
                bar:Show(true)
                bar:SetMax(self.tCBTracker[i].nEndTime-self.tCBTracker[i].nStartTime)
                bar:SetProgress(self.nMyTime-self.tCBTracker[i].nStartTime)
            else
                bar:Show(false)
            end
        end
    end

    if self.wFocus and self.wFocus:IsShown() then
        local bar = self.wFocus:FindChild("FocusProgress")
        local nCurr, nMax = uPlayer:GetMana(), uPlayer:GetMaxMana()
        bar:SetMax(nMax)
        bar:SetProgress(nCurr)
        --bar:SetText(formatFocusText(self.db.profile.focusTextStyle), nCurr, nMax)
        bar:SetText(math.floor(nCurr))
        if self.db.profile.bReactiveFocusColor then
            local r,g,b
            if ((nCurr / nMax) <= 0.25) then -- Reactive Color Change on Focus Loss
                r,g,b = unpack(self.db.profile.reactiveFocusBarColorBelow25Percent)
                self.wFocus:FindChild("FocusProgress"):SetBGColor(CColor.new(r,g,b,self.db.profile.nFocusOpacity))
            elseif ((nCurr / nMax) <= 0.50) then
                r,g,b = unpack(self.db.profile.reactiveFocusBarColorOver25Below50Percent)
                self.wFocus:FindChild("FocusProgress"):SetBGColor(CColor.new(r,g,b,self.db.profile.nFocusOpacity))
            elseif ((nCurr / nMax) <= 0.75) then
                r,g,b = unpack(self.db.profile.reactiveFocusBarColorOver50Below75Percent)
                self.wFocus:FindChild("FocusProgress"):SetBGColor(CColor.new(r,g,b,self.db.profile.nFocusOpacity))
            else
                r,g,b = unpack(self.db.profile.reactiveFocusBarColorOver75Percent)
                self.wFocus:FindChild("FocusProgress"):SetBGColor(CColor.new(r,g,b,self.db.profile.nFocusOpacity))
            end
        end
    end

end

-----------------------------------------------------------------------------------------------
-- Window management
-----------------------------------------------------------------------------------------------

function addon:LockUnlock(bValue)
    self.wAnchor:Show(bValue)
    self.db.profile.bFocusLocked = not bValue
    if bValue then
        self.wFocus:Show(true)
    end
    self.db.profile.bFocusShown = self.wFocus:IsShown()
    self.wFocus:FindChild("Header"):Show(bValue)
    self.wFocus:SetStyle("Moveable", bValue)
    self.wFocus:SetStyle("Sizable", bValue)
end

function addon:OpenMenu(_, input)
  -- Assuming "MyOptions" is the appName of a valid options table
    Apollo.GetPackage("Gemini:ConfigDialog-1.0").tPackage:Open("EsperPP")
    --if not input or input:trim() == "" then
    --LibStub("AceConfigDialog-3.0"):Open("MyOptions")
    --else
    --LibStub("AceConfigCmd-3.0").HandleCommand(MyAddon, "mychat", "MyOptions", input)
    --end
end

function addon:RepositionDisplay()
    local l,t,r,b = self.wAnchor:GetAnchorOffsets()
    self.wDisplay:SetAnchorOffsets(l, b, l+94, b+111) -- This has to be updated if the frame is resized in houston ( or probably should look into move to position or something)
end

function addon:OnAnchorMove(wHandler)
    local l,t,r,b = self.wAnchor:GetAnchorOffsets()
    self.db.profile.tPos.anchor = { l = l, t = t, r = r, b = b}
    self:RepositionDisplay()
end

function addon:FocusMoveOrScale()
    local l,t,r,b = self.wFocus:GetAnchorOffsets()
    self.db.profile.tFocusPos = { l = l, t = t, r = r, b = b}
end

function addon:OnFocusLockButton(wHandler)
    self.wFocus:FindChild("Header"):Show(false)
    self.wFocus:SetStyle("Moveable", false)
    self.wFocus:SetStyle("Sizable", false)
    self.db.profile.bFocusLocked = true
end

function addon:OnAnchorLockButton(wHandler)
    self.wAnchor:Show(false)
    self.db.profile.locked = true
end

function addon:HideFocus()
    self.wFocus:Show(false)
    self.db.profile.bFocusShown = false
end

function addon:OnSlashCommand(_, input)
    self.wAnchor:Show(true)
    self.db.profile.locked = false
    self.db.profile.bFocusLocked = false
    self.db.profile.bFocusShown = true
    self.wFocus:Show(true)
    self.wFocus:FindChild("Header"):Show(true)
    self.wFocus:SetStyle("Moveable", true)
    self.wFocus:SetStyle("Sizable", true)
end


-----------------------------------------------------------------------------------------------
-- Savedvariables
-----------------------------------------------------------------------------------------------

--[[
function addon:OnSave(eLevel)
    if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return end

    local l,t,r,b = self.wAnchor:GetAnchorOffsets()
    self.db.profile.tPos.anchor = { l = l, t = t, r = r, b = b}

    l,t,r,b = self.wFocus:GetAnchorOffsets()
    self.db.profile.tFocusPos = { l = l, t = t, r = r, b = b}
    self.db.profile.bFocusShown = self.wFocus:IsShown()
    return self.db
end

function addon:OnRestore(eLevel, tData)
    if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return end

    self.db = tData
    if tData.tPos then
        if tData.tPos.anchor then
            self.wAnchor:SetAnchorOffsets(tData.tPos.anchor.l, tData.tPos.anchor.t, tData.tPos.anchor.r, tData.tPos.anchor.b)
            self:RepositionDisplay()
        end
    end
    self.wAnchor:Show(not tData.locked)

    self.wFocus:FindChild("Header"):Show(not tData.bFocusLocked)
    self.wFocus:SetStyle("Moveable", not tData.bFocusLocked)
    self.wFocus:SetStyle("Sizable", not tData.bFocusLocked)

    if tData.tFocusPos then
        if tData.tFocusPos then
            self.wFocus:SetAnchorOffsets(tData.tFocusPos.l, tData.tFocusPos.t, tData.tFocusPos.r, tData.tFocusPos.b)
        end
    end
    self.wFocus:Show(tData.bFocusShown)
end
]]--