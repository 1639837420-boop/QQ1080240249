--来自李一一
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local hitEvent = game:GetService("ReplicatedStorage").Events.Hit
local bigDamage = 999999

local running = false
local attackInterval = 0.005

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoAttackGUI"
screenGui.Parent = game:GetService("CoreGui")
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 180, 0, 100)
panel.Position = UDim2.new(0, 10, 0.5, -50)
panel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 25)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Text = "NH HUB"
title.Font = Enum.Font.GothamBold
title.Parent = panel

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 70, 0, 45)
button.Position = UDim2.new(0.05, 0, 0.5, -10)
button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
button.BackgroundTransparency = 0.3
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.TextScaled = true
button.Text = "开启"
button.Font = Enum.Font.GothamBold
button.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = button

local intervalBox = Instance.new("TextBox")
intervalBox.Size = UDim2.new(0, 80, 0, 35)
intervalBox.Position = UDim2.new(0.55, 0, 0.5, -10)
intervalBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
intervalBox.BackgroundTransparency = 0.1
intervalBox.TextColor3 = Color3.fromRGB(255, 255, 255)
intervalBox.TextScaled = true
intervalBox.PlaceholderText = "间隔(秒)"
intervalBox.Text = "0.005"
intervalBox.Parent = panel

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 8)
boxCorner.Parent = intervalBox

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 1, -22)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextScaled = true
statusLabel.Text = "未开启"
statusLabel.Parent = panel

local UserInputService = game:GetService("UserInputService")
local dragging = false
local dragStartPos = nil
local panelStartPos = nil

local function updateDrag(input)
    if dragging then
        local delta = input.Position - dragStartPos
        panel.Position = UDim2.new(0, panelStartPos.X.Offset + delta.X, 0, panelStartPos.Y.Offset + delta.Y)
    end
end

local function onInputBegan(input, gameProcessed)
    if gameProcessed then return end
    local mousePos = input.Position
    local absPos = panel.AbsolutePosition
    local absSize = panel.AbsoluteSize
    if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and
       mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
        dragging = true
        dragStartPos = input.Position
        panelStartPos = panel.Position
    end
end

local function onInputEnded(input, gameProcessed)
    if dragging then
        dragging = false
        dragStartPos = nil
        panelStartPos = nil
    end
end

UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)
UserInputService.InputChanged:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        updateDrag(input)
    end
end)

button.MouseButton1Click:Connect(function()
    running = not running
    if running then
        button.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        button.Text = "关闭"
        statusLabel.Text = "攻击中（间隔: " .. attackInterval .. "s）"
        print("自动攻击已开启，间隔: " .. attackInterval .. " 秒")
    else
        button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        button.Text = "开启"
        statusLabel.Text = "未开启"
        print("自动攻击已关闭")
    end
end)

intervalBox.FocusLost:Connect(function()
    local val = tonumber(intervalBox.Text)
    if val and val > 0 then
        attackInterval = val
        intervalBox.Text = tostring(attackInterval)
        print("攻击间隔已设置为: " .. attackInterval .. " 秒")
        if running then
            statusLabel.Text = "攻击中（间隔: " .. attackInterval .. "s）"
        end
    else
        intervalBox.Text = tostring(attackInterval)
    end
end)

coroutine.wrap(function()
    while true do
        if running then
            pcall(function()
                hitEvent:FireServer(bigDamage)
            end)
        end
        task.wait(attackInterval)
    end
end)()