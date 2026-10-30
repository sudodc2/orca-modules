-- Unnamed ESP · orca edition
-- rebuilt on the Orca component model: el() element trees, uiIcon() lucide
-- pipeline, apps.players theme tokens, Card chrome, pill switches, icon buttons
-- https://github.com/sudodc2/orca-modules

if getgenv()._ORCA_ESP_UNLOAD then pcall(getgenv()._ORCA_ESP_UNLOAD) end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local TweenSvc   = game:GetService("TweenService")
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
local pool, conns = {}, {}
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
    return workspace:Raycast(Camera.CFrame.Position, head.Position - Camera.CFrame.Position, rayParams) == nil
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
        local a = visible(head, char) and 1 or 0.35

        local function setA(d)
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

-- ============================== orca ui kit ==============================
-- theme tokens (apps.players subtheme — same palette the dashboard uses)
local T = {
    background  = Color3.fromHex("#232428"), -- card
    inset       = Color3.fromHex("#1B1C20"), -- rows / chips / pills
    foreground  = Color3.fromHex("#ffffff"),
    accent      = Color3.fromHex("#37a4cc"), -- themeButton accent
    switchOff   = Color3.fromRGB(41, 42, 48),-- stock switch track when off
    danger      = Color3.fromHex("#EC423D"),
    dangerBg    = Color3.fromRGB(60, 30, 34),
}

local function ud(x, y) return UDim2.new(0, x, 0, y) end

-- same icon pipeline as the dashboard: lucide svg -> weserv png -> _orca/icons -> customasset
local _IC = (getgenv and getgenv()._ORCA_ICONS) or {}
if getgenv then getgenv()._ORCA_ICONS = _IC end
local function uiIcon(name)
    if _IC[name] ~= nil then return _IC[name] end
    local p = "_orca/icons/" .. name .. ".png"
    if not (isfile and isfile(p)) then
        -- fetch through the same proxy the bundle uses, then cache for every module
        local url = "https://images.weserv.nl/?url=api.iconify.design%2Flucide%2F"
            .. name .. ".svg%3Fcolor%3Dwhite%26height%3D64&w=64&h=64&fit=contain&output=png"
        local ok, data = pcall(function() return game:HttpGet(url, true) end)
        if ok and data and #data > 100 and writefile then
            pcall(makefolder, "_orca"); pcall(makefolder, "_orca/icons")
            pcall(writefile, p, data)
        end
    end
    if isfile and isfile(p) then
        local ok, v = pcall(getcustomasset, p)
        if ok and v ~= "" then _IC[name] = v return v end
    end
    _IC[name] = false
    return nil
end

-- roact-style element tree: el(class, props, {children}) / E.* = events
local E = {Activated="Activated", MouseEnter="MouseEnter", MouseLeave="MouseLeave",
           InputBegan="InputBegan", InputEnded="InputEnded"}
local function el(class, props, children)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do
        if E[k] then i[E[k]]:Connect(v) else pcall(function() i[k] = v end) end
    end
    for _, c in ipairs(children or {}) do c.Parent = i end
    return i
end
local function corner(r) return el("UICorner", {CornerRadius = UDim.new(0, r)}) end

-- ============================== window ==============================
local gui = el("ScreenGui", {
    Name = "OrcaESP_" .. HttpService:GenerateGUID(false):sub(1, 8),
    ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 8, IgnoreGuiInset = true,
})
pcall(function() gui.Parent = gethui() end)
if not gui.Parent then pcall(function() gui.Parent = game:GetService("CoreGui") end) end
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local CARD_W, PAD, ROW_W, ROW_H = 288, 12, 264, 30
local win = el("Frame", {
    Size = ud(CARD_W, 44), Position = ud(24, 140),
    BackgroundColor3 = T.background, BackgroundTransparency = 0.05,
    BorderSizePixel = 0, Active = true,
}, {
    corner(16),
    el("UIStroke", {Color = T.foreground, Transparency = 0.92, Thickness = 1}),
})
win.Parent = gui

-- icon button: lucide asset when the pipeline yields one, glyph fallback otherwise
local function iconBtn(name, glyph, x, y)
    local img = uiIcon(name)
    return el("ImageButton", {
        Size = ud(20, 20), Position = ud(x, y),
        BackgroundColor3 = T.inset, BackgroundTransparency = 1,
        Image = img or "", ScaleType = Enum.ScaleType.Fit,
        ImageColor3 = T.foreground, ImageTransparency = img and 0.45 or 1,
    }, {
        corner(6),
        el("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            Visible = img == nil, Text = glyph, Font = Enum.Font.GothamBold,
            TextSize = 13, TextColor3 = T.foreground}),
    })
end

-- ---- header (Card chrome: icon chip + title + subtitle + window buttons)
local header = el("Frame", {Size = ud(CARD_W, 40), Position = ud(0, 0),
    BackgroundTransparency = 1, Parent = win})

el("Frame", {Size = ud(26, 26), Position = ud(PAD, 7),
    BackgroundColor3 = T.inset, BorderSizePixel = 0, Parent = header}, {
    corner(8),
    el("ImageLabel", {Size = ud(14, 14), Position = ud(6, 6), BackgroundTransparency = 1,
        Image = uiIcon("eye") or "", ImageColor3 = T.accent, ScaleType = Enum.ScaleType.Fit}),
})
el("TextLabel", {Size = ud(150, 16), Position = ud(46, 7), BackgroundTransparency = 1,
    Text = "Unnamed ESP", Font = Enum.Font.GothamBlack, TextSize = 14,
    TextColor3 = T.foreground, TextXAlignment = Enum.TextXAlignment.Left, Parent = header})
el("TextLabel", {Size = ud(150, 12), Position = ud(46, 22), BackgroundTransparency = 1,
    Text = "orca edition", Font = Enum.Font.Gotham, TextSize = 10,
    TextColor3 = T.foreground, TextTransparency = 0.5,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = header})

local btnMin   = iconBtn("minus", "−", CARD_W - 56, 10); btnMin.Parent = header
local btnClose = iconBtn("x", "✕", CARD_W - 32, 10);     btnClose.Parent = header
for _, b in ipairs({btnMin, btnClose}) do
    b.MouseEnter:Connect(function()
        TweenSvc:Create(b, TweenInfo.new(0.1), {BackgroundTransparency = 0.55}):Play()
        if b.Image ~= "" then b.ImageTransparency = 0 end
    end)
    b.MouseLeave:Connect(function()
        TweenSvc:Create(b, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play()
        if b.Image ~= "" then b.ImageTransparency = 0.45 end
    end)
end

-- ---- body
local body = el("Frame", {Size = ud(CARD_W, 0), Position = ud(0, 40),
    BackgroundTransparency = 1, Parent = win})
local y = 4
local function rowFrame(h)
    local r = el("Frame", {Size = ud(ROW_W, h), Position = ud(PAD, y),
        BackgroundColor3 = T.inset, BackgroundTransparency = 0.2,
        BorderSizePixel = 0, Parent = body}, {corner(8)})
    y = y + h + 4
    return r
end
local function section(txt)
    el("TextLabel", {Size = ud(ROW_W, 14), Position = ud(PAD + 4, y), BackgroundTransparency = 1,
        Text = txt, Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = T.foreground, TextTransparency = 0.5,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = body})
    y = y + 18
end

-- orca pill switch: 40x22 track, 18x18 white knob, accent when on
local function sw(key, x, yy)
    local on = opts[key]
    local knob = el("Frame", {Size = ud(18, 18),
        Position = on and ud(20, 2) or ud(2, 2),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0}, {corner(9)})
    local track = el("Frame", {Size = ud(40, 22), Position = ud(x, yy),
        BackgroundColor3 = on and T.accent or T.switchOff, BorderSizePixel = 0}, {
        corner(11), knob,
        el("TextButton", {Text = "", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            [E.Activated] = function()
                opts[key] = not opts[key]
                local st = opts[key]
                TweenSvc:Create(track, TweenInfo.new(0.12), {
                    BackgroundColor3 = st and T.accent or T.switchOff}):Play()
                TweenSvc:Create(knob, TweenInfo.new(0.12), {
                    Position = st and ud(20, 2) or ud(2, 2)}):Play()
            end}),
    })
    return track
end

local function toggleRow(label, key)
    local r = rowFrame(ROW_H)
    el("TextLabel", {Size = ud(ROW_W - 60, ROW_H), Position = ud(10, 0), BackgroundTransparency = 1,
        Text = label, Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = T.foreground, TextXAlignment = Enum.TextXAlignment.Left, Parent = r})
    sw(key, ROW_W - 50, 4).Parent = r
end

local function stepperRow(label, key, min, max, stepv)
    local r = rowFrame(ROW_H)
    el("TextLabel", {Size = ud(ROW_W - 120, ROW_H), Position = ud(10, 0), BackgroundTransparency = 1,
        Text = label, Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = T.foreground, TextXAlignment = Enum.TextXAlignment.Left, Parent = r})
    local val = el("TextLabel", {Size = ud(40, 20), Position = ud(ROW_W - 68, 5),
        BackgroundColor3 = T.background, BackgroundTransparency = 0.3, BorderSizePixel = 0,
        Text = tostring(opts[key]), Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = T.foreground, Parent = r}, {corner(6)})
    local function stepBtn(name, glyph, x)
        local b = iconBtn(name, glyph, x, 5)
        b.BackgroundTransparency = 0.3; b.BackgroundColor3 = T.background
        b.Parent = r
        return b
    end
    local bm = stepBtn("minus", "−", ROW_W - 94)
    local bp = stepBtn("plus", "+", ROW_W - 24)
    bm.Activated:Connect(function()
        opts[key] = math.clamp(opts[key] - stepv, min, max); val.Text = tostring(opts[key])
    end)
    bp.Activated:Connect(function()
        opts[key] = math.clamp(opts[key] + stepv, min, max); val.Text = tostring(opts[key])
    end)
end

section("DISPLAY")
toggleRow("ESP Enabled",      "Enabled")
toggleRow("Show Team",        "TeamCheck")
toggleRow("Team Color",       "TeamColor")
toggleRow("Names",            "Names")
toggleRow("Distance",         "Distance")
toggleRow("Health",           "Health")
toggleRow("Boxes",            "Boxes")
toggleRow("Tracers",          "Tracers")
toggleRow("Head Dot",         "HeadDot")
toggleRow("Visibility Check", "VisibilityCheck")
toggleRow("Crosshair",        "Crosshair")
toggleRow("Text Outline",     "TextOutline")
section("SETTINGS")
stepperRow("Text Size",    "TextSize",    8,   32,   1)
stepperRow("Y Offset",     "YOffset",     -10, 10,   1)
stepperRow("Max Distance", "MaxDistance", 50,  5000, 50)

local foot = rowFrame(30)
foot.BackgroundColor3 = T.dangerBg; foot.BackgroundTransparency = 0.3
el("TextLabel", {Size = ud(ROW_W - 100, 30), Position = ud(10, 0), BackgroundTransparency = 1,
    Text = "Unload ESP", Font = Enum.Font.GothamBold, TextSize = 12,
    TextColor3 = Color3.fromRGB(255, 140, 140), TextXAlignment = Enum.TextXAlignment.Left,
    Parent = foot})
el("TextLabel", {Size = ud(90, 30), Position = ud(ROW_W - 96, 0), BackgroundTransparency = 1,
    Text = "RShift hide", Font = Enum.Font.Gotham, TextSize = 10,
    TextColor3 = T.foreground, TextTransparency = 0.5,
    TextXAlignment = Enum.TextXAlignment.Right, Parent = foot})
local footHit = el("TextButton", {Text = "", Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1, Parent = foot})

local BODY_H = y + 8
body.Size = ud(CARD_W, BODY_H)
local function setMin(m)
    body.Visible = not m
    TweenSvc:Create(win, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
        Size = ud(CARD_W, m and 44 or 40 + BODY_H)}):Play()
end
win.Size = ud(CARD_W, 40 + BODY_H)

-- drag on header
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(i)
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

local minimized = false
footHit.Activated:Connect(unload)
btnClose.Activated:Connect(unload)
btnMin.Activated:Connect(function() minimized = not minimized setMin(minimized) end)

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
