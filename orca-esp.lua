-- Unnamed ESP (Orca edition) — remade in the AudioCrafter/Orca style
-- draggable window · switch rows · steppers · unload button
-- Drawing API backend · safe to re-execute
-- https://github.com/sudodc2/orca-modules

if getgenv()._ORCA_ESP_UNLOAD then pcall(getgenv()._ORCA_ESP_UNLOAD) end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local HttpService= game:GetService("HttpService")
local LP         = Players.LocalPlayer
local Camera     = workspace.CurrentCamera

-- ============================== options ==============================
local opts = {
    Enabled        = true,
    TeamCheck      = false,
    TeamColor      = false,
    Names          = true,
    Distance       = true,
    Health         = true,
    Boxes          = true,
    Tracers        = false,
    HeadDot        = false,
    VisibilityCheck= true,
    Crosshair      = false,
    TextOutline    = true,
    TextSize       = 14,
    MaxDistance    = 1000,
    YOffset        = 0,
    MenuKey        = Enum.KeyCode.RightShift,
}
local ENEMY  = Color3.fromRGB(255, 70, 70)
local TEAM   = Color3.fromRGB(90, 200, 120)
local WHITE  = Color3.fromRGB(235, 235, 240)

-- ============================== drawing pool ==============================
local pool = {} -- [player] = {box=,boxo=,name=,dist=,hbg=,hfg=,tracer=,dot=}
local conns = {}
local dead = false

local function newDrawing(kind, props)
    local d = Drawing.new(kind)
    for k, v in pairs(props) do pcall(function() d[k] = v end) end
    return d
end

local function setup(plr)
    if pool[plr] then return end
    pool[plr] = {
        boxo   = newDrawing("Square", {Thickness = 3, Filled = false, Color = Color3.new(0,0,0)}),
        box    = newDrawing("Square", {Thickness = 1, Filled = false}),
        name   = newDrawing("Text",   {Size = opts.TextSize, Center = true, Outline = opts.TextOutline, Font = 2}),
        dist   = newDrawing("Text",   {Size = opts.TextSize, Center = true, Outline = opts.TextOutline, Font = 2}),
        hbg    = newDrawing("Square", {Filled = true, Color = Color3.fromRGB(30,30,35), Thickness = 0}),
        hfg    = newDrawing("Square", {Filled = true, Color = Color3.fromRGB(90,220,110), Thickness = 0}),
        tracer = newDrawing("Line",   {Thickness = 1}),
        dot    = newDrawing("Circle", {Radius = 3, Filled = true, NumSides = 24}),
    }
end

local function drop(plr)
    local p = pool[plr]; if not p then return end
    for _, d in pairs(p) do pcall(function() d:Remove() end) end
    pool[plr] = nil
end

local function hideAll(p)
    for _, d in pairs(p) do pcall(function() d.Visible = false end) end
end

local function teamOk(plr)
    if not opts.TeamCheck then return true end
    if plr.Neutral and LP.Neutral then return true end
    return plr.TeamColor == LP.TeamColor
end

local function colOf(plr)
    if opts.TeamColor and plr.TeamColor then return plr.TeamColor.Color end
    return (teamOk(plr) and plr.TeamColor == LP.TeamColor) and TEAM or ENEMY
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function visible(head, char)
    if not opts.VisibilityCheck then return true end
    rayParams.FilterDescendantsInstances = {LP.Character, char, Camera}
    local r = workspace:Raycast(Camera.CFrame.Position, head.Position - Camera.CFrame.Position, rayParams)
    return r == nil
end

local chCross = newDrawing("Circle", {Radius = 6, Thickness = 1, NumSides = 32, Filled = false, Color = WHITE})

local function step()
    local vp = Camera.ViewportSize
    chCross.Position = Vector2.new(vp.X/2, vp.Y/2)
    chCross.Visible = opts.Crosshair

    for plr, p in pairs(pool) do
        local char = plr.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not (opts.Enabled and char and hrp and head and hum and hum.Health > 0 and teamOk(plr)) then
            hideAll(p); continue
        end

        local rootPos = hrp.Position + Vector3.new(0, opts.YOffset, 0)
        local dist = (Camera.CFrame.Position - rootPos).Magnitude
        if dist > opts.MaxDistance then hideAll(p); continue end

        local pos, onScreen = Camera:WorldToViewportPoint(rootPos)
        if not onScreen or pos.Z <= 0 then hideAll(p); continue end

        local scale = 1 / (pos.Z * math.tan(math.rad(Camera.FieldOfView / 2)) * 2) * 1000
        local w = math.floor(4.5 * scale); local h = math.floor(6 * scale)
        local x = math.floor(pos.X - w/2); local y = math.floor(pos.Y - h/2)
        local col = colOf(plr)
        local a = visible(head, char) and 1 or 0.35 -- dim when occluded

        local function setA(d, base) -- cheap alpha via color lerp to black
            if a < 1 then pcall(function()
                local c = d.Color; if c then d.Color = c:Lerp(Color3.new(0,0,0), 1 - a) end
            end) end
        end

        p.box.Visible = opts.Boxes; p.boxo.Visible = opts.Boxes
        if opts.Boxes then
            p.box.Position = Vector2.new(x, y); p.box.Size = Vector2.new(w, h); p.box.Color = col
            p.boxo.Position = Vector2.new(x-1, y-1); p.boxo.Size = Vector2.new(w+2, h+2)
        end

        p.name.Visible = opts.Names
        if opts.Names then
            p.name.Text = plr.DisplayName; p.name.Size = opts.TextSize
            p.name.Position = Vector2.new(pos.X, y - opts.TextSize - 3); p.name.Color = col; setA(p.name)
            p.name.Outline = opts.TextOutline
        end

        p.dist.Visible = opts.Distance
        if opts.Distance then
            p.dist.Text = string.format("[%d]", dist); p.dist.Size = math.max(opts.TextSize - 2, 9)
            p.dist.Position = Vector2.new(pos.X, y + h + 2); p.dist.Color = WHITE; setA(p.dist)
            p.dist.Outline = opts.TextOutline
        end

        p.hbg.Visible = opts.Health; p.hfg.Visible = opts.Health
        if opts.Health then
            local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local bh = math.max(h - 2, 2)
            p.hbg.Position = Vector2.new(x - 6, y); p.hbg.Size = Vector2.new(3, h)
            p.hfg.Position = Vector2.new(x - 6, y + bh * (1 - frac)); p.hfg.Size = Vector2.new(3, bh * frac)
            p.hfg.Color = Color3.fromRGB(255 - 155*frac, 90 + 130*frac, 80)
        end

        p.tracer.Visible = opts.Tracers
        if opts.Tracers then
            p.tracer.From = Vector2.new(vp.X/2, vp.Y); p.tracer.To = Vector2.new(pos.X, y + h)
            p.tracer.Color = col; setA(p.tracer)
        end

        p.dot.Visible = opts.HeadDot
        if opts.HeadDot then
            local hp = Camera:WorldToViewportPoint(head.Position)
            p.dot.Position = Vector2.new(hp.X, hp.Y); p.dot.Color = col; setA(p.dot)
        end
    end
end

-- ============================== UI ==============================
local ACCENT = Color3.fromRGB(122, 162, 255)
local BG     = Color3.fromRGB(18, 19, 24)
local CARD   = Color3.fromRGB(28, 30, 38)
local ROW    = Color3.fromRGB(22, 23, 30)
local TXT    = Color3.fromRGB(232, 233, 240)
local SUB    = Color3.fromRGB(150, 152, 165)

local gui = Instance.new("ScreenGui")
gui.Name = "OrcaESP_" .. HttpService:GenerateGUID(false):sub(1, 8)
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 8
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = gethui() end)
if not gui.Parent then pcall(function() gui.Parent = game:GetService("CoreGui") end) end
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local win = Instance.new("Frame")
win.Size = UDim2.new(0, 252, 0, 0)
win.AutomaticSize = Enum.AutomaticSize.Y
win.Position = UDim2.new(0, 24, 0.5, -160)
win.BackgroundColor3 = BG
win.BackgroundTransparency = 0.06
win.BorderSizePixel = 0
win.Parent = gui
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke", win)
stroke.Color = Color3.fromRGB(255,255,255); stroke.Transparency = 0.9; stroke.Thickness = 1

local pad = Instance.new("UIPadding", win)
pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 10)
pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
local list = Instance.new("UIListLayout", win)
list.SortOrder = Enum.SortOrder.LayoutOrder; list.Padding = UDim.new(0, 4)

-- ---- title bar (drag handle)
local title = Instance.new("Frame")
title.Size = UDim2.new(1, 0, 0, 30); title.BackgroundTransparency = 1
title.LayoutOrder = 0; title.Parent = win
local ttl = Instance.new("TextLabel", title)
ttl.Size = UDim2.new(1, -60, 1, 0); ttl.Position = UDim2.new(0, 6, 0, 0)
ttl.BackgroundTransparency = 1; ttl.Text = "Unnamed ESP"; ttl.Font = Enum.Font.GothamBold
ttl.TextSize = 14; ttl.TextColor3 = TXT; ttl.TextXAlignment = Enum.TextXAlignment.Left
local by = Instance.new("TextLabel", title)
by.Size = UDim2.new(1, -60, 0, 12); by.Position = UDim2.new(0, 6, 0, 16)
by.BackgroundTransparency = 1; by.Text = "orca edition"; by.Font = Enum.Font.Gotham
by.TextSize = 10; by.TextColor3 = SUB; by.TextXAlignment = Enum.TextXAlignment.Left

local function titleBtn(txt, xoff, col)
    local b = Instance.new("TextButton", title)
    b.Size = UDim2.new(0, 22, 0, 22); b.Position = UDim2.new(1, xoff, 0, 4)
    b.BackgroundColor3 = ROW; b.BackgroundTransparency = 0.2; b.Text = txt
    b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.TextColor3 = col or TXT
    b.AutoButtonColor = true; b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end
local btnHide   = titleBtn("–", -50)
local btnUnload = titleBtn("✕", -26, Color3.fromRGB(255, 110, 110))

-- dragging
do
    local dragging, dragStart, startPos
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = i.Position; startPos = win.Position
        end
    end)
    table.insert(conns, UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                     startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    table.insert(conns, UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
end

-- ---- row builders
local function rowBase(h)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, h); r.BackgroundColor3 = ROW
    r.BackgroundTransparency = 0.35; r.BorderSizePixel = 0
    Instance.new("UICorner", r).CornerRadius = UDim.new(0, 8)
    r.Parent = win
    return r
end

local switches = {}
local function addToggle(label, key)
    local r = rowBase(30)
    local t = Instance.new("TextLabel", r)
    t.Size = UDim2.new(1, -52, 1, 0); t.Position = UDim2.new(0, 10, 0, 0)
    t.BackgroundTransparency = 1; t.Text = label; t.Font = Enum.Font.Gotham
    t.TextSize = 12; t.TextColor3 = TXT; t.TextXAlignment = Enum.TextXAlignment.Left
    local sw = Instance.new("Frame", r)
    sw.Size = UDim2.new(0, 34, 0, 18); sw.Position = UDim2.new(1, -44, 0.5, -9)
    sw.BackgroundColor3 = opts[key] and ACCENT or Color3.fromRGB(60, 62, 72)
    sw.BorderSizePixel = 0
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame", sw)
    knob.Size = UDim2.new(0, 12, 0, 12); knob.BorderSizePixel = 0
    knob.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
    knob.Position = opts[key] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local hit = Instance.new("TextButton", r)
    hit.Size = UDim2.new(1, 0, 1, 0); hit.BackgroundTransparency = 1; hit.Text = ""
    hit.Activated:Connect(function()
        opts[key] = not opts[key]
        local on = opts[key]
        game:GetService("TweenService"):Create(sw, TweenInfo.new(0.12), {
            BackgroundColor3 = on and ACCENT or Color3.fromRGB(60, 62, 72)}):Play()
        game:GetService("TweenService"):Create(knob, TweenInfo.new(0.12), {
            Position = on and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)}):Play()
    end)
    switches[key] = {sw = sw, knob = knob}
end

local function addStepper(label, key, min, max, stepv)
    local r = rowBase(30)
    local t = Instance.new("TextLabel", r)
    t.Size = UDim2.new(1, -110, 1, 0); t.Position = UDim2.new(0, 10, 0, 0)
    t.BackgroundTransparency = 1; t.Text = label; t.Font = Enum.Font.Gotham
    t.TextSize = 12; t.TextColor3 = TXT; t.TextXAlignment = Enum.TextXAlignment.Left
    local val = Instance.new("TextLabel", r)
    val.Size = UDim2.new(0, 46, 0, 20); val.Position = UDim2.new(1, -76, 0.5, -10)
    val.BackgroundColor3 = CARD; val.BackgroundTransparency = 0.2; val.BorderSizePixel = 0
    val.Text = tostring(opts[key]); val.Font = Enum.Font.GothamBold; val.TextSize = 11
    val.TextColor3 = TXT
    Instance.new("UICorner", val).CornerRadius = UDim.new(0, 6)
    local function mkBtn(txt, xo)
        local b = Instance.new("TextButton", r)
        b.Size = UDim2.new(0, 20, 0, 20); b.Position = UDim2.new(1, xo, 0.5, -10)
        b.BackgroundColor3 = CARD; b.BackgroundTransparency = 0.2; b.BorderSizePixel = 0
        b.Text = txt; b.Font = Enum.Font.GothamBold; b.TextSize = 13; b.TextColor3 = TXT
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end
    local minus = mkBtn("−", -52); local plus = mkBtn("+", -26)
    minus.Activated:Connect(function()
        opts[key] = math.clamp(opts[key] - stepv, min, max); val.Text = tostring(opts[key])
    end)
    plus.Activated:Connect(function()
        opts[key] = math.clamp(opts[key] + stepv, min, max); val.Text = tostring(opts[key])
    end)
end

local function addDivider(txt)
    local d = Instance.new("TextLabel")
    d.Size = UDim2.new(1, 0, 0, 16); d.BackgroundTransparency = 1; d.Text = txt
    d.Font = Enum.Font.GothamBold; d.TextSize = 10; d.TextColor3 = SUB
    d.TextXAlignment = Enum.TextXAlignment.Left; d.Parent = win
    local p2 = Instance.new("UIPadding", d); p2.PaddingLeft = UDim.new(0, 6)
end

addDivider("DISPLAY")
addToggle("ESP Enabled", "Enabled")
addToggle("Show Team", "TeamCheck")
addToggle("Team Color", "TeamColor")
addToggle("Names", "Names")
addToggle("Distance", "Distance")
addToggle("Health", "Health")
addToggle("Boxes", "Boxes")
addToggle("Tracers", "Tracers")
addToggle("Head Dot", "HeadDot")
addToggle("Visibility Check", "VisibilityCheck")
addToggle("Crosshair", "Crosshair")
addToggle("Text Outline", "TextOutline")
addDivider("SETTINGS")
addStepper("Text Size", "TextSize", 8, 32, 1)
addStepper("Y Offset", "YOffset", -10, 10, 1)
addStepper("Max Distance", "MaxDistance", 50, 5000, 50)

local foot = rowBase(32)
foot.BackgroundColor3 = Color3.fromRGB(60, 30, 34); foot.BackgroundTransparency = 0.3
local fl = Instance.new("TextLabel", foot)
fl.Size = UDim2.new(1, -10, 1, 0); fl.Position = UDim2.new(0, 10, 0, 0)
fl.BackgroundTransparency = 1; fl.Text = "Unload ESP"; fl.Font = Enum.Font.GothamBold
fl.TextSize = 12; fl.TextColor3 = Color3.fromRGB(255, 140, 140)
fl.TextXAlignment = Enum.TextXAlignment.Left
local hint = Instance.new("TextLabel", foot)
hint.Size = UDim2.new(0, 90, 1, 0); hint.Position = UDim2.new(1, -96, 0, 0)
hint.BackgroundTransparency = 1; hint.Text = "RShift hide"; hint.Font = Enum.Font.Gotham
hint.TextSize = 10; hint.TextColor3 = SUB; hint.TextXAlignment = Enum.TextXAlignment.Right
local fb = Instance.new("TextButton", foot)
fb.Size = UDim2.new(1, 0, 1, 0); fb.BackgroundTransparency = 1; fb.Text = ""

-- ============================== unload ==============================
local function unload()
    if dead then return end; dead = true
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for plr in pairs(pool) do drop(plr) end
    pcall(function() chCross:Remove() end)
    pcall(function() gui:Destroy() end)
    getgenv()._ORCA_ESP_UNLOAD = nil
    getgenv()._ORCA_ESP_LOADED = nil
end
getgenv()._ORCA_ESP_UNLOAD = unload
getgenv()._ORCA_ESP_LOADED = true

fb.Activated:Connect(unload)
btnUnload.Activated:Connect(unload)
btnHide.Activated:Connect(function() win.Visible = not win.Visible end)

-- menu key + player tracking
table.insert(conns, UIS.InputBegan:Connect(function(i, gpe)
    if not gpe and i.KeyCode == opts.MenuKey then win.Visible = not win.Visible end
end))
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LP then setup(plr) end
end
table.insert(conns, Players.PlayerAdded:Connect(function(plr)
    if plr ~= LP then setup(plr) end
end))
table.insert(conns, Players.PlayerRemoving:Connect(drop))
table.insert(conns, RunService.RenderStepped:Connect(function()
    Camera = workspace.CurrentCamera
    step()
end))

print("[OrcaESP] loaded — RightShift to hide menu")
