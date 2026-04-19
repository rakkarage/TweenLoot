-- 🌀 TweenLoot: Adds animations to loot alerts.

local addonName = ...

local frame = CreateFrame("Frame")

local defaults = {
	scaleTweenType = "Spring",
	positionTweenType = "Spring",
	alphaTweenType = "Spring",
	duration = 0.3,
}

local category
local pendingNormalTests = 0
local hooksInitialized = false
local initRetryTimer
local offsetY = 36

local TEST_ID = {
	205872, -- Earthvermin Fluff (poor/gray)
	6948, -- Hearthstone (common/white)
	1206, -- Moss Agate (uncommon/green)
	37653, -- Sword of Justice (rare/blue)
	18832, -- Brutality Blade (epic/purple)
	19019, -- Thunderfury, Blessed Blade of the Windseeker (legendary/orange)
}

-- #region 0. TWEEN FUNCTIONS

local tweens = {
	Linear = function(t, b, c, d)
		return c * t / d + b
	end,
	Sine = function(t, b, c, d)
		return c * math.sin(t / d * (math.pi / 2)) + b
	end,
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

local function GetTweenTypeFor(property)
	local dbKey = property .. "TweenType"
	local key = TweenLootDB and TweenLootDB[dbKey] or defaults[dbKey]
	return (tweens[key] and key) or defaults[dbKey]
end

local function GetDuration()
	return TweenLootDB and TweenLootDB.duration or defaults.duration
end

local function ClearAlerts()
	if not LootAlertSystem or not LootAlertSystem.alertFramePool then return end
	for frame in LootAlertSystem.alertFramePool:EnumerateActive() do
		if frame.animIn then frame.animIn:Stop() end
		if frame.waitAndAnimOut then frame.waitAndAnimOut:Stop() end
		frame._tweenState = nil
		frame:SetScript("OnUpdate", nil)
		frame:Hide()
	end
	if LootAlertSystem.queue then wipe(LootAlertSystem.queue) end
end

local function GetRandomOwnedItemLink()
	local links = {}
	local firstEquippedSlotID = 1
	local lastEquippedSlotID = 19
	local firstBagID = 0
	local lastBagID = 4

	for slotID = firstEquippedSlotID, lastEquippedSlotID do
		local itemLink = GetInventoryItemLink("player", slotID)
		if itemLink then
			links[#links + 1] = itemLink
		end
	end

	if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemLink then
		for bagID = firstBagID, lastBagID do
			local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
			for slotID = 1, slotCount do
				local itemLink = C_Container.GetContainerItemLink(bagID, slotID)
				if itemLink then
					links[#links + 1] = itemLink
				end
			end
		end
	else
		local GetContainerNumSlotsLegacy = GetContainerNumSlots
		local GetContainerItemLinkLegacy = GetContainerItemLink
		if GetContainerNumSlotsLegacy and GetContainerItemLinkLegacy then
			for bagID = firstBagID, lastBagID do
				local slotCount = GetContainerNumSlotsLegacy(bagID) or 0
				for slotID = 1, slotCount do
					local itemLink = GetContainerItemLinkLegacy(bagID, slotID)
					if itemLink then
						links[#links + 1] = itemLink
					end
				end
			end
		end
	end

	if #links == 0 then return nil end
	return links[math.random(#links)]
end

-- #endregion

-- #region 2. ANIMATION ENGINE

local function TweenLoot_OnUpdate(frame)
	local state = frame._tweenState
	if not state then
		frame:SetScript("OnUpdate", nil)
		return
	end

	local t = GetTime() - state.startTime
	if t >= state.duration then
		frame:SetScale(1.0)
		frame:SetAlpha(1)
		if state.useAbsolutePositionTween then
			frame:ClearAllPoints()
			if #state.originalPoints > 0 then
				for i = 1, #state.originalPoints do
					local p = state.originalPoints[i]
					frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
				end
			else
				frame:SetPoint("BOTTOM", UIParent, "BOTTOM", state.anchorX, state.anchorY)
			end
		end

		frame._tweenState = nil
		frame:SetScript("OnUpdate", nil)
		if frame.waitAndAnimOut then frame.waitAndAnimOut:Play() end
		return
	end

	frame:SetScale(state.scaleFunc(t, 0.4, 0.6, state.duration))
	frame:SetAlpha(math.max(0, math.min(state.alphaFunc(t, 0, 1, state.duration), 1)))

	if state.useAbsolutePositionTween and state.positionFunc then
		local currentOffsetY = state.positionFunc(t, state.anchorY - state.offsetY, state.offsetY, state.duration)
		frame:ClearAllPoints()
		frame:SetPoint("BOTTOM", UIParent, "BOTTOM", state.anchorX, currentOffsetY)
	end
end

local function Tween(self, disablePositionTween)
	local duration = GetDuration()
	local startTime = GetTime()
	local scaleMode = GetTweenTypeFor("scale")
	local positionMode = GetTweenTypeFor("position")
	local alphaMode = GetTweenTypeFor("alpha")

	local scaleFunc = tweens[scaleMode] or tweens.Spring
	local positionFunc = (not disablePositionTween) and (tweens[positionMode] or tweens.Spring)
	local alphaFunc = tweens[alphaMode] or tweens.Spring

	local originalPoints = {}
	for i = 1, self:GetNumPoints() do
		local point, relativeTo, relativePoint, offsetX, offsetY = self:GetPoint(i)
		originalPoints[#originalPoints + 1] = {
			point,
			relativeTo,
			relativePoint,
			offsetX or 0,
			offsetY or 0,
		}
	end

	-- Resolve a stable absolute BOTTOM anchor relative to UIParent.
	-- This keeps the original visual behavior (grows/slides from below) while
	-- avoiding circular dependencies from anchoring to other alert frames.
	local anchorX, anchorY
	do
		local l = self:GetLeft()
		local b = self:GetBottom()
		if l and b then
			local w = self:GetWidth() or 0
			local uiCenterX = select(1, UIParent:GetCenter())
			anchorX = (l + w / 2) - uiCenterX
			anchorY = b
		end
	end
	local useAbsolutePositionTween = positionFunc and anchorX ~= nil

	-- Frames are pooled/reused. Reset previous tween state before applying a new one.
	self._tweenState = nil
	self:SetScript("OnUpdate", nil)

	if useAbsolutePositionTween then
		self:ClearAllPoints()
		self:SetPoint("BOTTOM", UIParent, "BOTTOM", anchorX, anchorY - offsetY)
	end

	self:SetScale(0.4)
	self:SetAlpha(0)
	self._tweenState = {
		startTime = startTime,
		duration = duration,
		scaleFunc = scaleFunc,
		positionFunc = positionFunc,
		alphaFunc = alphaFunc,
		offsetY = offsetY,
		anchorX = anchorX,
		anchorY = anchorY,
		useAbsolutePositionTween = useAbsolutePositionTween,
		originalPoints = originalPoints,
	}

	self:SetScript("OnUpdate", TweenLoot_OnUpdate)
end

-- #endregion

-- #region 3. OPTIONS UI

local function RunTest(useTween)
	InitLootHooks()

	local function QueueModeAndAlert(itemLink)
		if type(itemLink) ~= "string" or not itemLink:find("|Hitem:") then return end
		if not useTween then
			pendingNormalTests = pendingNormalTests + 1
		end
		LootAlertSystem:AddAlert(itemLink)
	end

	-- Primary path: random real item from equipped gear/bags.
	local ownedItemLink = GetRandomOwnedItemLink()
	if ownedItemLink then
		QueueModeAndAlert(ownedItemLink)
		return
	end

	-- Fallback path: configured rarity list IDs.
	if not TEST_ID or #TEST_ID == 0 then return end

	local randomIndex = math.random(#TEST_ID)

	-- Prefer an already-cached item starting from a random point so tests feel random
	for i = 0, #TEST_ID - 1 do
		local index = ((randomIndex + i - 1) % #TEST_ID) + 1
		local itemLink = select(2, GetItemInfo(TEST_ID[index]))
		if itemLink then
			QueueModeAndAlert(itemLink)
			return
		end
	end

	local selectedItemID = TEST_ID[randomIndex]
	local testItem = Item:CreateFromItemID(selectedItemID)
	testItem:ContinueOnItemLoad(function()
		local itemLink = testItem:GetItemLink()
		if itemLink then
			QueueModeAndAlert(itemLink)
			return
		end

		-- Last-resort fallback to Hearthstone.
		QueueModeAndAlert(select(2, GetItemInfo(6948)))
	end)
end

function InitializeOptions()
	category = Settings.RegisterVerticalLayoutCategory(addonName)

	-- Test Page
	local testPage = CreateFrame("Frame")
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
	testPage.tweenButton:SetScript("OnClick", function() RunTest(true) end)

	testPage.tween3Button = CreateFrame("Button", nil, testPage, "UIPanelButtonTemplate")
	testPage.tween3Button:SetSize(150, 28)
	testPage.tween3Button:SetPoint("LEFT", testPage.tweenButton, "RIGHT", 12, 0)
	testPage.tween3Button:SetText("Test Tween (x3)")
	testPage.tween3Button:SetScript("OnClick", function()
		for i = 1, 3 do
			RunTest(true)
		end
	end)

	testPage.normalButton = CreateFrame("Button", nil, testPage, "UIPanelButtonTemplate")
	testPage.normalButton:SetSize(150, 28)
	testPage.normalButton:SetPoint("LEFT", testPage.tween3Button, "RIGHT", 12, 0)
	testPage.normalButton:SetText("Test Normal")
	testPage.normalButton:SetScript("OnClick", function() RunTest(false) end)

	testPage.normal4Button = CreateFrame("Button", nil, testPage, "UIPanelButtonTemplate")
	testPage.normal4Button:SetSize(150, 28)
	testPage.normal4Button:SetPoint("LEFT", testPage.normalButton, "RIGHT", 12, 0)
	testPage.normal4Button:SetText("Test Normal (x4)")
	testPage.normal4Button:SetScript("OnClick", function()
		for i = 1, 3 do
			RunTest(false)
		end
	end)

	testPage.clearButton = CreateFrame("Button", nil, testPage, "UIPanelButtonTemplate")
	testPage.clearButton:SetSize(150, 28)
	testPage.clearButton:SetPoint("TOPLEFT", testPage.tweenButton, "BOTTOMLEFT", 0, -10)
	testPage.clearButton:SetText("Clear Alerts")
	testPage.clearButton:SetScript("OnClick", function() ClearAlerts() end)

	local font, size = GameFontNormalLarge:GetFont()

	testPage.commands = testPage:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	testPage.commands:SetPoint("TOPLEFT", testPage.clearButton, "BOTTOMLEFT", 0, -20)
	testPage.commands:SetFont(font, size + 3, "THICKOUTLINE")
	testPage.commands:SetText("Slash commands: /tl and /tweenloot")

	testPage.description = testPage:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	testPage.description:SetPoint("TOPLEFT", testPage.commands, "BOTTOMLEFT", 0, -8)
	testPage.description:SetWidth(400)
	testPage.description:SetJustifyH("LEFT")
	testPage.description:SetFont(font, size, "OUTLINE")
	testPage.description:SetText("/tl (or /tweenloot) - Open TweenLoot options\n/testnew - Direct Tween Test\n/testold - Direct Normal Test")

	Settings.RegisterCanvasLayoutSubcategory(category, testPage, "Test")

	local tweenChoices = {}
	for k in pairs(tweens) do table.insert(tweenChoices, k) end
	table.sort(tweenChoices)

	local function GetOptions()
		local container = Settings.CreateControlTextContainer()
		for _, name in ipairs(tweenChoices) do container:Add(name, name) end
		return container:GetData()
	end

	local function RegisterAutoTest(variableName)
		Settings.SetOnValueChangedCallback(variableName, function() RunTest(true) end)
	end

	local scaleVar = Settings.RegisterAddOnSetting(category, "TweenLoot_ScaleTweenType", "scaleTweenType", TweenLootDB, Settings.VarType.String, "Scale Tween", defaults.scaleTweenType)
	Settings.CreateDropdown(category, scaleVar, function() return GetOptions() end)
	RegisterAutoTest("TweenLoot_ScaleTweenType")

	local posVar = Settings.RegisterAddOnSetting(category, "TweenLoot_PositionTweenType", "positionTweenType", TweenLootDB, Settings.VarType.String, "Position Tween", defaults.positionTweenType)
	Settings.CreateDropdown(category, posVar, function() return GetOptions() end)
	RegisterAutoTest("TweenLoot_PositionTweenType")

	local alphaVar = Settings.RegisterAddOnSetting(category, "TweenLoot_AlphaTweenType", "alphaTweenType", TweenLootDB, Settings.VarType.String, "Alpha Tween", defaults.alphaTweenType)
	Settings.CreateDropdown(category, alphaVar, function() return GetOptions() end)
	RegisterAutoTest("TweenLoot_AlphaTweenType")

	local durVar = Settings.RegisterAddOnSetting(category, "TweenLoot_Duration", "duration", TweenLootDB, Settings.VarType.Number, "Duration", defaults.duration)
	local durOptions = Settings.CreateSliderOptions(0.1, 2.0, 0.1)
	durOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return string.format("%.1f s", v) end)
	Settings.CreateSlider(category, durVar, durOptions)

	Settings.RegisterAddOnCategory(category)
end

-- #endregion

-- #region 4. INITIALIZATION & HOOKS

local function InstallHooks()
	if hooksInitialized then return true end
	if not LootAlertSystem or not LootAlertSystem.alertFramePool then return false end

	-- Hook the AddAlert method to apply tweens to any alert as soon as it's added
	hooksecurefunc(LootAlertSystem, "AddAlert", function()
		-- /testold should use Blizzard's default animation path.
		if pendingNormalTests > 0 then
			pendingNormalTests = pendingNormalTests - 1
			return
		end

		-- Alert frames are pooled/reused. Tween only frames that are currently
		-- playing the default intro anim (freshly shown alerts), so existing
		-- active/fading alerts are not pulled into the new tween.
		local activeCount = 0
		for _ in LootAlertSystem.alertFramePool:EnumerateActive() do
			activeCount = activeCount + 1
		end
		local disablePositionTween = activeCount > 1

		for frame in LootAlertSystem.alertFramePool:EnumerateActive() do
			local isFreshDefaultAnim = frame.animIn and frame.animIn:IsPlaying()
			if isFreshDefaultAnim then
				-- Stop any default Blizzard animations
				if frame.animIn then frame.animIn:Stop() end
				if frame.waitAndAnimOut then frame.waitAndAnimOut:Stop() end
				-- Apply our tween
				Tween(frame, disablePositionTween)
			end
		end
	end)

	hooksInitialized = true
	return true
end

function InitLootHooks()
	if hooksInitialized then return end

	if initRetryTimer then
		initRetryTimer:Cancel()
		initRetryTimer = nil
	end

	if InstallHooks() then
		return
	end

	initRetryTimer = C_Timer.NewTicker(0.5, function()
		if InstallHooks() and initRetryTimer then
			initRetryTimer:Cancel()
			initRetryTimer = nil
		end
	end)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= addonName then return end

		TweenLootDB = TweenLootDB or {}
		for key, value in pairs(defaults) do
			if TweenLootDB[key] == nil then
				TweenLootDB[key] = value
			end
		end

		InitializeOptions()
		self:UnregisterEvent(event)
	elseif event == "PLAYER_ENTERING_WORLD" then
		InitLootHooks()
	end
end)

-- #endregion

-- #region 5. SLASH COMMANDS & GLOBALS

function TweenLoot_Settings()
	if not InCombatLockdown() and category then
		Settings.OpenToCategory(category:GetID())
	end
end

SLASH_TWEENLOOT1 = "/tl"
SLASH_TWEENLOOT2 = "/tweenloot"
SlashCmdList["TWEENLOOT"] = TweenLoot_Settings

SLASH_TWEENLOOT_TESTNEW1 = "/testnew"
SlashCmdList["TWEENLOOT_TESTNEW"] = function() RunTest(true) end

SLASH_TWEENLOOT_TESTOLD1 = "/testold"
SlashCmdList["TWEENLOOT_TESTOLD"] = function() RunTest(false) end

-- #endregion
