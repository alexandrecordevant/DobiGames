-- TEST UNIQUEMENT — Supprimer avant publish
-- Script (pas ModuleScript) dans ServerScriptService
-- Lance en Play Solo pour voir les 6 bases se cloner sur les slots

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local template    = ReplicatedStorage:WaitForChild("BaseTemplate", 10)
local slotsFolder = workspace:WaitForChild("Slots", 10)

-- Vérifications préalables
if not template then
    error("❌ BaseTemplate introuvable dans ReplicatedStorage !")
end
if not slotsFolder then
    error("❌ Dossier 'Slots' introuvable dans Workspace !")
end

print("--- BaseTemplate ClassName : " .. template.ClassName .. " ---")
print("--- SpawnArea trouvée : " .. tostring(template:FindFirstChild("SpawnArea", true) ~= nil) .. " ---")

-- Laisse le serveur finir de charger
task.wait(0.5)

for i = 1, 6 do
    local slot = slotsFolder:FindFirstChild("Slot_" .. i)
    if not slot then
        warn("❌ Slot_" .. i .. " introuvable dans Workspace.Slots")
        continue
    end

    local base = template:Clone()
    base.Name  = "Base_TEST_" .. i

    -- PivotTo ne fonctionne que sur les Models
    if base:IsA("Model") then
        base:PivotTo(slot.CFrame)
        print("✅ Base_TEST_" .. i .. " clonée (Model) sur " .. slot.Name .. " — CFrame : " .. tostring(slot.CFrame))
    else
        -- Fallback Folder : déplacer chaque BasePart par rapport à l'origine du slot
        warn("⚠️  BaseTemplate est un " .. base.ClassName .. " — utilise le fallback. Convertis-le en Model dans Studio.")
        for _, part in ipairs(base:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CFrame = slot.CFrame * part.CFrame
            end
        end
        print("✅ Base_TEST_" .. i .. " clonée (Folder fallback) sur " .. slot.Name)
    end

    base.Parent = workspace

    -- Vérifier que SpawnArea est bien présente
    local spawnArea = base:FindFirstChild("SpawnArea", true)
    if spawnArea then
        print("   → SpawnArea trouvée : " .. spawnArea:GetFullName())
    else
        warn("   → ⚠️  SpawnArea ABSENTE dans Base_TEST_" .. i .. " !")
    end
end

print("--- Test terminé ---")
