--=====================================================================--
--   TrippyX HUB v2.0  |  Blox Fruits
--   cool / clean / reliable / draggable / animated
--
--   Features: AutoFarm, Raids, V4 Race Trial, Sea Events, Halloween,
--             Chests/Fruits/Candy, ESP, Teleports, Movement, Fly
--
--   Key: Right Ctrl = show / hide UI
--=====================================================================--

--// SERVICES
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local TeleportService   = game:GetService("TeleportService")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local unpack = unpack or table.unpack

--// CONFIG
local CFG = {
    UI_KEY      = Enum.KeyCode.RightControl,
    FARM_DELAY  = 0.25,
    BRING_DELAY = 0.45,
    KILL_HOVER  = 10,
    RAID_RADIUS = 900,
    SEA_RADIUS  = 3000,
    V4_RADIUS   = 700,
}

--// STATE
local State = {
    AutoFarm = false, BringMobs = false, AutoAttack = false,
    AutoChest = false, AutoFruit = false, AutoCollectAll = false,
    AutoRaid = false, RaidChip = "Flame",
    AutoV4 = false,
    SeaEvent = false,
    HalloweenCandy = false, HalloweenMobs = false,
    ESPPlayers = false, ESPEnemies = false, ESPFruits = false, ESPChests = false, ESPEvent = false,
    WalkSpeed = 16, JumpPower = 50,
    InfJump = false, Noclip = false, Fly = false, FlySpeed = 70,
    AntiAFK = true, TweenTP = true,
}

--// THEME
local T = {
    bg      = Color3.fromRGB(13, 13, 18),
    panel   = Color3.fromRGB(20, 20, 28),
    card    = Color3.fromRGB(28, 28, 40),
    hover   = Color3.fromRGB(38, 38, 54),
    stroke  = Color3.fromRGB(48, 48, 66),
    accent  = Color3.fromRGB(124, 92, 255),
    accent2 = Color3.fromRGB(168, 132, 255),
    text    = Color3.fromRGB(236, 236, 245),
    dim     = Color3.fromRGB(145, 145, 165),
    green   = Color3.fromRGB(76, 220, 130),
    red     = Color3.fromRGB(240, 84, 110),
}

--// GLOBALS / HELPERS
local conns = {}
local destroyed = false
local lastJumpReq = 0
local lastT = {}

local notify = function() end     -- real one set after GUI exists
local setStatus = function() end  -- real one set after GUI exists
local openUI = function() end     -- real ones set after GUI exists
local closeUI = function() end
local destroyUI = function() end
local StatusLabel = nil

local function gate(name, now, delay)
    local last = lastT[name]
    if last and (now - last) < delay then return false end
    lastT[name] = now
    return true
end

local function getChar()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then return c end
    end
    return nil
end

local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function posOf(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local ok, p = pcall(function() return obj:GetPivot().Position end)
        if ok and p then return p end
        local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        if pp then return pp.Position end
    end
    return nil
end

--// TELEPORT (tween + instant)
local currentTween = nil
local function cancelTP()
    if currentTween then
        pcall(function() currentTween:Cancel() end)
        currentTween = nil
    end
end

local function tpTo(cf)
    local hrp = getHRP()
    if not hrp then return end
    cancelTP()
    if not State.TweenTP then
        hrp.CFrame = cf
        return
    end
    local dist = (cf.Position - hrp.Position).Magnitude
    local dur = math.clamp(dist / 350, 0.2, 4)
    local tw = TweenService:Create(hrp, TweenInfo.new(dur, Enum.EasingStyle.Linear), { CFrame = cf })
    currentTween = tw
    tw:Play()
end

--// COMBAT
local lastAtk = 0
local function attackNow(now)
    if (now - lastAtk) < CFG.FARM_DELAY then return end
    lastAtk = now
    local c = getChar()
    if not c then return end
    local tool = c:FindFirstChildOfClass("Tool")
    if not tool then
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        local t = bp and bp:FindFirstChildOfClass("Tool") or nil
        local hum = c:FindFirstChildOfClass("Humanoid")
        if t and hum then
            pcall(function() hum:EquipTool(t) end)
        end
        tool = c:FindFirstChildOfClass("Tool")
    end
    if tool then
        pcall(function() tool:Activate() end)
    end
end

local function nearestMob(patterns, maxDist)
    local hrp = getHRP()
    if not hrp then return nil end
    local playerChars = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character then playerChars[pl.Character] = true end
    end
    local seen, list = {}, {}
    local folder = workspace:FindFirstChild("Enemies")
    if folder then
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and not seen[m] then seen[m] = true table.insert(list, m) end
        end
    end
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and not seen[m] and not playerChars[m] then
            if m:FindFirstChildOfClass("Humanoid") then table.insert(list, m) end
        end
    end
    local best, bd = nil, maxDist or math.huge
    for _, m in ipairs(list) do
        if m.Parent then
            local h = m:FindFirstChildOfClass("Humanoid")
            local r = m:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 then
                local match = true
                if patterns then
                    match = false
                    local n = string.lower(m.Name)
                    for _, p in ipairs(patterns) do
                        if string.find(n, p, 1, true) then match = true break end
                    end
                end
                if match then
                    local d = (r.Position - hrp.Position).Magnitude
                    if d < bd then best, bd = m, d end
                end
            end
        end
    end
    return best, bd
end

local function killMob(mob, now)
    local hrp = getHRP()
    if not hrp then return false end
    local r = mob:FindFirstChild("HumanoidRootPart")
    local h = mob:FindFirstChildOfClass("Humanoid")
    if not r or not h or h.Health <= 0 then return false end
    cancelTP()
    hrp.CFrame = r.CFrame * CFrame.new(0, CFG.KILL_HOVER, 0)
    attackNow(now)
    return true
end

--// PROMPTS / PICKUPS
local function firePrompts(obj)
    if not obj then return end
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            pcall(function()
                if fireproximityprompt then
                    fireproximityprompt(d)
                else
                    d:InputHoldBegin()
                    task.delay(0.1, function()
                        pcall(function() d:InputHoldEnd() end)
                    end)
                end
            end)
        end
    end
end

local EXCLUDE_WORDS = { "dealer", "npc", "shop", "gacha", "quest", "stock" }

local function nearestPickup(patterns)
    local hrp = getHRP()
    if not hrp then return nil end
    local best, bd = nil, math.huge
    for _, obj in ipairs(workspace:GetChildren()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and obj ~= LocalPlayer.Character then
            local n = string.lower(obj.Name)
            local hit = false
            for _, p in ipairs(patterns) do
                if string.find(n, p, 1, true) then hit = true break end
            end
            local bad = false
            for _, e in ipairs(EXCLUDE_WORDS) do
                if string.find(n, e, 1, true) then bad = true break end
            end
            if hit and not bad then
                local p2 = posOf(obj)
                if p2 then
                    local d = (p2 - hrp.Position).Magnitude
                    if d < bd then best, bd = obj, d end
                end
            end
        end
    end
    return best
end

--// NAMED LOCATION SCANNER (cached)
local scanCache = {}
local function scanFind(patterns)
    local function match(name)
        local ln = string.lower(name)
        for _, p in ipairs(patterns) do
            if string.find(ln, p, 1, true) then return true end
        end
        return false
    end
    local queue = workspace:GetChildren()
    local depth = 1
    local checked = 0
    while depth <= 4 do
        local nextQueue = {}
        for _, obj in ipairs(queue) do
            checked = checked + 1
            if checked > 6000 then return nil end
            if (obj:IsA("Model") or obj:IsA("BasePart")) and match(obj.Name) then
                return obj
            end
            if depth < 4 and (obj:IsA("Model") or obj:IsA("Folder")) then
                local ok, kids = pcall(function() return obj:GetChildren() end)
                if ok and kids then
                    for _, k in ipairs(kids) do table.insert(nextQueue, k) end
                end
            end
        end
        queue = nextQueue
        depth = depth + 1
    end
    return nil
end

local function findNamed(patterns)
    local key = table.concat(patterns, "|")
    local now = os.clock()
    local c = scanCache[key]
    if c and (now - c.t) < 6 then
        if c.obj and c.obj.Parent then return c.obj end
        if c.obj == nil then return nil end
    end
    local obj = scanFind(patterns)
    scanCache[key] = { obj = obj, t = now }
    return obj
end

--// REMOTES (for raids / trial)
local function CommF(...)
    local ok, res = pcall(function()
        local r = ReplicatedStorage:FindFirstChild("Remotes")
        local f = r and r:FindFirstChild("CommF_") or nil
        if not f then return nil end
        return f:InvokeServer(unpack({ ... }))
    end)
    if ok then return res end
    return nil
end

-- NOTE: if these remote names differ on your server, run TrippyX Recon
-- (the remote logger) and edit the argument strings below.
local RAID_BUY_VARIANTS = {
    function(chip) return CommF("BuyChip", chip) end,
    function(chip) return CommF("RaidsNpc", "BuyChip", chip) end,
    function(chip) return CommF("RaidsNpc", "Select", "Buy", chip) end,
}
local RAID_JOIN_VARIANTS = {
    function() return CommF("RaidsNpc", "Start") end,
    function() return CommF("RaidsNpc", "Select", "Start") end,
    function() return CommF("StartRaid") end,
}
local RAID_CHIPS = { "Flame", "Ice", "Quake", "Light", "Dark", "Buddha", "String", "Rumble", "Paw", "Phoenix", "Dough" }

--=====================================================================--
--  FEATURE TICKERS
--=====================================================================--

local function tickFarm(now)
    if not State.AutoFarm then return end
    if not gate("farm", now, 0.2) then return end
    local mob = nearestMob(nil, 3000)
    if mob then
        killMob(mob, now)
        local h = mob:FindFirstChildOfClass("Humanoid")
        local pct = h and math.floor((h.Health / math.max(h.MaxHealth, 1)) * 100) or 0
        setStatus("Auto Farm: " .. mob.Name .. " (" .. pct .. "%)")
    else
        setStatus("Auto Farm: no mobs found")
    end
end

local function tickBring(now)
    if not State.BringMobs then return end
    if not gate("bring", now, CFG.BRING_DELAY) then return end
    local hrp = getHRP()
    if not hrp then return end
    local f = workspace:FindFirstChild("Enemies")
    if not f then return end
    for _, m in ipairs(f:GetChildren()) do
        local h = m:FindFirstChildOfClass("Humanoid")
        local r = m:FindFirstChild("HumanoidRootPart")
        if h and r and h.Health > 0 then
            pcall(function()
                r.CFrame = hrp.CFrame * CFrame.new(0, 0, -6)
            end)
        end
    end
end

local function tickAutoAttack(now)
    if not State.AutoAttack then return end
    attackNow(now)
end

local COLLECTORS = {
    { key = "chest", state = "AutoChest",      patterns = { "chest" },                name = "Chest", delay = 0.55 },
    { key = "fruit", state = "AutoFruit",      patterns = { "fruit" },                name = "Fruit", delay = 0.8 },
    { key = "candy", state = "HalloweenCandy", patterns = { "candy", "present" },     name = "Candy", delay = 0.8 },
    { key = "all",   state = "AutoCollectAll", patterns = { "chest", "fruit", "candy", "present" }, name = "Loot", delay = 0.5 },
}

local curTargets = {}
local function tickCollect(cfg, now)
    if not State[cfg.state] then
        curTargets[cfg.key] = nil
        return
    end
    if not gate("col_" .. cfg.key, now, cfg.delay) then return end
    local hrp = getHRP()
    if not hrp then return end
    local t = curTargets[cfg.key]
    if t and not t.Parent then t = nil end
    local p = t and posOf(t) or nil
    if not t or not p then
        t = nearestPickup(cfg.patterns)
        curTargets[cfg.key] = t
        p = t and posOf(t) or nil
    end
    if not t or not p then
        if cfg.key ~= "all" then setStatus("Auto " .. cfg.name .. ": searching...") end
        return
    end
    local d = (p - hrp.Position).Magnitude
    cancelTP()
    hrp.CFrame = CFrame.new(p.X, p.Y + 2.5, p.Z)
    firePrompts(t)
    setStatus("Auto " .. cfg.name .. ": " .. t.Name .. " (" .. math.floor(d) .. "m)")
end

--// RAIDS
local raidWait = 0
local raidStep = 0
local function tickRaid(now)
    if not State.AutoRaid then raidStep = 0 return end
    if not gate("raid", now, 1.0) then return end
    local mob = nearestMob(nil, CFG.RAID_RADIUS)
    if mob then
        killMob(mob, now)
        setStatus("Raid: killing " .. mob.Name)
        return
    end
    if (now - raidWait) < 6 then
        setStatus("Raid: waiting for next wave / join...")
        return
    end
    raidWait = now
    raidStep = raidStep + 1
    local npc = findNamed({ "mysterious" })
    if npc then
        local p = posOf(npc)
        local hrp = getHRP()
        if p and hrp then
            cancelTP()
            hrp.CFrame = CFrame.new(p.X + 5, p.Y + 3, p.Z + 5)
            firePrompts(npc)
        end
    end
    local buy = RAID_BUY_VARIANTS[((raidStep - 1) % #RAID_BUY_VARIANTS) + 1]
    pcall(buy, State.RaidChip)
    local join = RAID_JOIN_VARIANTS[((raidStep - 1) % #RAID_JOIN_VARIANTS) + 1]
    pcall(join)
    setStatus("Raid: join attempt #" .. raidStep .. " (buy chip manually if needed)")
end

--// V4 TRIAL
local v4Wait = 0
local function tickV4(now)
    if not State.AutoV4 then return end
    if not gate("v4", now, 0.8) then return end
    local hrp = getHRP()
    if not hrp then return end
    local tree = findNamed({ "great tree", "greattree" })
    if not tree then
        setStatus("V4: Great Tree not found (go to 3rd Sea)")
        return
    end
    local tp = posOf(tree)
    if not tp then return end
    local dist = (tp - hrp.Position).Magnitude
    if dist > 350 then
        tpTo(CFrame.new(tp.X, tp.Y + 5, tp.Z))
        setStatus("V4: flying to Great Tree...")
        return
    end
    if (now - v4Wait) > 4 then
        v4Wait = now
        firePrompts(tree)
        pcall(function() CommF("MysteriousForce") end)
    end
    local mob = nearestMob(nil, CFG.V4_RADIUS)
    if mob then
        killMob(mob, now)
        setStatus("V4 Trial: killing " .. mob.Name)
    else
        setStatus("V4 Trial: at Great Tree — waiting for trial mobs")
    end
end

--// SEA EVENTS
local SEA_PATTERNS = { "terror", "piranha", "brigade", "sea beast", "kraken", "ghost ship" }
local function tickSea(now)
    if not State.SeaEvent then return end
    if not gate("sea", now, 0.6) then return end
    local mob = nearestMob(SEA_PATTERNS, CFG.SEA_RADIUS)
    if mob then
        killMob(mob, now)
        setStatus("Sea Event: killing " .. mob.Name)
    else
        setStatus("Sea Event: sail into deep sea — waiting for spawns")
    end
end

--// HALLOWEEN MOBS
local HLOW_PATTERNS = { "ghost", "hallow", "pumpkin", "headless", "witch" }
local function tickHallow(now)
    if not State.HalloweenMobs then return end
    if not gate("hlow", now, 0.5) then return end
    local mob = nearestMob(HLOW_PATTERNS, 3000)
    if mob then
        killMob(mob, now)
        setStatus("Halloween: killing " .. mob.Name)
    else
        setStatus("Halloween: no event mobs found")
    end
end

--// MOVEMENT / FLY
local flyBV, flyGyro, flyConn = nil, nil, nil
local function teardownFly()
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if flyBV then pcall(function() flyBV:Destroy() end) flyBV = nil end
    if flyGyro then pcall(function() flyGyro:Destroy() end) flyGyro = nil end
end

local function setupFly()
    local hrp = getHRP()
    if not hrp then return end
    flyBV = Instance.new("BodyVelocity")
    flyBV.Name = "TrippyXFly"
    flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    flyBV.Velocity = Vector3.new(0, 0, 0)
    flyBV.Parent = hrp
    flyGyro = Instance.new("BodyGyro")
    flyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    flyGyro.P = 9000
    flyGyro.D = 500
    flyGyro.Parent = hrp
    flyConn = RunService.Heartbeat:Connect(function()
        if not State.Fly or not flyBV then return end
        local c = getChar()
        local h = c and c:FindFirstChildOfClass("Humanoid") or nil
        local h2 = c and c:FindFirstChild("HumanoidRootPart") or nil
        if not h2 then return end
        local dir = h and h.MoveDirection or Vector3.new(0, 0, 0)
        local vel = Vector3.new(0, 0, 0)
        if dir.Magnitude > 0.05 then
            vel = dir.Unit * State.FlySpeed
        end
        if os.clock() - lastJumpReq < 0.15 then
            vel = vel + Vector3.new(0, State.FlySpeed * 0.8, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            vel = vel - Vector3.new(0, State.FlySpeed * 0.8, 0)
        end
        flyBV.Velocity = vel
        local cam = workspace.CurrentCamera
        if flyGyro and flyGyro.Parent and cam then
            flyGyro.CFrame = cam.CFrame
        end
    end)
end

local function tickMovement(now)
    if not gate("move", now, 0.4) then return end
    local c = getChar()
    if c then
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum then
            if State.WalkSpeed ~= 16 then
                pcall(function() hum.WalkSpeed = State.WalkSpeed end)
            end
            pcall(function()
                if hum.UseJumpPower then
                    hum.JumpPower = State.JumpPower
                else
                    hum.JumpHeight = math.clamp(State.JumpPower / 50 * 7.2, 7.2, 50)
                end
            end)
        end
    end
    if State.Fly then
        if (not flyBV) or flyBV.Parent == nil then setupFly() end
    else
        if flyBV then teardownFly() end
    end
end

--// ESP
local espMap = {}
local ESP_COLORS = {
    players = Color3.fromRGB(0, 200, 255),
    enemies = Color3.fromRGB(255, 70, 70),
    fruits  = Color3.fromRGB(255, 150, 0),
    chests  = Color3.fromRGB(255, 230, 60),
    event   = Color3.fromRGB(190, 90, 255),
}

local function makeHL(obj, cat)
    local h = Instance.new("Highlight")
    h.Name = "TrippyXESP"
    h.FillColor = ESP_COLORS[cat]
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.FillTransparency = 0.65
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    local ok = pcall(function() h.Parent = obj end)
    if ok then
        espMap[obj] = { h = h, cat = cat }
    else
        pcall(function() h:Destroy() end)
    end
end

local function refreshESP()
    local wanted = {}
    if State.ESPPlayers then
        for _, pl in ipairs(Players:GetPlayers()) do
            local c = pl.Character
            if c and pl ~= LocalPlayer and c:FindFirstChild("HumanoidRootPart") then
                wanted[c] = "players"
            end
        end
    end
    if State.ESPEnemies then
        local f = workspace:FindFirstChild("Enemies")
        if f then
            for _, m in ipairs(f:GetChildren()) do
                local h = m:IsA("Model") and m:FindFirstChildOfClass("Humanoid")
                if m:IsA("Model") and h and h.Health > 0 then wanted[m] = "enemies" end
            end
        end
    end
    if State.ESPFruits or State.ESPChests or State.ESPEvent then
        for _, obj in ipairs(workspace:GetChildren()) do
            if (obj:IsA("Model") or obj:IsA("BasePart")) and obj ~= LocalPlayer.Character then
                local n = string.lower(obj.Name)
                if State.ESPFruits and string.find(n, "fruit", 1, true) then
                    wanted[obj] = "fruits"
                elseif State.ESPChests and string.find(n, "chest", 1, true) then
                    wanted[obj] = "chests"
                elseif State.ESPEvent and (string.find(n, "candy", 1, true) or string.find(n, "ghost", 1, true) or string.find(n, "hallow", 1, true) or string.find(n, "pumpkin", 1, true)) then
                    wanted[obj] = "event"
                end
            end
        end
    end
    for obj, cat in pairs(wanted) do
        local e = espMap[obj]
        if e and e.h.Parent then
            if e.cat ~= cat then
                e.cat = cat
                e.h.FillColor = ESP_COLORS[cat]
            end
        else
            if e then pcall(function() e.h:Destroy() end) end
            makeHL(obj, cat)
        end
    end
    for obj, e in pairs(espMap) do
        if (not wanted[obj]) or (not obj.Parent) then
            pcall(function() e.h:Destroy() end)
            espMap[obj] = nil
        end
    end
end

local function clearESP()
    for obj, e in pairs(espMap) do
        pcall(function() e.h:Destroy() end)
        espMap[obj] = nil
    end
end

--=====================================================================--
--  GUI
--=====================================================================--

local gui = Instance.new("ScreenGui")
gui.Name = "TrippyXHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.DisplayOrder = 9999

pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(gui) end
end)

local parented = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not parented or not gui.Parent then
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ROOT (CanvasGroup if supported -> smooth fade animations)
local ROOT_CLASS = "Frame"
pcall(function()
    local cg = Instance.new("CanvasGroup")
    if cg then ROOT_CLASS = "CanvasGroup" end
end)

local ROOT = Instance.new(ROOT_CLASS)
ROOT.Size = UDim2.fromOffset(560, 372)
ROOT.Position = UDim2.new(0.5, -280, 0.5, -186)
ROOT.BackgroundColor3 = T.bg
ROOT.BorderSizePixel = 0
ROOT.Visible = false
ROOT.Parent = gui

local rootScale = Instance.new("UIScale")
rootScale.Scale = 0.8
rootScale.Parent = ROOT

pcall(function()
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 14)
    c.Parent = ROOT
    local s = Instance.new("UIStroke")
    s.Color = T.stroke
    s.Thickness = 1
    s.Parent = ROOT
end)

local function fitValue()
    local s = 1
    pcall(function()
        local vp = workspace.CurrentCamera.ViewportSize
        s = math.min(vp.X / 600, vp.Y / 430, 1)
        if s < 0.5 then s = 0.5 end
    end)
    return s
end

-- small helpers
local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = inst
end

local function hoverFx(btn, base, hi)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = hi }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = base }):Play()
    end)
end

--// TITLE BAR
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 46)
titleBar.BackgroundColor3 = T.accent
titleBar.BorderSizePixel = 0
titleBar.Parent = ROOT
corner(titleBar, 14)

local tg = Instance.new("UIGradient")
tg.Color = ColorSequence.new(T.accent, T.accent2)
tg.Rotation = 15
tg.Parent = titleBar

local logo = Instance.new("TextLabel")
logo.Size = UDim2.fromOffset(30, 30)
logo.Position = UDim2.new(0, 10, 0.5, 0)
logo.AnchorPoint = Vector2.new(0, 0.5)
logo.BackgroundColor3 = Color3.fromRGB(20, 16, 38)
logo.TextColor3 = T.text
logo.Font = Enum.Font.GothamBlack
logo.TextSize = 12
logo.Text = "TX"
logo.BorderSizePixel = 0
logo.Parent = titleBar
corner(logo, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -110, 0, 24)
title.Position = UDim2.new(0, 48, 0, 5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "TrippyX HUB"
title.Parent = titleBar

local ver = Instance.new("TextLabel")
ver.Size = UDim2.new(1, -110, 0, 14)
ver.Position = UDim2.new(0, 49, 0, 27)
ver.BackgroundTransparency = 1
ver.Font = Enum.Font.Gotham
ver.TextSize = 10
ver.TextColor3 = Color3.fromRGB(230, 225, 255)
ver.TextTransparency = 0.25
ver.TextXAlignment = Enum.TextXAlignment.Left
ver.Text = "Blox Fruits  |  v2.0  |  drag me"
ver.Parent = titleBar

--// BODY
local side = Instance.new("Frame")
side.Size = UDim2.new(0, 118, 1, -70)
side.Position = UDim2.new(0, 0, 0, 46)
side.BackgroundColor3 = T.panel
side.BorderSizePixel = 0
side.Parent = ROOT

local tabHolder = Instance.new("Frame")
tabHolder.Size = UDim2.new(1, -12, 1, -12)
tabHolder.Position = UDim2.new(0, 6, 0, 6)
tabHolder.BackgroundTransparency = 1
tabHolder.Parent = side

local tabList = Instance.new("UIListLayout")
tabList.Padding = UDim.new(0, 5)
tabList.SortOrder = Enum.SortOrder.LayoutOrder
tabList.Parent = tabHolder

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -118, 1, -70)
content.Position = UDim2.new(0, 118, 0, 46)
content.BackgroundColor3 = T.bg
content.BorderSizePixel = 0
content.ClipsDescendants = true
content.Parent = ROOT

--// STATUS BAR
StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -24, 0, 18)
StatusLabel.Position = UDim2.new(0, 12, 1, -22)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.TextColor3 = T.dim
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
StatusLabel.Text = "Status: idle"
StatusLabel.Parent = ROOT

setStatus = function(text)
    if StatusLabel then
        StatusLabel.Text = "Status: " .. tostring(text)
    end
end

--// NOTIFICATIONS
local noteHolder = Instance.new("Frame")
noteHolder.AnchorPoint = Vector2.new(1, 1)
noteHolder.Position = UDim2.new(1, -12, 1, -12)
noteHolder.Size = UDim2.new(0, 250, 0, 480)
noteHolder.BackgroundTransparency = 1
noteHolder.Parent = gui

local noteList = Instance.new("UIListLayout")
noteList.Padding = UDim.new(0, 6)
noteList.SortOrder = Enum.SortOrder.LayoutOrder
noteList.VerticalAlignment = Enum.VerticalAlignment.Bottom
noteList.Parent = noteHolder

local noteCount = 0
notify = function(text, color)
    pcall(function()
        noteCount = noteCount + 1
        local toast = Instance.new("Frame")
        toast.Size = UDim2.new(1, 0, 0, 30)
        toast.BackgroundColor3 = T.panel
        toast.BackgroundTransparency = 1
        toast.BorderSizePixel = 0
        toast.ZIndex = 100
        toast.LayoutOrder = noteCount
        toast.Parent = noteHolder
        corner(toast, 8)

        local st = Instance.new("UIStroke")
        st.Color = color or T.accent
        st.Thickness = 1
        st.Transparency = 0.4
        st.Parent = toast

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 4, 1, -10)
        bar.Position = UDim2.new(0, 6, 0.5, 0)
        bar.AnchorPoint = Vector2.new(0, 0.5)
        bar.BackgroundColor3 = color or T.accent
        bar.BorderSizePixel = 0
        bar.ZIndex = 101
        bar.Parent = toast
        corner(bar, 2)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -26, 1, 0)
        lbl.Position = UDim2.new(0, 16, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextColor3 = T.text
        lbl.TextTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Text = tostring(text)
        lbl.ZIndex = 101
        lbl.Parent = toast

        TweenService:Create(toast, TweenInfo.new(0.2), { BackgroundTransparency = 0.05 }):Play()
        TweenService:Create(lbl, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()

        task.delay(2.4, function()
            if not toast.Parent then return end
            TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(lbl, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
            task.delay(0.35, function()
                pcall(function() toast:Destroy() end)
            end)
        end)

        -- keep max 6 toasts
        local kids = {}
        for _, k in ipairs(noteHolder:GetChildren()) do
            if k:IsA("Frame") then table.insert(kids, k) end
        end
        if #kids > 6 then
            pcall(function() kids[1]:Destroy() end)
        end
    end)
end

--// PAGES + TABS
local pages = {}
local tabButtons = {}
local openDrop = nil

local function makePage(name)
    local sf = Instance.new("ScrollingFrame")
    sf.Name = name
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.ScrollingDirection = Enum.ScrollingDirection.Y
    sf.ScrollBarThickness = 4
    sf.ScrollBarImageColor3 = T.accent
    sf.Visible = false
    sf.Parent = content

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent = sf

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = sf

    pages[name] = sf
    return sf
end

local selectTab
local function makeTab(name, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = T.card
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.LayoutOrder = order
    btn.Parent = tabHolder
    corner(btn, 8)
    hoverFx(btn, T.card, T.hover)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 13
    lbl.TextColor3 = T.dim
    lbl.Text = name
    lbl.Parent = btn

    tabButtons[name] = { btn = btn, lbl = lbl }
    btn.Activated:Connect(function()
        selectTab(name)
    end)
end

selectTab = function(name)
    if openDrop then
        pcall(function() openDrop.close() end)
        openDrop = nil
    end
    for n, page in pairs(pages) do
        local on = (n == name)
        page.Visible = on
        if on then
            page.Position = UDim2.new(0, 0, 0, 14)
            TweenService:Create(page, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()
        end
    end
    for n, t in pairs(tabButtons) do
        local on = (n == name)
        TweenService:Create(t.btn, TweenInfo.new(0.18), { BackgroundColor3 = on and T.accent or T.card }):Play()
        TweenService:Create(t.lbl, TweenInfo.new(0.18), { TextColor3 = on and Color3.fromRGB(255, 255, 255) or T.dim }):Play()
    end
end

--// COMPONENT BUILDERS
local orderCounter = 0
local function nextOrder()
    orderCounter = orderCounter + 1
    return orderCounter
end

local function addSection(page, txt)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 20)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamBlack
    l.TextSize = 11
    l.TextColor3 = T.accent2
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = string.upper(txt)
    l.LayoutOrder = nextOrder()
    l.Parent = page
end

local function addNote(page, txt)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 0)
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.TextColor3 = T.dim
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = txt
    l.LayoutOrder = nextOrder()
    l.Parent = page
end

local function addToggle(page, txt, key, callback)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundColor3 = T.card
    row.Text = ""
    row.AutoButtonColor = false
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.Parent = page
    corner(row, 8)
    hoverFx(row, T.card, T.hover)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = T.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Text = txt
    lbl.Parent = row

    local pill = Instance.new("Frame")
    pill.Size = UDim2.fromOffset(36, 18)
    pill.Position = UDim2.new(1, -10, 0.5, 0)
    pill.AnchorPoint = Vector2.new(1, 0.5)
    pill.BackgroundColor3 = T.stroke
    pill.BorderSizePixel = 0
    pill.Parent = row
    corner(pill, 9)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(12, 12)
    knob.Position = UDim2.new(0, 3, 0.5, 0)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.BackgroundColor3 = T.dim
    knob.BorderSizePixel = 0
    knob.Parent = pill
    corner(knob, 6)

    local function render(instant)
        local on = State[key]
        local dur = instant and 0 or 0.18
        local info = TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(pill, info, { BackgroundColor3 = on and T.green or T.stroke }):Play()
        TweenService:Create(knob, info, {
            Position = UDim2.new(0, on and 21 or 3, 0.5, 0),
            BackgroundColor3 = on and Color3.fromRGB(16, 30, 20) or T.dim,
        }):Play()
    end

    row.Activated:Connect(function()
        State[key] = not State[key]
        render(false)
        notify(txt .. (State[key] and ": ON" or ": OFF"), State[key] and T.green or T.red)
        if callback then
            pcall(callback, State[key])
        end
    end)

    render(true)
end

local function addButton(page, txt, cb)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundColor3 = T.card
    row.Text = txt
    row.Font = Enum.Font.GothamSemibold
    row.TextSize = 12
    row.TextColor3 = T.text
    row.AutoButtonColor = false
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.Parent = page
    corner(row, 8)
    hoverFx(row, T.card, T.hover)
    row.Activated:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.08), { BackgroundColor3 = T.accent }):Play()
        task.delay(0.1, function()
            TweenService:Create(row, TweenInfo.new(0.2), { BackgroundColor3 = T.card }):Play()
        end)
        if cb then pcall(cb) end
    end)
end

local function addSlider(page, txt, min, max, key)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundColor3 = T.card
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.Parent = page
    corner(row, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 0, 18)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = T.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = txt
    lbl.Parent = row

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0, 50, 0, 18)
    val.Position = UDim2.new(1, -10, 0, 4)
    val.AnchorPoint = Vector2.new(1, 0)
    val.BackgroundTransparency = 1
    val.Font = Enum.Font.GothamBold
    val.TextSize = 12
    val.TextColor3 = T.accent2
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Text = tostring(State[key])
    val.Parent = row

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -20, 0, 6)
    barBg.Position = UDim2.new(0, 10, 0, 32)
    barBg.BackgroundColor3 = T.stroke
    barBg.BorderSizePixel = 0
    barBg.Parent = row
    corner(barBg, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0.5, 0, 1, 0)
    fill.BackgroundColor3 = T.accent
    fill.BorderSizePixel = 0
    fill.Parent = barBg
    corner(fill, 3)

    local function setVal(v)
        v = math.clamp(math.floor(v + 0.5), min, max)
        State[key] = v
        val.Text = tostring(v)
        local pct = (v - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
    end

    local sliding = false
    local function fromInput(input)
        local xp = input.Position.X - barBg.AbsolutePosition.X
        local pct = math.clamp(xp / math.max(barBg.AbsoluteSize.X, 1), 0, 1)
        setVal(min + (max - min) * pct)
    end

    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            fromInput(input)
        end
    end)

    table.insert(conns, UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromInput(input)
        end
    end))

    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end))

    setVal(State[key])
end

local function addDropdown(page, labelTxt, options, getKey, setKey)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 30)
    container.BackgroundTransparency = 1
    container.ClipsDescendants = true
    container.LayoutOrder = nextOrder()
    container.Parent = page

    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundColor3 = T.card
    row.Text = ""
    row.AutoButtonColor = false
    row.BorderSizePixel = 0
    row.Parent = container
    corner(row, 8)
    hoverFx(row, T.card, T.hover)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = T.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = labelTxt
    lbl.Parent = row

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0, 70, 1, 0)
    val.Position = UDim2.new(1, -10, 0, 0)
    val.AnchorPoint = Vector2.new(1, 0)
    val.BackgroundTransparency = 1
    val.Font = Enum.Font.GothamBold
    val.TextSize = 12
    val.TextColor3 = T.accent2
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Text = tostring(getKey())
    val.Parent = row

    local listHolder = Instance.new("Frame")
    listHolder.Size = UDim2.new(1, -10, 0, #options * 24 + 8)
    listHolder.Position = UDim2.new(0, 5, 0, 34)
    listHolder.BackgroundColor3 = T.panel
    listHolder.BorderSizePixel = 0
    listHolder.Parent = container
    corner(listHolder, 8)

    local self = nil
    local open = false
    local function render()
        local targetH = 30
        if open then targetH = 30 + 8 + #options * 24 + 8 end
        TweenService:Create(container, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, targetH) }):Play()
        val.Text = tostring(getKey())
    end

    self = {
        close = function()
            open = false
            render()
        end,
    }

    row.Activated:Connect(function()
        if open then
            open = false
            openDrop = nil
        else
            if openDrop then pcall(function() openDrop.close() end) end
            open = true
            openDrop = self
        end
        render()
    end)

    for i, opt in ipairs(options) do
        local ob = Instance.new("TextButton")
        ob.Size = UDim2.new(1, -8, 0, 22)
        ob.Position = UDim2.new(0, 4, 0, 4 + (i - 1) * 24)
        ob.BackgroundColor3 = T.card
        ob.Text = tostring(opt)
        ob.Font = Enum.Font.Gotham
        ob.TextSize = 12
        ob.TextColor3 = T.dim
        ob.AutoButtonColor = false
        ob.BorderSizePixel = 0
        ob.Parent = listHolder
        corner(ob, 6)
        hoverFx(ob, T.card, T.hover)
        ob.Activated:Connect(function()
            setKey(opt)
            open = false
            openDrop = nil
            render()
            notify(labelTxt .. ": " .. tostring(opt))
        end)
    end

    render()
    return self
end

--// DRAGGING
local function makeDraggable(handle, target)
    local dragging = false
    local dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
        end
    end)
    table.insert(conns, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

makeDraggable(titleBar, ROOT)

--// TITLE BUTTONS
local function mkTitleBtn(txt, xOffset, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(26, 26)
    b.Position = UDim2.new(1, xOffset, 0.5, 0)
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.BackgroundColor3 = Color3.fromRGB(20, 16, 38)
    b.Text = txt
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.TextColor3 = T.text
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.Parent = titleBar
    corner(b, 8)
    hoverFx(b, Color3.fromRGB(20, 16, 38), Color3.fromRGB(50, 40, 90))
    b.Activated:Connect(function() pcall(cb) end)
    return b
end

mkTitleBtn("X", -10, function() destroyUI() end)
mkTitleBtn("-", -42, function() closeUI(true) end)

--// MINI BUTTON
local mini = Instance.new("TextButton")
mini.Size = UDim2.fromOffset(54, 54)
mini.Position = UDim2.new(0, 16, 0.5, 0)
mini.BackgroundColor3 = T.accent
mini.Text = "TX"
mini.Font = Enum.Font.GothamBlack
mini.TextSize = 16
mini.TextColor3 = Color3.fromRGB(255, 255, 255)
mini.AutoButtonColor = false
mini.BorderSizePixel = 0
mini.Visible = false
mini.ZIndex = 100
mini.Parent = gui
corner(mini, 27)

local mg = Instance.new("UIGradient")
mg.Color = ColorSequence.new(T.accent, T.accent2)
mg.Rotation = 30
mg.Parent = mini

makeDraggable(mini, mini)
mini.Activated:Connect(function()
    if not destroyed then openUI(true) end
end)

openUI = function(animate)
    if destroyed then return end
    local fit = fitValue()
    mini.Visible = false
    ROOT.Visible = true
    if animate then
        rootScale.Scale = fit * 0.8
        if ROOT:IsA("CanvasGroup") then ROOT.GroupTransparency = 1 end
        TweenService:Create(rootScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
        if ROOT:IsA("CanvasGroup") then
            TweenService:Create(ROOT, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
        end
    else
        rootScale.Scale = fit
        if ROOT:IsA("CanvasGroup") then ROOT.GroupTransparency = 0 end
    end
end

closeUI = function(animate)
    if destroyed then return end
    local fit = fitValue()
    if animate then
        TweenService:Create(rootScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = fit * 0.8 }):Play()
        if ROOT:IsA("CanvasGroup") then
            TweenService:Create(ROOT, TweenInfo.new(0.2), { GroupTransparency = 1 }):Play()
        end
        task.delay(0.22, function()
            ROOT.Visible = false
            if not destroyed then
                mini.Visible = true
            end
        end)
    else
        ROOT.Visible = false
        mini.Visible = true
    end
end

--=====================================================================--
--  BUILD PAGES
--=====================================================================--

local pMain   = makePage("Main")
local pEvents = makePage("Events")
local pTP     = makePage("Teleport")
local pESP    = makePage("ESP")
local pPlayer = makePage("Player")
local pMisc   = makePage("Misc")

--// MAIN
addSection(pMain, "Farming")
addToggle(pMain, "Auto Farm (Mobs)", "AutoFarm")
addToggle(pMain, "Bring Enemies", "BringMobs")
addToggle(pMain, "Auto Attack (equip + swing)", "AutoAttack")
addSection(pMain, "Loot")
addToggle(pMain, "Auto Chest", "AutoChest")
addToggle(pMain, "Auto Fruit", "AutoFruit")
addNote(pMain, "Auto Farm hovers above the nearest mob and swings your weapon automatically. Bring Enemies pulls every alive mob in the Enemies folder to you.")

--// EVENTS
addSection(pEvents, "Raids")
addDropdown(pEvents, "Raid Chip", RAID_CHIPS, function() return State.RaidChip end, function(v) State.RaidChip = v end)
addToggle(pEvents, "Auto Raid", "AutoRaid")
addButton(pEvents, "TP: Raid NPC (Mysterious)", function()
    local npc = findNamed({ "mysterious" })
    if npc then
        local p = posOf(npc)
        if p then
            tpTo(CFrame.new(p.X + 5, p.Y + 3, p.Z + 5))
            notify("Teleport: Raid NPC")
            return
        end
    end
    notify("Raid NPC not found", T.red)
end)
addNote(pEvents, "Auto Raid: kills raid mobs in range, and every few seconds tries the chip/join remotes + fires NPC prompts. If auto-join fails on your executor, buy the chip and start the raid manually — the killing is still automatic.")

addSection(pEvents, "Race V4 Trial")
addToggle(pEvents, "Auto V4 Trial", "AutoV4")
addButton(pEvents, "TP: Great Tree", function()
    local tree = findNamed({ "great tree", "greattree" })
    if tree then
        local p = posOf(tree)
        if p then
            tpTo(CFrame.new(p.X, p.Y + 5, p.Z))
            notify("Teleport: Great Tree")
            return
        end
    end
    notify("Great Tree not found (3rd Sea only)", T.red)
end)
addNote(pEvents, "Auto V4: flies you to the Great Tree, fires the door prompts to start the trial, then kills everything that spawns inside.")

addSection(pEvents, "Sea Events")
addToggle(pEvents, "Sea Event Auto-Kill", "SeaEvent")
addButton(pEvents, "TP: Open Sea (2k out)", function()
    local hrp = getHRP()
    if not hrp then return end
    local cam = workspace.CurrentCamera
    local dir = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 0.05 then dir = Vector3.new(0, 0, -1) end
    dir = dir.Unit
    tpTo(CFrame.new(hrp.Position + dir * 2000 + Vector3.new(0, 20, 0)))
    notify("Teleport: open sea — drive a boat, auto-kill is ON")
end)
addNote(pEvents, "Spawn a boat, sail into the deep sea zone. TrippyX auto-kills Terrorsharks, Piranhas, Brigade ships and other sea spawns in a 3000 stud range.")

addSection(pEvents, "Halloween")
addToggle(pEvents, "Auto Candy", "HalloweenCandy")
addToggle(pEvents, "Halloween Mob Farm", "HalloweenMobs")
addNote(pEvents, "Auto Candy teleports to every candy / present pickup and opens it. Mob farm kills Ghost / Halloween spawns by name.")

addSection(pEvents, "Collect")
addToggle(pEvents, "Auto Collect All (Chest+Fruit+Candy)", "AutoCollectAll")

--// TELEPORT
addSection(pTP, "First Sea")
local FIRST_SEA = {
    { "Windmill Village", { "windmill" },       CFrame.new(955.8, 12.9, 1296.4) },
    { "Marine Starter",   { "marine starter" }, CFrame.new(2681.5, 17.1, 1683.2) },
    { "Middle Town",      { "middle town" },    CFrame.new(0, 7.2, -1200.4) },
    { "Jungle",           { "jungle" },         CFrame.new(-1614.6, 36.9, 152.1) },
    { "Pirate Village",   { "pirate village" }, CFrame.new(-1130.1, 12.9, 3870.4) },
    { "Desert",           { "desert" },         CFrame.new(1098.4, 6.9, 4200.1) },
    { "Frozen Village",   { "frozen" },         CFrame.new(1198.3, 7.7, 10534.9) },
    { "Marine Fortress",  { "fortress" },       CFrame.new(4781.2, 6.9, 3923.4) },
    { "Skylands",         { "skyland", "sky" }, CFrame.new(-4607.5, 733.2, -3444.7) },
    { "Prison",           { "prison", "impel" },CFrame.new(4875.6, 5.7, 735.8) },
    { "Colosseum",        { "colosseum" },      CFrame.new(-1500.3, 6.9, 900.1) },
    { "Magma Village",    { "magma" },          CFrame.new(-5242.4, 12.1, 8504.3) },
    { "Underwater City",  { "underwater" },     CFrame.new(61163.4, 11.2, 1819.7) },
    { "Fountain City",    { "fountain" },       CFrame.new(5251.5, 6.9, -257.2) },
}
local function addTPButton(page, label, patterns, cframe)
    addButton(page, "TP: " .. label, function()
        local obj = findNamed(patterns)
        if obj then
            local p = posOf(obj)
            if p then
                tpTo(CFrame.new(p.X, p.Y + 4, p.Z))
                notify("Teleport: " .. label)
                return
            end
        end
        if cframe then
            tpTo(cframe)
            notify("Teleport: " .. label)
        else
            notify("TP failed: " .. label .. " not found", T.red)
        end
    end)
end
for _, isl in ipairs(FIRST_SEA) do
    addTPButton(pTP, isl[1], isl[2], isl[3])
end

addSection(pTP, "Second Sea")
local SECOND_SEA = {
    { "Kingdom of Rose",  { "kingdom of rose", "rose" } },
    { "Green Zone",       { "green zone" } },
    { "Zombie Island",    { "zombie" } },
    { "Snow Mountain",    { "snow" } },
    { "Hot and Cold",     { "hot and cold" } },
    { "Cursed Ship",      { "cursed" } },
    { "Ice Castle",       { "ice castle" } },
    { "Forgotten Island", { "forgotten" } },
    { "Usoap's Island",   { "usoa" } },
    { "Miniskirt Island", { "miniskirt" } },
    { "Cave Island",      { "cave" } },
}
for _, isl in ipairs(SECOND_SEA) do
    addTPButton(pTP, isl[1], isl[2], nil)
end

addSection(pTP, "Third Sea")
local THIRD_SEA = {
    { "Port Town",         { "port town" } },
    { "Hydra Island",      { "hydra" } },
    { "Great Tree",        { "great tree", "greattree" } },
    { "Castle on the Sea", { "castle on the sea" } },
    { "Floating Turtle",   { "turtle" } },
    { "Mansion",           { "mansion" } },
    { "Peanut Island",     { "peanut" } },
    { "Chocolate Island",  { "chocolate" } },
    { "Cake Loaf",         { "cake loaf", "cake" } },
    { "Tiki Outpost",      { "tiki" } },
}
for _, isl in ipairs(THIRD_SEA) do
    addTPButton(pTP, isl[1], isl[2], nil)
end
addNote(pTP, "2nd/3rd Sea TPs scan the map by island name (auto-updates with game changes). Smooth Teleport in Misc makes them fly instead of blink.")

--// ESP
addSection(pESP, "Visuals")
addToggle(pESP, "Player ESP", "ESPPlayers")
addToggle(pESP, "Enemy ESP", "ESPEnemies")
addToggle(pESP, "Fruit ESP", "ESPFruits")
addToggle(pESP, "Chest ESP", "ESPChests")
addToggle(pESP, "Event ESP (Candy/Ghosts)", "ESPEvent")
addNote(pESP, "Colors: players cyan, enemies red, fruits orange, chests yellow, event items purple.")

--// PLAYER
addSection(pPlayer, "Movement")
addSlider(pPlayer, "WalkSpeed", 16, 350, "WalkSpeed")
addSlider(pPlayer, "JumpPower", 50, 350, "JumpPower")
addToggle(pPlayer, "Infinite Jump", "InfJump")
addToggle(pPlayer, "Noclip", "Noclip")
addToggle(pPlayer, "Fly (joystick + jump = up, shift = down)", "Fly")
addSlider(pPlayer, "Fly Speed", 20, 300, "FlySpeed")

--// MISC
addSection(pMisc, "Settings")
addToggle(pMisc, "Anti-AFK", "AntiAFK")
addToggle(pMisc, "Smooth Teleports (tween)", "TweenTP")
addButton(pMisc, "FPS Boost", function()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e6
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") then
                v.Enabled = false
            end
        end
    end)
    pcall(function() settings().Rendering.QualityLevel = 1 end)
    notify("FPS Boost applied")
end)
addButton(pMisc, "Rejoin Server", function()
    notify("Rejoining server...")
    task.delay(0.5, function()
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)
end)
addButton(pMisc, "Destroy UI", function() destroyUI() end)
addNote(pMisc, "Right Ctrl = show/hide. Drag the purple top bar to move. Destroy UI stops all loops and removes everything.")
addSection(pMisc, "About")
addNote(pMisc, "TrippyX HUB v2.0 — clean, animated, draggable. Works on mobile + PC executors. If a remote name ever changes, run the TrippyX Recon script to find the new one.")

--// DESTROY
destroyUI = function()
    if destroyed then return end
    destroyed = true
    State.Fly = false
    teardownFly()
    for _, key in ipairs({ "AutoFarm", "BringMobs", "AutoAttack", "AutoChest", "AutoFruit", "AutoCollectAll", "AutoRaid", "AutoV4", "SeaEvent", "HalloweenCandy", "HalloweenMobs", "Noclip", "InfJump" }) do
        State[key] = false
    end
    clearESP()
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    pcall(function()
        local c = getChar()
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then
            h.WalkSpeed = 16
            if h.UseJumpPower then h.JumpPower = 50 end
        end
    end)
    pcall(function() gui:Destroy() end)
    print("[TrippyX] HUB closed. All loops stopped.")
end

--=====================================================================--
--  KEYBINDS + LOOPS
--=====================================================================--

table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == CFG.UI_KEY then
        if ROOT.Visible then
            closeUI(true)
        else
            openUI(true)
        end
    end
end))

table.insert(conns, UserInputService.JumpRequest:Connect(function()
    lastJumpReq = os.clock()
    if State.InfJump then
        local c = getChar()
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then
            pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
    end
end))

table.insert(conns, RunService.Stepped:Connect(function()
    if State.Noclip then
        local c = getChar()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                end
            end
        end
    end
end))

-- master tick loop
local ALL_TICKERS = {}
table.insert(ALL_TICKERS, tickFarm)
table.insert(ALL_TICKERS, tickBring)
table.insert(ALL_TICKERS, tickAutoAttack)
table.insert(ALL_TICKERS, function(now)
    for _, cfg in ipairs(COLLECTORS) do
        pcall(tickCollect, cfg, now)
    end
end)
table.insert(ALL_TICKERS, tickRaid)
table.insert(ALL_TICKERS, tickV4)
table.insert(ALL_TICKERS, tickSea)
table.insert(ALL_TICKERS, tickHallow)
table.insert(ALL_TICKERS, tickMovement)
table.insert(ALL_TICKERS, function(now)
    if gate("esp", now, 1.0) then
        pcall(refreshESP)
    end
end)

table.insert(conns, RunService.Heartbeat:Connect(function()
    if destroyed then return end
    local now = os.clock()
    for _, t in ipairs(ALL_TICKERS) do
        local ok, err = pcall(t, now)
        if not ok then
            setStatus("loop err: " .. tostring(err))
        end
    end
end))

--// ANTI-AFK
table.insert(conns, LocalPlayer.Idled:Connect(function()
    if State.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end))

--// BOOT
selectTab("Main")
openUI(true)
notify("TrippyX HUB v2.0 loaded", T.green)
notify("Right Ctrl = show/hide UI")

print("===========================================")
print("  TrippyX HUB v2.0 loaded")
print("  Blox Fruits | autofarm + events + more")
print("  Key: Right Ctrl = show / hide UI")
print("===========================================")
