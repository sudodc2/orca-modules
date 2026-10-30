-- Dex Explorer · orca edition
-- stock Dex core (vendored to our repo) + live Orca skin pass:
-- #232428 cards / #1B1C20 insets / Gotham / UICorner chrome
-- https://github.com/sudodc2/orca-modules

local RunService = game:GetService("RunService")

-- orca theme tokens (same palette as the dashboard)
local CARD   = Color3.fromHex("#232428")
local INSET  = Color3.fromHex("#1B1C20")
local MID    = Color3.fromHex("#2E2F35")
local ACCENT = Color3.fromHex("#37a4cc")
local TEXT   = Color3.fromHex("#ffffff")

-- snapshot every ScreenGui that exists before Dex loads
local roots = {}
pcall(function() roots[#roots+1] = gethui() end)
pcall(function() roots[#roots+1] = game:GetService("CoreGui") end)
pcall(function() roots[#roots+1] = game:GetService("Players").LocalPlayer:FindFirstChildWhichIsA("PlayerGui") end)
local seen, skinned = {}, {}
for _, r in ipairs(roots) do
    for _, d in ipairs(r:GetDescendants()) do
        if d:IsA("ScreenGui") then seen[d] = true end
    end
end

local function reskinNode(d)
    pcall(function()
        if d:IsA("Frame") or d:IsA("ScrollingFrame") or d:IsA("ImageLabel")
            or d:IsA("TextButton") or d:IsA("TextBox") or d:IsA("ImageButton") then
            local c = d.BackgroundColor3
            local hi, lo = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
            if hi - lo < 0.05 then                    -- grays -> orca palette
                local lum = 0.299*c.R + 0.587*c.G + 0.114*c.B
                if lum < 0.15 then d.BackgroundColor3 = INSET
                elseif lum < 0.30 then d.BackgroundColor3 = CARD
                elseif lum < 0.60 then d.BackgroundColor3 = MID end
            elseif c.B > c.R + 0.08 then              -- blue accents/selection
                d.BackgroundColor3 = ACCENT
            end
        end
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            local f = d.Font
            if f == Enum.Font.SourceSans or f == Enum.Font.SourceSansSemibold
                or f == Enum.Font.SourceSansLight or f == Enum.Font.Arial then
                d.Font = Enum.Font.Gotham
            elseif f == Enum.Font.SourceSansBold or f == Enum.Font.ArialBold then
                d.Font = Enum.Font.GothamBold
            end
            local tc = d.TextColor3
            local tlum = 0.299*tc.R + 0.587*tc.G + 0.114*tc.B
            if tlum < 0.35 and tlum > 0 then d.TextColor3 = TEXT end
        end
    end)
end

local function skinGui(g)
    if skinned[g] then return end
    skinned[g] = true
    for _, d in ipairs(g:GetDescendants()) do reskinNode(d) end
    -- rounded chrome on top-level window frames
    for _, w in ipairs(g:GetChildren()) do
        pcall(function()
            if w:IsA("GuiObject") and not w:FindFirstChildOfClass("UICorner") then
                local c = Instance.new("UICorner")
                c.CornerRadius = UDim.new(0, 10)
                c.Parent = w
            end
        end)
    end
    -- Dex builds panels lazily: reskin anything it adds later (debounced)
    local pending = false
    g.DescendantAdded:Connect(function(n)
        if pending then return end
        pending = true
        task.delay(0.4, function()
            pending = false
            if g.Parent then reskinNode(n) end
        end)
    end)
end

local function scanForDex()
    for _, r in ipairs(roots) do
        for _, d in ipairs(r:GetDescendants()) do
            if d:IsA("ScreenGui") and not seen[d] then
                seen[d] = true
                task.delay(0.3, function() skinGui(d) end)
            end
        end
    end
end
for _, r in ipairs(roots) do
    r.DescendantAdded:Connect(function(d)
        if d:IsA("ScreenGui") and not seen[d] then
            seen[d] = true
            task.delay(0.3, function() skinGui(d) end)
        end
    end)
end

-- stock Dex core, vendored under our own repo
loadstring(game:HttpGet("https://raw.githubusercontent.com/sudodc2/orca-modules/main/dex-core.lua"))()
task.delay(2, scanForDex)
print("[Dex] orca skin loaded")
