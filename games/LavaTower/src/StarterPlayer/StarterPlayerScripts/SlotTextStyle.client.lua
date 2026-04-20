-- StarterPlayer/StarterPlayerScripts/SlotTextStyle.client.lua
-- LavaTower — Style des textes sur les plateformes vertes de récupération
-- Rend les textes $amount et $offline : bleus, plus grands, centrés
-- Cache les textes des étages non débloqués ; les affiche quand ils le sont

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Logger            = require(game:GetService("ReplicatedStorage").SharedLib.Logger)

local player = Players.LocalPlayer

-- ───────────────────────────────────────────────
-- Style des textes
-- ───────────────────────────────────────────────
local COULEUR_TEXTE  = Color3.fromRGB(255, 255, 255)  -- blanc
local TAILLE_TEXTE   = 28                              -- bien visible sur la plateforme
local COULEUR_STROKE = Color3.fromRGB(0, 0, 0)         -- contour noir pour lisibilité

-- ───────────────────────────────────────────────
-- État local
-- ───────────────────────────────────────────────
local baseIndex = nil

-- ───────────────────────────────────────────────
-- Remotes
-- ───────────────────────────────────────────────
local AssignBase    = ReplicatedStorage:WaitForChild("AssignBase",    15)
local GetPlayerData = ReplicatedStorage:WaitForChild("GetPlayerData", 15)
local UpdateHUD     = ReplicatedStorage:WaitForChild("UpdateHUD",     15)

-- ───────────────────────────────────────────────
-- Utilitaires — trouver les TextLabels d'un spot
-- Structure : spot_X / Button / TouchPart / Text (SurfaceGui) → $amount, $offline
-- ───────────────────────────────────────────────
local function getTextLabels(spotModel)
    local buttonModel = spotModel:FindFirstChild("Button")
    if not buttonModel then return nil, nil end
    local tp = buttonModel:FindFirstChild("TouchPart")
    if not tp then tp = buttonModel:FindFirstChildWhichIsA("BasePart") end
    if not tp then return nil, nil end
    local surfGui = tp:FindFirstChild("Text")
    if not surfGui then return nil, nil end
    return surfGui:FindFirstChild("$amount"), surfGui:FindFirstChild("$offline")
end

-- Applique le style grand/centré avec stroke sur un TextLabel
local function appliquerStyle(lbl)
    if not lbl or not lbl:IsA("TextLabel") then return end
    pcall(function()
        lbl.TextColor3             = COULEUR_TEXTE
        lbl.TextSize               = TAILLE_TEXTE
        lbl.TextScaled             = false
        lbl.TextXAlignment         = Enum.TextXAlignment.Center
        lbl.TextYAlignment         = Enum.TextYAlignment.Center
        lbl.TextStrokeColor3       = COULEUR_STROKE
        lbl.TextStrokeTransparency = 0.3
        lbl.Font                   = Enum.Font.GothamBold
    end)
end

-- ───────────────────────────────────────────────
-- Mise à jour complète des visuels de la base
-- ───────────────────────────────────────────────
local function mettreAJourVisuels(progression)
    if not baseIndex then return end

    local bases = Workspace:FindFirstChild("Bases")
    if not bases then return end
    local base = bases:FindFirstChild("Base_" .. baseIndex)
    if not base then return end

    -- Cherche le conteneur Base (structure Shared/Base)
    local shared     = base:FindFirstChild("Shared")
    local baseFolder = shared and shared:FindFirstChild("Base") or base

    for floorNum = 1, 4 do
        -- Cherche le floor (nom exact ou fallback Floor_N)
        local floorObj = baseFolder:FindFirstChild("Floor_" .. floorNum)
        if not floorObj then
            -- Fallback : cherche dans Shared directement
            floorObj = base:FindFirstChild("Floor_" .. floorNum)
        end
        if not floorObj then continue end

        -- Le floor est-il débloqué ? (spot 1 du floor dans la progression)
        local cleEtage      = floorNum .. "_1"
        local etageDebloque = progression and progression[cleEtage] == true

        for spotNum = 1, 10 do
            local spotObj = floorObj:FindFirstChild("spot_" .. spotNum)
            if not spotObj then continue end

            -- Masquer le vieux SurfaceGui rouge sur l'outer TouchPart (géré par DropSystem)
            local outerTp = spotObj:FindFirstChild("TouchPart")
            if outerTp then
                local outerGui = outerTp:FindFirstChild("Text")
                if outerGui and outerGui:IsA("SurfaceGui") then
                    pcall(function() outerGui.Enabled = false end)
                end
            end

            -- Labels sur Button/TouchPart (gérés par IncomeSystem)
            local lblAmount, lblOffline = getTextLabels(spotObj)

            -- $amount : coins accumulés en attente — stylé bleu, visibilité gérée par IncomeSystem
            if lblAmount then
                appliquerStyle(lblAmount)
                if not etageDebloque then
                    pcall(function() lblAmount.Visible = false end)
                end
            end

            -- $offline : taux de revenu — stylé bleu
            if lblOffline then
                appliquerStyle(lblOffline)
                if not etageDebloque then
                    pcall(function() lblOffline.Visible = false end)
                end
            end
        end
    end
end

-- ───────────────────────────────────────────────
-- Réception du baseIndex assigné (depuis Main.server.lua)
-- ───────────────────────────────────────────────
if AssignBase then
    AssignBase.OnClientEvent:Connect(function(idx)
        baseIndex = idx

        -- Attendre que le Workspace soit peuplé
        task.wait(0.5)

        -- Récupérer la progression initiale via GetPlayerData
        if GetPlayerData then
            local ok, data = pcall(function()
                return GetPlayerData:InvokeServer()
            end)
            if ok and data then
                mettreAJourVisuels(data.progression)
            end
        end
    end)
end

-- ───────────────────────────────────────────────
-- Mise à jour à chaque UpdateHUD (rebirth, déblocage slot…)
-- ───────────────────────────────────────────────
if UpdateHUD then
    UpdateHUD.OnClientEvent:Connect(function(data)
        if baseIndex and data then
            mettreAJourVisuels(data.progression)
        end
    end)
end

Logger.info("HUD", "[SlotTextStyle] Pret")
