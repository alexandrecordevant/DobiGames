-- ServerScriptService/Common/Events/EventGolden.lua
-- BrainRotFarm — Golden Event
-- Tout devient doré, tous les gains ×5 pendant 60s

local EventGolden = {}
EventGolden.NOM          = "Golden"
EventGolden.DUREE_DEFAUT = 60

-- ============================================================
-- Services
-- ============================================================
local TweenService        = game:GetService("TweenService")
local Lighting            = game:GetService("Lighting")
local Workspace           = game:GetService("Workspace")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- Chargement différé des systèmes gameplay
-- ============================================================
local _IncomeSystem = nil
local function getIncomeSystem()
    if not _IncomeSystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SharedLib.Server.IncomeSystem)
        if ok and m then _IncomeSystem = m end
    end
    return _IncomeSystem
end

local _CollectSystem = nil
local function getCollectSystem()
    if not _CollectSystem then
        local ok, m = pcall(require, ServerScriptService.SharedLib.Shared.CollectSystem)
        if ok and m then _CollectSystem = m end
    end
    return _CollectSystem
end

-- ============================================================
-- État interne
-- ============================================================
local savedAmbient     = nil
local savedColorShift  = nil
local bloomEffect      = nil
local highlights       = {}    -- Highlight instances créées sur les BR

-- ============================================================
-- Utilitaires
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

-- Ajoute un Highlight doré sur tous les BR actifs du Workspace
local function appliquerHighlightsBR(couleurGolden)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:match("^BR_") then
            -- Vérifier qu'il n'a pas déjà un highlight golden
            if not obj:FindFirstChild("GoldenHighlight") then
                local ok, hl = pcall(function()
                    local h = Instance.new("Highlight")
                    h.Name                = "GoldenHighlight"
                    h.FillColor           = couleurGolden or Color3.fromRGB(255, 215, 0)
                    h.FillTransparency    = 0.4
                    h.OutlineColor        = Color3.fromRGB(255, 200, 0)
                    h.OutlineTransparency = 0
                    h.Adornee             = obj
                    h.Parent              = obj
                    return h
                end)
                if ok and hl then
                    table.insert(highlights, hl)
                end
            end
        end
    end
end

-- Supprime tous les Highlights golden
local function supprimerHighlights()
    for _, hl in ipairs(highlights) do
        if hl and hl.Parent then
            pcall(function() hl:Destroy() end)
        end
    end
    highlights = {}
    -- Nettoyer aussi tout résidu dans le workspace (sécurité)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "GoldenHighlight" then
            pcall(function() obj:Destroy() end)
        end
    end
end

-- ============================================================
-- API
-- ============================================================

function EventGolden.Demarrer(config)
    highlights    = {}

    -- Sauvegarder l'état Lighting
    savedAmbient    = Lighting.Ambient
    savedColorShift = pcall(function() return Lighting.ColorShift_Top end)
        and Lighting.ColorShift_Top or Color3.new(0, 0, 0)

    -- Notifier + EventStarted
    notifierTous(config.message)
    local es = ReplicatedStorage:FindFirstChild("EventStarted")
    if es then pcall(function() es:FireAllClients("Golden", config.duree) end) end

    -- Flash doré côté client
    local reGolden = ReplicatedStorage:FindFirstChild("GoldenStart")
    if reGolden then pcall(function() reGolden:FireAllClients() end) end

    -- Ambient doré (TweenService 2s)
    local infoGolden = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    pcall(function()
        TweenService:Create(Lighting, infoGolden, {
            Ambient = config.ambientGolden or Color3.fromRGB(255, 200, 50),
        }):Play()
    end)

    -- ColorShift doré
    pcall(function()
        Lighting.ColorShift_Top = Color3.fromRGB(255, 200, 0)
    end)

    -- BloomEffect
    local existingBloom = Lighting:FindFirstChild("GoldenBloom")
    if existingBloom then existingBloom:Destroy() end

    local ok, bloom = pcall(function()
        local b = Instance.new("BloomEffect")
        b.Name      = "GoldenBloom"
        b.Intensity = 0.5
        b.Size      = 24
        b.Threshold = 0.95
        b.Parent    = Lighting
        return b
    end)
    if ok and bloom then bloomEffect = bloom end

    -- Highlights sur les BR actifs (après un court délai pour laisser le tween démarrer)
    task.delay(0.5, function()
        appliquerHighlightsBR(config.couleurGolden)
    end)

    -- Booster les multiplicateurs de gains
    local IS = getIncomeSystem()
    local CS = getCollectSystem()
    local mult = config.multiplicateur or 5
    if IS and IS.SetEventMultiplier then pcall(IS.SetEventMultiplier, mult) end
    if CS and CS.SetEventMultiplier then pcall(CS.SetEventMultiplier, mult) end

    print("[EventGolden] ▶ Golden Event démarré (" .. (config.duree or 60) .. "s) — ×" .. mult)
end

function EventGolden.Terminer()
    -- Remettre l'ambient original (TweenService 3s)
    if savedAmbient then
        local infoRestore = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        pcall(function()
            TweenService:Create(Lighting, infoRestore, { Ambient = savedAmbient }):Play()
        end)
    end

    -- Remettre ColorShift
    pcall(function()
        Lighting.ColorShift_Top = savedColorShift or Color3.new(0, 0, 0)
    end)

    -- Supprimer le BloomEffect
    if bloomEffect and bloomEffect.Parent then
        pcall(function() bloomEffect:Destroy() end)
        bloomEffect = nil
    end
    -- Sécurité : supprimer tout GoldenBloom résiduel
    local residuel = Lighting:FindFirstChild("GoldenBloom")
    if residuel then pcall(function() residuel:Destroy() end) end

    -- Supprimer les Highlights
    supprimerHighlights()

    -- Remettre les multiplicateurs à 1
    local IS = getIncomeSystem()
    local CS = getCollectSystem()
    if IS and IS.SetEventMultiplier then pcall(IS.SetEventMultiplier, 1) end
    if CS and CS.SetEventMultiplier then pcall(CS.SetEventMultiplier, 1) end

    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", "✨ The Golden Event is over. See you soon!") end) end

    print("[EventGolden] ■ Golden Event terminé")
end

return EventGolden
