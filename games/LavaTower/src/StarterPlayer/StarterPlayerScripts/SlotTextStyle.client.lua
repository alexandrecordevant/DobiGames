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
-- Cherche les labels dans un SurfaceGui : $amount/$offline par nom, sinon premier TextLabel
local function searchLabelsInSurfGui(sg)
    if not sg or not sg:IsA("SurfaceGui") then return nil, nil end
    local a = sg:FindFirstChild("$amount")
    local o = sg:FindFirstChild("$offline")
    if a or o then return a, o end
    local tl = sg:FindFirstChildOfClass("TextLabel")
    return tl, nil
end

-- Cherche les labels du spot : Button children → outer TouchPart → tous descendants
local function getTextLabels(spotModel)
    -- 1. Tous les BaseParts enfants de Button
    local buttonModel = spotModel:FindFirstChild("Button")
    if buttonModel then
        for _, child in ipairs(buttonModel:GetChildren()) do
            if child:IsA("BasePart") then
                for _, sg in ipairs(child:GetChildren()) do
                    if sg:IsA("SurfaceGui") then
                        local a, o = searchLabelsInSurfGui(sg)
                        if a or o then return a, o end
                    end
                end
            end
        end
    end
    -- 2. Outer TouchPart
    local outerTp = spotModel:FindFirstChild("TouchPart")
    if outerTp then
        for _, sg in ipairs(outerTp:GetChildren()) do
            if sg:IsA("SurfaceGui") then
                local a, o = searchLabelsInSurfGui(sg)
                if a or o then return a, o end
            end
        end
    end
    -- 3. Tout descendant SurfaceGui dans le spot
    for _, desc in ipairs(spotModel:GetDescendants()) do
        if desc:IsA("SurfaceGui") then
            local a, o = searchLabelsInSurfGui(desc)
            if a or o then return a, o end
        end
    end
    return nil, nil
end

-- Applique le style grand/centré avec stroke sur un TextLabel
-- Active aussi le SurfaceGui parent s'il était désactivé
local function appliquerStyle(lbl)
    if not lbl or not lbl:IsA("TextLabel") then return end
    pcall(function()
        local sg = lbl.Parent
        if sg and sg:IsA("SurfaceGui") and not sg.Enabled then
            sg.Enabled = true
        end
        lbl.TextColor3             = COULEUR_TEXTE
        lbl.TextTransparency       = 0
        lbl.TextSize               = TAILLE_TEXTE
        lbl.TextScaled             = false
        lbl.TextXAlignment         = Enum.TextXAlignment.Center
        lbl.TextYAlignment         = Enum.TextYAlignment.Center
        lbl.TextStrokeColor3       = COULEUR_STROKE
        lbl.TextStrokeTransparency = 0.3
        lbl.Font                   = Enum.Font.GothamBold
        lbl.BackgroundTransparency = 1
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

            -- Labels : Button/TouchPart/Text en priorité, outer TouchPart/Text en fallback
            local lblAmount, lblOffline = getTextLabels(spotObj)

            -- Désactiver le SurfaceGui de l'outer TouchPart seulement si les labels actifs
            -- sont dans le Button interne — sinon l'outer est le seul affichage, ne pas le cacher
            local outerTp = spotObj:FindFirstChild("TouchPart")
            if outerTp then
                local outerGui = outerTp:FindFirstChild("Text")
                if outerGui and outerGui:IsA("SurfaceGui") then
                    -- Désactiver l'outer seulement si les labels actifs sont dans le Button
                    local hasInnerLabels = false
                    local bm = spotObj:FindFirstChild("Button")
                    if bm then
                        for _, child in ipairs(bm:GetChildren()) do
                            if child:IsA("BasePart") then
                                for _, sg in ipairs(child:GetChildren()) do
                                    if sg:IsA("SurfaceGui") then
                                        local a2, o2 = searchLabelsInSurfGui(sg)
                                        if a2 or o2 then
                                            hasInnerLabels = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if hasInnerLabels then
                        pcall(function() outerGui.Enabled = false end)
                    end
                end
            end

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
