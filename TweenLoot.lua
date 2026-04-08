local addonName, ns = ...

ns.TweenLoot = CreateFrame("Frame")
local TweenLoot = ns.TweenLoot
TweenLoot.name = addonName

TweenLoot.defaults = {
	tweenType = "Spring",
	duration = 0.5,
}

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

TweenLoot.category = nil
TweenLoot.tweenChoices = nil

function TweenLoot:GetTweenType()
	local key = TweenLootDB and TweenLootDB.tweenType or self.defaults.tweenType
	if self.tweens[key] then return key end
	return self.defaults.tweenType
end

function TweenLoot:GetDuration()
	return TweenLootDB and TweenLootDB.duration or self.defaults.duration
end

-- ==========================================
-- 2. ANIMATION ENGINE
-- ==========================================
function TweenLoot:Tween(frame, duration, startScale, endScale)
	local startTime = GetTime()
	local tweenType = self:GetTweenType()
	local func = self.tweens[tweenType] or self.tweens.Spring

	frame:SetScale(startScale)
	frame:SetAlpha(0)

	frame:SetScript("OnUpdate", function(self, elapsed)
		local t = GetTime() - startTime

		if t >= duration then
			self:SetScale(endScale)
			self:SetAlpha(1)
			self:SetScript("OnUpdate", nil)
			if self.waitAndAnimOut then self.waitAndAnimOut:Play() end
			return
		end

		local currentScale = func(t, startScale, endScale - startScale, duration)
		self:SetScale(currentScale)
		self:SetAlpha(math.min(t / (duration * 0.15), 1))
	end)
end

-- ==========================================
-- 3. OPTIONS UI (Settings Panel)
-- ==========================================
function TweenLoot:InitializeOptions()
	if self.category then return end

	local rootCategory = Settings.RegisterVerticalLayoutCategory(self.name)
	self.category = rootCategory

	local testPage = CreateFrame("Frame", nil, UIParent)
	testPage.name = "Test"

	testPage.title = testPage:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	testPage.title:SetPoint("TOPLEFT", 7, -22)
	testPage.title:SetText("TweenLoot - Test")

	testPage.divider = testPage:CreateTexture(nil, "ARTWORK")
	testPage.divider:SetAtlas("Options_HorizontalDivider", true)
	testPage.divider:SetPoint("TOP", 0, -50)

	testPage.note = testPage:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	testPage.note:SetPoint("TOPLEFT", testPage.divider, "BOTTOMLEFT", 0, -20)
	testPage.note:SetJustifyH("LEFT")
	testPage.note:SetText("Use these to compare tweened and normal loot alerts.")

	testPage.tweenButton = CreateFrame("Button", nil, testPage, "UIPanelButtonTemplate")
	testPage.tweenButton:SetSize(150, 28)
	testPage.tweenButton:SetPoint("TOPLEFT", testPage.note, "BOTTOMLEFT", 0, -14)
	testPage.tweenButton:SetText("Test Tween")
	testPage.tweenButton:SetScript("OnClick", function() TweenLoot:RunTest(true) end)

	testPage.normalButton = CreateFrame("Button", nil, testPage, "UIPanelButtonTemplate")
	testPage.normalButton:SetSize(150, 28)
	testPage.normalButton:SetPoint("LEFT", testPage.tweenButton, "RIGHT", 12, 0)
	testPage.normalButton:SetText("Test Normal")
	testPage.normalButton:SetScript("OnClick", function() TweenLoot:RunTest(false) end)

	testPage.commands = testPage:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	testPage.commands:SetPoint("TOPLEFT", testPage.tweenButton, "BOTTOMLEFT", 0, -10)
	testPage.commands:SetJustifyH("LEFT")
	testPage.commands:SetText("Slash commands: /tl and /nl")

	local testCategory = Settings.RegisterCanvasLayoutSubcategory(rootCategory, testPage, "Test")

	if not self.tweenChoices then
		local choices = {}
		for tweenKey in pairs(self.tweens) do
			choices[#choices + 1] = tweenKey
		end
		table.sort(choices)
		self.tweenChoices = choices
	end

	local tweenContainer = Settings.CreateControlTextContainer()
	for _, tweenName in ipairs(self.tweenChoices) do
		tweenContainer:Add(tweenName, tweenName)
	end
	local tweenOptions = tweenContainer:GetData()

	Settings.CreateDropdown(rootCategory,
		Settings.RegisterAddOnSetting(rootCategory,
			"TweenLoot_TweenType", "tweenType", TweenLootDB, Settings.VarType.String, "Tween Type", self.defaults.tweenType),
		function() return tweenOptions end,
		"Easing function used for loot alert scale animation.")

	local durationSetting = Settings.RegisterAddOnSetting(rootCategory,
		"TweenLoot_Duration", "duration", TweenLootDB, Settings.VarType.Number, "Animation Duration", self.defaults.duration)
	local durationOptions = Settings.CreateSliderOptions(0.1, 2.0, 0.1)
	durationOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return string.format("%.1f sec", value)
	end)
	Settings.CreateSlider(rootCategory, durationSetting, durationOptions,
		"Duration of the loot alert tween animation (in seconds).")

	Settings.RegisterAddOnCategory(rootCategory)
	Settings.RegisterAddOnCategory(testCategory)
end

-- ==========================================
-- 4. INITIALIZATION & HOOKS
-- ==========================================
function TweenLoot:InitLootHooks()
	if not LootAlertSystem then return end

	hooksecurefunc(LootAlertSystem, "AddAlert", function(self)
		if self.tempDisableTween then return end

		for frame in self.alertFramePool:EnumerateActive() do
			if not frame.isSpringHooked then
				frame:HookScript("OnShow", function(s)
					if s.animIn then s.animIn:Stop() end
					if s.waitAndAnimOut then s.waitAndAnimOut:Stop() end
					TweenLoot:Tween(s, TweenLoot:GetDuration(), 0.4, 1.0)
				end)
				frame.isSpringHooked = true
			end

			if frame:IsVisible() and not frame:GetScript("OnUpdate") then
				if frame.animIn then frame.animIn:Stop() end
				if frame.waitAndAnimOut then frame.waitAndAnimOut:Stop() end
				TweenLoot:Tween(frame, TweenLoot:GetDuration(), 0.4, 1.0)
			end
		end
	end)
end

function TweenLoot:PLAYER_ENTERING_WORLD()
	self:InitLootHooks()
	print("|cFF00FF00TweenLoot:|r /tl or /nl to test. Settings in AddOns menu.")
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

function TweenLoot:ADDON_LOADED(event, name)
	if name ~= self.name then return end

	TweenLootDB = TweenLootDB or {}
	for key, value in pairs(self.defaults) do
		if TweenLootDB[key] == nil then
			TweenLootDB[key] = value
		end
	end

	self:InitializeOptions()

	self:UnregisterEvent("ADDON_LOADED")
end

TweenLoot:SetScript("OnEvent", function(self, event, ...)
	if self[event] then self[event](self, event, ...) end
end)
TweenLoot:RegisterEvent("ADDON_LOADED")
TweenLoot:RegisterEvent("PLAYER_ENTERING_WORLD")

-- ==========================================
-- 5. SLASH COMMANDS
-- ==========================================
function TweenLoot:RunTest(useTween)
	if not LootAlertSystem then return end

	local function ShowTestAlert(itemLink)
		LootAlertSystem.tempDisableTween = not useTween
		LootAlertSystem:AddAlert(itemLink, 1)
		LootAlertSystem.tempDisableTween = nil
	end

	local function FindRandomBagItemLink()
		if not C_Container then return nil end
		local bagItemLinks = {}
		for bag = 0, NUM_BAG_SLOTS do
			local numSlots = C_Container.GetContainerNumSlots(bag)
			for slot = 1, numSlots do
				local link = C_Container.GetContainerItemLink(bag, slot)
				if link then
					bagItemLinks[#bagItemLinks + 1] = link
				end
			end
		end

		if #bagItemLinks == 0 then
			return nil
		end

		local index = math.random(1, #bagItemLinks)
		return bagItemLinks[index]
	end

	local itemLink = FindRandomBagItemLink()
	if not itemLink then
		local testItemID = 6948 -- Fallback when bags are empty.
		itemLink = select(2, GetItemInfo(testItemID))
	end

	if itemLink then
		ShowTestAlert(itemLink)
	else
		print("|cFF00FF00TweenLoot:|r No cached item link available yet. Open bags and try again.")
	end
end

function TweenLoot_Settings()
	if TweenLoot.category and not InCombatLockdown() then
		Settings.OpenToCategory(TweenLoot.category:GetID())
	end
end

SLASH_TWEENLOOT1, SLASH_TWEENLOOT2 = "/testloottween", "/tl"
SlashCmdList["TWEENLOOT"] = function() TweenLoot:RunTest(true) end

SLASH_NOTWEEN1, SLASH_NOTWEEN2 = "/testlootnormal", "/nl"
SlashCmdList["NOTWEEN"] = function() TweenLoot:RunTest(false) end
