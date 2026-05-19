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
local Logger = require(script.Parent.Parent.Logger)

-- ============================================================
-- État interne
-- ============================================================
local savedAmbient          = nil
local savedColorShift       = nil
local bloomEffect           = nil
local highlights            = {}   -- Highlight instances créées sur les BR
local connDescendant        = nil  -- connexion DescendantAdded pour les nouveaux BR
local couleurActive         = nil  -- couleur golden en cours
local savedChampignons      = {}   -- { [BasePart] = { color, material } }
local savedChampignonLights = {}   -- { PointLight, ... }

-- ============================================================
-- Utilitaires
-- ============================================================
local function notifierTous(message)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireAllClients("INFO", message) end) end
end

-- Applique un Highlight doré sur un BR Model
-- Utilise l'attribut Rarete (plus robuste que le nom qui varie selon l'origine)
local function highlighterBR(obj, couleur)
    if not obj:IsA("Model") then return end
    if not obj:GetAttribute("Rarete") then return end
    if obj:FindFirstChild("GoldenHighlight") then return end
    local ok, hl = pcall(function()
        local h = Instance.new("Highlight")
        h.Name                = "GoldenHighlight"
        h.FillColor           = couleur or Color3.fromRGB(255, 215, 0)
        h.FillTransparency    = 0.4
        h.OutlineColor        = Color3.fromRGB(255, 200, 0)
        h.OutlineTransparency = 0
        h.Adornee             = obj
        h.Parent              = obj
        return h
    end)
    if ok and hl then table.insert(highlights, hl) end
end

-- Ajoute un Highlight doré sur tous les BR actifs + écoute les nouveaux
local function appliquerHighlightsBR(couleurGolden)
    couleurActive = couleurGolden
    -- BR déjà présents
    for _, obj in ipairs(Workspace:GetDescendants()) do
        highlighterBR(obj, couleurActive)
    end
    -- BR qui spawent ou sont déposés pendant l'event
    connDescendant = Workspace.DescendantAdded:Connect(function(obj)
        if not obj:IsA("Model") then return end
        -- Petit délai pour laisser le BR finir son init et recevoir ses attributs
        task.delay(0.3, function()
            if obj and obj.Parent and obj:GetAttribute("Rarete") then
                highlighterBR(obj, couleurActive)
            end
        end)
    end)
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
        if obj:IsA("Highlight") and obj.Name == "GoldenHighlight" then
            pcall(function() obj:Destroy() end)
        end
    end
end

-- ============================================================
-- Champignons : Neon doré pendant Golden Event
-- ============================================================
local function appliquerChampignons()
    savedChampignons      = {}
    savedChampignonLights = {}
    local folder = Workspace:FindFirstChild("Deco")
    if folder then folder = folder:FindFirstChild("Champignons") end
    if not folder then return end
    for _, model in ipairs(folder:GetChildren()) do
        local lightAdded = false
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                local r, g, b = part.Color.R * 255, part.Color.G * 255, part.Color.B * 255
                if g > 150 and b > 100 then  -- tiges beiges + points blancs, exclut rouge
                    savedChampignons[part] = { color = part.Color, material = part.Material }
                    part.Material = Enum.Material.Neon
                    part.Color    = Color3.fromRGB(255, 215, 0)
                    if not lightAdded then
                        local pl = Instance.new("PointLight")
                        pl.Brightness = 2 ; pl.Range = 16
                        pl.Color      = Color3.fromRGB(255, 200, 50)
                        pl.Parent     = part
                        table.insert(savedChampignonLights, pl)
                        lightAdded = true
                    end
                end
            end
        end
    end
end

local function restaurerChampignons()
    for _, light in ipairs(savedChampignonLights) do
        if light and light.Parent then light:Destroy() end
    end
    savedChampignonLights = {}
    for part, saved in pairs(savedChampignons) do
        if part and part.Parent then
            part.Material = saved.material
            part.Color    = saved.color
        end
    end
    savedChampignons = {}
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

    -- Highlights sur les BR actifs + champignons dorés
    task.delay(0.5, function()
        appliquerHighlightsBR(config.couleurGolden)
    end)
    task.delay(1, appliquerChampignons)

    -- Booster les multiplicateurs de gains
    local IS = getIncomeSystem()
    local CS = getCollectSystem()
    local mult = config.multiplicateur or 5
    if IS and IS.SetEventMultiplier then pcall(IS.SetEventMultiplier, mult) end
    if CS and CS.SetEventMultiplier then pcall(CS.SetEventMultiplier, mult) end

    Logger.info("Event", "▶ Golden Event démarré (%ds) — ×%s", (config.duree or 60), tostring(mult))
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

    -- Arrêter l'écoute des nouveaux BR
    if connDescendant then
        connDescendant:Disconnect()
        connDescendant = nil
    end
    couleurActive = nil
    restaurerChampignons()

    -- Supprimer les Highlights
    supprimerHighlights()

    -- Remettre les multiplicateurs à 1
    local IS = getIncomeSystem()
    local CS = getCollectSystem()
    if IS and IS.SetEventMultiplier then pcall(IS.SetEventMultiplier, 1) end
    if CS and CS.SetEventMultiplier then pcall(CS.SetEventMultiplier, 1) end

    Logger.info("Event", "■ Golden Event terminé")
end

return EventGolden
