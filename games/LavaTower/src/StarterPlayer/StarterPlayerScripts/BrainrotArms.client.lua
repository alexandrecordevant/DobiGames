-- BrainrotArms.client.lua
-- LocalScript -> StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local joueur = Players.LocalPlayer

local evtPorter  = ReplicatedStorage:WaitForChild("BrainrotPorter", 10)
local evtDeposer = ReplicatedStorage:WaitForChild("BrainrotDeposer", 10)

local brasLeves = false
local connexionBras = nil

local function leverLesBras()
    local character = joueur.Character or joueur.CharacterAdded:Wait()
    local humanoid  = character:WaitForChild("Humanoid")

    brasLeves = true

    if connexionBras then
        connexionBras:Disconnect()
        connexionBras = nil
    end

    connexionBras = RunService.Stepped:Connect(function()
        if not brasLeves then
            if connexionBras then
                connexionBras:Disconnect()
                connexionBras = nil
            end
            return
        end

        local char = joueur.Character
        if not char then return end

        -- R15
        local leftUpperArm  = char:FindFirstChild("LeftUpperArm")
        local rightUpperArm = char:FindFirstChild("RightUpperArm")

        if leftUpperArm and rightUpperArm then
            local lm = leftUpperArm:FindFirstChildOfClass("Motor6D")
            local rm = rightUpperArm:FindFirstChildOfClass("Motor6D")
            if lm then lm.C0 = CFrame.new(-1, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
                             * CFrame.Angles(math.rad(-170), 0, 0) end
            if rm then rm.C0 = CFrame.new(1, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
                             * CFrame.Angles(math.rad(-170), 0, 0) end
            return
        end

        -- R6
        local torso = char:FindFirstChild("Torso")
        if torso then
            local lm = torso:FindFirstChild("Left Shoulder")
            local rm = torso:FindFirstChild("Right Shoulder")
            if lm then lm.C0 = CFrame.new(-1.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
                             * CFrame.Angles(math.rad(-170), 0, 0) end
            if rm then rm.C0 = CFrame.new(1.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
                             * CFrame.Angles(math.rad(-170), 0, 0) end
        end
    end)
end

local function baisserLesBras()
    brasLeves = false
    if connexionBras then
        connexionBras:Disconnect()
        connexionBras = nil
    end
end

if evtPorter then
    evtPorter.OnClientEvent:Connect(function()
        leverLesBras()
    end)
end

if evtDeposer then
    evtDeposer.OnClientEvent:Connect(function()
        baisserLesBras()
    end)
end

joueur.CharacterAdded:Connect(function()
    baisserLesBras()
end)