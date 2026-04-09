local addonName, ns = ...

ns.TweenLoot = CreateFrame("Frame")
local TweenLoot = ns.TweenLoot
TweenLoot.name = addonName

local pendingNormalTests = 0

TweenLoot.defaults = {
	scaleTweenType = "Spring",
	positionTweenType = "Spring",
	alphaTweenType = "Spring",
	duration = 0.5,
}

TweenLoot.positionOffsetY = 36

-- #region 0. TWEEN FUNCTIONS
TweenLoot.tweens = {
	Linear = function(t, b, c, d) return c * t / d + b end,
	Sine = function(t, b, c, d) return c * math.sin(t / d * (math.pi / 2)) + b end,
	Quint = function(t, b, c, d)
		t = t / d - 1
		return c * (t * t * t * t * t + 1) + b
	end,
	Quart = function(t, b, c, d)
		t = t / d - 1
		return -c * (t * t * t * t - 1) + b
	end,
	Quad = function(t, b, c, d)
		t = t / d
		return -c * t * (t - 2) + b
	end,
	Expo = function(t, b, c, d)
		if t == d then return b + c end
		return c * 1.001 * (-(2 ^ (-10 * t / d)) + 1) + b
	end,
	Elastic = function(t, b, c, d)
		if t == 0 then return b end
		t = t / d
		if t == 1 then return b + c end
		local p = d * 0.3
		local s = p / 4
		return (c * (2 ^ (-10 * t)) * math.sin((t * d - s) * (2 * math.pi) / p) + c + b)
	end,
	Cubic = function(t, b, c, d)
		t = t / d - 1
		return c * (t * t * t + 1) + b
	end,
	Circ = function(t, b, c, d)
		t = t / d - 1
		return c * math.sqrt(1 - t * t) + b
	end,
	Bounce = function(t, b, c, d)
		t = t / d
		if t < (1 / 2.75) then return c * (7.5625 * t * t) + b end
		if t < (2 / 2.75) then
			t = t - (1.5 / 2.75)
			return c * (7.5625 * t * t + 0.75) + b
		end
		if t < (2.5 / 2.75) then
			t = t - (2.25 / 2.75)
			return c * (7.5625 * t * t + 0.9375) + b
		end
		t = t - (2.625 / 2.75)
		return c * (7.5625 * t * t + 0.984375) + b
	end,
	Back = function(t, b, c, d)
		local s = 1.70158
		t = t / d - 1
		return c * (t * t * ((s + 1) * t + s) + 1) + b
	end,
	Spring = function(t, b, c, d)
		t = t / d
		local s = 1.0 - t
		t = (math.sin(t * math.pi * (0.2 + 2.5 * t * t * t)) * (s ^ 2.2) + t) * (1.0 + (1.2 * s))
		return c * t + b
	end,
}
-- #endregion

-- #region 1. UTILITIES
function TweenLoot:GetTweenTypeFor(property)
	local variableKey = property .. "TweenType"
	local key = TweenLootDB and TweenLootDB[variableKey] or self.defaults[variableKey]
	return (self.tweens[key] and key) or self.defaults[variableKey]
end

function TweenLoot:GetDuration()
	return TweenLootDB and TweenLootDB.duration or self.defaults.duration
end

function TweenLoot:ClearAlerts()
	if not LootAlertSystem or not LootAlertSystem.alertFramePool then return end
	for frame in LootAlertSystem.alertFramePool:EnumerateActive() do
		if frame.animIn then frame.animIn:Stop() end
		if frame.waitAndAnimOut then frame.waitAndAnimOut:Stop() end
		frame:SetScript("OnUpdate", nil)
		frame:Hide()
	end
	if LootAlertSystem.queue then wipe(LootAlertSystem.queue) end
end
-- #endregion

-- #region 2. ANIMATION ENGINE
function TweenLoot:Tween(frame)
	if pendingNormalTests > 0 then
		pendingNormalTests = pendingNormalTests - 1
		return
	end

	local duration = self:GetDuration()
	local startTime = GetTime()
	local scaleMode = self:GetTweenTypeFor("scale")
	local positionMode = self:GetTweenTypeFor("position")
	local alphaMode = self:GetTweenTypeFor("alpha")

	local scaleFunc = self.tweens[scaleMode] or self.tweens.Spring
	local positionFunc = self.tweens[positionMode] or self.tweens.Spring
	local alphaFunc = self.tweens[alphaMode] or self.tweens.Spring

	local point, relativeTo, relativePoint, offsetX, originalOffsetY = frame:GetPoint(1)
	offsetX, originalOffsetY = offsetX or 0, originalOffsetY or 0
	local offsetY = self.positionOffsetY

	frame:SetScale(0.4)
	frame:SetAlpha(0)

	frame:SetScript("OnUpdate", function(s, elapsed)
		local t = GetTime() - startTime

		if t >= duration then
			s:SetScale(1.0)
			s:SetAlpha(1)
			if positionFunc then
				s:ClearAllPoints()
				s:SetPoint(point, relativeTo, relativePoint, offsetX, originalOffsetY)
			end
			s:SetScript("OnUpdate", nil)
			if s.waitAndAnimOut then s.waitAndAnimOut:Play() end
			return
		end

		s:SetScale(scaleFunc(t, 0.4, 0.6, duration))
		s:SetAlpha(math.max(0, math.min(alphaFunc(t, 0, 1, duration), 1)))

		if positionFunc then
			local currentOffsetY = positionFunc(t, originalOffsetY - offsetY, offsetY, duration)
			s:ClearAllPoints()
			s:SetPoint(point, relativeTo, relativePoint, offsetX, currentOffsetY)
		end
	end)
end
-- #endregion

-- #region 3. OPTIONS UI
function TweenLoot:InitializeOptions()
	if self.category then return end

	local rootCategory = Settings.RegisterVerticalLayoutCategory(self.name)
	self.category = rootCategory

	-- Test Page
	local testPage = CreateFrame("Frame", nil, UIParent)
	testPage.name = "Test"
	testPage.title = testPage:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	testPage.title:SetPoint("TOPLEFT", 7, -22)
	testPage.title:SetText("TweenLoot - Test")

	testPage.divider = testPage:CreateTexture(nil, "ARTWORK")
	testPage.divider:SetAtlas("Options_HorizontalDivider", true)
	testPage.divider:SetPoint("TOP", 0, -50)

	testPage.tweenButton = CreateFrame("Button", nil, testPage, "UIPanelButtonTemplate")
	testPage.tweenButton:SetSize(150, 28)
	testPage.tweenButton:SetPoint("TOPLEFT", testPage.title, "BOTTOMLEFT", 0, -20)
	testPage.tweenButton:SetText("Test Tween")
	testPage.tweenButton:SetScript("OnClick", function() TweenLoot:RunTest(true) end)

	testPage.normalButton = CreateFrame("Button", nil, testPage, "UIPanelButtonTemplate")
	testPage.normalButton:SetSize(150, 28)
	testPage.normalButton:SetPoint("LEFT", testPage.tweenButton, "RIGHT", 12, 0)
	testPage.normalButton:SetText("Test Normal")
	testPage.normalButton:SetScript("OnClick", function() TweenLoot:RunTest(false) end)

	testPage.clearButton = CreateFrame("Button", nil, testPage, "UIPanelButtonTemplate")
	testPage.clearButton:SetSize(150, 28)
	testPage.clearButton:SetPoint("TOPLEFT", testPage.tweenButton, "BOTTOMLEFT", 0, -10)
	testPage.clearButton:SetText("Clear Alerts")
	testPage.clearButton:SetScript("OnClick", function() TweenLoot:ClearAlerts() end)

	local font, size = GameFontNormalLarge:GetFont()

	testPage.commands = testPage:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	testPage.commands:SetPoint("TOPLEFT", testPage.clearButton, "BOTTOMLEFT", 0, -20)
	testPage.commands:SetFont(font, size + 3, "THICKOUTLINE")
	testPage.commands:SetText("Slash commands: /tl and /nl")

	testPage.description = testPage:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	testPage.description:SetPoint("TOPLEFT", testPage.commands, "BOTTOMLEFT", 0, -8)
	testPage.description:SetWidth(400)
	testPage.description:SetJustifyH("LEFT")
	testPage.description:SetFont(font, size, "OUTLINE")
	testPage.description:SetText("/tl (or /tweenloot) - Test Tween Loot\n/nl (or /normalloot) - Test Normal Loot")

	local testCategory = Settings.RegisterCanvasLayoutSubcategory(rootCategory, testPage, "Test")

	local tweenChoices = {}
	for k in pairs(self.tweens) do table.insert(tweenChoices, k) end
	table.sort(tweenChoices)

	local function GetOptions()
		local container = Settings.CreateControlTextContainer()
		for _, name in ipairs(tweenChoices) do container:Add(name, name) end
		return container:GetData()
	end

	local function RegisterAutoTest(variableName)
		Settings.SetOnValueChangedCallback(variableName, function() TweenLoot:RunTest(true) end)
	end

	local scaleVar = Settings.RegisterAddOnSetting(rootCategory, "TweenLoot_ScaleTweenType", "scaleTweenType", TweenLootDB, Settings.VarType.String, "Scale Tween", self.defaults.scaleTweenType)
	Settings.CreateDropdown(rootCategory, scaleVar, function() return GetOptions() end)
	RegisterAutoTest("TweenLoot_ScaleTweenType")

	local posVar = Settings.RegisterAddOnSetting(rootCategory, "TweenLoot_PositionTweenType", "positionTweenType", TweenLootDB, Settings.VarType.String, "Position Tween", self.defaults.positionTweenType)
	Settings.CreateDropdown(rootCategory, posVar, function() return GetOptions() end)
	RegisterAutoTest("TweenLoot_PositionTweenType")

	local alphaVar = Settings.RegisterAddOnSetting(rootCategory, "TweenLoot_AlphaTweenType", "alphaTweenType", TweenLootDB, Settings.VarType.String, "Alpha Tween", self.defaults.alphaTweenType)
	Settings.CreateDropdown(rootCategory, alphaVar, function() return GetOptions() end)
	RegisterAutoTest("TweenLoot_AlphaTweenType")

	local durVar = Settings.RegisterAddOnSetting(rootCategory, "TweenLoot_Duration", "duration", TweenLootDB, Settings.VarType.Number, "Duration", self.defaults.duration)
	local durOptions = Settings.CreateSliderOptions(0.1, 2.0, 0.1)
	durOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return string.format("%.1f s", v) end)
	Settings.CreateSlider(rootCategory, durVar, durOptions)

	Settings.RegisterAddOnCategory(rootCategory)
	Settings.RegisterAddOnCategory(testCategory)
end
-- #endregion

-- #region 4. INITIALIZATION & HOOKS
function TweenLoot:InitLootHooks()
	if not LootAlertSystem or not LootAlertSystem.alertFramePool then return end

	local function ApplyTweenLogic(frame)
		if frame and not frame.isTweenHooked then
			frame:HookScript("OnShow", function(s)
				if s.animIn then s.animIn:Stop() end
				if s.waitAndAnimOut then s.waitAndAnimOut:Stop() end
				TweenLoot:Tween(s)
			end)
			frame.isTweenHooked = true
		end
	end

	if LootAlertSystem.alertFramePool.EnumerateInactive then
		for frame in LootAlertSystem.alertFramePool:EnumerateInactive() do ApplyTweenLogic(frame) end
	end
	for frame in LootAlertSystem.alertFramePool:EnumerateActive() do ApplyTweenLogic(frame) end

	local oldCreationFunc = LootAlertSystem.alertFramePool.creationFunc
	LootAlertSystem.alertFramePool.creationFunc = function(pool)
		local frame = oldCreationFunc(pool)
		ApplyTweenLogic(frame)
		return frame
	end
end

function TweenLoot:PLAYER_ENTERING_WORLD()
	self:InitLootHooks()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

function TweenLoot:ADDON_LOADED(event, name)
	if name ~= self.name then return end
	TweenLootDB = TweenLootDB or {}
	for key, value in pairs(self.defaults) do
		if TweenLootDB[key] == nil then TweenLootDB[key] = value end
	end
	self:InitializeOptions()
end

TweenLoot:SetScript("OnEvent", function(self, event, ...)
	if self[event] then self[event](self, event, ...) end
end)
TweenLoot:RegisterEvent("ADDON_LOADED")
TweenLoot:RegisterEvent("PLAYER_ENTERING_WORLD")
-- #endregion

-- #region 5. SLASH COMMANDS & GLOBALS
function TweenLoot:RunTest(useTween)
	local function QueueModeAndAlert(itemLink)
		if not itemLink then return end
		if not useTween then
			pendingNormalTests = pendingNormalTests + 1
		end
		LootAlertSystem:AddAlert(itemLink)
	end

	local testItem = Item:CreateFromItemID(6948)
	testItem:ContinueOnItemLoad(function()
		QueueModeAndAlert(testItem:GetItemLink())
	end)

	QueueModeAndAlert(select(2, GetItemInfo(6948)))
end

function TweenLoot_Settings()
	if TweenLoot.category and not InCombatLockdown() then
		Settings.OpenToCategory(TweenLoot.category:GetID())
	end
end

SLASH_TWEENLOOT1, SLASH_TWEENLOOT2 = "/tl", "/tweenloot"
SlashCmdList["TWEENLOOT"] = function() TweenLoot:RunTest(true) end

SLASH_NOTWEEN1, SLASH_NOTWEEN2 = "/nl", "/normalloot"
SlashCmdList["NOTWEEN"] = function() TweenLoot:RunTest(false) end
-- #endregion
