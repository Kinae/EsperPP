-----------------------------------------------------------------------------------------------
-- Client Lua Script for EsperPP
-- Very basic Psi Point tracker
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "CColor"
require "ActionSetLib"
require "AbilityBook"

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

local EsperPP = {}
local addon = EsperPP

local uPlayer = nil

function addon:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	self.tDB = {}
	return o
end

function addon:Init()
	Apollo.RegisterAddon(self)
end

local function hexToCColor(color, a)
	if not a then a = 1 end
	local r = tonumber(string.sub(color,1,2), 16) / 255
	local g = tonumber(string.sub(color,3,4), 16) / 255
	local b = tonumber(string.sub(color,5,6), 16) / 255
	return CColor.new(r,g,b,a)
end

local tColor = {
	xkcdAquaBlue = hexToCColor("02d8e9"),
	xkcdAlgaeGreen = hexToCColor("21c36f"),
	yellow = hexToCColor("fff600"),
	orange = hexToCColor("feb408"),
	red = hexToCColor("c6002a"),
	green = hexToCColor("01a825"),
	blue = hexToCColor("00b0d8"),
}

-----------------------------------------------------------------------------------------------
-- EsperPP OnLoad
-----------------------------------------------------------------------------------------------
function addon:OnLoad()
	Apollo.RegisterSlashCommand("EsperPP", "OnSlashCommand", self)
	self.wAnchor = Apollo.LoadForm("EsperPP.xml", "Anchor", nil, self)

	self.wFocus = Apollo.LoadForm("EsperPP.xml", "Focus", nil, self)
	self.wFocus:Show(true)
	self.wFocus:FindChild("FocusProgress"):SetBarColor(tColor.xkcdAquaBlue)
	self.wFocus:FindChild("FocusProgress"):SetBGColor(tColor.orange)

	self.wDisplay = Apollo.LoadForm("EsperPP.xml", "Display", nil, self)
	self.wDisplay:Show(true)

	Apollo.RegisterEventHandler("AbilityBookChange", "OnAbilityBookChange", self)
	Apollo.RegisterEventHandler("VarChange_FrameCount", "OnUpdate", self)

	self.splCB = nil
	self.tCBChargeData = nil
	self.tCBTracker = {}
	self.tDB.tPos = {}
	self.tDB.tFocusPos = {}

	self.nMyTime = 1
	Apollo.RegisterTimerHandler("FastTimer", "FastTimer", self)
	Apollo.CreateTimer("FastTimer", 0.1, true)

	Apollo.RegisterTimerHandler("DelayedAbilityBookCheck", "DelayedAbilityBookCheck", self)
	Apollo.CreateTimer("DelayedAbilityBookCheck", 1, false)
end

-----------------------------------------------------------------------------------------------
-- EsperPP Functions
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

-- utility function that gets the spellId from abilityId
function addon:GetTieredSpellIdFromLasAbilityId(nAbilityId)
	-- this only works for abilities the player can cast
	local wAbility = Apollo.LoadForm("EsperPP.xml", "TempAbilityWindow", nil, self)
	wAbility:SetAbilityId(nAbilityId)
	local sSpellId = wAbility:GetAbilityTierId()
	wAbility:Destroy()
	return sSpellId
end

function addon:DelayedAbilityBookCheck()
	local tCurrLAS = ActionSetLib.GetCurrentActionSet()
	local nSpellId
	if tCurrLAS then
		for nIndex, nAbilityId in ipairs(tCurrLAS) do
			if nAbilityId == 28756 then -- Concentrated Blades
				nSpellId = self:GetTieredSpellIdFromLasAbilityId(nAbilityId)
			end
		end
	else
		Apollo.CreateTimer("DelayedAbilityBookCheck", 1, false)
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
	Apollo.CreateTimer("DelayedAbilityBookCheck", 0.2, false)
end

function addon:FastTimer()
	self.nMyTime = self.nMyTime + 1
end

function addon:OnUpdate()
	local uPlayer = GameLib.GetPlayerUnit()
	if not uPlayer then return end
	if uPlayer:GetClassId() ~= 3 then self.wDisplay:Show(false) self.wAnchor:Show(false) return end -- not esper
	self.wDisplay:Show(true)
	self.wDisplay:FindChild("Text"):SetText(uPlayer:GetResource(1) > 0 and uPlayer:GetResource(1) or "")
	self.wDisplay:GetName()
	self.wDisplay:FindChild("Full"):Show(uPlayer:GetResource(1) == uPlayer:GetMaxResource(1) and true or false)

	-- PP tracking
	if uPlayer:IsInCombat() then
		if uPlayer:GetResource(1) == uPlayer:GetMaxResource(1) then
			self.wDisplay:FindChild("Text"):SetTextColor(tColor.red)
		elseif uPlayer:GetResource(1) == 4 then
			self.wDisplay:FindChild("Text"):SetTextColor(tColor.yellow)
		else
			self.wDisplay:FindChild("Text"):SetTextColor(tColor.xkcdAquaBlue)
		end
	else
		self.wDisplay:FindChild("Text"):SetTextColor(tColor.xkcdAlgaeGreen)
	end

	-- T8 builder stack tracking
	-- buff or API is bugged and does not show up among the return values
	--local tBuffs = uPlayer:GetBuffs().arBeneficial
	--if tBuffs then
	--	if
	--	/eval for index, tData in pairs(GameLib.GetPlayerUnit():GetBuffs().arBeneficial) do Print(tData.splEffect:GetName() .. " " .. tData.splEffect:GetId()) end
	--	/eval Print(#GameLib.GetPlayerUnit():GetBuffs().arBeneficial)
	--else
	--	self.wDisplay:FindChild("T8stack"):Show(false)
	--end
	-- CB tracking
	if self.splCB and self.tCBChargeData and self.nMyTime then -- this also works as a check if CB is even on the LAS because if it is not then this is nil
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
		bar:SetMax(uPlayer:GetMaxMana())
		bar:SetProgress(uPlayer:GetMana())
	end

end

function addon:RepositionDisplay()
	local l,t,r,b = self.wAnchor:GetAnchorOffsets()
	self.wDisplay:SetAnchorOffsets(l, b, l+94, b+111) -- This has to be updated if the frame is resized in houston ( or probably should look into move ot position or something)
end

function addon:OnAnchorMove(wHandler)
	local l,t,r,b = self.wAnchor:GetAnchorOffsets()
	self.tDB.tPos.anchor = { l = l, t = t, r = r, b = b}
	self:RepositionDisplay()
end

function addon:OnFocusLockButton(wHandler)
	self.wFocus:FindChild("Header"):Show(false)
	self.wFocus:SetStyle("Moveable", false)
	self.wFocus:SetStyle("Sizable", false)
	self.tDB.bFocusLocked = true
end

function addon:OnAnchorLockButton(wHandler)
	self.wAnchor:Show(false)
	self.tDB.locked = true
end

function addon:HideFocus()
	self.wFocus:Show(false)
end

-----------------------------------------------------------------------------------------------
-- Savedvariables
-----------------------------------------------------------------------------------------------

function addon:OnSlashCommand(_, input)
	self.wAnchor:Show(true)
	self.tDB.locked = false
	self.tDB.bFocusLocked = false
	self.wFocus:Show(true)
	self.wFocus:FindChild("Header"):Show(true)
	self.wFocus:SetStyle("Moveable", true)
	self.wFocus:SetStyle("Sizable", true)
end

function addon:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return end

	local l,t,r,b = self.wAnchor:GetAnchorOffsets()
	self.tDB.tPos.anchor = { l = l, t = t, r = r, b = b}

	l,t,r,b = self.wFocus:GetAnchorOffsets()
	self.tDB.tFocusPos = { l = l, t = t, r = r, b = b}
	self.tDB.bFocusShown = self.wFocus:IsShown()
	return self.tDB
end

function addon:OnRestore(eLevel, tData)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return end

	self.tDB = tData
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

-----------------------------------------------------------------------------------------------
-- EsperPP Instance
-----------------------------------------------------------------------------------------------
local EsperPPInst = addon:new()
EsperPPInst:Init()
