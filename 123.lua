local player = game.Players.LocalPlayer

if getgenv().InstantRespawn then return end
getgenv().InstantRespawn = true

local function killNow(character)
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid.Health = 0
    end
end

player.CharacterAdded:Connect(function(character)
    if not getgenv().InstantRespawn then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        killNow(character)
    else
        task.spawn(function()
            local start = os.clock()
            while not humanoid and os.clock() - start < 0.1 do
                humanoid = character:FindFirstChildOfClass("Humanoid")
                task.wait()
            end
            if humanoid and humanoid.Health > 0 then
                humanoid.Health = 0
            end
        end)
    end
end)

if player.Character then
    killNow(player.Character)
end