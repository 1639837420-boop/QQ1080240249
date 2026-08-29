--[[
    ╔══════════════════════════════════════════════════════════╗
    ║              FH Combat Suite - Client Script               ║
    ║              基于 Remote Spy 日志分析构建                    ║
    ║              UI 框架: WindUI v1.6.64                        ║
    ╠══════════════════════════════════════════════════════════╣
    ║  远程事件分析结果:                                          ║
    ║  1. SetLookAngles (Incoming) -> Player, pitch, yaw         ║
    ║     路径: ReplicatedStorage.SetLookAngles                  ║
    ║     功能: 同步其他玩家视角角度                                ║
    ║  2. StaminaSync (Incoming) -> current, isSprint, max      ║
    ║     路径: ReplicatedStorage.FH_Remotes.StaminaSync         ║
    ║     功能: 同步体力值                                        ║
    ╚══════════════════════════════════════════════════════════╝
]]

-- ============================================================
--  第一部分: 加载 WindUI 库
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/Source.lua"))()

-- ============================================================
--  第一点五部分: 手机端 Drawing API 兼容层
--  如果执行器不支持 Drawing API, 自动降级为 ScreenGui 方式
-- ============================================================
local HasDrawing = pcall(function() return Drawing and Drawing.new end)
local DrawLib = HasDrawing and Drawing or nil

-- 如果不支持 Drawing, 创建基于 ScreenGui 的替代实现
if not DrawLib then
    warn("[FH Suite] Drawing API 不可用, 使用 ScreenGui 降级方案 (手机端兼容)")

    -- 创建专用 ScreenGui 用于绘制
    local drawGui = Instance.new("ScreenGui")
    drawGui.Name = "FH_DrawLayer"
    drawGui.ResetOnSpawn = false
    drawGui.IgnoreGuiInset = true
    drawGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() drawGui.Parent = (gethui and gethui() or CoreGui or game:GetService("CoreGui")) end)
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(drawGui) end end)

    DrawLib = {}
    DrawLib.new = function(objType)
        if objType == "Circle" then
            local frame = Instance.new("Frame")
            frame.BackgroundTransparency = 1
            frame.Size = UDim2.new(0, 0, 0, 0)
            frame.Position = UDim2.new(0.5, 0, 0.5, 0)
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.Parent = drawGui

            local circle = Instance.new("Frame")
            circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            circle.BackgroundTransparency = 1
            circle.Size = UDim2.new(1, 0, 1, 0)
            circle.AnchorPoint = Vector2.new(0.5, 0.5)
            circle.Position = UDim2.new(0.5, 0, 0.5, 0)
            circle.Parent = frame

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = circle

            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(255, 255, 255)
            stroke.Thickness = 1
            stroke.Parent = circle

            local proxy = {
                Visible = false,
                Radius = 0,
                Color = Color3.fromRGB(255, 255, 255),
                Thickness = 1,
                Filled = false,
                Position = Vector2.new(0, 0),
                _frame = frame,
                _circle = circle,
                _stroke = stroke,
            }
            local mt = {
                __index = function(t, k)
                    if k == "Visible" then return t._circle.Visible end
                    return rawget(t, k)
                end,
                __newindex = function(t, k, v)
                    rawset(t, k, v)
                    if k == "Visible" then
                        t._circle.Visible = v
                    elseif k == "Radius" then
                        local size = v * 2
                        t._frame.Size = UDim2.new(0, size, 0, size)
                    elseif k == "Color" then
                        t._stroke.Color = v
                        t._circle.BackgroundColor3 = v
                    elseif k == "Thickness" then
                        t._stroke.Thickness = v
                    elseif k == "Filled" then
                        t._circle.BackgroundTransparency = v and 0 or 1
                    elseif k == "Position" then
                        t._frame.Position = UDim2.new(0, v.X, 0, v.Y)
                    end
                end,
            }
            setmetatable(proxy, mt)
            return proxy
        elseif objType == "Line" then
            local frame = Instance.new("Frame")
            frame.BackgroundTransparency = 1
            frame.Parent = drawGui
            local proxy = {
                Visible = false,
                From = Vector2.new(0, 0),
                To = Vector2.new(0, 0),
                Color = Color3.fromRGB(255, 255, 255),
                Thickness = 1,
                _frame = frame,
            }
            local lmt = {
                __newindex = function(t, k, v)
                    rawset(t, k, v)
                    if k == "Visible" then t._frame.Visible = v
                    elseif k == "Color" then t._frame.BackgroundColor3 = v
                    elseif k == "Thickness" then t._frame.Size = UDim2.new(0, t._frame.Size.X.Offset, 0, v)
                    elseif k == "From" or k == "To" then
                        local f = t.From
                        local to = t.To
                        local dx = to.X - f.X
                        local dy = to.Y - f.Y
                        local length = math.sqrt(dx*dx + dy*dy)
                        local angle = math.atan2(dy, dx)
                        t._frame.Size = UDim2.new(0, length, 0, t.Thickness)
                        t._frame.Position = UDim2.new(0, f.X, 0, f.Y)
                        t._frame.Rotation = math.deg(angle)
                    end
                end,
            }
            setmetatable(proxy, lmt)
            return proxy
        elseif objType == "Text" then
            local label = Instance.new("TextLabel")
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.SourceSans
            label.TextSize = 16
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.TextStrokeTransparency = 0
            label.Parent = drawGui
            local proxy = {
                Visible = false,
                Text = "",
                Color = Color3.fromRGB(255, 255, 255),
                Size = 16,
                Center = true,
                Outline = true,
                Position = Vector2.new(0, 0),
                _label = label,
            }
            local tmt = {
                __newindex = function(t, k, v)
                    rawset(t, k, v)
                    if k == "Visible" then t._label.Visible = v
                    elseif k == "Text" then t._label.Text = v
                    elseif k == "Color" then t._label.TextColor3 = v
                    elseif k == "Size" then t._label.TextSize = v
                    elseif k == "Position" then t._label.Position = UDim2.new(0, v.X, 0, v.Y)
                    elseif k == "Center" then t._label.TextXAlignment = v and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
                    elseif k == "Outline" then t._label.TextStrokeTransparency = v and 0 or 1
                    end
                end,
            }
            setmetatable(proxy, tmt)
            return proxy
        elseif objType == "Square" then
            local frame = Instance.new("Frame")
            frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            frame.BackgroundTransparency = 1
            frame.Parent = drawGui
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(255, 255, 255)
            stroke.Thickness = 1
            stroke.Parent = frame
            local proxy = {
                Visible = false,
                Size = Vector2.new(0, 0),
                Position = Vector2.new(0, 0),
                Color = Color3.fromRGB(255, 255, 255),
                Thickness = 1,
                Filled = false,
                _frame = frame,
                _stroke = stroke,
            }
            local smt = {
                __newindex = function(t, k, v)
                    rawset(t, k, v)
                    if k == "Visible" then t._frame.Visible = v
                    elseif k == "Size" then t._frame.Size = UDim2.new(0, v.X, 0, v.Y)
                    elseif k == "Position" then t._frame.Position = UDim2.new(0, v.X, 0, v.Y)
                    elseif k == "Color" then t._stroke.Color = v
                    elseif k == "Thickness" then t._stroke.Thickness = v
                    elseif k == "Filled" then t._frame.BackgroundTransparency = v and 0 or 1
                    end
                end,
            }
            setmetatable(proxy, smt)
            return proxy
        end
        return {}
    end
end

-- 统一 Drawing 入口 (无论原生还是降级)
local function NewDrawing(objType)
    return DrawLib.new(objType)
end

-- 设置全局 Drawing 以兼容所有 Drawing.new 调用
pcall(function() getgenv().Drawing = DrawLib end)
pcall(function() rawset(_G, "Drawing", DrawLib) end)

-- mouse1click 兼容
local function SafeMouseClick()
    if mouse1click then
        mouse1click()
    elseif Mouse then
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait()
            vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)
    end
end

-- ============================================================
--  第二部分: 服务与变量
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- 远程事件引用 (从日志中提取)
local SetLookAnglesEvent = ReplicatedStorage:WaitForChild("SetLookAngles", 5)
local FH_Remotes = ReplicatedStorage:FindFirstChild("FH_Remotes")
local StaminaSyncEvent = FH_Remotes and FH_Remotes:FindFirstChild("StaminaSync") or nil

-- ============================================================
--  第三部分: 配置表
-- ============================================================
local Config = {
    -- Aimbot
    AimbotEnabled = false,
    AimbotFOV = 120,
    AimbotSmoothness = 0.15,
    AimbotTargetPart = "Head",
    AimbotWallCheck = true,
    AimbotTeamCheck = true,
    AimbotVisibleCheck = true,

    -- Silent Aim
    SilentAimEnabled = false,
    SilentAimFOV = 200,
    SilentAimHitPart = "Head",

    -- Hitbox
    HitboxEnabled = false,
    HitboxSize = 10,
    HitboxTransparency = 0.7,
    HitboxColor = Color3.fromRGB(255, 0, 0),

    -- Anti Look
    AntiLookSync = false,

    -- Stamina
    InfiniteStamina = false,

    -- Movement
    SpeedEnabled = false,
    SpeedValue = 32,
    JumpEnabled = false,
    JumpValue = 60,
    InfiniteJump = false,
    FlyEnabled = false,
    FlySpeed = 50,
    NoclipEnabled = false,

    -- ESP
    ESPEnabled = false,
    ESPName = true,
    ESPDistance = true,
    ESPHealth = true,
    ESPBox = true,
    ESPTracer = true,
    ESPMaxDistance = 2000,

    -- Visuals
    Fullbright = false,
    FOVValue = 70,
    CrosshairEnabled = false,
    TimeOfDay = nil,

    -- Trigger Bot
    TriggerBotEnabled = false,
    TriggerBotDelay = 0.05,

    -- Anti AFK
    AntiAFK = true,

    -- UI
    UIToggleKey = Enum.KeyCode.RightShift,
}

-- ============================================================
--  第四部分: 工具函数
-- ============================================================
local Utils = {}

-- 获取所有玩家角色
function Utils.GetPlayers()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            table.insert(list, plr)
        end
    end
    return list
end

-- 获取玩家角色
function Utils.GetCharacter(plr)
    return plr and plr.Character
end

-- 获取角色的特定部件
function Utils.GetPart(char, partName)
    if not char then return nil end
    return char:FindFirstChild(partName)
end

-- 获取 Humanoid
function Utils.GetHumanoid(char)
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("AnimationController")
end

-- 获取 HumanoidRootPart
function Utils.GetRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end

-- 获取 Head
function Utils.GetHead(char)
    if not char then return nil end
    return char:FindFirstChild("Head")
end

-- 检查角色是否存活
function Utils.IsAlive(char)
    local hum = Utils.GetHumanoid(char)
    return hum and hum.Health > 0
end

-- 检查墙壁遮挡
function Utils.IsVisible(targetPart)
    if not targetPart then return false end
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    local result = Workspace:Raycast(origin, direction, params)
    if result and result.Instance then
        local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
        if hitChar and Players:GetPlayerFromCharacter(hitChar) then
            return true
        end
        return false
    end
    return true
end

-- 获取最近的玩家
function Utils.GetNearestPlayer(fovCheck, maxDistance)
    local nearest = nil
    local shortestDist = math.huge
    local mousePos = UserInputService:GetMouseLocation()
    local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and Utils.IsAlive(plr.Character) then
            local targetPart = Utils.GetPart(plr.Character, Config.AimbotTargetPart) or Utils.GetHead(plr.Character)
            if targetPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude
                    if (not fovCheck or dist <= Config.AimbotFOV) then
                        local worldDist = (targetPart.Position - Camera.CFrame.Position).Magnitude
                        if (not maxDistance or worldDist <= maxDistance) then
                            if not Config.AimbotWallCheck or Utils.IsVisible(targetPart) then
                                if dist < shortestDist then
                                    shortestDist = dist
                                    nearest = plr
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nearest
end

-- 获取最近的可见玩家 (用于 Silent Aim)
function Utils.GetClosestPlayerToMouse()
    local nearest = nil
    local shortestDist = Config.SilentAimFOV
    local mousePos = UserInputService:GetMouseLocation()
    local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and Utils.IsAlive(plr.Character) then
            local targetPart = Utils.GetPart(plr.Character, Config.SilentAimHitPart) or Utils.GetHead(plr.Character)
            if targetPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude
                    if dist < shortestDist then
                        if Utils.IsVisible(targetPart) then
                            shortestDist = dist
                            nearest = plr
                        end
                    end
                end
            end
        end
    end
    return nearest
end

-- 通知
function Utils.Notify(title, content, duration)
    WindUI:Notify({
        Title = title,
        Content = content,
        Duration = duration or 5,
    })
end

-- ============================================================
--  第五部分: 功能实现
-- ============================================================

-- ----------------------------------------------------------
--  5.1 Aimbot 自瞄
-- ----------------------------------------------------------
local AimbotConnection
local AimbotFOVCircle

function StartAimbot()
    if AimbotConnection then AimbotConnection:Disconnect() end
    AimbotConnection = RunService.RenderStepped:Connect(function()
        if not Config.AimbotEnabled then return end
        local target = Utils.GetNearestPlayer(true, nil)
        if target and target.Character then
            local part = Utils.GetPart(target.Character, Config.AimbotTargetPart) or Utils.GetHead(target.Character)
            if part then
                local currentCF = Camera.CFrame
                local targetCF = CFrame.new(currentCF.Position, part.Position)
                Camera.CFrame = currentCF:Lerp(targetCF, Config.AimbotSmoothness)
            end
        end
    end)
end

-- Aimbot FOV 圆圈
function CreateAimbotFOV()
    if AimbotFOVCircle then AimbotFOVCircle:Destroy() end
    AimbotFOVCircle = NewDrawing("Circle")
    AimbotFOVCircle.Visible = false
    AimbotFOVCircle.Radius = Config.AimbotFOV
    AimbotFOVCircle.Color = Color3.fromRGB(255, 255, 255)
    AimbotFOVCircle.Thickness = 1
    AimbotFOVCircle.Filled = false
    AimbotFOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    RunService.RenderStepped:Connect(function()
        if AimbotFOVCircle then
            AimbotFOVCircle.Visible = Config.AimbotEnabled
            AimbotFOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            AimbotFOVCircle.Radius = Config.AimbotFOV
        end
    end)
end

-- ----------------------------------------------------------
--  5.2 Silent Aim 静默瞄准 (Hook FireServer / RemoteEvent)
-- ----------------------------------------------------------
local SilentAimTarget = nil
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
local oldIndex = mt.__index

function EnableSilentAim()
    if setreadonly then setreadonly(mt, false) end

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if Config.SilentAimEnabled and (method == "FireServer" or method == "fireServer") then
            local target = Utils.GetClosestPlayerToMouse()
            if target and target.Character then
                local hitPart = Utils.GetPart(target.Character, Config.SilentAimHitPart) or Utils.GetHead(target.Character)
                if hitPart then
                    -- 尝试替换参数中的位置参数为目标部位
                    for i = 1, #args do
                        if typeof(args[i]) == "Vector3" then
                            args[i] = hitPart.Position
                        end
                        if typeof(args[i]) == "Instance" and args[i]:IsA("BasePart") then
                            args[i] = hitPart
                        end
                    end
                end
            end
        end

        return oldNamecall(self, table.unpack(args))
    end)

    if setreadonly then setreadonly(mt, true) end
end

function DisableSilentAim()
    if setreadonly then setreadonly(mt, false) end
    mt.__namecall = oldNamecall
    if setreadonly then setreadonly(mt, true) end
end

-- ----------------------------------------------------------
--  5.3 Hitbox Expander 碰撞箱放大
-- ----------------------------------------------------------
local HitboxConnections = {}

function UpdateHitboxes()
    -- 清除旧的
    for _, conn in ipairs(HitboxConnections) do
        conn:Disconnect()
    end
    HitboxConnections = {}

    if not Config.HitboxEnabled then
        -- 恢复原始大小
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                for _, part in ipairs(plr.Character:GetChildren()) do
                    if part:IsA("BasePart") and part:FindFirstChild("OriginalSize") then
                        part.Size = part.OriginalSize.Value
                        part.OriginalSize:Destroy()
                        part.Transparency = part:GetAttribute("OriginalTransparency") or 0
                    end
                end
            end
        end
        return
    end

    local conn = RunService.RenderStepped:Connect(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and Utils.IsAlive(plr.Character) then
                local head = Utils.GetHead(plr.Character)
                if head then
                    if not head:FindFirstChild("OriginalSize") then
                        local val = Instance.new("Vector3Value")
                        val.Name = "OriginalSize"
                        val.Value = head.Size
                        val.Parent = head
                        head:SetAttribute("OriginalTransparency", head.Transparency)
                    end
                    head.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                    head.Transparency = Config.HitboxTransparency
                    head.Color = Config.HitboxColor
                    head.Material = Enum.Material.ForceField
                end
            end
        end
    end)
    table.insert(HitboxConnections, conn)
end

-- ----------------------------------------------------------
--  5.4 Anti Look Sync (Hook SetLookAngles)
--  功能: 拦截/修改 Incoming 的 SetLookAngles 远程事件
--  可以用于: 阻止其他玩家的视角同步到你的客户端
-- ----------------------------------------------------------
local LookAngleHooked = false

function EnableAntiLookSync()
    if LookAngleHooked then return end
    if not SetLookAnglesEvent then
        Utils.Notify("警告", "未找到 SetLookAngles 远程事件", 5)
        return
    end

    -- Hook OnClientEvent 来拦截 Incoming 的 SetLookAngles
    -- 该事件从服务器发来, 参数: (Player, pitch, yaw)
    -- 我们拦截它来防止视角被强制修改
    pcall(function()
        if mt and setreadonly then
            setreadonly(mt, false)
        end

        -- 存储原始连接
        local oldFire = mt.__namecall

        -- 方法1: 使用 disconnect 原有监听器 + 重新连接过滤版
        -- 由于 Incoming 事件是通过 OnClientEvent 触发,
        -- 我们可以使用 hookmetamethod 来过滤

        if hookmetamethod then
            local oldNamecall2 = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if Config.AntiLookSync and self == SetLookAnglesEvent and method == "FireServer" then
                    -- 如果是 outgoing SetLookAngles, 可以选择阻止或修改
                    return -- 阻止发送
                end
                return oldNamecall2(self, ...)
            end)
        end

        if setreadonly then
            setreadonly(mt, true)
        end
    end)

    -- 方法2: 监听并覆盖 look angle 的应用
    -- Hook firesignal 来阻止 Incoming 触发
    pcall(function()
        if firesignal then
            -- 原始函数引用
            local originalfiresignal = firesignal
            firesignal = function(event, ...)
                if Config.AntiLookSync and event == SetLookAnglesEvent.OnClientEvent then
                    -- 阻止 Incoming SetLookAngles 的触发
                    return
                end
                return originalfiresignal(event, ...)
            end
        end
    end)

    -- 方法3: 直接监听 OnClientEvent 并记录/过滤
    -- 由于 SetLookAngles 是 Incoming (server->client),
    -- 客户端可以通过覆盖 onLookReceive 函数来阻止

    LookAngleHooked = true
end

function DisableAntiLookSync()
    if not LookAngleHooked then return end
    -- 恢复 firesignal
    pcall(function()
        if firesignal then
            -- 由于闭包引用, 这里只是标记关闭
            -- 实际恢复需要在 hook 函数内部检查 Config.AntiLookSync 标志
        end
    end)
    LookAngleHooked = false
end

-- ----------------------------------------------------------
--  5.5 Infinite Stamina (Hook StaminaSync)
--  功能: 拦截 StaminaSync 远程事件, 强制体力为最大值
--  参数: (currentStamina, isSprinting, maxStamina)
-- ----------------------------------------------------------
local StaminaHooked = false

function EnableInfiniteStamina()
    if StaminaHooked then return end
    if not StaminaSyncEvent then
        Utils.Notify("警告", "未找到 StaminaSync 远程事件", 5)
        return
    end

    -- Hook Incoming StaminaSync 事件
    -- 当服务器发送体力同步时, 我们拦截并修改参数
    StaminaHooked = true

    -- 方法1: Hook firesignal (如果 executor 支持)
    pcall(function()
        if firesignal then
            local originalfiresignal = firesignal
            _G.OriginalFireSignal = originalfiresignal
            firesignal = function(event, ...)
                if Config.InfiniteStamina and event == StaminaSyncEvent.OnClientEvent then
                    local args = {...}
                    -- 参数: (currentStamina, isSprinting, maxStamina)
                    -- 强制当前体力 = 最大体力
                    if #args >= 3 then
                        args[1] = args[3] or 100  -- current = max
                        args[2] = false            -- not sprinting
                    end
                    return originalfiresignal(event, table.unpack(args))
                end
                return originalfiresignal(event, ...)
            end
        end
    end)

    -- 方法2: 监听 OnClientEvent 并覆盖体力值
    pcall(function()
        StaminaSyncEvent.OnClientEvent:Connect(function(current, isSprinting, maxStamina)
            if Config.InfiniteStamina then
                -- 尝试修改本地体力显示/系统
                local char = LocalPlayer.Character
                if char then
                    local hum = Utils.GetHumanoid(char)
                    -- 如果有 stamina 属性, 设置为最大值
                    if hum and hum:GetAttribute("Stamina") then
                        hum:SetAttribute("Stamina", maxStamina or 100)
                    end
                end
            end
        end)
    end)

    -- 方法3: 如果游戏有 stamina GUI, 定期强制更新
    pcall(function()
        task.spawn(function()
            while StaminaHooked do
                if Config.InfiniteStamina then
                    local char = LocalPlayer.Character
                    if char then
                        local hum = Utils.GetHumanoid(char)
                        if hum then
                            pcall(function()
                                if hum:GetAttribute("MaxStamina") then
                                    hum:SetAttribute("Stamina", hum:GetAttribute("MaxStamina"))
                                end
                            end)
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
    end)
end

function DisableInfiniteStamina()
    StaminaHooked = false
    -- 恢复依赖于 Config.InfiniteStamina 标志位
    pcall(function()
        if _G.OriginalFireSignal then
            firesignal = _G.OriginalFireSignal
            _G.OriginalFireSignal = nil
        end
    end)
end

-- ----------------------------------------------------------
--  5.6 Speed Hack 移动速度
-- ----------------------------------------------------------
local SpeedConnection

function UpdateSpeed()
    if SpeedConnection then SpeedConnection:Disconnect() end
    if not Config.SpeedEnabled then
        -- 恢复
        local char = LocalPlayer.Character
        if char then
            local hum = Utils.GetHumanoid(char)
            if hum then hum.WalkSpeed = 16 end
        end
        return
    end
    SpeedConnection = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if char then
            local hum = Utils.GetHumanoid(char)
            if hum and hum.Health > 0 then
                hum.WalkSpeed = Config.SpeedValue
            end
        end
    end)
end

-- ----------------------------------------------------------
--  5.7 Jump Power 跳跃高度
-- ----------------------------------------------------------
local JumpConnection

function UpdateJump()
    if JumpConnection then JumpConnection:Disconnect() end
    if not Config.JumpEnabled then
        local char = LocalPlayer.Character
        if char then
            local hum = Utils.GetHumanoid(char)
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = 50
            end
        end
        return
    end
    JumpConnection = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if char then
            local hum = Utils.GetHumanoid(char)
            if hum and hum.Health > 0 then
                hum.UseJumpPower = true
                hum.JumpPower = Config.JumpValue
            end
        end
    end)
end

-- ----------------------------------------------------------
--  5.8 Infinite Jump 无限跳跃
-- ----------------------------------------------------------
local InfJumpConnection

function ToggleInfiniteJump()
    if InfJumpConnection then InfJumpConnection:Disconnect() end
    if not Config.InfiniteJump then return end
    InfJumpConnection = UserInputService.JumpRequest:Connect(function()
        local char = LocalPlayer.Character
        if char then
            local hum = Utils.GetHumanoid(char)
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)
end

-- ----------------------------------------------------------
--  5.9 Fly 飞行
-- ------------------------------------------------==========
local FlyConnection
local FlyInputConn1
local FlyInputConn2
local FlyVel
local FlyDir = {F = false, B = false, L = false, R = false, U = false, D = false}

function StartFly()
    if FlyConnection then FlyConnection:Disconnect() end
    if FlyInputConn1 then FlyInputConn1:Disconnect() end
    if FlyInputConn2 then FlyInputConn2:Disconnect() end
    if not Config.FlyEnabled then
        if FlyVel then FlyVel:Destroy() FlyVel = nil end
        return
    end

    local flyInputConn1 = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.W then FlyDir.F = true end
        if input.KeyCode == Enum.KeyCode.S then FlyDir.B = true end
        if input.KeyCode == Enum.KeyCode.A then FlyDir.L = true end
        if input.KeyCode == Enum.KeyCode.D then FlyDir.R = true end
        if input.KeyCode == Enum.KeyCode.Space then FlyDir.U = true end
        if input.KeyCode == Enum.KeyCode.LeftControl then FlyDir.D = true end
    end)

    local flyInputConn2 = UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.W then FlyDir.F = false end
        if input.KeyCode == Enum.KeyCode.S then FlyDir.B = false end
        if input.KeyCode == Enum.KeyCode.A then FlyDir.L = false end
        if input.KeyCode == Enum.KeyCode.D then FlyDir.R = false end
        if input.KeyCode == Enum.KeyCode.Space then FlyDir.U = false end
        if input.KeyCode == Enum.KeyCode.LeftControl then FlyDir.D = false end
    end)

    FlyConnection = RunService.RenderStepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local root = Utils.GetRoot(char)
        local hum = Utils.GetHumanoid(char)
        if not root or not hum then return end

        if FlyVel then FlyVel:Destroy() end
        FlyVel = Instance.new("BodyVelocity")
        FlyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        FlyVel.Velocity = Vector3.new(0, 0, 0)

        local camCF = Camera.CFrame
        local moveVec = Vector3.new(0, 0, 0)

        if FlyDir.F then moveVec = moveVec + camCF.LookVector end
        if FlyDir.B then moveVec = moveVec - camCF.LookVector end
        if FlyDir.L then moveVec = moveVec - camCF.RightVector end
        if FlyDir.R then moveVec = moveVec + camCF.RightVector end
        if FlyDir.U then moveVec = moveVec + Vector3.new(0, 1, 0) end
        if FlyDir.D then moveVec = moveVec - Vector3.new(0, 1, 0) end

        if moveVec.Magnitude > 0 then
            moveVec = moveVec.Unit * Config.FlySpeed
        end

        FlyVel.Velocity = moveVec
        FlyVel.Parent = root

        -- 防止下落
        hum:ChangeState(Enum.HumanoidStateType.Physics)
    end)

    -- 存储连接以便清理
    FlyInputConn1 = flyInputConn1
    FlyInputConn2 = flyInputConn2
end

-- ----------------------------------------------------------
--  5.10 Noclip 穿墙
-- ----------------------------------------------------------
local NoclipConnection

function ToggleNoclip()
    if NoclipConnection then NoclipConnection:Disconnect() end
    if not Config.NoclipEnabled then return end
    NoclipConnection = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

-- ----------------------------------------------------------
--  5.11 ESP 透视
-- ----------------------------------------------------------
local ESPObjects = {}
local ESPConnection

function ToggleESP()
    -- 清除现有
    for _, obj in ipairs(ESPObjects) do
        pcall(function() obj:Destroy() end) -- 如果是 Instance
        pcall(function() obj:Remove() end)   -- 如果是 Drawing
    end
    ESPObjects = {}
    if ESPConnection then ESPConnection:Disconnect() end

    if not Config.ESPEnabled then return end

    ESPConnection = RunService.RenderStepped:Connect(function()
        -- 清除旧的
        for key, obj in pairs(ESPObjects) do
            if type(obj) == "table" then
                for _, drawing in pairs(obj) do
                    pcall(function() drawing:Remove() end)
                end
            end
        end
        ESPObjects = {}

        local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and Utils.IsAlive(plr.Character) then
                local root = Utils.GetRoot(plr.Character)
                local head = Utils.GetHead(plr.Character)
                local hum = Utils.GetHumanoid(plr.Character)
                if root and head then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0))
                    local rootPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

                    if onScreen then
                        local worldDist = (root.Position - Camera.CFrame.Position).Magnitude
                        if worldDist <= Config.ESPMaxDistance then
                            local espData = {}

                            -- 名称
                            if Config.ESPName then
                                local text = NewDrawing("Text")
                                text.Text = plr.Name
                                text.Color = Color3.fromRGB(255, 255, 255)
                                text.Size = 16
                                text.Center = true
                                text.Outline = true
                                text.Position = Vector2.new(screenPos.X, headPos.Y - 20)
                                text.Visible = true
                                table.insert(espData, text)
                            end

                            -- 距离
                            if Config.ESPDistance then
                                local text = NewDrawing("Text")
                                text.Text = string.format("[%dm]", math.floor(worldDist))
                                text.Color = Color3.fromRGB(180, 180, 255)
                                text.Size = 14
                                text.Center = true
                                text.Outline = true
                                text.Position = Vector2.new(screenPos.X, headPos.Y - 5)
                                text.Visible = true
                                table.insert(espData, text)
                            end

                            -- 血量
                            if Config.ESPHealth and hum then
                                local text = NewDrawing("Text")
                                local healthPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                                local color = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), healthPct)
                                text.Text = string.format("%d HP", math.floor(hum.Health))
                                text.Color = color
                                text.Size = 14
                                text.Center = true
                                text.Outline = true
                                text.Position = Vector2.new(screenPos.X, rootPos.Y + 2)
                                text.Visible = true
                                table.insert(espData, text)
                            end

                            -- 方框
                            if Config.ESPBox then
                                local box = NewDrawing("Square")
                                local height = math.abs(rootPos.Y - headPos.Y)
                                local width = height * 0.5
                                box.Size = Vector2.new(width, height)
                                box.Position = Vector2.new(screenPos.X - width / 2, headPos.Y)
                                box.Color = Color3.fromRGB(255, 255, 255)
                                box.Thickness = 1
                                box.Filled = false
                                box.Visible = true
                                table.insert(espData, box)
                            end

                            -- 连线
                            if Config.ESPTracer then
                                local tracer = NewDrawing("Line")
                                tracer.From = viewportCenter
                                tracer.To = Vector2.new(screenPos.X, rootPos.Y)
                                tracer.Color = Color3.fromRGB(255, 255, 0)
                                tracer.Thickness = 1
                                tracer.Visible = true
                                table.insert(espData, tracer)
                            end

                            ESPObjects[plr] = espData
                        end
                    end
                end
            end
        end
    end)
end

-- ----------------------------------------------------------
--  5.12 Fullbright 全亮
-- ----------------------------------------------------------
local OriginalLighting = {}

function ToggleFullbright()
    if Config.Fullbright then
        if not next(OriginalLighting) then
            OriginalLighting.Brightness = Lighting.Brightness
            OriginalLighting.ClockTime = Lighting.ClockTime
            OriginalLighting.FogEnd = Lighting.FogEnd
            OriginalLighting.GlobalShadows = Lighting.GlobalShadows
            OriginalLighting.Ambient = Lighting.Ambient
            OriginalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
            OriginalLighting.ExposureCompensation = Lighting.ExposureCompensation
        end
        Lighting.Brightness = 3
        Lighting.ClockTime = 12
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        Lighting.ExposureCompensation = 0.5
    else
        if next(OriginalLighting) then
            Lighting.Brightness = OriginalLighting.Brightness
            Lighting.ClockTime = OriginalLighting.ClockTime
            Lighting.FogEnd = OriginalLighting.FogEnd
            Lighting.GlobalShadows = OriginalLighting.GlobalShadows
            Lighting.Ambient = OriginalLighting.Ambient
            Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
            Lighting.ExposureCompensation = OriginalLighting.ExposureCompensation
        end
    end
end

-- ----------------------------------------------------------
--  5.13 FOV 视角修改
-- ----------------------------------------------------------
function UpdateFOV()
    pcall(function()
        local hum = Utils.GetHumanoid(LocalPlayer.Character)
        if hum then
            Camera.FieldOfView = Config.FOVValue
        end
    end)
end

-- ----------------------------------------------------------
--  5.14 Crosshair 准星
-- ----------------------------------------------------------
local CrosshairDrawings = {}

function ToggleCrosshair()
    for _, draw in ipairs(CrosshairDrawings) do
        pcall(function() draw:Remove() end)
    end
    CrosshairDrawings = {}

    if not Config.CrosshairEnabled then return end

    -- 十字准星: 4条线
    local function createLine()
        local line = NewDrawing("Line")
        line.Color = Color3.fromRGB(0, 255, 0)
        line.Thickness = 1
        line.Visible = true
        return line
    end

    local top = createLine()
    local bottom = createLine()
    local left = createLine()
    local right = createLine()

    table.insert(CrosshairDrawings, top)
    table.insert(CrosshairDrawings, bottom)
    table.insert(CrosshairDrawings, left)
    table.insert(CrosshairDrawings, right)

    RunService.RenderStepped:Connect(function()
        if not Config.CrosshairEnabled then return end
        local cx = Camera.ViewportSize.X / 2
        local cy = Camera.ViewportSize.Y / 2
        local size = 8
        local gap = 4

        top.From = Vector2.new(cx, cy - gap - size)
        top.To = Vector2.new(cx, cy - gap)
        bottom.From = Vector2.new(cx, cy + gap)
        bottom.To = Vector2.new(cx, cy + gap + size)
        left.From = Vector2.new(cx - gap - size, cy)
        left.To = Vector2.new(cx - gap, cy)
        right.From = Vector2.new(cx + gap, cy)
        right.To = Vector2.new(cx + gap + size, cy)
    end)
end

-- ----------------------------------------------------------
--  5.15 Time Changer 时间修改
-- ----------------------------------------------------------
function SetTimeOfDay(time)
    if time then
        Lighting.ClockTime = time
    else
        Lighting.ClockTime = OriginalLighting.ClockTime or 14
    end
end

-- ----------------------------------------------------------
--  5.16 Trigger Bot 自动攻击
-- ----------------------------------------------------------
local TriggerBotConnection

function ToggleTriggerBot()
    if TriggerBotConnection then TriggerBotConnection:Disconnect() end
    if not Config.TriggerBotEnabled then return end

    TriggerBotConnection = RunService.RenderStepped:Connect(function()
        local target = Utils.GetClosestPlayerToMouse()
        if target and target.Character then
            local targetPart = Utils.GetPart(target.Character, "HumanoidRootPart") or Utils.GetHead(target.Character)
            if targetPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                local mouseLoc = UserInputService:GetMouseLocation()
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mouseLoc).Magnitude
                if dist < 50 and Utils.IsVisible(targetPart) then
                    -- 模拟点击
                    SafeMouseClick()
                    task.wait(Config.TriggerBotDelay)
                end
            end
        end
    end)
end

-- ----------------------------------------------------------
--  5.17 Anti-AFK 防挂机
-- ----------------------------------------------------------
function EnableAntiAFK()
    local vu = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        if Config.AntiAFK then
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
            vu:KeySequenced(Enum.KeyCode.Semicolon)
        end
    end)
end

-- ----------------------------------------------------------
--  5.18 Remote Spy 实时日志
-- ----------------------------------------------------------
local SpyConnections = {}
local SpyLog = {}
local SpyMaxEntries = 200

function StartRemoteSpy(onUpdate)
    -- 清除旧连接
    for _, conn in ipairs(SpyConnections) do
        pcall(function() conn:Disconnect() end)
    end
    SpyConnections = {}
    SpyLog = {}

    -- Hook metatable 来捕获所有 FireServer / InvokeServer
    local mt2 = getrawmetatable(game)
    local oldNC = mt2.__namecall

    if setreadonly then setreadonly(mt2, false) end

    local function getArgsString(args, depth)
        depth = depth or 0
        if depth > 2 then return "..." end
        local parts = {}
        for i, arg in ipairs(args) do
            if typeof(arg) == "Instance" then
                table.insert(parts, arg:GetFullName())
            elseif typeof(arg) == "table" then
                table.insert(parts, "{table}")
            elseif typeof(arg) == "Vector3" then
                table.insert(parts, string.format("V3(%.2f,%.2f,%.2f)", arg.X, arg.Y, arg.Z))
            elseif typeof(arg) == "CFrame" then
                table.insert(parts, "CFrame")
            elseif typeof(arg) == "number" then
                table.insert(parts, tostring(arg))
            elseif typeof(arg) == "string" then
                table.insert(parts, '"' .. arg:sub(1, 50) .. '"')
            elseif typeof(arg) == "boolean" then
                table.insert(parts, tostring(arg))
            else
                table.insert(parts, typeof(arg))
            end
        end
        return table.concat(parts, ", ")
    end

    mt2.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "FireServer" or method == "InvokeServer" then
            if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") then
                local entry = {
                    time = os.date("%H:%M:%S"),
                    type = method == "FireServer" and "RemoteEvent" or "RemoteFunction",
                    direction = "Outgoing",
                    name = self.Name,
                    path = self:GetFullName(),
                    args = getArgsString(args),
                }
                table.insert(SpyLog, 1, entry)
                if #SpyLog > SpyMaxEntries then
                    table.remove(SpyLog, #SpyLog)
                end
                if onUpdate then onUpdate(entry) end
            end
        end

        return oldNC(self, ...)
    end)

    if setreadonly then setreadonly(mt2, true) end

    -- 同时监听 Incoming 事件
    pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                if obj:IsA("RemoteEvent") then
                    local conn = obj.OnClientEvent:Connect(function(...)
                        local entry = {
                            time = os.date("%H:%M:%S"),
                            type = "RemoteEvent",
                            direction = "Incoming",
                            name = obj.Name,
                            path = obj:GetFullName(),
                            args = getArgsString({...}),
                        }
                        table.insert(SpyLog, 1, entry)
                        if #SpyLog > SpyMaxEntries then
                            table.remove(SpyLog, #SpyLog)
                        end
                        if onUpdate then onUpdate(entry) end
                    end)
                    table.insert(SpyConnections, conn)
                end
            end
        end
    end)
end

function GetSpyLog()
    return SpyLog
end

function StopRemoteSpy()
    for _, conn in ipairs(SpyConnections) do
        pcall(function() conn:Disconnect() end)
    end
    SpyConnections = {}
end

-- ----------------------------------------------------------
--  5.19 Teleport 传送
-- ----------------------------------------------------------
function TeleportToPlayer(plr)
    if not plr or not plr.Character then return end
    local targetRoot = Utils.GetRoot(plr.Character)
    local myRoot = Utils.GetRoot(LocalPlayer.Character)
    if targetRoot and myRoot then
        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 5)
    end
end

function TeleportToPosition(pos)
    local myRoot = Utils.GetRoot(LocalPlayer.Character)
    if myRoot then
        myRoot.CFrame = CFrame.new(pos)
    end
end

function TeleportToSpawn()
    local spawn = Workspace:FindFirstChild("SpawnLocation") or Workspace:FindFirstChildOfClass("SpawnLocation")
    if spawn then
        TeleportToPosition(spawn.Position + Vector3.new(0, 5, 0))
    else
        -- 尝试其他方式
        local myRoot = Utils.GetRoot(LocalPlayer.Character)
        if myRoot then
            myRoot.CFrame = CFrame.new(0, 50, 0)
        end
    end
end

-- 点击传送
local ClickTPConn
function EnableClickTP()
    if ClickTPConn then ClickTPConn:Disconnect() end
    ClickTPConn = Mouse.Button1Down:Connect(function()
        local myRoot = Utils.GetRoot(LocalPlayer.Character)
        if myRoot then
            local target = Mouse.Hit
            myRoot.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
        end
    end)
end

function DisableClickTP()
    if ClickTPConn then ClickTPConn:Disconnect() ClickTPConn = nil end
end

-- 保存/加载位置
local SavedPositions = {}

function SavePosition(name)
    local myRoot = Utils.GetRoot(LocalPlayer.Character)
    if myRoot then
        SavedPositions[name] = myRoot.CFrame
        return true
    end
    return false
end

function LoadPosition(name)
    if SavedPositions[name] then
        local myRoot = Utils.GetRoot(LocalPlayer.Character)
        if myRoot then
            myRoot.CFrame = SavedPositions[name]
            return true
        end
    end
    return false
end

-- ----------------------------------------------------------
--  5.20 FPS Boost 性能优化
-- ----------------------------------------------------------
function FPSBoost()
    -- 降低渲染距离
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Part") and not obj:IsDescendantOf(LocalPlayer.Character) then
            pcall(function()
                obj.Material = Enum.Material.Plastic
                if obj:FindFirstChild("Texture") or obj:FindFirstChild("Decal") then
                    -- 保持不变
                end
            end)
        end
    end

    -- 关闭阴影
    Lighting.GlobalShadows = false

    -- 降低质量
    settings().Rendering.QualityLevel = 1

    -- 禁用一些特效
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
            obj.Enabled = false
        end
    end

    Utils.Notify("FPS Boost", "已优化性能, 可能降低画质", 3)
end

-- ----------------------------------------------------------
--  5.21 Server Hop / Rejoin
-- ----------------------------------------------------------
function ServerHop()
    pcall(function()
        local baseUrl = "https://games.roblox.com/v1/games/%d/servers/Public?limit=100"
        local gameId = game.PlaceId
        local response = game:HttpGet(string.format(baseUrl, gameId))
        local data = HttpService:JSONDecode(response)

        local servers = {}
        for _, server in ipairs(data.data) do
            if server.playing < server.maxPlayers then
                table.insert(servers, server)
            end
        end

        if #servers > 0 then
            local target = servers[math.random(1, #servers)]
            TeleportService:TeleportToPlaceInstance(gameId, target.id, LocalPlayer)
        else
            Utils.Notify("Server Hop", "没有可用的服务器", 3)
        end
    end)
end

function RejoinServer()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end

-- ============================================================
--  第六部分: 构建 WindUI 界面
-- ============================================================
local Window = WindUI:CreateWindow({
    Title = "FH Combat Suite",
    Author = "Based on Remote Spy Analysis",
    Icon = "bloc",
    Folder = "FHCombatSuite",
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinSize = Vector2.new(400, 350),
})

-- 创建标签页
local CombatTab = Window:Tab({ Title = "战斗", Icon = "swords" })
local PlayerTab = Window:Tab({ Title = "角色", Icon = "user" })
local VisualTab = Window:Tab({ Title = "视觉", Icon = "eye" })
local TeleportTab = Window:Tab({ Title = "传送", Icon = "map-pin" })
local ToolsTab = Window:Tab({ Title = "工具", Icon = "wrench" })
local SettingsTab = Window:Tab({ Title = "设置", Icon = "settings" })

-- ===== 战斗 Tab =====
CombatTab:Paragraph({
    Title = "自瞄系统",
    Desc = "Aimbot & Silent Aim",
})

CombatTab:Toggle({
    Title = "Aimbot 开关",
    Desc = "自动瞄准最近的玩家",
    Value = false,
    Callback = function(v)
        Config.AimbotEnabled = v
        if v then StartAimbot() end
        Utils.Notify("Aimbot", v and "已开启" or "已关闭", 3)
    end,
})

CombatTab:Slider({
    Title = "Aimbot FOV",
    Value = { Min = 30, Max = 500, Default = 120 },
    Callback = function(v)
        Config.AimbotFOV = v
    end,
})

CombatTab:Slider({
    Title = "Aimbot 平滑度",
    Value = { Min = 1, Max = 100, Default = 15 },
    Callback = function(v)
        Config.AimbotSmoothness = v / 100
    end,
})

CombatTab:Dropdown({
    Title = "瞄准部位",
    Values = { "Head", "HumanoidRootPart", "Torso", "UpperTorso" },
    Value = "Head",
    Callback = function(v)
        Config.AimbotTargetPart = v
    end,
})

CombatTab:Toggle({
    Title = "墙壁检测",
    Desc = "不瞄准墙后的玩家",
    Value = true,
    Callback = function(v)
        Config.AimbotWallCheck = v
    end,
})

CombatTab:Toggle({
    Title = "显示 FOV 圆圈",
    Value = false,
    Callback = function(v)
        if AimbotFOVCircle then
            AimbotFOVCircle.Visible = v
        end
    end,
})

CombatTab:Divider()

CombatTab:Paragraph({
    Title = "Silent Aim",
    Desc = "静默瞄准 (Hook Remote)",
})

CombatTab:Toggle({
    Title = "Silent Aim 开关",
    Desc = "自动修正射击参数",
    Value = false,
    Callback = function(v)
        Config.SilentAimEnabled = v
        if v then
            EnableSilentAim()
        else
            DisableSilentAim()
        end
    end,
})

CombatTab:Slider({
    Title = "Silent Aim FOV",
    Value = { Min = 30, Max = 1000, Default = 200 },
    Callback = function(v)
        Config.SilentAimFOV = v
    end,
})

CombatTab:Dropdown({
    Title = "命中部位",
    Values = { "Head", "HumanoidRootPart", "Torso", "UpperTorso" },
    Value = "Head",
    Callback = function(v)
        Config.SilentAimHitPart = v
    end,
})

CombatTab:Divider()

CombatTab:Paragraph({
    Title = "其他战斗功能",
    Desc = "Hitbox / Trigger Bot / Anti Look",
})

CombatTab:Toggle({
    Title = "Hitbox Expander",
    Desc = "放大玩家头部碰撞箱",
    Value = false,
    Callback = function(v)
        Config.HitboxEnabled = v
        UpdateHitboxes()
    end,
})

CombatTab:Slider({
    Title = "Hitbox 大小",
    Value = { Min = 1, Max = 50, Default = 10 },
    Callback = function(v)
        Config.HitboxSize = v
    end,
})

CombatTab:Slider({
    Title = "Hitbox 透明度",
    Value = { Min = 0, Max = 100, Default = 70 },
    Callback = function(v)
        Config.HitboxTransparency = v / 100
    end,
})

CombatTab:Toggle({
    Title = "Trigger Bot",
    Desc = "自动点击攻击准星内的敌人",
    Value = false,
    Callback = function(v)
        Config.TriggerBotEnabled = v
        ToggleTriggerBot()
    end,
})

CombatTab:Slider({
    Title = "Trigger Bot 延迟",
    Value = { Min = 1, Max = 100, Default = 5 },
    Callback = function(v)
        Config.TriggerBotDelay = v / 100
    end,
})

CombatTab:Toggle({
    Title = "Anti Look Sync",
    Desc = "拦截 SetLookAngles (阻止视角被服务器同步)",
    Value = false,
    Callback = function(v)
        Config.AntiLookSync = v
        if v then EnableAntiLookSync() else DisableAntiLookSync() end
    end,
})

-- ===== 角色 Tab =====
PlayerTab:Paragraph({
    Title = "移动修改",
    Desc = "Speed / Jump / Fly / Noclip",
})

PlayerTab:Toggle({
    Title = "速度修改",
    Value = false,
    Callback = function(v)
        Config.SpeedEnabled = v
        UpdateSpeed()
    end,
})

PlayerTab:Slider({
    Title = "移动速度",
    Value = { Min = 16, Max = 500, Default = 32 },
    Callback = function(v)
        Config.SpeedValue = v
    end,
})

PlayerTab:Toggle({
    Title = "跳跃高度修改",
    Value = false,
    Callback = function(v)
        Config.JumpEnabled = v
        UpdateJump()
    end,
})

PlayerTab:Slider({
    Title = "跳跃力度",
    Value = { Min = 50, Max = 500, Default = 60 },
    Callback = function(v)
        Config.JumpValue = v
    end,
})

PlayerTab:Toggle({
    Title = "无限跳跃",
    Desc = "按空格可以无限跳",
    Value = false,
    Callback = function(v)
        Config.InfiniteJump = v
        ToggleInfiniteJump()
    end,
})

PlayerTab:Divider()

PlayerTab:Paragraph({
    Title = "飞行 & 穿墙",
    Desc = "Fly & Noclip",
})

PlayerTab:Toggle({
    Title = "飞行 (WASD + Space/Ctrl)",
    Value = false,
    Callback = function(v)
        Config.FlyEnabled = v
        StartFly()
    end,
})

PlayerTab:Slider({
    Title = "飞行速度",
    Value = { Min = 10, Max = 500, Default = 50 },
    Callback = function(v)
        Config.FlySpeed = v
    end,
})

PlayerTab:Toggle({
    Title = "Noclip 穿墙",
    Value = false,
    Callback = function(v)
        Config.NoclipEnabled = v
        ToggleNoclip()
    end,
})

PlayerTab:Divider()

PlayerTab:Paragraph({
    Title = "体力系统 (Hook StaminaSync)",
    Desc = "基于 FH_Remotes.StaminaSync 远程事件",
})

PlayerTab:Toggle({
    Title = "无限体力",
    Desc = "拦截 StaminaSync, 强制体力满值",
    Value = false,
    Callback = function(v)
        Config.InfiniteStamina = v
        if v then EnableInfiniteStamina() else DisableInfiniteStamina() end
    end,
})

-- ===== 视觉 Tab =====
VisualTab:Paragraph({
    Title = "ESP 透视",
    Desc = "Player ESP System",
})

VisualTab:Toggle({
    Title = "ESP 开关",
    Value = false,
    Callback = function(v)
        Config.ESPEnabled = v
        ToggleESP()
    end,
})

VisualTab:Toggle({
    Title = "显示名称",
    Value = true,
    Callback = function(v)
        Config.ESPName = v
    end,
})

VisualTab:Toggle({
    Title = "显示距离",
    Value = true,
    Callback = function(v)
        Config.ESPDistance = v
    end,
})

VisualTab:Toggle({
    Title = "显示血量",
    Value = true,
    Callback = function(v)
        Config.ESPHealth = v
    end,
})

VisualTab:Toggle({
    Title = "方框 ESP",
    Value = true,
    Callback = function(v)
        Config.ESPBox = v
    end,
})

VisualTab:Toggle({
    Title = "连线 ESP",
    Value = true,
    Callback = function(v)
        Config.ESPTracer = v
    end,
})

VisualTab:Slider({
    Title = "ESP 最大距离",
    Value = { Min = 100, Max = 5000, Default = 2000 },
    Callback = function(v)
        Config.ESPMaxDistance = v
    end,
})

VisualTab:Divider()

VisualTab:Paragraph({
    Title = "视觉效果",
    Desc = "Lighting / FOV / Crosshair",
})

VisualTab:Toggle({
    Title = "Fullbright 全亮",
    Desc = "照亮整个地图",
    Value = false,
    Callback = function(v)
        Config.Fullbright = v
        ToggleFullbright()
    end,
})

VisualTab:Slider({
    Title = "FOV 视角",
    Value = { Min = 40, Max = 120, Default = 70 },
    Callback = function(v)
        Config.FOVValue = v
        UpdateFOV()
    end,
})

VisualTab:Toggle({
    Title = "准星 Crosshair",
    Value = false,
    Callback = function(v)
        Config.CrosshairEnabled = v
        ToggleCrosshair()
    end,
})

VisualTab:Slider({
    Title = "时间 (ClockTime)",
    Value = { Min = 0, Max = 24, Default = 14 },
    Callback = function(v)
        Config.TimeOfDay = v
        Lighting.ClockTime = v
    end,
})

-- ===== 传送 Tab =====
TeleportTab:Paragraph({
    Title = "玩家传送",
    Desc = "Teleport to Players",
})

local PlayerDropdown
local SelectedPlayer = nil

local function refreshPlayerList()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(names, plr.Name)
        end
    end
    return names
end

PlayerDropdown = TeleportTab:Dropdown({
    Title = "选择玩家",
    Values = refreshPlayerList(),
    Value = nil,
    Callback = function(v)
        SelectedPlayer = v
    end,
})

TeleportTab:Button({
    Title = "传送到该玩家",
    Desc = "传送到选中的玩家旁边",
    Callback = function()
        if SelectedPlayer then
            local plr = Players:FindFirstChild(SelectedPlayer)
            if plr then
                TeleportToPlayer(plr)
                Utils.Notify("传送", "已传送到 " .. SelectedPlayer, 3)
            end
        else
            Utils.Notify("传送", "请先选择玩家", 3)
        end
    end,
})

TeleportTab:Button({
    Title = "刷新玩家列表",
    Callback = function()
        if PlayerDropdown and PlayerDropdown.Refresh then
            PlayerDropdown:Refresh(refreshPlayerList())
        end
        Utils.Notify("传送", "玩家列表已刷新", 3)
    end,
})

TeleportTab:Divider()

TeleportTab:Paragraph({
    Title = "其他传送",
    Desc = "Spawn / Click TP / Position Save",
})

TeleportTab:Button({
    Title = "传送到出生点",
    Callback = function()
        TeleportToSpawn()
        Utils.Notify("传送", "已传送到出生点", 3)
    end,
})

TeleportTab:Toggle({
    Title = "点击传送",
    Desc = "左键点击地面传送到该位置",
    Value = false,
    Callback = function(v)
        if v then EnableClickTP() else DisableClickTP() end
    end,
})

TeleportTab:Divider()

TeleportTab:Paragraph({
    Title = "位置保存/加载",
    Desc = "Save & Load Positions",
})

local PosNameInput = ""
TeleportTab:Input({
    Title = "位置名称",
    Placeholder = "输入名称...",
    Callback = function(v)
        PosNameInput = v
    end,
})

TeleportTab:Button({
    Title = "保存当前位置",
    Callback = function()
        if PosNameInput ~= "" then
            if SavePosition(PosNameInput) then
                Utils.Notify("传送", "已保存位置: " .. PosNameInput, 3)
            end
        end
    end,
})

TeleportTab:Button({
    Title = "加载保存的位置",
    Callback = function()
        if PosNameInput ~= "" then
            if LoadPosition(PosNameInput) then
                Utils.Notify("传送", "已加载位置: " .. PosNameInput, 3)
            else
                Utils.Notify("传送", "未找到该位置", 3)
            end
        end
    end,
})

-- ===== 工具 Tab =====
ToolsTab:Paragraph({
    Title = "Remote Spy",
    Desc = "实时远程事件监控 (基于日志分析)",
})

local spyActive = false
ToolsTab:Toggle({
    Title = "开启 Remote Spy",
    Desc = "监控所有 Incoming/Outgoing 远程事件",
    Value = false,
    Callback = function(v)
        spyActive = v
        if v then
            StartRemoteSpy()
            Utils.Notify("Remote Spy", "已开启监控", 3)
        else
            StopRemoteSpy()
            Utils.Notify("Remote Spy", "已关闭监控", 3)
        end
    end,
})

ToolsTab:Button({
    Title = "打印最近 10 条日志",
    Callback = function()
        local log = GetSpyLog()
        local count = math.min(10, #log)
        Utils.Notify("Remote Spy", string.format("共 %d 条记录, 显示最近 %d 条", #log, count), 5)
        for i = 1, count do
            local entry = log[i]
            print(string.format("[Spy] %s %s %s -> %s (%s)",
                entry.time, entry.direction, entry.type, entry.name, entry.args))
        end
    end,
})

ToolsTab:Button({
    Title = "测试 SetLookAngles 参数",
    Desc = "从日志中提取的参数格式",
    Callback = function()
        if SetLookAnglesEvent then
            Utils.Notify("Remote Spy", "SetLookAngles: (Player, pitch, yaw) - Incoming", 5)
            print("SetLookAngles 参数结构:")
            print("  Arg1: Player (Player 实例)")
            print("  Arg2: pitch (数字, 如 0.02)")
            print("  Arg3: yaw (数字, 如 -0.01)")
        else
            Utils.Notify("Remote Spy", "未找到 SetLookAngles", 3)
        end
        if StaminaSyncEvent then
            Utils.Notify("Remote Spy", "StaminaSync: (current, isSprint, max) - Incoming", 5)
            print("StaminaSync 参数结构:")
            print("  Arg1: currentStamina (数字, 如 100)")
            print("  Arg2: isSprinting (布尔, 如 false)")
            print("  Arg3: maxStamina (数字, 如 100)")
        end
    end,
})

ToolsTab:Divider()

ToolsTab:Paragraph({
    Title = "实用工具",
    Desc = "Anti-AFK / FPS / Server",
})

ToolsTab:Toggle({
    Title = "Anti-AFK 防挂机",
    Value = true,
    Callback = function(v)
        Config.AntiAFK = v
    end,
})

ToolsTab:Button({
    Title = "FPS Boost 性能优化",
    Desc = "降低画质提升帧率",
    Callback = function()
        FPSBoost()
    end,
})

ToolsTab:Button({
    Title = "Server Hop 换服",
    Desc = "传送到其他服务器",
    Callback = function()
        Utils.Notify("Server Hop", "正在搜索可用服务器...", 3)
        ServerHop()
    end,
})

ToolsTab:Button({
    Title = "Rejoin 重新加入",
    Callback = function()
        RejoinServer()
    end,
})

-- ===== 设置 Tab =====
SettingsTab:Paragraph({
    Title = "界面设置",
    Desc = "UI Theme & Keybind",
})

SettingsTab:Dropdown({
    Title = "主题",
    Values = { "Dark", "Light", "AMOLED" },
    Value = "Dark",
    Callback = function(v)
        WindUI:SetTheme(v)
    end,
})

SettingsTab:Toggle({
    Title = "窗口透明 (Acrylic)",
    Value = true,
    Callback = function(v)
        WindUI:ToggleAcrylic(v)
    end,
})

SettingsTab:Button({
    Title = "复制 Remote Spy 分析结果",
    Desc = "将日志分析数据复制到剪贴板",
    Callback = function()
        local analysis = [[
=== Remote Spy 日志分析结果 ===

1. SetLookAngles (RemoteEvent - Incoming)
   路径: game:GetService("ReplicatedStorage").SetLookAngles
   参数: (Player, pitch:number, yaw:number)
   功能: 服务器→客户端同步其他玩家的视角角度
   频率: 极高 (每秒数十次)
   
2. StaminaSync (RemoteEvent - Incoming)
   路径: game:GetService("ReplicatedStorage").FH_Remotes.StaminaSync
   参数: (currentStamina:number, isSprinting:boolean, maxStamina:number)
   功能: 服务器→客户端同步体力值
   示例: (100, false, 100)

=== 可利用点 ===
- SetLookAngles: 可 Hook 拦截, 阻止视角被同步
- StaminaSync: 可 Hook 修改, 强制体力满值
- FH_Remotes 文件夹可能包含更多远程事件
]]
        if setclipboard then
            setclipboard(analysis)
            Utils.Notify("设置", "已复制到剪贴板", 3)
        else
            print(analysis)
            Utils.Notify("设置", "不支持剪贴板, 已打印到控制台", 5)
        end
    end,
})

SettingsTab:Divider()

SettingsTab:Paragraph({
    Title = "关于",
    Desc = "FH Combat Suite",
    Content = "基于 Remote Spy 日志分析的 Roblox 客户端脚本\nUI: WindUI v1.6.64\n功能: Aimbot/ESP/Fly/Speed/Stamina Hack 等",
})

SettingsTab:Button({
    Title = "销毁界面",
    Desc = "关闭并清理所有功能",
    Callback = function()
        -- 关闭所有功能
        Config.AimbotEnabled = false
        Config.SilentAimEnabled = false
        Config.HitboxEnabled = false
        Config.ESPEnabled = false
        Config.SpeedEnabled = false
        Config.JumpEnabled = false
        Config.FlyEnabled = false
        Config.NoclipEnabled = false
        Config.InfiniteStamina = false
        Config.AntiLookSync = false
        Config.TriggerBotEnabled = false
        Config.Fullbright = false
        Config.CrosshairEnabled = false

        -- 清理
        if AimbotConnection then AimbotConnection:Disconnect() end
        if ESPConnection then ESPConnection:Disconnect() end
        if SpeedConnection then SpeedConnection:Disconnect() end
        if JumpConnection then JumpConnection:Disconnect() end
        if InfJumpConnection then InfJumpConnection:Disconnect() end
        if FlyConnection then FlyConnection:Disconnect() end
        if FlyInputConn1 then FlyInputConn1:Disconnect() end
        if FlyInputConn2 then FlyInputConn2:Disconnect() end
        if NoclipConnection then NoclipConnection:Disconnect() end
        if TriggerBotConnection then TriggerBotConnection:Disconnect() end
        if ClickTPConn then ClickTPConn:Disconnect() end
        StopRemoteSpy()
        DisableSilentAim()
        DisableInfiniteStamina()
        ToggleFullbright()
        UpdateHitboxes()
        ToggleESP()
        DisableClickTP()

        -- 销毁 UI
        WindUI:Destroy()
    end,
})

-- ============================================================
--  第七部分: 初始化
-- ============================================================

-- 创建 Aimbot FOV 圆圈
CreateAimbotFOV()

-- 启用 Anti-AFK
EnableAntiAFK()

-- 监听角色生成
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if Config.SpeedEnabled then UpdateSpeed() end
    if Config.JumpEnabled then UpdateJump() end
    if Config.FlyEnabled then StartFly() end
    if Config.NoclipEnabled then ToggleNoclip() end
end)

-- 监听玩家加入/离开 (更新 ESP)
Players.PlayerAdded:Connect(function() end)
Players.PlayerRemoving:Connect(function() end)

-- UI 切换快捷键
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Config.UIToggleKey then
        -- WindUI 内置的 UI 切换功能
    end
end)

-- 初始通知
task.wait(1)
Utils.Notify("FH Combat Suite", "脚本加载完成! 按 RightShift 切换界面", 6)
print("====================================")
print("  FH Combat Suite - 已加载")
print("  基于 Remote Spy 日志分析构建")
print("  UI: WindUI v1.6.64")
print("====================================")
print("  远程事件分析:")
print("  1. SetLookAngles (Incoming): Player, pitch, yaw")
print("  2. StaminaSync (Incoming): current, isSprint, max")
print("====================================")