--[[
═══════════════════════════════════════════════════════════════════════════
                           RemoteForge v1.0
              基于 Remote Spy 数据的全方位客户端操控脚本
                         (Obsidian UI Library)

  捕获目标:
    1. SetLookAngles  → ReplicatedStorage.SetLookAngles (RemoteEvent)
       参数: (Player, pitch:number, yaw:number)
       用途: 服务器同步其他玩家的视角角度

    2. StaminaSync     → ReplicatedStorage.FH_Remotes.StaminaSync (RemoteEvent)
       参数: (currentStamina:number, isExhausted:boolean, maxStamina:number)
       用途: 服务器同步体力状态

  功能模块:
    • 体力操控 (无限/冻结/自定义/防疲劳/强制同步)
    • 视角操控 (阻止/冻结/自定义/范围控制)
    • 玩家追踪 (实时视角追踪/距离显示)
    • 玩家 ESP (高亮/名称/距离/视角指示)
    • 远程监控 (实时日志/事件统计)
    • 远程发送 (自定义参数/快捷发送)
    • 实用工具 (飞行/穿墙/速度/跳跃/全亮/反挂机)
═══════════════════════════════════════════════════════════════════════════
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- 第一部分: 环境检测与服务引用
-- ═══════════════════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local Stats             = game:GetService("Stats")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- 执行器兼容性检测
local getconnections = getconnections or get_signal_cons or getconnections
local hookmetamethod = hookmetamethod or hookmeta
local hookfunction   = hookfunction or replaceclosure
local setclipboard    = setclipboard or toclipboard or set_clipboard
local firesignal      = firesignal or fire_signal
local isexecutor      = identifyexecutor and pcall(identifyexecutor)

local ExecutorName = "未知"
if identifyexecutor then
    local ok, name = pcall(identifyexecutor)
    if ok and name then ExecutorName = name end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 第二部分: 远程事件引用
-- ═══════════════════════════════════════════════════════════════════════════

local Remotes = {}

Remotes.SetLookAngles = ReplicatedStorage:FindFirstChild("SetLookAngles")
Remotes.FH_Remotes    = ReplicatedStorage:FindFirstChild("FH_Remotes")
Remotes.StaminaSync   = Remotes.FH_Remotes and Remotes.FH_Remotes:FindFirstChild("StaminaSync")

-- 远程事件存在性检查
local RemoteStatus = {}
for name, remote in pairs(Remotes) do
    RemoteStatus[name] = remote ~= nil
end

if not Remotes.SetLookAngles then
    warn("[RemoteForge] 警告: 未找到 SetLookAngles 远程事件")
end
if not Remotes.StaminaSync then
    warn("[RemoteForge] 警告: 未找到 StaminaSync 远程事件")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 第三部分: 状态管理
-- ═══════════════════════════════════════════════════════════════════════════

local State = {
    -- 体力操控
    InfiniteStamina   = false,
    FreezeStamina     = false,
    CustomStamina     = false,
    StaminaValue      = 100,
    MaxStaminaValue   = 100,
    NoExhaustion      = false,
    ForceStaminaSync  = false,

    -- 视角操控
    BlockLookAngles   = false,
    FreezeLookAngles  = false,
    CustomLookAngles  = false,
    CustomPitch       = 0,
    CustomYaw         = 0,
    LookAngleRange    = 0,

    -- 玩家追踪
    PlayerTracking    = false,
    ShowLookInfo      = false,

    -- 玩家 ESP
    PlayerESP         = false,
    ESPColor          = Color3.fromRGB(0, 255, 100),
    ShowNames         = true,
    ShowDistance      = true,
    ShowLookDirection = false,

    -- 远程监控
    RemoteMonitor     = false,
    MonitorLookAngles = false,
    MonitorStamina    = false,

    -- 实用工具
    FlyEnabled       = false,
    FlySpeed          = 50,
    NoclipEnabled     = false,
    WalkSpeed         = 16,
    JumpPower         = 50,
    WalkSpeedEnabled  = false,
    JumpPowerEnabled  = false,
    Fullbright        = false,
    AntiAfk           = false,
    ShowWatermark     = true,
}

-- 玩家数据追踪表
local PlayerData = {}
local RemoteLog = {}
local MaxLogEntries = 50

-- 远程事件统计
local RemoteStats = {
    SetLookAngles = { count = 0, lastArgs = nil, lastTime = 0 },
    StaminaSync   = { count = 0, lastArgs = nil, lastTime = 0 },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 第四部分: 工具函数
-- ═══════════════════════════════════════════════════════════════════════════

local function safeGetConnections(signal)
    if not getconnections then return nil end
    local ok, conns = pcall(getconnections, signal)
    if ok and type(conns) == "table" then
        return conns
    end
    return nil
end

local function notify(title, desc, duration)
    if _G.RemoteForgeLibrary then
        _G.RemoteForgeLibrary:Notify({
            Title = title,
            Description = desc,
            Time = duration or 4,
        })
    end
end

local function getCharacter(player)
    if not player then return nil end
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    return char, hrp, hum
end

local function getDistance(part)
    local char, hrp = getCharacter(LocalPlayer)
    if not hrp or not part then return 0 end
    return (hrp.Position - part.Position).Magnitude
end

local function addLogEntry(remoteName, args)
    local entry = {
        time = os.clock(),
        remote = remoteName,
        args = args,
    }
    table.insert(RemoteLog, 1, entry)
    if #RemoteLog > MaxLogEntries then
        table.remove(RemoteLog)
    end
end

local function formatArgs(args)
    local parts = {}
    for i, arg in ipairs(args) do
        if type(arg) == "userdata" and arg:IsA("Player") then
            table.insert(parts, arg.Name)
        elseif type(arg) == "boolean" then
            table.insert(parts, arg and "true" or "false")
        elseif type(arg) == "number" then
            table.insert(parts, string.format("%.2f", arg))
        elseif type(arg) == "string" then
            table.insert(parts, '"' .. arg .. '"')
        else
            table.insert(parts, tostring(arg))
        end
    end
    return table.concat(parts, ", ")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 第五部分: 远程事件 Hook 系统
-- ═══════════════════════════════════════════════════════════════════════════

-- 存储原始连接函数
local OriginalHandlers = {
    SetLookAngles = {},
    StaminaSync   = {},
}

local HooksInstalled = false

local function installRemoteHooks()
    if HooksInstalled then return end
    HooksInstalled = true

    -- ── Hook StaminaSync ──────────────────────────────────────────────
    if Remotes.StaminaSync then
        local conns = safeGetConnections(Remotes.StaminaSync.OnClientEvent)
        if conns then
            for _, conn in ipairs(conns) do
                local func = nil
                pcall(function() func = conn.Function end)
                if func then
                    table.insert(OriginalHandlers.StaminaSync, func)
                end
                pcall(function() conn:Disable() end)
            end
        end

        Remotes.StaminaSync.OnClientEvent:Connect(function(current, exhausted, maxStam)
            -- 统计
            RemoteStats.StaminaSync.count = RemoteStats.StaminaSync.count + 1
            RemoteStats.StaminaSync.lastArgs = { current, exhausted, maxStam }
            RemoteStats.StaminaSync.lastTime = os.clock()

            -- 监控日志
            if State.RemoteMonitor and State.MonitorStamina then
                addLogEntry("StaminaSync", { current, exhausted, maxStam })
            end

            -- 修改参数
            local modifiedCurrent  = current
            local modifiedExhausted = exhausted
            local modifiedMax      = maxStam

            if State.FreezeStamina then
                return -- 完全阻止事件
            end

            if State.InfiniteStamina then
                modifiedCurrent  = modifiedMax > 0 and modifiedMax or 100
                modifiedExhausted = false
            end

            if State.CustomStamina then
                modifiedCurrent  = State.StaminaValue
                modifiedMax      = State.MaxStaminaValue
            end

            if State.NoExhaustion then
                modifiedExhausted = false
            end

            -- 调用原始处理器
            if #OriginalHandlers.StaminaSync > 0 then
                for _, func in ipairs(OriginalHandlers.StaminaSync) do
                    pcall(func, modifiedCurrent, modifiedExhausted, modifiedMax)
                end
            end
        end)
    end

    -- ── Hook SetLookAngles ────────────────────────────────────────────
    if Remotes.SetLookAngles then
        local conns = safeGetConnections(Remotes.SetLookAngles.OnClientEvent)
        if conns then
            for _, conn in ipairs(conns) do
                local func = nil
                pcall(function() func = conn.Function end)
                if func then
                    table.insert(OriginalHandlers.SetLookAngles, func)
                end
                pcall(function() conn:Disable() end)
            end
        end

        Remotes.SetLookAngles.OnClientEvent:Connect(function(player, pitch, yaw)
            -- 统计
            RemoteStats.SetLookAngles.count = RemoteStats.SetLookAngles.count + 1
            RemoteStats.SetLookAngles.lastArgs = { player, pitch, yaw }
            RemoteStats.SetLookAngles.lastTime = os.clock()

            -- 玩家追踪数据
            if player and player:IsA("Player") then
                PlayerData[player] = {
                    pitch = pitch,
                    yaw   = yaw,
                    time  = os.clock(),
                    name  = player.Name,
                }
            end

            -- 监控日志
            if State.RemoteMonitor and State.MonitorLookAngles then
                addLogEntry("SetLookAngles", { player, pitch, yaw })
            end

            -- 修改参数
            if State.BlockLookAngles then
                return -- 完全阻止
            end

            local modifiedPitch = pitch
            local modifiedYaw   = yaw

            if State.FreezeLookAngles then
                -- 冻结: 使用上一次的角度 (不更新)
                return
            end

            if State.CustomLookAngles then
                modifiedPitch = State.CustomPitch
                modifiedYaw   = State.CustomYaw
            end

            -- 调用原始处理器
            if #OriginalHandlers.SetLookAngles > 0 then
                for _, func in ipairs(OriginalHandlers.SetLookAngles) do
                    pcall(func, player, modifiedPitch, modifiedYaw)
                end
            end
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 第六部分: 远程事件发送
-- ═══════════════════════════════════════════════════════════════════════════

local RemoteSender = {}

function RemoteSender.SendSetLookAngles(player, pitch, yaw)
    if not Remotes.SetLookAngles then return false end
    local ok, err = pcall(function()
        Remotes.SetLookAngles:FireServer(player, pitch, yaw)
    end)
    return ok, err
end

function RemoteSender.SendStaminaSync(current, exhausted, maxStam)
    if not Remotes.StaminaSync then return false end
    local ok, err = pcall(function()
        Remotes.StaminaSync:FireServer(current, exhausted, maxStam)
    end)
    return ok, err
end

-- 强制体力同步 (定时向服务器发送满体力)
local ForceStaminaLoop = nil
function RemoteSender.StartForceStaminaSync()
    if ForceStaminaLoop then return end
    ForceStaminaLoop = RunService.Heartbeat:Connect(function()
        if State.ForceStaminaSync and Remotes.StaminaSync then
            pcall(function()
                Remotes.StaminaSync:FireServer(
                    State.MaxStaminaValue,
                    false,
                    State.MaxStaminaValue
                )
            end)
        end
    end)
end

function RemoteSender.StopForceStaminaSync()
    if ForceStaminaLoop then
        ForceStaminaLoop:Disconnect()
        ForceStaminaLoop = nil
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 第七部分: 玩家 ESP 系统
-- ═══════════════════════════════════════════════════════════════════════════

local ESPObjects = {}
local ESPLoop = nil

local function createESP(player)
    if player == LocalPlayer then return end

    local esp = {
        highlight = Instance.new("Highlight"),
        billboard = Instance.new("BillboardGui"),
        nameLabel = Instance.new("TextLabel"),
        infoLabel = Instance.new("TextLabel"),
    }

    esp.highlight.Name = "RemoteForge_ESP"
    esp.highlight.FillColor = State.ESPColor
    esp.highlight.OutlineColor = State.ESPColor
    esp.highlight.FillTransparency = 0.5
    esp.highlight.OutlineTransparency = 0
    esp.highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    esp.billboard.Name = "RemoteForge_ESP_Billboard"
    esp.billboard.Size = UDim2.fromOffset(200, 60)
    esp.billboard.StudsOffset = Vector3.new(0, 3, 0)
    esp.billboard.AlwaysOnTop = true

    esp.nameLabel.Parent = esp.billboard
    esp.nameLabel.BackgroundTransparency = 1
    esp.nameLabel.Size = UDim2.fromScale(1, 0.5)
    esp.nameLabel.Position = UDim2.fromScale(0, 0)
    esp.nameLabel.Font = Enum.Font.Code
    esp.nameLabel.TextSize = 14
    esp.nameLabel.TextColor3 = State.ESPColor
    esp.nameLabel.TextStrokeTransparency = 0.5
    esp.nameLabel.Text = player.Name

    esp.infoLabel.Parent = esp.billboard
    esp.infoLabel.BackgroundTransparency = 1
    esp.infoLabel.Size = UDim2.fromScale(1, 0.5)
    esp.infoLabel.Position = UDim2.fromScale(0, 0.5)
    esp.infoLabel.Font = Enum.Font.Code
    esp.infoLabel.TextSize = 12
    esp.infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    esp.infoLabel.TextStrokeTransparency = 0.5
    esp.infoLabel.Text = ""

    ESPObjects[player] = esp
end

local function removeESP(player)
    local esp = ESPObjects[player]
    if esp then
        if esp.highlight then esp.highlight:Destroy() end
        if esp.billboard then esp.billboard:Destroy() end
        ESPObjects[player] = nil
    end
end

local function updateESP()
    for player, esp in pairs(ESPObjects) do
        local char, hrp, hum = getCharacter(player)
        if char and hrp then
            esp.highlight.Parent = char
            esp.billboard.Parent = hrp

            local parts = {}
            if State.ShowNames then
                table.insert(parts, player.Name)
            end
            if State.ShowDistance then
                local dist = getDistance(hrp)
                table.insert(parts, string.format("%.0f studs", dist))
            end
            if State.ShowLookDirection and PlayerData[player] then
                local pd = PlayerData[player]
                table.insert(parts, string.format("P:%.1f Y:%.1f", pd.pitch, pd.yaw))
            end

            esp.nameLabel.Text = table.concat(parts, "\n")
            esp.nameLabel.Visible = #parts > 0
            esp.infoLabel.Visible = false

            esp.highlight.FillColor = State.ESPColor
            esp.highlight.OutlineColor = State.ESPColor
            esp.nameLabel.TextColor3 = State.ESPColor
        else
            esp.highlight.Parent = nil
            esp.billboard.Parent = nil
        end
    end
end

local function startESPLoop()
    if ESPLoop then return end
    ESPLoop = RunService.RenderStepped:Connect(function()
        if not State.PlayerESP then return end

        -- 为新玩家创建 ESP
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not ESPObjects[player] then
                createESP(player)
            end
        end

        updateESP()
    end)
end

local function stopESPLoop()
    if ESPLoop then
        ESPLoop:Disconnect()
        ESPLoop = nil
    end
    for player, _ in pairs(ESPObjects) do
        removeESP(player)
    end
end

-- 玩家加入/离开事件
Players.PlayerAdded:Connect(function(player)
    if State.PlayerESP then
        createESP(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
    PlayerData[player] = nil
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- 第八部分: 实用工具功能
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 飞行系统 ──────────────────────────────────────────────────────────────
local FlyLoop = nil
local FlyBodyVelocity = nil
local FlyBodyGyro = nil

local function startFly()
    local char, hrp, hum = getCharacter(LocalPlayer)
    if not hrp then return end

    FlyBodyVelocity = Instance.new("BodyVelocity")
    FlyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    FlyBodyVelocity.Velocity = Vector3.zero
    FlyBodyVelocity.Parent = hrp

    FlyBodyGyro = Instance.new("BodyGyro")
    FlyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    FlyBodyGyro.CFrame = Camera.CFrame
    FlyBodyGyro.Parent = hrp

    FlyLoop = RunService.RenderStepped:Connect(function()
        if not State.FlyEnabled then return end
        local c, h = getCharacter(LocalPlayer)
        if not h then return end

        FlyBodyGyro.CFrame = Camera.CFrame

        local direction = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            direction = direction + Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            direction = direction - Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            direction = direction - Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            direction = direction + Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            direction = direction + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            direction = direction - Vector3.new(0, 1, 0)
        end

        FlyBodyVelocity.Velocity = direction * State.FlySpeed
    end)
end

local function stopFly()
    if FlyLoop then
        FlyLoop:Disconnect()
        FlyLoop = nil
    end
    if FlyBodyVelocity then
        FlyBodyVelocity:Destroy()
        FlyBodyVelocity = nil
    end
    if FlyBodyGyro then
        FlyBodyGyro:Destroy()
        FlyBodyGyro = nil
    end
end

-- ── 穿墙系统 ──────────────────────────────────────────────────────────────
local NoclipLoop = nil
local function startNoclip()
    NoclipLoop = RunService.Stepped:Connect(function()
        if not State.NoclipEnabled then return end
        local char = getCharacter(LocalPlayer)
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function stopNoclip()
    if NoclipLoop then
        NoclipLoop:Disconnect()
        NoclipLoop = nil
    end
end

-- ── 速度/跳跃力 ────────────────────────────────────────────────────────────
local SpeedLoop = nil
local function startSpeedLoop()
    if SpeedLoop then return end
    SpeedLoop = RunService.Heartbeat:Connect(function()
        local char, hrp, hum = getCharacter(LocalPlayer)
        if hum then
            if State.WalkSpeedEnabled then
                hum.WalkSpeed = State.WalkSpeed
            end
            if State.JumpPowerEnabled then
                hum.JumpPower = State.JumpPower
                pcall(function() hum.JumpHeight = State.JumpPower end)
            end
        end
    end)
end

-- ── 全亮 ──────────────────────────────────────────────────────────────────
local OriginalLighting = {}
local function enableFullbright()
    OriginalLighting.Brightness = Lighting.Brightness
    OriginalLighting.ClockTime = Lighting.ClockTime
    OriginalLighting.FogEnd = Lighting.FogEnd
    OriginalLighting.GlobalShadows = Lighting.GlobalShadows
    OriginalLighting.Ambient = Lighting.Ambient

    Lighting.Brightness = 3
    Lighting.ClockTime = 14
    Lighting.FogEnd = 1e9
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(178, 178, 178)
end

local function disableFullbright()
    if OriginalLighting.Brightness then Lighting.Brightness = OriginalLighting.Brightness end
    if OriginalLighting.ClockTime then Lighting.ClockTime = OriginalLighting.ClockTime end
    if OriginalLighting.FogEnd then Lighting.FogEnd = OriginalLighting.FogEnd end
    if OriginalLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = OriginalLighting.GlobalShadows end
    if OriginalLighting.Ambient then Lighting.Ambient = OriginalLighting.Ambient end
end

-- ── 反挂机 ─────────────────────────────────────────────────────────────────
local AntiAfkConnection = nil
local function enableAntiAfk()
    if AntiAfkConnection then return end
    local VirtualUser = nil
    pcall(function()
        VirtualUser = game:GetService("VirtualUser")
    end)
    AntiAfkConnection = LocalPlayer.Idled:Connect(function()
        if VirtualUser then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end)
end

local function disableAntiAfk()
    if AntiAfkConnection then
        AntiAfkConnection:Disconnect()
        AntiAfkConnection = nil
    end
end

-- ── 传送至玩家 ──────────────────────────────────────────────────────────────
local function teleportToPlayer(player)
    local char, hrp = getCharacter(LocalPlayer)
    local targetChar, targetHrp = getCharacter(player)
    if hrp and targetHrp then
        hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 3)
        notify("传送", "已传送到 " .. player.Name, 3)
    else
        notify("传送", "无法传送: 目标或自身角色不存在", 3)
    end
end

-- ── 重置角色 ────────────────────────────────────────────────────────────────
local function resetCharacter()
    local char, hrp, hum = getCharacter(LocalPlayer)
    if hum then
        hum.Health = 0
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 第九部分: Obsidian UI 界面构建
-- ═══════════════════════════════════════════════════════════════════════════

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

_G.RemoteForgeLibrary = Library

local Window = Library:CreateWindow({
    Title       = "RemoteForge",
    Footer      = "v1.0 | " .. ExecutorName,
    NotifySide   = "Right",
    ShowCustomCursor = true,
    MobileButtonsSide = "Right",
    ToggleKeybind = Enum.KeyCode.RightControl,
    AutoShow = true,
})

-- ─── 创建标签页 ─────────────────────────────────────────────────────────────
local Tabs = {
    Main     = Window:AddTab("主功能", "zap", "体力与视角操控"),
    Players  = Window:AddTab("玩家", "users", "玩家追踪与 ESP"),
    Remote   = Window:AddTab("远程", "radio", "远程事件监控与发送"),
    Utility  = Window:AddTab("实用", "wrench", "飞行/穿墙/速度等"),
    Settings = Window:AddTab("设置", "settings", "主题与配置"),
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 第十部分: 主功能标签页
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 左侧: 体力操控 ──────────────────────────────────────────────────────────
local StaminaGroup = Tabs.Main:AddLeftGroupbox("体力操控", "heart")

StaminaGroup:AddToggle("InfiniteStamina", {
    Text     = "无限体力",
    Default  = false,
    Tooltip  = "Hook StaminaSync 入站事件, 强制体力为最大值",
    Callback = function(val)
        State.InfiniteStamina = val
        notify("体力操控", val and "无限体力 已开启" or "无限体力 已关闭", 3)
    end,
})

StaminaGroup:AddToggle("FreezeStamina", {
    Text     = "体力冻结",
    Default  = false,
    Tooltip  = "完全阻止 StaminaSync 事件, 体力不再更新",
    Callback = function(val)
        State.FreezeStamina = val
        notify("体力操控", val and "体力冻结 已开启" or "体力冻结 已关闭", 3)
    end,
})

StaminaGroup:AddToggle("NoExhaustion", {
    Text     = "防疲劳",
    Default  = false,
    Tooltip  = "强制 isExhausted 参数为 false",
    Callback = function(val)
        State.NoExhaustion = val
    end,
})

StaminaGroup:AddToggle("CustomStamina", {
    Text     = "自定义体力",
    Default  = false,
    Tooltip  = "使用自定义体力值覆盖服务器数据",
    Callback = function(val)
        State.CustomStamina = val
    end,
})

StaminaGroup:AddSlider("StaminaValue", {
    Text     = "体力值",
    Default  = 100,
    Min      = 0,
    Max      = 999,
    Rounding = 0,
    Callback = function(val)
        State.StaminaValue = val
    end,
})

StaminaGroup:AddSlider("MaxStaminaValue", {
    Text     = "最大体力值",
    Default  = 100,
    Min      = 1,
    Max      = 999,
    Rounding = 0,
    Callback = function(val)
        State.MaxStaminaValue = val
    end,
})

StaminaGroup:AddToggle("ForceStaminaSync", {
    Text     = "强制体力同步",
    Default  = false,
    Tooltip  = "定时向服务器发送满体力数据 (FireServer)",
    Callback = function(val)
        State.ForceStaminaSync = val
        if val then
            RemoteSender.StartForceStaminaSync()
        else
            RemoteSender.StopForceStaminaSync()
        end
    end,
})

StaminaGroup:AddButton({
    Text = "立即发送满体力",
    Tooltip = "向服务器发送一次满体力 FireServer 请求",
    Func = function()
        local ok = RemoteSender.SendStaminaSync(State.MaxStaminaValue, false, State.MaxStaminaValue)
        notify("体力同步", ok and "已发送满体力数据" or "发送失败", 3)
    end,
})

StaminaGroup:AddLabel("远程状态:"):AddLabel(
    Remotes.StaminaSync and "✓ StaminaSync 已连接" or "✗ StaminaSync 未找到"
)

-- ─── 右侧: 视角操控 ──────────────────────────────────────────────────────────
local LookGroup = Tabs.Main:AddRightGroupbox("视角操控", "eye")

LookGroup:AddToggle("BlockLookAngles", {
    Text     = "阻止视角更新",
    Default  = false,
    Tooltip  = "完全阻止 SetLookAngles 事件",
    Callback = function(val)
        State.BlockLookAngles = val
        notify("视角操控", val and "视角更新已阻止" or "视角更新已恢复", 3)
    end,
})

LookGroup:AddToggle("FreezeLookAngles", {
    Text     = "冻结视角",
    Default  = false,
    Tooltip  = "冻结所有玩家的视角角度, 不再更新",
    Callback = function(val)
        State.FreezeLookAngles = val
    end,
})

LookGroup:AddToggle("CustomLookAngles", {
    Text     = "自定义视角",
    Default  = false,
    Tooltip  = "用自定义值覆盖所有玩家的视角角度",
    Callback = function(val)
        State.CustomLookAngles = val
    end,
})

LookGroup:AddSlider("CustomPitch", {
    Text     = "俯仰角 (Pitch)",
    Default  = 0,
    Min      = -3.14,
    Max      = 3.14,
    Rounding = 2,
    Callback = function(val)
        State.CustomPitch = val
    end,
})

LookGroup:AddSlider("CustomYaw", {
    Text     = "偏航角 (Yaw)",
    Default  = 0,
    Min      = -3.14,
    Max      = 3.14,
    Rounding = 2,
    Callback = function(val)
        State.CustomYaw = val
    end,
})

LookGroup:AddButton({
    Text = "立即同步视角",
    Tooltip = "对所有玩家触发一次自定义视角 firesignal",
    Func = function()
        if not Remotes.SetLookAngles then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                pcall(function()
                    firesignal(Remotes.SetLookAngles.OnClientEvent,
                        player, State.CustomPitch, State.CustomYaw)
                end)
            end
        end
        notify("视角操控", "已对所有玩家触发自定义视角", 3)
    end,
})

LookGroup:AddLabel("远程状态:"):AddLabel(
    Remotes.SetLookAngles and "✓ SetLookAngles 已连接" or "✗ SetLookAngles 未找到"
)

-- ═══════════════════════════════════════════════════════════════════════════
-- 第十一部分: 玩家标签页
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 左侧: 玩家追踪 ──────────────────────────────────────────────────────────
local TrackGroup = Tabs.Players:AddLeftGroupbox("玩家追踪", "radar")

TrackGroup:AddToggle("PlayerTracking", {
    Text     = "启用追踪",
    Default  = false,
    Tooltip  = "实时记录所有玩家的视角角度数据",
    Callback = function(val)
        State.PlayerTracking = val
    end,
})

TrackGroup:AddToggle("ShowLookInfo", {
    Text     = "显示视角信息",
    Default  = false,
    Tooltip  = "在下方显示选中玩家的视角数据",
    Callback = function(val)
        State.ShowLookInfo = val
    end,
})

local PlayerDropdown = TrackGroup:AddDropdown("TargetPlayer", {
    SpecialType = "Player",
    Text        = "选择玩家",
    ExcludeLocalPlayer = true,
    Callback = function(val)
        -- val is player name
    end,
})

local TrackInfoLabel = TrackGroup:AddLabel("选择玩家以查看视角数据")

TrackGroup:AddButton({
    Text = "传送至玩家",
    Func = function()
        local targetName = Options.TargetPlayer.Value
        if not targetName or targetName == "" then
            notify("传送", "请先选择一个玩家", 3)
            return
        end
        local target = Players:FindFirstChild(targetName)
        if target then
            teleportToPlayer(target)
        else
            notify("传送", "玩家不存在或已离开", 3)
        end
    end,
})

-- 追踪信息更新循环
task.spawn(function()
    while true do
        if State.ShowLookInfo then
            local targetName = Options.TargetPlayer and Options.TargetPlayer.Value or ""
            if targetName and targetName ~= "" then
                local target = Players:FindFirstChild(targetName)
                if target and PlayerData[target] then
                    local pd = PlayerData[target]
                    local char, hrp = getCharacter(target)
                    local dist = hrp and getDistance(hrp) or 0
                    TrackInfoLabel:SetText(string.format(
                        "%s\n俯仰: %.2f | 偏航: %.2f\n距离: %.0f studs\n更新: %.1f秒前",
                        targetName, pd.pitch, pd.yaw, dist, os.clock() - pd.time
                    ))
                else
                    TrackInfoLabel:SetText(targetName .. "\n等待视角数据...")
                end
            else
                TrackInfoLabel:SetText("请选择一个玩家")
            end
        end
        task.wait(0.2)
    end
end)

-- ─── 右侧: 玩家 ESP ──────────────────────────────────────────────────────────
local ESPGroup = Tabs.Players:AddRightGroupbox("玩家 ESP", "eye")

ESPGroup:AddToggle("PlayerESP", {
    Text     = "启用 ESP",
    Default  = false,
    Tooltip  = "高亮所有玩家并显示信息",
    Callback = function(val)
        State.PlayerESP = val
        if val then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    createESP(player)
                end
            end
            startESPLoop()
            notify("ESP", "已开启", 3)
        else
            stopESPLoop()
            notify("ESP", "已关闭", 3)
        end
    end,
})

ESPGroup:AddLabel("ESP 颜色"):AddColorPicker("ESPColor", {
    Default = Color3.fromRGB(0, 255, 100),
    Title   = "ESP 颜色",
    Callback = function(color)
        State.ESPColor = color
    end,
})

ESPGroup:AddToggle("ShowNames", {
    Text    = "显示名称",
    Default = true,
    Callback = function(val)
        State.ShowNames = val
    end,
})

ESPGroup:AddToggle("ShowDistance", {
    Text    = "显示距离",
    Default = true,
    Callback = function(val)
        State.ShowDistance = val
    end,
})

ESPGroup:AddToggle("ShowLookDirection", {
    Text    = "显示视角方向",
    Default = false,
    Tooltip = "显示玩家的 Pitch/Yaw 值",
    Callback = function(val)
        State.ShowLookDirection = val
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════
-- 第十二部分: 远程标签页
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 左侧: 远程监控 ──────────────────────────────────────────────────────────
local MonitorGroup = Tabs.Remote:AddLeftGroupbox("远程监控", "activity")

MonitorGroup:AddToggle("RemoteMonitor", {
    Text     = "启用监控",
    Default  = false,
    Tooltip  = "记录所有远程事件到日志",
    Callback = function(val)
        State.RemoteMonitor = val
        RemoteLog = {}
    end,
})

MonitorGroup:AddToggle("MonitorLookAngles", {
    Text    = "监控 SetLookAngles",
    Default = true,
    Callback = function(val)
        State.MonitorLookAngles = val
    end,
})

MonitorGroup:AddToggle("MonitorStamina", {
    Text    = "监控 StaminaSync",
    Default = true,
    Callback = function(val)
        State.MonitorStamina = val
    end,
})

local StatsLabel = MonitorGroup:AddLabel("事件统计")

MonitorGroup:AddButton({
    Text = "清空日志",
    Func = function()
        RemoteLog = {}
        notify("监控", "日志已清空", 2)
    end,
})

-- 统计信息更新循环
task.spawn(function()
    while true do
        local lookCount = RemoteStats.SetLookAngles.count
        local stamCount = RemoteStats.StaminaSync.count
        local lookArgs = RemoteStats.SetLookAngles.lastArgs
        local stamArgs = RemoteStats.StaminaSync.lastArgs

        local text = string.format(
            "SetLookAngles: %d 次\nStaminaSync: %d 次",
            lookCount, stamCount
        )

        if lookArgs then
            text = text .. "\n\n上次 SetLookAngles:\n  " .. formatArgs(lookArgs)
        end
        if stamArgs then
            text = text .. "\n\n上次 StaminaSync:\n  " .. formatArgs(stamArgs)
        end

        if #RemoteLog > 0 then
            text = text .. "\n\n最近日志:"
            for i = 1, math.min(#RemoteLog, 5) do
                local entry = RemoteLog[i]
                text = text .. string.format("\n  [%d] %s: %s",
                    i, entry.remote, formatArgs(entry.args))
            end
        end

        StatsLabel:SetText(text)
        task.wait(0.5)
    end
end)

-- ─── 右侧: 远程发送 ──────────────────────────────────────────────────────────
local SenderGroup = Tabs.Remote:AddRightGroupbox("远程发送", "send")

SenderGroup:AddDropdown("SenderRemote", {
    Values  = { "StaminaSync", "SetLookAngles" },
    Default = 1,
    Text    = "选择远程",
    Callback = function(val)
        -- val is the selected value
    end,
})

SenderGroup:AddInput("SendArg1", {
    Text        = "参数 1",
    Default     = "100",
    Numeric     = true,
    Placeholder = "数值",
    Tooltip     = "StaminaSync: 体力值 | SetLookAngles: 玩家名",
})

SenderGroup:AddInput("SendArg2", {
    Text        = "参数 2",
    Default     = "0",
    Numeric     = true,
    Placeholder = "数值",
    Tooltip     = "StaminaSync: 是否疲劳 | SetLookAngles: Pitch",
})

SenderGroup:AddInput("SendArg3", {
    Text        = "参数 3",
    Default     = "100",
    Numeric     = true,
    Placeholder = "数值",
    Tooltip     = "StaminaSync: 最大体力 | SetLookAngles: Yaw",
})

SenderGroup:AddButton({
    Text     = "发送 (FireServer)",
    Tooltip  = "向服务器发送远程事件",
    Func = function()
        local remoteName = Options.SenderRemote.Value
        local arg1 = Options.SendArg1.Value
        local arg2 = Options.SendArg2.Value
        local arg3 = Options.SendArg3.Value

        if remoteName == "StaminaSync" then
            local ok = RemoteSender.SendStaminaSync(
                tonumber(arg1) or 100,
                arg2 == "true" or tonumber(arg2) == 1,
                tonumber(arg3) or 100
            )
            notify("发送", ok and "StaminaSync 已发送" or "发送失败", 3)
        elseif remoteName == "SetLookAngles" then
            local targetPlayer = Players:FindFirstChild(arg1)
            if not targetPlayer then
                notify("发送", "未找到玩家: " .. tostring(arg1), 3)
                return
            end
            local ok = RemoteSender.SendSetLookAngles(
                targetPlayer,
                tonumber(arg2) or 0,
                tonumber(arg3) or 0
            )
            notify("发送", ok and "SetLookAngles 已发送" or "发送失败", 3)
        end
    end,
})

SenderGroup:AddDivider()

SenderGroup:AddLabel("快捷发送:")

SenderGroup:AddButton({
    Text = "发送满体力",
    Func = function()
        RemoteSender.SendStaminaSync(100, false, 100)
        notify("发送", "已发送 (100, false, 100)", 2)
    end,
})

SenderGroup:AddButton({
    Text = "发送零体力",
    Func = function()
        RemoteSender.SendStaminaSync(0, true, 100)
        notify("发送", "已发送 (0, true, 100)", 2)
    end,
})

SenderGroup:AddButton({
    Text = "对所有玩家触发视角",
    Tooltip = "在客户端对所有玩家触发 firesignal",
    Func = function()
        if not Remotes.SetLookAngles then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                pcall(function()
                    firesignal(Remotes.SetLookAngles.OnClientEvent,
                        player, 0, 0)
                end)
            end
        end
        notify("发送", "已对所有玩家触发 (0, 0) 视角", 3)
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════
-- 第十三部分: 实用工具标签页
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 左侧: 角色操控 ──────────────────────────────────────────────────────────
local CharGroup = Tabs.Utility:AddLeftGroupbox("角色操控", "person-standing")

CharGroup:AddToggle("WalkSpeedEnabled", {
    Text     = "自定义移动速度",
    Default  = false,
    Callback = function(val)
        State.WalkSpeedEnabled = val
        if val then startSpeedLoop() end
    end,
})

CharGroup:AddSlider("WalkSpeed", {
    Text     = "移动速度",
    Default  = 16,
    Min      = 0,
    Max      = 500,
    Rounding = 0,
    Callback = function(val)
        State.WalkSpeed = val
    end,
})

CharGroup:AddToggle("JumpPowerEnabled", {
    Text     = "自定义跳跃力",
    Default  = false,
    Callback = function(val)
        State.JumpPowerEnabled = val
        if val then startSpeedLoop() end
    end,
})

CharGroup:AddSlider("JumpPower", {
    Text     = "跳跃力",
    Default  = 50,
    Min      = 0,
    Max      = 500,
    Rounding = 0,
    Callback = function(val)
        State.JumpPower = val
    end,
})

CharGroup:AddDivider()

CharGroup:AddToggle("FlyEnabled", {
    Text     = "飞行",
    Default  = false,
    Tooltip  = "WASD 移动, Space 上升, Shift 下降",
    Callback = function(val)
        State.FlyEnabled = val
        if val then startFly() else stopFly() end
    end,
})

CharGroup:AddSlider("FlySpeed", {
    Text     = "飞行速度",
    Default  = 50,
    Min      = 1,
    Max      = 500,
    Rounding = 0,
    Callback = function(val)
        State.FlySpeed = val
    end,
})

CharGroup:AddToggle("NoclipEnabled", {
    Text     = "穿墙",
    Default  = false,
    Tooltip  = "角色可穿过所有障碍物",
    Callback = function(val)
        State.NoclipEnabled = val
        if val then startNoclip() else stopNoclip() end
    end,
})

CharGroup:AddButton({
    Text    = "重置角色",
    Risky   = true,
    Tooltip = "杀死当前角色以重生",
    Func = function()
        resetCharacter()
    end,
})

-- ─── 右侧: 其他工具 ──────────────────────────────────────────────────────────
local OtherGroup = Tabs.Utility:AddRightGroupbox("其他工具", "sparkles")

OtherGroup:AddToggle("Fullbright", {
    Text     = "全亮",
    Default  = false,
    Tooltip  = "提高场景亮度",
    Callback = function(val)
        State.Fullbright = val
        if val then enableFullbright() else disableFullbright() end
    end,
})

OtherGroup:AddToggle("AntiAfk", {
    Text     = "反挂机",
    Default  = false,
    Tooltip  = "防止因空闲被踢出",
    Callback = function(val)
        State.AntiAfk = val
        if val then enableAntiAfk() else disableAntiAfk() end
    end,
})

OtherGroup:AddToggle("ShowWatermark", {
    Text     = "显示水印",
    Default  = true,
    Tooltip  = "显示 FPS / Ping / 脚本信息",
    Callback = function(val)
        State.ShowWatermark = val
        Library:SetWatermarkVisibility(val)
    end,
})

OtherGroup:AddDivider()

OtherGroup:AddButton({
    Text    = "复制游戏 ID",
    Tooltip = "将当前游戏 PlaceId 复制到剪贴板",
    Func = function()
        if setclipboard then
            setclipboard(tostring(game.PlaceId))
            notify("复制", "PlaceId 已复制: " .. game.PlaceId, 3)
        else
            notify("复制", "当前执行器不支持剪贴板", 3)
        end
    end,
})

OtherGroup:AddButton({
    Text    = "复制 JobId",
    Tooltip = "将当前服务器 JobId 复制到剪贴板",
    Func = function()
        if setclipboard then
            setclipboard(tostring(game.JobId))
            notify("复制", "JobId 已复制", 3)
        else
            notify("复制", "当前执行器不支持剪贴板", 3)
        end
    end,
})

OtherGroup:AddButton({
    Text    = "卸载脚本",
    Risky   = true,
    Tooltip = "完全卸载 RemoteForge",
    Func = function()
        -- 停止所有功能
        stopFly()
        stopNoclip()
        stopESPLoop()
        RemoteSender.StopForceStaminaSync()
        disableFullbright()
        disableAntiAfk()
        Library:Unload()
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════
-- 第十四部分: 设置标签页 (主题与配置)
-- ═══════════════════════════════════════════════════════════════════════════

local MenuGroup = Tabs.Settings:AddLeftGroupbox("菜单", "menu")

MenuGroup:AddLabel("菜单快捷键"):AddKeyPicker("MenuKeybind", {
    Default       = "RightControl",
    SyncToggleState  = true,
    NoUI          = true,
    Text          = "菜单键",
})

Library.ToggleKeybind = Options.MenuKeybind

-- 主题与配置管理
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("RemoteForge")
SaveManager:SetFolder("RemoteForge/specific-game")
SaveManager:SetSubFolder("specific-place")

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

-- ═══════════════════════════════════════════════════════════════════════════
-- 第十五部分: 水印系统
-- ═══════════════════════════════════════════════════════════════════════════

Library:SetWatermarkVisibility(true)
Library:SetWatermark("RemoteForge | 加载中...")

local FrameTimer = tick()
local FrameCounter = 0
local FPS = 60

local WatermarkConnection = RunService.RenderStepped:Connect(function()
    FrameCounter = FrameCounter + 1
    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter
        FrameTimer = tick()
        FrameCounter = 0
    end

    if State.ShowWatermark then
        local ping = 0
        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)

        Library:SetWatermark(string.format(
            "RemoteForge v1.0 | %d FPS | %d MS | %s",
            math.floor(FPS), ping, ExecutorName
        ))
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- 第十六部分: 初始化
-- ═══════════════════════════════════════════════════════════════════════════

-- 安装远程 Hook
installRemoteHooks()

-- 启动速度循环 (用于持续应用速度/跳跃力)
startSpeedLoop()

-- 加载自动配置
SaveManager:LoadAutoloadConfig()

-- 加载完成通知
task.delay(0.5, function()
    local features = {}
    if Remotes.SetLookAngles then table.insert(features, "SetLookAngles") end
    if Remotes.StaminaSync then table.insert(features, "StaminaSync") end

    notify("RemoteForge", string.format(
        "加载完成!\n执行器: %s\n已 Hook: %s\n按键: RightCtrl 打开菜单",
        ExecutorName,
        #features > 0 and table.concat(features, ", ") or "无远程事件"
    ), 6)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- 脚本结束
-- ═══════════════════════════════════════════════════════════════════════════