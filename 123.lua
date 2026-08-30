local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local DodgeEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Dodge")

-- 创建 GUI
local DodgeToggleGui = Instance.new("ScreenGui")
DodgeToggleGui.Name = "DodgeToggleGui"
DodgeToggleGui.Parent = CoreGui
DodgeToggleGui.ResetOnSpawn = false

local TextButton = Instance.new("TextButton")
TextButton.Size = UDim2.new(0, 120, 0, 50)
TextButton.Position = UDim2.new(0.5, -60, 0.7, 0)
TextButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TextButton.TextColor3 = Color3.new(1, 1, 1)
TextButton.Text = "闪避: 关"
TextButton.Parent = DodgeToggleGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = TextButton

-- 拖拽逻辑
local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    TextButton.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end

TextButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = TextButton.Position
    end
end)

TextButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

TextButton.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- 闪避功能：循环发送 A-Z
local function startDodge()
    TextButton.Text = "闪避: 开"
    TextButton.BackgroundColor3 = Color3.fromRGB(0, 170,