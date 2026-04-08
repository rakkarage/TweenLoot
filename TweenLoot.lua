local addonName, ns = ...

-- ==========================================
-- 1. MATH CORE (Ported from Godot Engine)
-- ==========================================
local Spring = {}
local PI = math.pi
local sin = math.sin
local pow = math.pow

-- The "Spring Out" easing formula
-- t: current time, b: beginning value, c: total change, d: duration
function Spring.out(t, b, c, d)
    t = t / d
    local s = 1.0 - t
    -- Frequency shifts based on t^3 + power decay of 2.2
    t = (sin(t * PI * (0.2 + 2.5 * t ^ 3)) * pow(s, 2.2) + t) * (1.0 + (1.2 * s))
    return c * t + b
end

-- ==========================================
-- 2. ANIMATION ENGINE
-- ==========================================
local function Tween(frame, duration, startScale, endScale)
    local startTime = GetTime()

    -- Set initial state
    frame:SetScale(startScale)
    frame:SetAlpha(0)

    -- Update loop
    frame:SetScript("OnUpdate", function(self, elapsed)
        local t = GetTime() - startTime

        if t >= duration then
            self:SetScale(endScale)
            self:SetAlpha(1)
            self:SetScript("OnUpdate", nil) -- Kill script when done
            return
        end

        -- Calculate and apply new scale
        local currentScale = Spring.out(t, startScale, endScale - startScale, duration)
        self:SetScale(currentScale)

        -- Quick alpha fade-in (first 15% of duration)
        local alpha = math.min(t / (duration * 0.15), 1)
        self:SetAlpha(alpha)
    end)
end

-- ==========================================
-- 3. LOOT ALERT HOOKS
-- ==========================================
local function InitLootHooks()
    -- Check if the alert system exists
    if not LootAlertSystem or not LootAlertSystem.alertFramePool then return end

    -- Hook the pool's resetter. This runs whenever a frame is grabbed for use.
    hooksecurefunc(LootAlertSystem.alertFramePool, "resetterFunc", function(pool, frame)
        -- We use a one-time hook on OnShow so it doesn't loop infinitely
        if not frame.isSpringHooked then
            frame:HookScript("OnShow", function(self)
                -- 0.7s duration, pops from 40% size to 100%
                Tween(self, 0.7, 0.4, 1.0)
            end)
            frame.isSpringHooked = true
        end
    end)
end

-- Wait for the UI to be ready
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self, event)
    InitLootHooks()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    print("|cFF00FF00SpringLoot Loaded:|r Type /sl to test.")
end)

-- ==========================================
-- 4. TESTING TOOLS
-- ==========================================
SLASH_SPRINGLOOT1 = "/tl"
SlashCmdList["TWEENLOOT"] = function()
    if LootAlertSystem then
        -- Generate a fake legendary loot alert (Thunderfury)
        LootAlertSystem:AddAlert(ItemLocation:CreateFromItemID(19019))
        print("TweenLoot: Triggering test alert...")
    else
        print("TweenLoot: Alert system not found.")
    end
end
