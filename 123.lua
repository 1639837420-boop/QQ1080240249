local OrionLib = loadstring(game:HttpGet('https://pastebin.com/raw/xLRUSiKx'))()
local Window = OrionLib:MakeWindow({Name = "玩家击飞系统", HidePremium = false, SaveConfig = true,IntroText = "功能加载完毕", ConfigFolder = "KnockSystem"})
local Tab = Window:MakeTab({
    Name = "击飞功能",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local enableKnock = false

local function ThrowNearPlayers()
    local myChar = localPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end
    local myRoot = myChar.HumanoidRootPart
    local range = 15 --触发范围，靠近15格内就会被击飞

    for _,targetPlr in ipairs(Players:GetPlayers()) do
        if targetPlr ~= localPlayer then
            local tarChar = targetPlr.Character
            if tarChar and tarChar:FindFirstChild("HumanoidRootPart") and tarChar:FindFirstChild("Humanoid") then
                local tarRoot = tarChar.HumanoidRootPart
                local distance = (myRoot.Position - tarRoot.Position).Magnitude
                if distance <= range then
                    local force = Instance.new("BodyVelocity")
                    force.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    force.Velocity = (tarRoot.Position - myRoot.Position).Unit * 90 + Vector3.new(0,35,0)
                    force.Parent = tarRoot
                    task.delay(0.4,function()
                        force:Destroy()
                    end)
                end
            end
        end
    end
end

Tab:AddButton({
	Name = "开启靠近自动击飞",
	Callback = function()
        enableKnock = not enableKnock
	end
})

RunService.RenderStepped:Connect(function()
    if enableKnock then
        ThrowNearPlayers()
    end
end)
