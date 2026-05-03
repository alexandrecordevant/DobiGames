-- StarterPlayerScripts/RocketClient.client.lua
-- Saut + Rocket en main → propulsion verticale pure de 100 studs.
-- Pendant le vol : X/Z forcés à 0 à chaque frame via Heartbeat.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local BOOST_HEIGHT = 100
local COOLDOWN     = 1.5

local lastBoost  = 0
local boosting   = false
local boostConn  = nil

local ETATS_ATTERRISSAGE = {
    [Enum.HumanoidStateType.Landed]   = true,
    [Enum.HumanoidStateType.Running]  = true,
    [Enum.HumanoidStateType.Standing] = true,
    [Enum.HumanoidStateType.Swimming] = true,
}

local function setupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid")
    local hrp      = character:WaitForChild("HumanoidRootPart")

    local savedSpeed = 0

    local function endBoost()
        if not boosting then return end
        boosting = false
        humanoid.WalkSpeed = savedSpeed
        if boostConn then boostConn:Disconnect(); boostConn = nil end
    end

    humanoid.StateChanged:Connect(function(_, newState)
        if boosting and ETATS_ATTERRISSAGE[newState] then
            endBoost()
            return
        end

        if newState ~= Enum.HumanoidStateType.Jumping then return end
        if not character:FindFirstChild("Rocket") then return end

        local now = os.clock()
        if now - lastBoost < COOLDOWN then return end
        lastBoost = now
        boosting  = true

        savedSpeed         = humanoid.WalkSpeed
        humanoid.WalkSpeed = 0

        -- Impulsion verticale initiale
        local vitesse = math.sqrt(2 * workspace.Gravity * BOOST_HEIGHT)
        hrp.AssemblyLinearVelocity = Vector3.new(0, vitesse, 0)

        -- Boucle qui force X=0 Z=0 à chaque frame tant qu'on est en vol
        if boostConn then boostConn:Disconnect() end
        boostConn = RunService.Heartbeat:Connect(function()
            if not boosting then
                boostConn:Disconnect()
                boostConn = nil
                return
            end
            local vel = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
        end)
    end)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    boosting  = false
    if boostConn then boostConn:Disconnect(); boostConn = nil end
    setupCharacter(char)
end)
if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
