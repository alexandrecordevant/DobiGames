-- ServerScriptService/Debug/ResetGraines.server.lua
-- Remet data.graines à zéro ET vide CarriedSeeds en session
-- Utile pour corriger les données corrompues (ex: graines stale)
-- SUPPRIMER après usage

local Players             = game:GetService("Players")
local DataStoreService    = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local DS = DataStoreService:GetDataStore("BrainRotIdleV1")

local function resetGrainesJoueur(player)
    -- 1. Reset DataStore
    local ok, data = pcall(function()
        return DS:GetAsync("player_" .. player.UserId)
    end)
    if not ok or not data then
        warn("[ResetGraines] GetAsync échoué pour " .. player.Name)
        return
    end

    local ancien = {}
    if data.graines then
        for r, v in pairs(data.graines) do ancien[r] = v end
    end

    data.graines           = { MYTHIC = 0, SECRET = 0 }
    data.grainesMigratedV2 = true  -- marquer comme migré

    local saveOk, err = pcall(function()
        DS:SetAsync("player_" .. player.UserId, data)
    end)

    if saveOk then
        print("[ResetGraines] ✅ DS mis à jour pour " .. player.Name
            .. " — avant : MYTHIC=" .. tostring(ancien.MYTHIC or 0)
            .. " SECRET=" .. tostring(ancien.SECRET or 0))
    else
        warn("[ResetGraines] ❌ SetAsync échoué : " .. tostring(err))
    end

    -- 2. Vider CarriedSeeds en session (sinon les graines stale restent jusqu'au prochain login)
    local carriedSeeds = player:FindFirstChild("CarriedSeeds")
    if carriedSeeds then
        local nbAvant = #carriedSeeds:GetChildren()
        for _, sv in ipairs(carriedSeeds:GetChildren()) do
            sv:Destroy()
        end
        print("[ResetGraines] ✅ CarriedSeeds vidé (" .. nbAvant .. " graine(s) supprimée(s)) pour " .. player.Name)
    else
        print("[ResetGraines] CarriedSeeds absent (déjà vide) pour " .. player.Name)
    end

    -- 3. Retirer les Tools de graine du Backpack
    local nbOutils = 0
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("IsSeed") then
                t:Destroy()
                nbOutils = nbOutils + 1
            end
        end
    end
    if player.Character then
        for _, t in ipairs(player.Character:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("IsSeed") then
                t:Destroy()
                nbOutils = nbOutils + 1
            end
        end
    end
    if nbOutils > 0 then
        print("[ResetGraines] ✅ " .. nbOutils .. " Seed Tool(s) supprimé(s) du Backpack pour " .. player.Name)
    end

    -- 4. Notifier le client pour mettre à jour l'UI graines
    local UpdateGraines = ReplicatedStorage:FindFirstChild("UpdateGraines")
    if UpdateGraines then
        pcall(function() UpdateGraines:FireClient(player, { MYTHIC = 0, SECRET = 0 }) end)
    end

    -- 5. Mettre à jour le HUD carry
    local CarrySystem = require(ServerScriptService.SharedLib.Server.CarrySystem)
    CarrySystem.EnvoyerCarryUpdate(player)

    print("[ResetGraines] ✅ Reset complet pour " .. player.Name)
end

task.wait(2) -- attendre DataStore Studio
for _, player in ipairs(Players:GetPlayers()) do
    resetGrainesJoueur(player)
end

Players.PlayerAdded:Connect(function(player)
    task.wait(4) -- attendre que Main.server.lua charge les données
    resetGrainesJoueur(player)
end)

print("[ResetGraines] Script actif")
