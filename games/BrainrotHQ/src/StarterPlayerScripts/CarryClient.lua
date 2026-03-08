-- CarryClient.lua
-- StarterPlayer/StarterPlayerScripts/CarryClient
-- Gère les effets visuels/physiques côté client du système carry brainrot :
--   - Animation "bras levés" (Motor6D ou AnimationTrack selon config)
--   - Réduction WalkSpeed / blocage JumpPower
--   - Reset complet à chaque respawn

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player     = Players.LocalPlayer
local character  = player.Character or player.CharacterAdded:Wait()
local humanoid   = character:WaitForChild("Humanoid")

-- ─── Config ──────────────────────────────────────────────────────────────────
local CarryConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CarryConfig"))

-- ─── RemoteEvents ─────────────────────────────────────────────────────────────
local eventsFolder  = ReplicatedStorage:WaitForChild("CarryEvents", 10)
if not eventsFolder then
    warn("[CarryClient] CarryEvents introuvable dans ReplicatedStorage.")
    return
end

local evCarryStarted   = eventsFolder:WaitForChild("CarryStarted",   10)
local evCarryStopped   = eventsFolder:WaitForChild("CarryStopped",   10)
local evRewardReceived = eventsFolder:WaitForChild("RewardReceived",  10)

-- ─── État local ───────────────────────────────────────────────────────────────
local isCarrying         = false
local steppedConnection  = nil   -- Connexion RunService.Stepped pour Motor6D
local savedWalkSpeed     = 16
local savedJumpPower     = 50    -- Sera mis à jour depuis le Humanoid réel au pickup

-- Motor6D : stockage des C0 originaux pour restauration.
-- motorOriginals[motorName] = CFrame
local motorOriginals     = {}

-- AnimationTrack : référence à la piste en cours.
local activeAnimTrack    = nil

-- ─── Helpers ─────────────────────────────────────────────────────────────────

-- Retourne le Humanoid du character courant, ou nil.
local function getHumanoid()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

-- Retourne le HumanoidRootPart du character courant, ou nil.
local function getHRP()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

-- ─── Stats carry ──────────────────────────────────────────────────────────────

-- Sauvegarde les stats actuelles et applique les valeurs carry.
local function applyCarryStats()
    local hum = getHumanoid()
    if not hum then return end

    savedWalkSpeed = hum.WalkSpeed
    savedJumpPower = hum.JumpPower

    hum.WalkSpeed  = CarryConfig.CARRY_WALKSPEED
    hum.JumpPower  = CarryConfig.CARRY_JUMPPOWER
end

-- Restaure les stats d'avant le carry.
local function restoreStats()
    local hum = getHumanoid()
    if not hum then return end
    hum.WalkSpeed = savedWalkSpeed
    hum.JumpPower = savedJumpPower
end

-- ─── Motor6D : bras levés ─────────────────────────────────────────────────────

-- Noms des Motor6D R15 à modifier pour lever les bras.
local ARM_MOTOR_NAMES = {
    "LeftShoulder",   -- R15 : Left Upper Arm → Upper Torso
    "RightShoulder",  -- R15 : Right Upper Arm → Upper Torso
    -- Fallback R6 (présents si le rig est R6) :
    "Left Shoulder",
    "Right Shoulder",
}

-- CFrame de rotation "bras levés" relatif au C0 d'origine.
-- Rotation de -π/2 sur Z pour le bras gauche, +π/2 pour le droit.
local ARM_ROTATIONS = {
    ["LeftShoulder"]  = CFrame.Angles(0, 0,  math.rad(90)),
    ["RightShoulder"] = CFrame.Angles(0, 0, -math.rad(90)),
    ["Left Shoulder"] = CFrame.Angles(0, 0,  math.rad(90)),
    ["Right Shoulder"]= CFrame.Angles(0, 0, -math.rad(90)),
}

-- Sauvegarde les C0 d'origine des Motor6D et commence la boucle Stepped.
local function startMotor6DArms()
    local char = player.Character
    if not char then return end

    -- Recherche des Motor6D dans tout le character (R15 : dans les parts, R6 : dans Torso).
    for _, motorName in ipairs(ARM_MOTOR_NAMES) do
        local motor = char:FindFirstChild(motorName, true) -- recursive
        if motor and motor:IsA("Motor6D") then
            -- Sauvegarder C0 d'origine seulement si pas déjà sauvegardé.
            if not motorOriginals[motorName] then
                motorOriginals[motorName] = motor.C0
            end
        end
    end

    -- Boucle Stepped : forcer le C0 des bras à chaque frame pour contrer
    -- l'animation par défaut du Humanoid.
    steppedConnection = RunService.Stepped:Connect(function()
        local c = player.Character
        if not c then return end

        for _, motorName in ipairs(ARM_MOTOR_NAMES) do
            local motor    = c:FindFirstChild(motorName, true)
            local rotation = ARM_ROTATIONS[motorName]
            local original = motorOriginals[motorName]

            if motor and motor:IsA("Motor6D") and rotation and original then
                -- Applique la rotation "bras levés" par-dessus le C0 d'origine.
                motor.C0 = original * rotation
            end
        end
    end)
end

-- Stoppe la boucle Stepped et restaure les C0 d'origine.
local function stopMotor6DArms()
    if steppedConnection then
        steppedConnection:Disconnect()
        steppedConnection = nil
    end

    local char = player.Character
    if char then
        for motorName, originalC0 in pairs(motorOriginals) do
            local motor = char:FindFirstChild(motorName, true)
            if motor and motor:IsA("Motor6D") then
                motor.C0 = originalC0
            end
        end
    end

    -- Vider la table pour le prochain carry.
    motorOriginals = {}
end

-- ─── AnimationTrack : animation uploadée ─────────────────────────────────────

-- Charge et joue l'animation en loop sur le Humanoid courant.
local function startAnimationTrack()
    local hum = getHumanoid()
    if not hum then return end

    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end

    local animInstance = Instance.new("Animation")
    animInstance.AnimationId = CarryConfig.ANIMATION_ID

    activeAnimTrack = animator:LoadAnimation(animInstance)
    activeAnimTrack.Priority = Enum.AnimationPriority.Action
    activeAnimTrack.Looped   = true
    activeAnimTrack:Play()
end

-- Arrête et détruit la piste d'animation en cours.
local function stopAnimationTrack()
    if activeAnimTrack then
        activeAnimTrack:Stop()
        activeAnimTrack:Destroy()
        activeAnimTrack = nil
    end
end

-- ─── Carry : démarrage / arrêt ────────────────────────────────────────────────

-- Déclenché par evCarryStarted (Server → Client).
local function onCarryStarted()
    if isCarrying then return end
    isCarrying = true

    applyCarryStats()

    if CarryConfig.USE_MOTOR6D then
        startMotor6DArms()
    else
        startAnimationTrack()
    end
end

-- Déclenché par evCarryStopped (Server → Client).
local function onCarryStopped()
    if not isCarrying then return end
    isCarrying = false

    restoreStats()

    if CarryConfig.USE_MOTOR6D then
        stopMotor6DArms()
    else
        stopAnimationTrack()
    end
end

-- ─── Reset complet de l'état local ───────────────────────────────────────────

-- Appelé à chaque CharacterAdded (respawn) pour éviter tout état bloqué.
local function resetLocalState()
    isCarrying = false

    -- Stopper proprement ce qui tourne encore.
    if steppedConnection then
        steppedConnection:Disconnect()
        steppedConnection = nil
    end
    if activeAnimTrack then
        activeAnimTrack:Stop()
        activeAnimTrack = nil
    end

    motorOriginals = {}

    -- Réinitialiser les références au nouveau character.
    character = player.Character or player.CharacterAdded:Wait()
    humanoid  = character:WaitForChild("Humanoid")

    -- Réinitialiser les valeurs sauvegardées avec celles du nouveau character.
    savedWalkSpeed = humanoid.WalkSpeed
    savedJumpPower = humanoid.JumpPower
end

-- ─── Connexions des events ────────────────────────────────────────────────────

evCarryStarted.OnClientEvent:Connect(onCarryStarted)
evCarryStopped.OnClientEvent:Connect(onCarryStopped)

-- evRewardReceived : actuellement un simple print.
-- TODO : brancher sur le futur système d'UI (notification flottante, son, etc.).
evRewardReceived:OnClientEvent:Connect(function(amount, brainrotName)
    print(string.format("[CarryClient] Récompense reçue : +%d %s pour avoir déposé '%s'.",
        amount, CarryConfig.CASH_ATTRIBUTE, brainrotName))
end)

-- ─── CharacterAdded ───────────────────────────────────────────────────────────

-- À chaque respawn, on remet tout à zéro pour éviter les états bloqués.
player.CharacterAdded:Connect(function(newCharacter)
    resetLocalState()
end)

print("[CarryClient] Système carry brainrot client initialisé.")
