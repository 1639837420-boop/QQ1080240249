local p=game.Players.LocalPlayer
p.CharacterAdded:Connect(function(c)
    local h=c:WaitForChild("Humanoid")
    if h and h.Health>0 then h.Health=0 end
end)
local c=p.Character
if c then
    local h=c:FindFirstChild("Humanoid")
    if h and h.Health>0 then h.Health=0 end
end