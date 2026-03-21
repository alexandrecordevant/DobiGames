-- PadTP.lua
-- Script -> ServerScriptService
-- DÉSACTIVÉ : TourCycle gère le TP en masse à la fin des 30 secondes.
-- Ce script causait un TP immédiat qui vidait le pad avant la fin du countdown.
return

local Players       = game:GetService("Players")
local pad           = workspace:WaitForChild("TourCommune"):WaitForChild("Triggers"):WaitForChild("StartZone")
local interiorSpawn = workspace:WaitForChild("TourCommune"):WaitForChild("InterriorSpawn")

local COOLDOWN = 1
local lastTp   = {}

pad.Touched:Connect(function(hit)
    local character = hit.Parent
    local player    = Players:GetPlayerFromCharacter(character)
    if not player then return end

    -- Bloqué si Locked
    if pad:GetAttribute("Locked") == true then return end

    -- Anti-spam
    local now = os.clock()
    if lastTp[player] and (now - lastTp[player]) < COOLDOWN then return end
    lastTp[player] = now

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = interiorSpawn.CFrame + Vector3.new(0, 3, 0)
        print("[PadTP] " .. player.Name .. " teleporte manuellement")
    end
end)

Players.PlayerRemoving:Connect(function(player)
    lastTp[player] = nil
end)