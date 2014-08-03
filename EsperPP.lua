-----------------------------------------------------------------------------------------------
-- EsperPP
-- Not so basic Esper helper by Caleb - calebzor@gmail.com
-- /epp
-----------------------------------------------------------------------------------------------

--[[
    TODO:
        move EVERYTHING to GeminiGUI
        localization
        move options to it's own file

        bar texture picker for focus/CB bar -- this will probably have to wait for some shared media support

        properly toggle CB tracking
]]--

local sVersion = "9.1.0.126"

require "Window"
require "GameLib"
require "CColor"
require "ActionSetLib"
require "AbilityBook"
require "Sound"

-----------------------------------------------------------------------------------------------
-- Upvalues
-----------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local string = string
local ipairs = ipairs
local table = table
local GameLib = GameLib
local Apollo = Apollo
local CColor = CColor
local Sound = Sound
local ActionSetLib = ActionSetLib
local AbilityBook = AbilityBook
local Print = Print
local unpack = unpack
local math = math
local Vector3 = Vector3
local os = os

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
local nAnchorEdge = 3
local nMBAbilityId = 19019

local defaults = {
    profile = {
        locked = false,
        tPos = {},
        tFocusPos = {},
        focusBarColor = {0.13,0.76,0.44,0.7},
        focusBarBackgroundColor = {0.78,0,0.16,0.7},
        focusFont = 73, -- CRB_Interface14_BO
        focusTextStyle = "def",
        focusTextColor = {1,1,1,1},
        bShowFocusAnchor = true,
        bReactiveFocusColor = false,
        reactiveFocusBarColorOver75Percent = {0,0.63,0.77,0.7},
        reactiveFocusBarColorOver50Below75Percent = {1,0.96,0,0.7},
        reactiveFocusBarColorOver25Below50Percent =  {1,0.71,0.03,0.7},
        reactiveFocusBarColorBelow25Percent = {0.78,0,0.16,0.7},
        bShow0pp = false,
        bShowFullEffect = true,
        ppColor0 = {0.01,0.85,0.91,1},
        ppColor1 = {0.01,0.85,0.91,1},
        ppColor2 = {0.01,0.85,0.91,1},
        ppColor3 = {0.01,0.85,0.91,1},
        ppColor4 = {1,0.96,0,1},
        ppColor5 = {0.78,0,0.16,1},
        ppColorOOC = {0.13,0.76,0.44,0.7},
        nPPScale = 1,
        psiPointFont = 116, -- Subtitle
        nLOffset = -59,
        nTOffset = -96,
        nROffset = -10,
        nBOffset = -44,
        bShowCB = true,
        nCBWidth = 94,
        nCBHeight = 10,
        nCBPadding = 1,
        CBBarColor = {0.20,0.64,0.67,0.7},
        CBBarBackgroundColor = {0.03,0.05,0.07,0.7},
        bShowPsiCharge = true,
        bShowPsiChargeAnchor = true,
        nPsiChargeScale = 3.5,
        tPsiChargePos = {825,492,871,538},
        nPsiChargeBuffWindowOffset = 11,
        nPsiChargeOpacity = 0.7,
        nMindBurstDotCount = 5,
        nMindBurstOpacity = 0.5,
        bShowMBAssist = true,
        nMindBurstPPShowThreshold = 3,
        MBAssistColor = {0.01,0.85,0.91,0.5},
        nUISoundsVolumeValue = 0.7,
        nMasterVolumeValue = 1,
        nVolumeChangeDuration = 5,
        psiPointSoundEffect = "175",
        nPlaySoundForPsiPoint = 5,
        bPlaySoundForPsiPoint = false,
        bChangeVolumeForPsiPoints = true,
        bSimpleColorMBAssist = false,
        nMindBurstDotSize = 6,
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
    none = "None",
    perc = "Percentage",
    def = "Default",
    currOnly = "Current",
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
    -- Telegraph assist marker definition
    self.tMarkerDef = {
        AnchorOffsets = { -5, -5, 5, 5 },
        AnchorPoints = { "SELF", "SELF", "SELF", "SELF" },
        Class = "WorldFixedWindow",
        RelativeToClient = true,
        Picture = true,
        SwallowMouseClicks = true,
        Overlapped = true,
        IgnoreMouse = true,
        Visible = false,
        Name = "Marker",
        Sprite = "ClientSprites:WhiteCircle",
    }
    self.db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(self, defaults, true)

    self.myOptionsTable = {
        type = "group",
        get = function(info) return self.db.profile[info[#info]] end,
        set = function(info, v) self.db.profile[info[#info]] = v end,
        args = {
            locked = {
                order = 1,
                name = "Lock/Unlock all anchors",
                desc = "Use this button to Lock/Unlock all the anchors. When toggled to unlock, it'll also reveal all hidden windows such as the focus bar.",
                type = "toggle",
                width = "full",
                set = function(info, v) self.db.profile[info[#info]] = v; self:LockUnlock(v) end,
            },
            focusBar = {
                order = 10,
                name = "Focus bar",
                type = "group",
                args={
-----------------------------------------------------------------------------------------------
-- Focus options
-----------------------------------------------------------------------------------------------
                    focusHeader = {
                        order = 1,
                        name = "Focus bar settings",
                        type = "header",
                    },
                    focusHelp = {
                        order = 2,
                        name = "Remember you resize the focus bar when it is unlocked by dragging it's corners.",
                        type = "description",
                    },
                    bShowFocusAnchor = {
                        order = 3,
                        name = "Lock/Unlock focus bar",
                        type = "toggle",
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v; self:LockUnlockFocusAnchor(v) end,
                    },
                    bFocusShown = {
                        order = 4,
                        name = "Hide/Show focus bar",
                        type = "toggle",
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v; self.wFocus:Show(v) end,
                    },
                    focusBarColor = {
                        order = 10,
                        name = "Fill color",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a}; self.wFocus:FindChild("FocusProgress"):SetBarColor(CColor.new(r,g,b,a)) end,
                    },
                    focusBarBackgroundColor = {
                        order = 20,
                        name = "Background color",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a}; self.wFocus:FindChild("FocusProgress"):SetBGColor(CColor.new(r,g,b,a)) end,
                    },
                    -- Focus font and text options
                    focusTextColor = {
                        order = 25,
                        name = "Text color",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a}; self.wFocus:FindChild("FocusProgress"):SetTextColor(CColor.new(r,g,b,a)) end,
                    },
                    focusFont = {
                      order = 30,
                      width = "full",
                      name = "Font style",
                      type = "select",
                      values = tMyFontTable,
                      style = "dropdown",
                      set = function(info, v) self.db.profile[info[#info]] = v; self.wFocus:FindChild("FocusProgress"):SetFont(tMyFontTable[v]) end,
                    },
                    focusTextStyle = {
                      order = 50,
                      width = "full",
                      name = "Text style",
                      type = "select",
                      values = tFocusTextStyle,
                      style = "dropdown",
                    },
                    -- Focus bar color options
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
                    GeminiConfigScrollingFrameBottomWidgetFix = {
                        order = 9999,
                        name = "",
                        type = "description",
                    },
                }
            },
-----------------------------------------------------------------------------------------------
-- Psi Point options
-----------------------------------------------------------------------------------------------
            psiPoints = {
                order = 20,
                name = "Psi points",
                type = "group",
                args={
                    psiPointHeader = {
                        order = 1,
                        name = "Psi point options",
                        type = "header",
                    },
                    bShowPPAnchor = {
                        order = 2,
                        name = "Show psi point anchor",
                        desc = "Show the psi point anchor.",
                        type = "toggle",
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v;  self.wAnchor:Show(v) end,
                    },
                    bShow0pp = {
                        order = 4,
                        name = "Show 0 psi point",
                        desc = "Show 0 psi point too.",
                        type = "toggle",
                        width = "full",
                    },
                    bShowFullEffect = {
                        order = 5,
                        name = "Show full effect",
                        desc = "Show extra effect when you have the maximum possible psi points.",
                        type = "toggle",
                        width = "full",
                    },
                    psiPointColoringHeader = {
                        order = 8,
                        name = "Psi point coloring",
                        type = "header",
                    },
                    ppColor0 = {
                        width = "full",
                        order = 9,
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
                        order = 60,
                        name = "Color for psi points while out of combat",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a} end,
                    },
                    psiPointSizeHeader = {
                        order = 61,
                        name = "Psi point size",
                        type = "header",
                    },
                    psiPointSizeDesc = {
                        order = 62,
                        name = [[The easiest way to change the display size is with the slider for scale. However this might make the text look ugly. Alternatively you could leave the scale on 1 and just change the font from the dropout then you might need to change anchor offsets if necessary.
 
It might be a good idea to toggle "Show 0 psi point" while testing different fonts.
]],
                        type = "description",
                    },
                    nPPScale = {
                        order = 63,
                        name = "Psi point display scale",
                        type = "range",
                        min = 0.5,
                        max = 5,
                        step = 0.05,
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v; self:RecreatePPDisplay() end,
                    },
                    psiPointFont = {
                      order = 64,
                      width = "full",
                      name = "Font style",
                      type = "select",
                      values = tMyFontTable,
                      style = "dropdown",
                      set = function(info, v) self.db.profile[info[#info]] = v; self:RecreatePPDisplay() end,
                    },
                    nLOffset = {
                        order = 65,
                        name = "Left offset",
                        type = "input",
                        usage = "Number expected.",
                        pattern = "%d+",
                        get = function(info) return tostring(self.db.profile[info[#info]]) end,
                        set = function(info, v) self.db.profile[info[#info]] = tonumber(v); self:RecreatePPDisplay() end,
                    },
                    nTOffset = {
                        order = 66,
                        name = "Top offset",
                        type = "input",
                        usage = "Number expected.",
                        pattern = "%d+",
                        get = function(info) return tostring(self.db.profile[info[#info]]) end,
                        set = function(info, v) self.db.profile[info[#info]] = tonumber(v); self:RecreatePPDisplay() end,
                    },
                    nROffset = {
                        order = 67,
                        name = "Right offset",
                        type = "input",
                        usage = "Number expected.",
                        pattern = "%d+",
                        get = function(info) return tostring(self.db.profile[info[#info]]) end,
                        set = function(info, v) self.db.profile[info[#info]] = tonumber(v); self:RecreatePPDisplay() end,
                    },
                    nBOffset = {
                        order = 68,
                        name = "Bottom offset",
                        type = "input",
                        usage = "Number expected.",
                        pattern = "%d+",
                        get = function(info) return tostring(self.db.profile[info[#info]]) end,
                        set = function(info, v) self.db.profile[info[#info]] = tonumber(v); self:RecreatePPDisplay() end,
                    },

                    psiPointSoundHeader = {
                        order = 70,
                        name = "Psi point sound options",
                        type = "header",
                    },
                    bPlaySoundForPsiPoint = {
                        order = 80,
                        name = "Play sound when reaching this amount of psi point(s)",
                        type = "toggle",
                        width = "full",
                    },
                    nPlaySoundForPsiPoint = {
                        order = 85,
                        name = "Play sound when at the configured psi point count",
                        type = "range",
                        min = 1,
                        max = 5,
                        step = 1,
                        disabled = function() return not self.db.profile.bPlaySoundForPsiPoint end,
                        width = "full",
                    },
                    psiPointSoundEffect = {
                        order = 90,
                        width = "full",
                        name = "Psi point sound selector",
                        type = "select",
                        values = {
                            ["96"] = "96",
                            ["97"] = "97",
                            ["114"] = "114",
                            ["146"] = "146",
                            ["205"] = "205",
                            ["186"] = "186",
                            ["175"] = "175",
                            ["Sounds/Airhorn.wav"] = "Air horn",
                            ["Sounds/DING.wav"] = "Ding",
                        },
                        style = "dropdown",
                    },
                    psiPointSoundTest = {
                        order = 100,
                        name = "Play selected sound (test)",
                        type = "execute",
                        width = "full",
                        func = function() self:PlayPPSound() end,
                    },
                    psiPointVolumeHeader = {
                        order = 110,
                        name = "Psi point volume options",
                        type = "header",
                    },
                    bChangeVolumeForPsiPoints = {
                        order = 120,
                        name = "Change volume for Psi Point",
                        desc = "Change the games volume while the sound is playing for the specific psi point count, then restore sound volume settings.",
                        disabled = function() return not self.db.profile.bPlaySoundForPsiPoint end,
                        type = "toggle",
                        width = "full",
                    },
                    VolumeChangeDurationDesc = {
                        order = 129,
                        name = "Volume change duration: For how long should the volume be changed to the given levels before setting them back to original values. (in seconds)",
                        type = "description",
                    },
                    nVolumeChangeDuration = {
                        order = 130,
                        name = "Volume change duration",
                        desc = "For how long should the volume be changed to the given levels before setting them back to original values. (in seconds)",
                        disabled = function() return not self.db.profile.bChangeVolumeForPsiPoints end,
                        type = "range",
                        width = "full",
                        min = 0,
                        max = 10,
                        step = 0.1,
                    },
                    nMasterVolumeValue = {
                        order = 140,
                        name = "Master volume while sound is playing",
                        disabled = function() return not self.db.profile.bChangeVolumeForPsiPoints end,
                        type = "range",
                        width = "full",
                        min = 0,
                        max = 1,
                        step = 0.1,
                    },
                    nUISoundsVolumeValue = {
                        order = 150,
                        name = "UI Sound FX volume while sound is playing",
                        disabled = function() return not self.db.profile.bChangeVolumeForPsiPoints end,
                        type = "range",
                        width = "full",
                        min = 0,
                        max = 1,
                        step = 0.1,
                    },
                    GeminiConfigScrollingFrameBottomWidgetFix = {
                        order = 9999,
                        name = "",
                        type = "description",
                    },
                },
            },
-----------------------------------------------------------------------------------------------
-- Concentrated Blade options
-----------------------------------------------------------------------------------------------
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
                        set = function(info, v)
                            self.db.profile[info[#info]] = v
                            self:ToggleCBTrackerTimer(v)
                            if not v then
                                self.db.profile.bShowCBTestBars = v
                                self:ShowCBTestBars(v)
                                for i=1, 3 do
                                    local bar = self.wCBDisplay:FindChild(("CBProgressBar%d"):format(i))
                                    if self.tCBTracker[i] then
                                        bar:Show(true)
                                        bar:SetMax(self.tCBTracker[i].nEndTime-self.tCBTracker[i].nStartTime)
                                        bar:SetProgress(self.nMyTime-self.tCBTracker[i].nStartTime)
                                    else
                                        bar:Show(false)
                                    end
                                end
                            end
                        end,
                    },
                    bShowCBAnchor = {
                        order = 2,
                        name = "Show concentrated blade anchor",
                        type = "toggle",
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v;  self.wCBAnchor:Show(v) end,
                    },

                    bShowCBTestBars = {
                        order = 10,
                        name = "Shows some test bars to help setup",
                        type = "toggle",
                        width = "full",
                        disabled = function() return not self.db.profile.bShowCB end,
                        set = function(info, v) self.db.profile[info[#info]] = v; self:ShowCBTestBars(v) end,
                    },
                    nCBWidth = {
                        order = 20,
                        name = "Bar width",
                        type = "range",
                        width = "full",
                        min = 0,
                        max = 1000,
                        step = 1,
                        set = function(info, v) self.db.profile[info[#info]] = v; self:RecreateCBDisplay() end,
                    },
                    nCBHeight = {
                        order = 30,
                        name = "Bar height",
                        type = "range",
                        width = "full",
                        min = 0,
                        max = 1000,
                        step = 1,
                        set = function(info, v) self.db.profile[info[#info]] = v; self:RecreateCBDisplay() end,
                    },
                    nCBPadding = {
                        order = 40,
                        name = "Bar padding (distance between bars)",
                        type = "range",
                        width = "full",
                        min = 0,
                        max = 100,
                        step = 1,
                        set = function(info, v) self.db.profile[info[#info]] = v; self:RecreateCBDisplay() end,
                    },
                    concentratedBladeColoringHeader = {
                        order = 50,
                        name = "Concentrated blade bar color options",
                        type = "header",
                    },
                    CBBarColor = {
                        order = 70,
                        name = "Fill color",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a}; self:SetCBBarColors() end,
                    },
                    CBBarBackgroundColor = {
                        order = 80,
                        name = "Background color",
                        type = "color",
                        hasAlpha = true,
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a}; self:SetCBBarColors() end,
                    },
                    GeminiConfigScrollingFrameBottomWidgetFix = {
                        order = 9999,
                        name = "",
                        type = "description",
                    },
                },
            },
-----------------------------------------------------------------------------------------------
-- Psi Charge options
-----------------------------------------------------------------------------------------------
            PsiCharge = {
                order = 40,
                name = "Psi Charge",
                type = "group",
                args={
                    psiChargeDescriptionHeader = {
                        order = 1,
                        name = "Psi charge READ ME!",
                        type = "header",
                    },
                    psiChargeDescription = {
                        order = 2,
                        name = [[Psi Charge tracking finally available! Sadly I had to do all kinds of workarounds to get it somewhat usable and the result is not pretty, but at least functional. Till Carbine fixes the API I don't think it is going to get any better than this.
 
On to the caveats: I think the default settings are pretty good and you probably just want to reposition the display, but I included some options to try and make it more customizable. Basically there is no way to get the stacks number directly, so the best you can do is to scale up the buff icon and only show that scaled up ugly number in the top left corner of a container window and then move it to the right a bit with some offset values. You could try and set the scale to 1 and have no offsets, but then I think the stack number (the number you care about) will be very small.
 
If you messed with the settings but could not quite get it the way you wanted, there is a reset button on the bottom of this configuration window. You can use that to set the psi charger tracker back to it's default settings.
                        ]],
                        type = "description",
                    },
                    psiChargeOptionsHeader = {
                        order = 3,
                        name = "Psi charge options",
                        type = "header",
                    },
                    bShowPsiChargeAnchor = {
                        order = 4,
                        name = "Show psi charge anchor",
                        type = "toggle",
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v; self:HideShowPsiChargeContainer(v) end,
                    },
                    bShowPsiCharge = {
                        order = 5,
                        name = "Show psi charge tracker",
                        type = "toggle",
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v; self:TogglePsichargeTracker(v) end,
                    },
                    nPsiChargeScale = {
                        order = 10,
                        name = "Psi charge scale",
                        type = "range",
                        min = 1,
                        max = 6,
                        step = 0.1,
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v;
                            if self.wBuffBar then
                                self.wBuffBar:SetScale(v)
                            end
                        end,
                    },
                    nPsiChargeBuffWindowOffset = {
                        order = 15,
                        name = "Psi charge buff window offset",
                        type = "range",
                        min = -50,
                        max = 50,
                        step = 1,
                        width = "full",
                    },
                    nPsiChargeOpacity = {
                        order = 20,
                        name = "Psi charge opacity",
                        type = "range",
                        min = 0,
                        max = 1,
                        step = 0.01,
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v;
                            if self.wBuffBar then
                                self.wBuffBar:SetOpacity(v)
                            end
                        end,
                    },
                    restHeader = {
                        order = 100,
                        name = "Reset psi charge options",
                        type = "header",
                    },
                    restToDefaults = {
                        order = 101,
                        name = "Reset",
                        type = "execute",
                        width = "full",
                        func = function()
                            self.db.profile.bShowPsiChargeAnchor = true
                            local l,t,r,b = unpack(defaults.profile.tPsiChargePos)
                            self.db.profile.tPsiChargePos = {l,t,r,b}
                            self.wPsiChargeContainer:SetAnchorOffsets(unpack(defaults.profile.tPsiChargePos))
                            self.db.profile.nPsiChargeScale = defaults.profile.nPsiChargeScale
                            self.db.profile.nPsiChargeBuffWindowOffset = defaults.profile.nPsiChargeBuffWindowOffset
                            self.db.profile.nPsiChargeOpacity = defaults.profile.nPsiChargeOpacity
                            self:HideShowPsiChargeContainer(true)
                            if self.wBuffBar then
                                self.wBuffBar:SetScale(self.db.profile.nPsiChargeScale)
                                self.wBuffBar:SetOpacity(self.db.profile.nPsiChargeOpacity)
                            end
                        end,
                    },
                    GeminiConfigScrollingFrameBottomWidgetFix = {
                        order = 9999,
                        name = "",
                        type = "description",
                    },
                },
            },
-----------------------------------------------------------------------------------------------
-- Telegraph assist options
-----------------------------------------------------------------------------------------------
            TelegrapAssist = {
                order = 40,
                name = "Telegraph assist",
                type = "group",
                args={
                    telegraphAssistHeader = {
                        order = 1,
                        name = "Telegraph assist READ ME!",
                        type = "header",
                    },
                    telegraphAssisttDescription = {
                        order = 2,
                        name = [[Telegraph assist: This feature trys to provide some assistance for those instant spell that you really don't want to miss because the intended target was not inside the telegraph.
 
Caveats: This feature works best on flat surfaces, and is probably not very useful when you are fighting on uneven ground. Since there is no way to compensate for the grounds elevation sadly it can't really get better than as it is now.
 
Remember telegraph assists only shows up if you have the corresponding ability in your LAS.
 
Note: this is quite resource heavy, especially the more dots you have the more resource the addon will use.]],
                        type = "description",
                    },
                    telegraphAssisttOptionsHeader = {
                        order = 3,
                        name = "Telegraph assist options",
                        type = "header",
                    },
                    bShowMBAssist = {
                        order = 10,
                        name = "Show mind burst telegraph assist",
                        type = "toggle",
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v
                            if v then
                                self:SetUpMarkersForTelegraphAssist(nMBAbilityId, 3, self.db.profile.nMindBurstDotCount)
                                local r,g,b = unpack(self.db.profile.MBAssistColor)
                                self:SetTelegraphAssistColor(nMBAbilityId, CColor.new(r,g,b,self.db.profile.nMindBurstOpacity))
                            else
                                self:DestroyMarkersForTelegraphAssist(nMBAbilityId)
                            end
                        end,
                    },
                    MindBurstPPShowThresholdDesc = {
                        order = 14,
                        name = "Mind burst telegraph assist psi point threshold: Amount of psi points you need to have for the mind burst telegraph assist to show up. 0 means always show.",
                        type = "description",
                    },
                    nMindBurstPPShowThreshold = {
                        order = 15,
                        name = "Mind burst telegraph assist psi point threshold",
                        desc = "Amount of psi points you need to have for the mind burst telegraph assist to show up. 0 means always show.",
                        type = "range",
                        disabled = function() return not self.db.profile.bShowMBAssist end,
                        min = 0,
                        max = 5,
                        step = 1,
                        width = "full",
                    },
                    nMindBurstOpacity = {
                        order = 20,
                        name = "Mind burst telegraph assist opacity",
                        type = "range",
                        min = 0,
                        max = 1,
                        step = 0.01,
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v
                            local r,g,b = unpack(self.db.profile.MBAssistColor)
                            self:SetTelegraphAssistColor(nMBAbilityId, CColor.new(r,g,b,v))
                        end,
                    },
                    nMindBurstDotCount = {
                        order = 30,
                        name = "Mind burst dots per line",
                        type = "range",
                        min = 2,
                        max = 50,
                        step = 1,
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v
                            self:DestroyMarkersForTelegraphAssist(nMBAbilityId)
                            self:SetUpMarkersForTelegraphAssist(nMBAbilityId, 3, v)
                            local r,g,b = unpack(self.db.profile.MBAssistColor)
                            self:SetTelegraphAssistColor(nMBAbilityId, CColor.new(r,g,b,self.db.profile.nMindBurstOpacity))
                        end,
                    },
                    nMindBurstDotSize = {
                        order = 35,
                        name = "Mind burst dots size",
                        type = "range",
                        min = 1,
                        max = 20,
                        step = 1,
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v
                            self:DestroyMarkersForTelegraphAssist(nMBAbilityId)
                            self:SetUpMarkersForTelegraphAssist(nMBAbilityId, 3, v)
                            local r,g,b = unpack(self.db.profile.MBAssistColor)
                            self:SetTelegraphAssistColor(nMBAbilityId, CColor.new(r,g,b,self.db.profile.nMindBurstOpacity))
                        end,
                    },
                    bSimpleColorMBAssist = {
                        order = 40,
                        name = "Simple color mind burst telegraph assist",
                        desc = "Use only one color for mind burst telegraph assist, if this is off then the dots will be colored based on your psi point color settings.",
                        type = "toggle",
                        width = "full",
                        set = function(info, v) self.db.profile[info[#info]] = v
                            local r,g,b = unpack(self.db.profile.MBAssistColor)
                            self:SetTelegraphAssistColor(nMBAbilityId, CColor.new(r,g,b,self.db.profile.nMindBurstOpacity))
                        end,
                    },
                    MBAssistColor = {
                        width = "full",
                        order = 50,
                        name = "Color for mind burst assist",
                        disabled = function() return not self.db.profile.bSimpleColorMBAssist end,
                        type = "color",
                        get = function(info) return unpack(self.db.profile[info[#info]]) end,
                        set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a}
                            self:SetTelegraphAssistColor(nMBAbilityId, CColor.new(r,g,b,self.db.profile.nMindBurstOpacity))
                        end,
                    },
                    GeminiConfigScrollingFrameBottomWidgetFix = {
                        order = 9999,
                        name = "",
                        type = "description",
                    },
                },
            },
        }
    }
end

-----------------------------------------------------------------------------------------------
-- OnEnable
-----------------------------------------------------------------------------------------------
function addon:OnEnable()
    if GameLib.GetPlayerUnit():GetClassId() ~= GameLib.CodeEnumClass.Esper then return end -- not esper

    GeminiConfig:RegisterOptionsTable("EsperPP", self.myOptionsTable)

    Apollo.RegisterSlashCommand("EsperPP", "OpenMenu", self)
    Apollo.RegisterSlashCommand("esperpp", "OpenMenu", self)
    Apollo.RegisterSlashCommand("epp", "OpenMenu", self)

    -- create anchors and windows and load database values
    self.wPsiChargeContainer = Apollo.LoadForm("EsperPP.xml", "PsiChargeContainer", nil, self)
    self.wPsiChargeContainer:SetAnchorOffsets(unpack(self.db.profile.tPsiChargePos))
    self:HideShowPsiChargeContainer(self.db.profile.bShowPsiChargeAnchor)
    self.wPsiChargeContainer:AddEventHandler("WindowMove", "OnMoveOrResizePsiChargeContainer", self)
    self.wPsiChargeContainer:AddEventHandler("WindowSizeChanged", "OnMoveOrResizePsiChargeContainer", self)
    if self.db.profile.bShowPsiCharge then
        self.wBuffBar = Apollo.LoadForm("EsperPP.xml", "BuffBar", self.wPsiChargeContainer, self)
        self.wBuffBar:SetScale(self.db.profile.nPsiChargeScale)
        self.buffUpdaterTimer = self:ScheduleRepeatingTimer("BuffBarFilterUpdater", 0.1)
        local l,t,r,b = unpack(self.db.profile.tPsiChargePos)
        self.wBuffBar:SetAnchorOffsets(-1,-1,1,1)
        self.wBuffBar:SetOpacity(self.db.profile.nPsiChargeOpacity)
    end

    self.wFocus = Apollo.LoadForm("EsperPP.xml", "Focus", nil, self)
    self.wFocus:Show(true)
    local r,g,b,a = unpack(self.db.profile.focusBarColor)
    self.wFocus:FindChild("FocusProgress"):SetBarColor(CColor.new(r,g,b,a))
    r,b,g,a = unpack(self.db.profile.focusBarBackgroundColor)
    self.wFocus:FindChild("FocusProgress"):SetBGColor(CColor.new(r,g,b,a))
    self.wFocus:FindChild("FocusProgress"):SetTextColor(CColor.new(unpack(self.db.profile.focusTextColor)))
    self.wFocus:FindChild("FocusProgress"):SetFont(tMyFontTable[self.db.profile.focusFont] or "CRB_Interface14_BO")

    self.nLastPP = 0

    self.wAnchor = Apollo.LoadForm("EsperPP.xml", "Anchor", nil, self)
    self:RecreatePPDisplay()

    self.wCBAnchor = Apollo.LoadForm("EsperPP.xml", "CBAnchor", nil, self)
    self:RecreateCBDisplay()
    if self.db.profile.bShowCBTestBars then
        self:ShowCBTestBars(true)
    end

    self.tMarkers = {}

    self.bMBonLAS = nil
    self.nMBDegree = 15
    self.nMBRange = 25+1/math.cos(math.rad(self.nMBDegree))

    self:SetUpMarkersForTelegraphAssist(nMBAbilityId, 3, self.db.profile.nMindBurstDotCount)
    r,g,b = unpack(self.db.profile.MBAssistColor)
    self:SetTelegraphAssistColor(nMBAbilityId, CColor.new(r,g,b,self.db.profile.nMindBurstOpacity))

    Apollo.RegisterEventHandler("AbilityBookChange", "OnAbilityBookChange", self)
    Apollo.RegisterEventHandler("NextFrame", "OnUpdate", self)

    self.splCB = nil
    self.tCBChargeData = nil
    self.tCBTracker = {}

    self.nMyTime = os.clock()
    -- Gemini timers can't be faster than 0.1 so we use apollo timers, for stuff that needs to be done fast but not quite as NextFrame fast
    Apollo.CreateTimer("FastTimer", 0.033)
    Apollo.RegisterTimerHandler("FastTimer", "FastTimer", self)
    Apollo.StopTimer("FastTimer")
    self.CBTimerRunning = false
    self:ToggleCBTrackerTimer(self.db.profile.bShowCB)

    -- For stuff like focus that does not really need very fast update
    self.fastTimer = self:ScheduleRepeatingTimer("NotSoFastTimer", 0.2)

    self.abilityBookTimer = self:ScheduleRepeatingTimer("DelayedAbilityBookCheck", 1)

    if self.db.profile.tPos then
        if self.db.profile.tPos.anchor and #self.db.profile.tPos.anchor > 0 then
            self.wAnchor:SetAnchorOffsets(unpack(self.db.profile.tPos.anchor))
            self:RepositionDisplay()
        end
    end
    self.wAnchor:Show(self.db.profile.bShowPPAnchor)

    if self.db.profile.tCBPos then
        if self.db.profile.tCBPos.anchor and #self.db.profile.tCBPos.anchor > 0 then
            self.wCBAnchor:SetAnchorOffsets(unpack(self.db.profile.tCBPos.anchor))
            self:RepositionCBDisplay()
        end
    end
    self.wCBAnchor:Show(self.db.profile.bShowCBAnchor)

    self.wFocus:FindChild("Header"):Show(self.db.profile.bShowFocusAnchor)
    self.wFocus:SetStyle("Moveable", self.db.profile.bShowFocusAnchor)
    self.wFocus:SetStyle("Sizable", self.db.profile.bShowFocusAnchor)

    if self.db.profile.tFocusPos and #self.db.profile.tFocusPos > 0 then
        self.wFocus:SetAnchorOffsets(unpack(self.db.profile.tFocusPos))
    end
    self.wFocus:Show(self.db.profile.bFocusShown)


    -- Apollo.GetPackage("Gemini:ConfigDialog-1.0").tPackage:Open("EsperPP")
end

-----------------------------------------------------------------------------------------------
-- Ability related functions
-----------------------------------------------------------------------------------------------

do
    local nUIVolume, nMasterVolume
    local restoreTimer = nil
    local bAllowVolumeSave = true
    function addon:RestoreVolume()
        Apollo.SetConsoleVariable("sound.volumeMaster", nMasterVolume)
        Apollo.SetConsoleVariable("sound.volumeUI", nUIVolume)
        bAllowVolumeSave = true
    end
    function addon:PlayPPSound()
        -- save volume settings
        if self.db.profile.bChangeVolumeForPsiPoints then
            local nCurrMasterVolume = Apollo.GetConsoleVariable("sound.volumeMaster")
            local nCurrUIVolume = Apollo.GetConsoleVariable("sound.volumeUI")
            -- lets not save current volume if it is same as the one we are using in config
            if bAllowVolumeSave then
                nMasterVolume = nCurrMasterVolume
                nUIVolume = nCurrUIVolume
            end
            bAllowVolumeSave = false
            -- set volume as set in the options
            Apollo.SetConsoleVariable("sound.volumeMaster", self.db.profile.nMasterVolumeValue)
            Apollo.SetConsoleVariable("sound.volumeUI", self.db.profile.nUISoundsVolumeValue)
        end
        -- play sound
        if self.db.profile.psiPointSoundEffect:match("%d+") then
            Sound.Play(self.db.profile.psiPointSoundEffect)
        else
            Sound.PlayFile(self.db.profile.psiPointSoundEffect)
        end
        -- wait for the the time set in the options to restore volume
        if self.db.profile.bChangeVolumeForPsiPoints then
            if restoreTimer then
                self:CancelTimer(restoreTimer, true)
                restoreTimer = nil
            end
            restoreTimer = self:ScheduleTimer("RestoreVolume", self.db.profile.nVolumeChangeDuration)
        end
    end
end

function addon:SetUpMarkersForTelegraphAssist(nAbilityId, nLineCount, nDotCount)
    local nScale = tonumber(self.db.profile.nMindBurstDotSize)
    self.tMarkerDef.AnchorOffsets = {-nScale,-nScale,nScale,nScale}
    local tMarker = GeminiGUI:Create("AbilityItemWindow", self.tMarkerDef)
    self.tMarkers[nAbilityId] = {}
    for i = 1, nLineCount do
        self.tMarkers[nAbilityId][i] = {}
        for j = 1, nDotCount do
            self.tMarkers[nAbilityId][i][j] = tMarker:GetInstance()
        end
    end
end

function addon:DestroyMarkersForTelegraphAssist(nAbilityId)
    if not self.tMarkers[nAbilityId] then return end
    for _, line in ipairs(self.tMarkers[nAbilityId]) do
        for _, wDot in ipairs(line) do
            wDot:Destroy()
        end
    end
    self.tMarkers[nAbilityId] = nil
end

function addon:SetTelegraphAssistColor(nAbilityId, color)
    if not self.tMarkers[nAbilityId] then return end
    for _, line in ipairs(self.tMarkers[nAbilityId]) do
        for _, wDot in ipairs(line) do
            wDot:SetBGColor(color)
        end
    end
end

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
        -- this should be faster than loading xml files
        local wAbility = GeminiGUI:Create("AbilityItemWindow", tTempAbilityWindowDef):GetInstance()
        wAbility:SetAbilityId(nAbilityId)
        local sSpellId = wAbility:GetAbilityTierId()
        wAbility:Destroy()
        return sSpellId
    end
end

function addon:DelayedAbilityBookCheck()
    local tCurrLAS = ActionSetLib.GetCurrentActionSet()
    local nCBSpellId, nMBSpellId
    if tCurrLAS then
        for nIndex, nAbilityId in ipairs(tCurrLAS) do
            if nAbilityId == 28756 then -- Concentrated Blades
                nCBSpellId = self:GetTieredSpellIdFromLasAbilityId(nAbilityId)
            elseif nAbilityId == nMBAbilityId then -- Mind Burst
                nMBSpellId = self:GetTieredSpellIdFromLasAbilityId(nAbilityId)
            end
        end
        if self.abilityBookTimer then
            self:CancelTimer(self.abilityBookTimer)
            self.abilityBookTimer = nil
        end
    else
        if not self.abilityBookTimer then
            self.abilityBookTimer = self:ScheduleRepeatingTimer("DelayedAbilityBookCheck", 1)
        end
    end

    if nCBSpellId then
        self.splCB = GameLib.GetSpell(nCBSpellId)
        if self.splCB then
            self.tCBChargeData = self.splCB:GetAbilityCharges()
            if not self.CBTimerRunning and self.db.profile.bShowCB then
                Apollo.StartTimer("FastTimer")
                self.CBTimerRunning = true
            end
        end
    else
        self.splCB = nil
        self.tCBChargeData = nil
        for i=1, 3 do
            local bar = self.wCBDisplay:FindChild(("CBProgressBar%d"):format(i))
            bar:Show(false)
        end
        if self.CBTimerRunning and self.db.profile.bShowCB then
            Apollo.StopTimer("FastTimer")
            self.CBTimerRunning = false
        end
    end
    if nMBSpellId then
        self.bMBonLAS = true
    else
        self.bMBonLAS = nil
    end
end

function addon:OnAbilityBookChange()
    -- have to do this because if you get ability list at this event then it will return what you had not what you have right now.
    self:ScheduleTimer("DelayedAbilityBookCheck", 0.2)
end

-----------------------------------------------------------------------------------------------
-- Updaters
-----------------------------------------------------------------------------------------------

function addon:FastTimer()
    if not uPlayer then return end
    self.nMyTime = os.clock()
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
            tTrackingData.nEndTime = self.nMyTime+3

            self.tCBTracker[#self.tCBTracker+1] = tTrackingData
        end
        self.tCBChargeData = tChargeData

        for i=1, 3 do
            local bar = self.wCBDisplay:FindChild(("CBProgressBar%d"):format(i))
            if self.tCBTracker[i] then
                bar:Show(true)
                bar:SetMax(self.tCBTracker[i].nEndTime-self.tCBTracker[i].nStartTime)
                bar:SetProgress(self.nMyTime-self.tCBTracker[i].nStartTime)
            else
                bar:Show(false)
            end
        end
    end
end

function addon:NotSoFastTimer()
    uPlayer = GameLib.GetPlayerUnit() -- uPlayer is local for the file, because we use it multiple timers
    if not uPlayer then return end
    -- Focus display
    if self.wFocus and self.wFocus:IsShown() then
        local bar = self.wFocus:FindChild("FocusProgress")
        local nCurr, nMax = uPlayer:GetMana(), uPlayer:GetMaxMana()
        bar:SetMax(nMax)
        bar:SetProgress(nCurr)
        bar:SetText(formatFocusText(self.db.profile.focusTextStyle, nCurr, nMax))
        if self.db.profile.bReactiveFocusColor then
            local r,g,b,a
            if ((nCurr / nMax) <= 0.25) then -- Reactive Color Change on Focus Loss
                r,g,b,a = unpack(self.db.profile.reactiveFocusBarColorBelow25Percent)
                self.wFocus:FindChild("FocusProgress"):SetBGColor(CColor.new(r,g,b,a))
            elseif ((nCurr / nMax) <= 0.50) then
                r,g,b,a = unpack(self.db.profile.reactiveFocusBarColorOver25Below50Percent)
                self.wFocus:FindChild("FocusProgress"):SetBGColor(CColor.new(r,g,b,a))
            elseif ((nCurr / nMax) <= 0.75) then
                r,g,b,a = unpack(self.db.profile.reactiveFocusBarColorOver50Below75Percent)
                self.wFocus:FindChild("FocusProgress"):SetBGColor(CColor.new(r,g,b,a))
            else
                r,g,b,a = unpack(self.db.profile.reactiveFocusBarColorOver75Percent)
                self.wFocus:FindChild("FocusProgress"):SetBGColor(CColor.new(r,g,b,a))
            end
        end
    end
end

function addon:BuffBarFilterUpdater()
    if not uPlayer then return end
    self.wBuffBar:SetUnit(uPlayer)
    local tBuffs = self.wBuffBar:GetChildren()
    local bFound = false
    if tBuffs then
        for _, wBuff in ipairs(tBuffs) do
            local sTooltip = wBuff:GetBuffTooltip()
            --"Building up Psi Energy, at 6 charges, gain 1 Psi Point."
            -- hopefully not likely to have a similarly structured tooltip for another buff
            -- if sTooltip:match("Psi Energy") then
            if sTooltip:match(".*,.*%d.*,.*%d.*%.") then -- to possibly work for more localization, assuming some comma usage and 2 numbers
                wBuff:Show(true)
                bFound = true

                wBuff:SetAnchorOffsets(0,0,self.wPsiChargeContainer:GetWidth()+self.db.profile.nPsiChargeBuffWindowOffset,self.wPsiChargeContainer:GetHeight())
                self.wBuffBar:ToFront()
            else
                wBuff:Show(false)
            end
        end
    end
    self.wBuffBar:Show(bFound)
end

function addon:OnUpdate()
    if not uPlayer then return end

    -- PP tracking
    local nPP = uPlayer:GetResource(1)
    local bPPChanged = false
    if self.nLastPP ~= nPP then -- PP changed
        -- do the sound stuff
        if self.db.profile.bPlaySoundForPsiPoint and self.db.profile.nPlaySoundForPsiPoint == nPP then
            self:PlayPPSound()
        end
        self.nLastPP = nPP
        bPPChanged = true
    end
    local wText = self.wDisplay:FindChild("Text")
    wText:SetText((self.db.profile.bShow0pp or nPP > 0) and nPP or "")
    wText:SetTextColor(uPlayer:IsInCombat() and CColor.new(unpack(self.db.profile["ppColor"..nPP])) or CColor.new(unpack(self.db.profile.ppColorOOC)))
    self.wDisplay:FindChild("Full"):Show((self.db.profile.bShowFullEffect and nPP == uPlayer:GetMaxResource(1)) and true or false)


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


    if self.bMBonLAS and self.db.profile.bShowMBAssist and self.tMarkers[nMBAbilityId] and #self.tMarkers[nMBAbilityId] > 1 then
        if self.db.profile.nMindBurstPPShowThreshold > nPP then
            for nCounter = 1, #self.tMarkers[nMBAbilityId] do
                for i = 1, #self.tMarkers[nMBAbilityId][nCounter] do
                    self.tMarkers[nMBAbilityId][nCounter][i]:Show(false)
                end
            end
        else
            local tFacing, tPos = uPlayer:GetFacing(), uPlayer:GetPosition()
            if tFacing and tPos then
                local rot = math.atan2(tFacing.x, tFacing.z)

                local rotPlus = rot+math.rad(self.nMBDegree) -- offset
                local rotNeg = rot+math.rad(-self.nMBDegree) -- offset

                local nOffset, nOffsetDegree = 1, 180 -- center point is not on the player but behind it

                for nCounter = 1, #self.tMarkers[nMBAbilityId] do
                    for i = 1, #self.tMarkers[nMBAbilityId][nCounter] do
                        if (nCounter%3) == 1 then
                            local tStartPoint = { x = tPos.x+nOffset*math.sin(rot+math.rad(nOffsetDegree)) , y = tPos.y , z = tPos.z+nOffset*math.cos(rot+math.rad(nOffsetDegree)) }
                            local tEndPoint = { x = tStartPoint.x+self.nMBRange*math.sin(rotPlus), y = tStartPoint.y, z = tStartPoint.z+self.nMBRange*math.cos(rotPlus)}
                            local vV1 = Vector3.New(tStartPoint.x, tStartPoint.y, tStartPoint.z)
                            local vV2 = Vector3.New(tEndPoint.x, tEndPoint.y, tEndPoint.z)
                            local vVector = Vector3.InterpolateLinear(vV1, vV2, (1/#self.tMarkers[nMBAbilityId][nCounter]) * (i-1))
                            self.tMarkers[nMBAbilityId][nCounter][i]:SetWorldLocation(vVector)
                        elseif (nCounter%3) == 2 then
                            local tStartPoint = { x = tPos.x+nOffset*math.sin(rot+math.rad(nOffsetDegree)) , y = tPos.y , z = tPos.z+nOffset*math.cos(rot+math.rad(nOffsetDegree)) }
                            local tEndPoint = { x = tStartPoint.x+self.nMBRange*math.sin(rotNeg), y = tStartPoint.y, z = tStartPoint.z+self.nMBRange*math.cos(rotNeg)}
                            local vV1 = Vector3.New(tStartPoint.x, tStartPoint.y, tStartPoint.z)
                            local vV2 = Vector3.New(tEndPoint.x, tEndPoint.y, tEndPoint.z)
                            local vVector = Vector3.InterpolateLinear(vV1, vV2, (1/#self.tMarkers[nMBAbilityId][nCounter]) * (i-1))
                            self.tMarkers[nMBAbilityId][nCounter][i]:SetWorldLocation(vVector)
                        elseif (nCounter%3) == 0 then
                            local tRightStartPoint = { x = tPos.x+nOffset*math.sin(rot+math.rad(nOffsetDegree)) , y = tPos.y , z = tPos.z+nOffset*math.cos(rot+math.rad(nOffsetDegree)) }
                            local tRightEndPoint = { x = tRightStartPoint.x+self.nMBRange*math.sin(rotNeg), y = tRightStartPoint.y, z = tRightStartPoint.z+self.nMBRange*math.cos(rotNeg)}
                            local tLeftStartPoint = { x = tPos.x+nOffset*math.sin(rot+math.rad(nOffsetDegree)) , y = tPos.y , z = tPos.z+nOffset*math.cos(rot+math.rad(nOffsetDegree)) }
                            local tLeftEndPoint = { x = tLeftStartPoint.x+self.nMBRange*math.sin(rotPlus), y = tLeftStartPoint.y, z = tLeftStartPoint.z+self.nMBRange*math.cos(rotPlus)}
                            local vV1 = Vector3.New(tLeftEndPoint.x, tLeftEndPoint.y, tLeftEndPoint.z)
                            local vV2 = Vector3.New(tRightEndPoint.x, tRightEndPoint.y, tRightEndPoint.z)
                            local vVector = Vector3.InterpolateLinear(vV1, vV2, (1/(#self.tMarkers[nMBAbilityId][nCounter]-1)) * (i-1))
                            self.tMarkers[nMBAbilityId][nCounter][i]:SetWorldLocation(vVector)
                        end
                        if not self.db.profile.bSimpleColorMBAssist and bPPChanged then
                            local a = self.db.profile.nMindBurstOpacity
                            local r,g,b
                            if uPlayer:IsInCombat() then
                                r,g,b = unpack(self.db.profile["ppColor"..nPP])
                            else
                                r,g,b = unpack(self.db.profile.ppColorOOC)
                            end
                            self.tMarkers[nMBAbilityId][nCounter][i]:SetBGColor(CColor.new(r,g,b,a))
                        end
                        self.tMarkers[nMBAbilityId][nCounter][i]:Show(true)
                    end
                end
            end
        end
    end
end

-----------------------------------------------------------------------------------------------
-- Window management
-----------------------------------------------------------------------------------------------

function addon:SetCBBarColors()
    local db = self.db.profile
    for i=1, 3 do
        local bar = self.wCBDisplay:FindChild(("CBProgressBar%d"):format(i))
        local r,g,b,a = unpack(db.CBBarColor)
        bar:SetBarColor(CColor.new(r,g,b,a))
        r,g,b,a = unpack(db.CBBarBackgroundColor)
        bar:SetBGColor(CColor.new(r,g,b,a))
    end
end

local function startCBTestBars()
    if not addon.nMyTime then return end
    for i = 1, 3 do
       local tTrackingData = {}
       tTrackingData.nStartTime = addon.nMyTime
       tTrackingData.nEndTime = addon.nMyTime+3

       addon.tCBTracker[#addon.tCBTracker+1] = tTrackingData
    end
end

function addon:ShowCBTestBars(bShow)
    if bShow then
        startCBTestBars()
        if not self.CBTestTimer then
            self.CBTestTimer = self:ScheduleRepeatingTimer(startCBTestBars, 3)
        end
    else
        if self.CBTestTimer then
            self.tCBTracker = {}
            self:CancelTimer(self.CBTestTimer)
            self.CBTestTimer = nil
        end
    end
end

do
    local tDisplayDef = {
        -- window def will go here when I'm ready to completely switch to GeminiGUI
    }

    -- we recreate from scratch because this way I only have to edit code at one place rather than multiple because of the options and initialization
    function addon:RecreatePPDisplay()
        -- destroy stuff
        if self.wDisplay then self.wDisplay:Destroy() end

        -- create the display
        self.wDisplay = Apollo.LoadForm("EsperPP.xml", "Display", nil, self)
        self.wDisplay:Show(true)

        -- apply db settings to the GeminiGUI window def
        local db = self.db.profile
        self.wDisplay:SetScale(db.nPPScale)
        self.wDisplay:FindChild("Text"):SetFont(tMyFontTable[db.psiPointFont])
        self.wDisplay:FindChild("Text"):SetAnchorOffsets(db.nLOffset, db.nTOffset, db.nROffset, db.nBOffset)

        self:RepositionDisplay()
    end
end

do
    local tCBDisplayDef = {
        -- window def will go here when I'm ready to completely switch to GeminiGUI
    }

    function addon:RecreateCBDisplay()
        -- destroy stuff
        if self.wCBDisplay then self.wCBDisplay:Destroy() end

        -- create the display
        self.wCBDisplay = Apollo.LoadForm("EsperPP.xml", "CBDisplay", nil, self)
        self.wCBDisplay:Show(true)

        -- apply db settings to the GeminiGUI window def
        self:RepositionCBDisplay()
        local db = self.db.profile
        for i=1, 3 do
            local wCBBar = Apollo.LoadForm("EsperPP.xml", "CBProgressBar", self.wCBDisplay, self)
            wCBBar:SetName(("CBProgressBar%d"):format(i))
            wCBBar:SetAnchorOffsets(0,(i-1)*db.nCBHeight+(i-1)*db.nCBPadding,0,i*db.nCBHeight+(i-1)*db.nCBPadding)
        end
        self:SetCBBarColors()
    end
end

function addon:LockUnlock(bValue)
    self.db.profile.bShowPPAnchor = bValue
    self.wAnchor:Show(bValue)

    self.db.profile.bShowCBAnchor = bValue
    self.wCBAnchor:Show(bValue)

    self.db.profile.bShowPsiChargeAnchor = bValue
    self:HideShowPsiChargeContainer(bValue)

    self.db.profile.bShowFocusAnchor = bValue
    self:LockUnlockFocusAnchor(bValue)
end

function addon:OpenMenu(_, input)
    Apollo.GetPackage("Gemini:ConfigDialog-1.0").tPackage:Open("EsperPP")
end

function addon:RepositionDisplay()
    local l,t,r,b = self.wAnchor:GetAnchorOffsets()
    self.wDisplay:SetAnchorOffsets(l, b, l+94, b+111) -- This has to be updated if the frame is resized in houston ( or probably should look into move to position or something)
end

function addon:RepositionCBDisplay()
    local db = self.db.profile
    local l,t,r,b = self.wCBAnchor:GetAnchorOffsets()
    self.wCBDisplay:SetAnchorOffsets(l,b,l+db.nCBWidth,b+db.nCBHeight*3+db.nCBPadding*2)
end

function addon:OnAnchorMove(wHandler)
    local l,t,r,b = self.wAnchor:GetAnchorOffsets()
    if not self.db.profile.tPos then
        self.db.profile.tPos = {}
    end
    self.db.profile.tPos.anchor = {l,t,r,b}
    self:RepositionDisplay()
end

function addon:OnCBAnchorMove(wHandler)
    local l,t,r,b = self.wCBAnchor:GetAnchorOffsets()
    if not self.db.profile.tCBPos then
        self.db.profile.tCBPos = {}
    end
    self.db.profile.tCBPos.anchor = {l,t,r,b}
    self:RepositionCBDisplay()
end

function addon:FocusMoveOrScale()
    local l,t,r,b = self.wFocus:GetAnchorOffsets()
    self.db.profile.tFocusPos = {l,t,r,b}
end

function addon:LockUnlockFocusAnchor(bValue)
    if bValue then
        self.wFocus:Show(true)
    end
    self.db.profile.bFocusShown = self.wFocus:IsShown()

    self.wFocus:FindChild("Header"):Show(bValue)
    self.wFocus:SetStyle("Moveable", bValue)
    self.wFocus:SetStyle("Sizable", bValue)
end

function addon:HideFocus()
    self.wFocus:Show(false)
    self.db.profile.bFocusShown = false
end

function addon:TogglePsichargeTracker(bEnable)
    if bEnable then
        if not self.buffUpdaterTimer then
            self.wBuffBar = Apollo.LoadForm("EsperPP.xml", "BuffBar", self.wPsiChargeContainer, self)
            self.wBuffBar:SetScale(self.db.profile.nPsiChargeScale)
            self.wBuffBar:SetOpacity(self.db.profile.nPsiChargeOpacity)
            self.buffUpdaterTimer = self:ScheduleRepeatingTimer("BuffBarFilterUpdater", 0.1)
            self:OnMoveOrResizePsiChargeContainer()
        end
    else
        if self.buffUpdaterTimer then
            self:CancelTimer(self.buffUpdaterTimer)
            self.buffUpdaterTimer = nil
            self.wBuffBar:Destroy()
        end
    end
end

function addon:ToggleCBTrackerTimer(bEnable)
    if bEnable and not self.CBTimerRunning then
        Apollo.StartTimer("FastTimer")
        self.CBTimerRunning = bEnable
    elseif not bEnable and self.CBTimerRunning then
        Apollo.StopTimer("FastTimer")
        self.CBTimerRunning = bEnable
    end
end

function addon:OnMoveOrResizePsiChargeContainer(wHandler, wControl)
    if wHandler ~= wControl then return end
    local l,t,r,b = self.wPsiChargeContainer:GetAnchorOffsets()
    self.db.profile.tPsiChargePos = {l,t,r,b}

    if self.wBuffBar then
        self.wBuffBar:SetAnchorOffsets(-1,-1,1,1)
    end
end

function addon:HideShowPsiChargeContainer(bValue)
    self.wPsiChargeContainer:SetText(bValue and "PC" or "")
    self.wPsiChargeContainer:SetStyle("Picture", bValue)
    self.wPsiChargeContainer:SetStyle("Moveable", bValue)
    self.wPsiChargeContainer:SetStyle("Sizable", bValue)
    self.wPsiChargeContainer:SetStyle("IgnoreMouse", not bValue)
end