-- ServerScriptService/Common/FlowerPotSystem.lua
-- DobiGames — Pots de fleurs : planter MYTHIC/SECRET, 4 stages, BR Mutant, Daily Seed
-- Pot 1 actif par défaut, pots 2-4 débloqués coins/R$

local FlowerPotSystem = {}

-- ============================================================
-- Services
-- ============================================================
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage       = game:GetService("ServerStorage")
local Workspace           = game:GetService("Workspace")
local TweenService        = game:GetService("TweenService")
local MarketplaceService  = game:GetService("MarketplaceService")

-- ============================================================
-- Config
-- ============================================================
local Config   = require(ReplicatedStorage.Specialized.GameConfig)
local FPConfig = Config.FlowerPotConfig

-- ============================================================
-- Lazy loaders (éviter dépendances circulaires)
-- ============================================================
local _AssignationSystem = nil
local function getAssignation()
    if not _AssignationSystem then
        local ok, m = pcall(require,
            ReplicatedStorage.SharedLib.Server.AssignationSystem)
        if ok then _AssignationSystem = m end
    end
    return _AssignationSystem
end

local _CarrySystem = nil
local function getCarry()
    if not _CarrySystem then
        local ok, m = pcall(require,
            ReplicatedStorage.SharedLib.Server.CarrySystem)
        if ok then _CarrySystem = m end
    end
    return _CarrySystem
end

-- Chargement différé SeedInventory
local _SeedInventory = nil
local function getSeedInventory()
    if not _SeedInventory then
        local ok, m = pcall(require,
            ServerScriptService.Specialized.SeedInventory)
        if ok then _SeedInventory = m end
    end
    return _SeedInventory
end

-- Chargement différé MutantGenerator
local _MutantGenerator = nil
local function getMutantGenerator()
    if not _MutantGenerator then
        local ok, m = pcall(require,
            ServerScriptService.Specialized.MutantGenerator)
        if ok then _MutantGenerator = m end
    end
    return _MutantGenerator
end

-- ============================================================
-- RemoteEvents (créés dans InitServeur)
-- ============================================================
local NotifEvent    = nil
local UpdateHUD     = nil
local OuvrirPot     = nil
local PotUpdate     = nil
local DebloquerPotEv = nil
local InstantGrowEv  = nil
local ClaimDailySeedEv = nil

local function getRemote(nom)
    local existing = ReplicatedStorage:FindFirstChild(nom)
    if existing then return existing end
    local re = Instance.new("RemoteEvent")
    re.Name   = nom
    re.Parent = ReplicatedStorage
    return re
end

-- ============================================================
-- Source de données (définie par Main via SetGetData)
-- ============================================================
local _getData = nil
function FlowerPotSystem.SetGetData(fn) _getData = fn end

local function GetData(player)
    return _getData and _getData(player)
end

-- ============================================================
-- Threads de croissance actifs [userId_potIndex]
-- ============================================================
local _threads = {}

-- ============================================================
-- FadeIn — anime la transparence de toutes les parts vers 0
-- ============================================================
local function FadeIn(model, duree)
    local TS = game:GetService("TweenService")
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            local cible = part:GetAttribute("OriginalTransparency") or 0
            TS:Create(part,
                TweenInfo.new(duree, Enum.EasingStyle.Quad),
                { Transparency = cible }
            ):Play()
        end
    end
end

-- ============================================================
-- NettoyerModeleVisuel — supprime parasites visuels d'un clone BR
-- (VfxInstance, FakeRootPart, constraints → cubes gris)
-- Marque OriginalTransparency=1 sur les parts à garder invisibles
-- afin que FadeIn les laisse à 1 lors de l'animation
-- ============================================================
local function NettoyerModeleVisuel(clone)
    local toDetruire = {}
    for _, descendant in ipairs(clone:GetDescendants()) do
        -- VfxInstance : cause principale des cubes gris
        if descendant.Name == "VfxInstance" then
            table.insert(toDetruire, descendant)

        -- FakeRootPart : rendre invisible + marquer pour FadeIn
        elseif descendant.Name == "FakeRootPart" and descendant:IsA("BasePart") then
            pcall(function()
                descendant.Transparency = 1
                descendant.CanCollide   = false
                descendant.CanTouch     = false
                descendant.Anchored     = true
                descendant.Size         = Vector3.new(0.01, 0.01, 0.01)
                descendant:SetAttribute("OriginalTransparency", 1)
            end)

        -- Contraintes physiques résiduelles
        elseif descendant:IsA("WeldConstraint")
            or descendant:IsA("Weld")
            or descendant:IsA("Motor6D")
            or descendant:IsA("BodyForce")
            or descendant:IsA("BodyVelocity")
            or descendant:IsA("BodyGyro") then
            table.insert(toDetruire, descendant)

        -- Parts sans mesh déjà transparentes → garder invisibles (FadeIn les laissera à 1)
        elseif descendant:IsA("BasePart") then
            local hasMesh = descendant:FindFirstChildOfClass("SpecialMesh")
                         or descendant:FindFirstChildOfClass("MeshPart")
                         or descendant:IsA("MeshPart")
                         or descendant:IsA("UnionOperation")
            if not hasMesh and descendant.Transparency >= 0.9 then
                pcall(function()
                    descendant.Transparency = 1
                    descendant:SetAttribute("OriginalTransparency", 1)
                end)
            end
            pcall(function()
                descendant.Anchored   = true
                descendant.CanCollide = false
                descendant.CanTouch   = false
            end)
        end
    end
    -- Détruire hors boucle (évite de modifier la liste pendant l'itération)
    for _, v in ipairs(toDetruire) do
        pcall(function() v:Destroy() end)
    end
end

-- ============================================================
-- NettoyerPot — supprime les visuels plante du pot
-- ============================================================
local function NettoyerPot(baseIndex, potIndex)
    pcall(function()
        local base     = Workspace:FindFirstChild("Bases")
                      and Workspace.Bases:FindFirstChild("Base_" .. baseIndex)
        local potModel = base and base:FindFirstChild("FlowerPot_" .. potIndex)
        if not potModel then return end

        local existingPlant = potModel:FindFirstChild("PlantModel")
        local existingBR    = potModel:FindFirstChild("GrowthModel")
        if existingPlant then existingPlant:Destroy() end
        if existingBR    then existingBR:Destroy()    end
    end)
end

-- ============================================================
-- FallbackPlante — visuels simples quand PlantModels absent
-- ============================================================
local function FallbackPlante(potModel, basePos, stage)
    local model = Instance.new("Model")
    model.Name = "PlantModel"

    -- Hauteur et couleur selon stage
    local hauteurs = { [0]=0.25, [1]=0.5, [2]=1.0, [3]=1.8, [4]=3.0 }
    local couleurs = {
        [0] = Color3.fromRGB(139, 90,  43),   -- brun   (graine)
        [1] = Color3.fromRGB(120, 220, 60),   -- vert clair (pousse)
        [2] = Color3.fromRGB(80,  190, 30),   -- vert
        [3] = Color3.fromRGB(50,  160, 20),   -- vert foncé
        [4] = Color3.fromRGB(255, 215, 0),    -- or (mûr)
    }

    local h = hauteurs[stage] or 0.5
    local c = couleurs[stage] or Color3.fromRGB(80, 190, 30)

    -- Tige
    local tige = Instance.new("Part", model)
    tige.Size         = Vector3.new(0.25, h, 0.25)
    tige.Position     = basePos + Vector3.new(0, h / 2, 0)
    tige.Anchored     = true
    tige.CanCollide   = false
    tige.Color        = c
    tige.Material     = Enum.Material.SmoothPlastic
    tige.Transparency = 1

    -- Tête ronde (stages 1-4)
    if stage > 0 then
        local tete = Instance.new("Part", model)
        tete.Size         = Vector3.new(h * 0.7, h * 0.5, h * 0.7)
        tete.Position     = basePos + Vector3.new(0, h + h * 0.25, 0)
        tete.Anchored     = true
        tete.CanCollide   = false
        tete.Color        = c
        tete.Material     = Enum.Material.SmoothPlastic
        tete.Transparency = 1
        Instance.new("SpecialMesh", tete).MeshType = Enum.MeshType.Sphere

        TweenService:Create(tete,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad),
            { Transparency = 0 }):Play()
    end

    model.Parent = potModel

    TweenService:Create(tige,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad),
        { Transparency = 0 }):Play()
end

-- ============================================================
-- GererVisuelsPlante — Graine (stage 0) ou Tree scalé (stages 1-4)
-- ServerStorage.PlantModels.Graine → Part + SpecialMesh
-- ServerStorage.PlantModels.Tree   → Model (~86 parts)
-- Si PlantModels absent → FallbackPlante (parts colorées)
-- ============================================================
local function GererVisuelsPlante(baseIndex, potIndex, stage)
    pcall(function()
        local base     = Workspace:FindFirstChild("Bases")
                      and Workspace.Bases:FindFirstChild("Base_" .. baseIndex)
        local potModel = base and base:FindFirstChild("FlowerPot_" .. potIndex)
        if not potModel then return end

        local potPart = potModel:IsA("BasePart") and potModel
                     or potModel:FindFirstChildWhichIsA("BasePart")
        if not potPart then return end

        local basePos = potPart.Position + Vector3.new(0, potPart.Size.Y / 2, 0)

        -- Fallback si PlantModels absent
        local plantModels = ServerStorage:FindFirstChild("PlantModels")
        if not plantModels then
            FallbackPlante(potModel, basePos, stage or 0)
            return
        end

        if stage == 0 then
            -- Graine : fade in depuis l'invisible
            local graineSrc = plantModels:FindFirstChild("Graine")
            if not graineSrc then
                FallbackPlante(potModel, basePos, 0)
                return
            end
            local clone = graineSrc:Clone()

            if clone:IsA("Model") then
                local root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
                if root then clone:SetPrimaryPartCFrame(CFrame.new(basePos)) end
                for _, p in ipairs(clone:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.Transparency = 1
                        p.Anchored     = true
                        p.CanCollide   = false
                    end
                end
                clone.Name   = "PlantModel"
                clone.Parent = potModel
                FadeIn(clone, 0.5)
            else
                -- BasePart directe (Part + SpecialMesh enfant)
                clone.Position     = basePos
                clone.Transparency = 1
                clone.Anchored     = true
                clone.CanCollide   = false
                clone.Name         = "PlantModel"
                clone.Parent       = potModel
                TweenService:Create(clone,
                    TweenInfo.new(0.5, Enum.EasingStyle.Quad),
                    { Transparency = 0 }):Play()
            end

        else
            -- Tree scalé selon stage : 0.05 / 0.2 / 0.5 / 1.0
            local treeSrc = plantModels:FindFirstChild("Tree")
            if not treeSrc then
                FallbackPlante(potModel, basePos, stage)
                return
            end

            local scales      = { [1]=0.05, [2]=0.2, [3]=0.5, [4]=1.0 }
            local targetScale = scales[stage] or 0.05

            local clone = treeSrc:Clone()

            -- Positionner à l'échelle native d'abord
            local root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
            if root then clone:SetPrimaryPartCFrame(CFrame.new(basePos)) end

            -- Appliquer l'échelle cible et mémoriser les tailles finales
            pcall(function() clone:ScaleTo(targetScale) end)
            local cibles = {}
            for _, p in ipairs(clone:GetDescendants()) do
                if p:IsA("BasePart") then
                    cibles[p]      = p.Size
                    p.Transparency = 1
                    p.Anchored     = true
                    p.CanCollide   = false
                end
            end

            -- Réduire à 10 % de la taille cible pour l'animation d'entrée
            pcall(function() clone:ScaleTo(targetScale * 0.1) end)

            clone.Name   = "PlantModel"
            clone.Parent = potModel

            -- Fade in des transparences
            FadeIn(clone, 0.4)

            -- Tween croissance vers la taille cible
            local ti = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            for part, siz in pairs(cibles) do
                if part.Parent then
                    TweenService:Create(part, ti, { Size = siz }):Play()
                end
            end
        end
    end)
end

-- ============================================================
-- Utilitaires
-- ============================================================

local function notifier(player, type_, msg)
    if NotifEvent then
        pcall(function() NotifEvent:FireClient(player, type_, msg) end)
    end
end

local function majHUD(player)
    local data = GetData(player)
    if data and UpdateHUD then
        pcall(function() UpdateHUD:FireClient(player, data) end)
    end
end

local function getPotPart(potModel)
    if potModel:IsA("BasePart") then return potModel end
    return potModel:FindFirstChildWhichIsA("BasePart")
end

-- ============================================================
-- FormatTemps helper
-- ============================================================

function FlowerPotSystem.FormatTemps(secondes)
    if not secondes or secondes <= 0 then return "Ready!" end
    secondes = math.floor(secondes)
    local h = math.floor(secondes / 3600)
    local m = math.floor((secondes % 3600) / 60)
    local s = secondes % 60
    if h > 0 then
        return h .. "h " .. string.format("%02d", m) .. "m"
    elseif m > 0 then
        return m .. "m " .. string.format("%02d", s) .. "s"
    else
        return s .. "s"
    end
end

-- ============================================================
-- Billboard permanent sur chaque pot
-- ============================================================

function FlowerPotSystem.CreerBillboard(potPart, texte)
    local existing = potPart:FindFirstChild("PotBillboard")
    if existing then pcall(function() existing:Destroy() end) end

    local bb = Instance.new("BillboardGui")
    bb.Name        = "PotBillboard"
    bb.Size        = UDim2.new(0, 180, 0, 44)
    bb.StudsOffset = Vector3.new(0, 5, 0)
    bb.AlwaysOnTop = false
    bb.MaxDistance = 30
    bb.Adornee     = potPart
    bb.Parent      = potPart

    local cadre = Instance.new("Frame", bb)
    cadre.Size                   = UDim2.new(1, 0, 1, 0)
    cadre.BackgroundColor3       = Color3.fromRGB(15, 15, 25)
    cadre.BackgroundTransparency = 0.35
    cadre.BorderSizePixel        = 0
    Instance.new("UICorner", cadre).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel", cadre)
    label.Name                   = "BillboardLabel"
    label.Size                   = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3             = Color3.fromRGB(255, 255, 255)
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 12
    label.RichText               = true
    label.TextWrapped            = true
    label.Text                   = texte

    return bb
end

-- Met à jour le texte d'un billboard existant (évite de le recréer)
local function majBillboard(potPart, texte)
    local bb = potPart:FindFirstChild("PotBillboard")
    if not bb then
        FlowerPotSystem.CreerBillboard(potPart, texte)
        return
    end
    local cadre = bb:FindFirstChildOfClass("Frame")
    local label = cadre and cadre:FindFirstChild("BillboardLabel")
    if label then
        pcall(function() label.Text = texte end)
    end
end

-- ============================================================
-- ProximityPrompt selon l'état du pot
-- ============================================================

function FlowerPotSystem.CreerProximityPrompt(player, potPart, potIndex, etat)
    local existing = potPart:FindFirstChildOfClass("ProximityPrompt")
    if existing then pcall(function() existing:Destroy() end) end

    local prompt = Instance.new("ProximityPrompt")
    prompt.KeyboardKeyCode       = Enum.KeyCode.F
    prompt.MaxActivationDistance = 8
    prompt.HoldDuration          = 0
    prompt.RequiresLineOfSight   = false

    if etat == "locked" then
        local potCfg = FPConfig.pots[potIndex]
        local prixLabel = potCfg.prixCoins > 0
            and potCfg.prixCoins .. " 💰"
            or  potCfg.prixRobux .. " R$"
        prompt.ActionText = "Unlock"
        prompt.ObjectText = "🔒 Pot " .. potIndex .. " — " .. prixLabel
    elseif etat == "empty" then
        prompt.ActionText = "Plant"
        prompt.ObjectText = "🌱 Flower Pot"
    elseif etat == "growing" then
        prompt.ActionText = "Info"
        prompt.ObjectText = "🌱 Growing..."
    elseif etat == "harvest" then
        prompt.ActionText = "Harvest"
        prompt.ObjectText = "🌟 Mutant Ready!"
    end

    prompt.Enabled = true
    prompt.Parent  = potPart

    prompt.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer ~= player then return end
        FlowerPotSystem.OnTrigger(player, potIndex, etat)
    end)

    return prompt
end

-- ============================================================
-- Dispatch ProximityPrompt → action
-- ============================================================

function FlowerPotSystem.OnTrigger(player, potIndex, etat)
    if etat == "locked" then
        if OuvrirPot then
            pcall(function()
                OuvrirPot:FireClient(player, potIndex, "debloque")
            end)
        end

    elseif etat == "empty" then
        -- Vérifier si le joueur a des graines disponibles dans son inventaire
        local SI   = getSeedInventory()
        local data = GetData(player)
        local hasSeed = false
        if SI and data then
            hasSeed, _ = SI.HasAny(data)
        end

        if hasSeed then
            FlowerPotSystem.Planter(player, potIndex)
        else
            -- Pas de graines → ouvrir menu daily seed
            if OuvrirPot then
                pcall(function()
                    OuvrirPot:FireClient(player, potIndex, "empty",
                        data and data.dailySeed or {})
                end)
            end
        end

    elseif etat == "growing" then
        local data = GetData(player)
        if data and OuvrirPot then
            pcall(function()
                OuvrirPot:FireClient(player, potIndex, "infos",
                    data.pots[potIndex])
            end)
        end

    elseif etat == "harvest" then
        FlowerPotSystem.Recolter(player, potIndex)
    end
end

-- ============================================================
-- Visuels croissance — GrowthModel
-- ============================================================

function FlowerPotSystem.ActualiserVisuels(baseIndex, potIndex, stage, rarete)
    NettoyerPot(baseIndex, potIndex)
    GererVisuelsPlante(baseIndex, potIndex, stage or 0)
end

-- ============================================================
-- Illuminer les pots quand un BR plantable est dans le carry
-- ============================================================

function FlowerPotSystem.SetPotsIllumines(player, baseIndex, actif, data)
    local bases = Workspace:FindFirstChild("Bases")
    local base  = bases and bases:FindFirstChild("Base_" .. baseIndex)
    if not base then return end

    for i = 1, 4 do
        local potModel = base:FindFirstChild("FlowerPot_" .. i)
        if not potModel then continue end

        local potPart = getPotPart(potModel)
        if not potPart then continue end

        local potData = data.pots and data.pots[i]
        if not potData then continue end

        -- Illuminer uniquement les pots débloqués et vides
        if potData.debloque and not potData.rarete then
            pcall(function()
                -- PointLight
                local light = potPart:FindFirstChild("PotLight")
                if not light then
                    light      = Instance.new("PointLight", potPart)
                    light.Name = "PotLight"
                end
                light.Brightness = actif and 4 or 0
                light.Range      = 18
                light.Color      = Color3.fromRGB(180, 0, 255)

                -- Billboard
                majBillboard(potPart, actif
                    and "<font color='#CC00FF'>🌱 Plant here!</font>"
                    or  FPConfig.labelPotVide)
            end)
        end
    end
end

-- ============================================================
-- OnCarryChange — appelé par CarrySystem à chaque changement
-- ============================================================

function FlowerPotSystem.OnCarryChange(player, portes)
    local data = GetData(player)
    if not data or not data.pots then return end

    local AS = getAssignation()
    local baseIndex = AS and AS.GetBaseIndex(player)
    if not baseIndex then return end

    -- Illuminer les pots si le joueur a des graines disponibles
    local SI = getSeedInventory()
    local hasSeed = false
    if SI then
        hasSeed, _ = SI.HasAny(data)
    end

    pcall(FlowerPotSystem.SetPotsIllumines,
        player, baseIndex, hasSeed, data)
end

-- ============================================================
-- ActualiserPot — état complet d'un pot (visuels + prompts)
-- ============================================================

function FlowerPotSystem.ActualiserPot(player, baseIndex, potIndex, data)
    local potData  = data.pots and data.pots[potIndex]
    local potCfg   = FPConfig.pots[potIndex]
    if not potData or not potCfg then return end

    local bases    = Workspace:FindFirstChild("Bases")
    local base     = bases and bases:FindFirstChild("Base_" .. baseIndex)
    local potModel = base and base:FindFirstChild("FlowerPot_" .. potIndex)
    if not potModel then return end

    local potPart = getPotPart(potModel)
    if not potPart then return end

    if not potData.debloque then
        local prixLabel = potCfg.prixCoins and potCfg.prixCoins > 0
            and "🔒 " .. potCfg.prixCoins .. " 💰"
            or  "🔒 " .. (potCfg.prixRobux or 0) .. " R$"
        pcall(FlowerPotSystem.CreerBillboard, potPart, prixLabel)
        pcall(FlowerPotSystem.CreerProximityPrompt,
            player, potPart, potIndex, "locked")

    elseif potData.stage == 4 then
        pcall(FlowerPotSystem.CreerBillboard, potPart,
            "<font color='#FFD700'>🌟 READY! Harvest!</font>")
        pcall(FlowerPotSystem.CreerProximityPrompt,
            player, potPart, potIndex, "harvest")
        pcall(FlowerPotSystem.ActualiserVisuels,
            baseIndex, potIndex, 4, potData.rarete)

    elseif potData.rarete then
        local t = FlowerPotSystem.FormatTemps(potData.tempsRestant or 0)
        pcall(FlowerPotSystem.CreerBillboard, potPart,
            "🌱 " .. potData.rarete .. " Stage "
            .. potData.stage .. "/4  ⏱ " .. t)
        pcall(FlowerPotSystem.CreerProximityPrompt,
            player, potPart, potIndex, "growing")
        pcall(FlowerPotSystem.ActualiserVisuels,
            baseIndex, potIndex, potData.stage, potData.rarete)

    else
        pcall(FlowerPotSystem.CreerBillboard, potPart,
            FPConfig.labelPotVide)
        pcall(FlowerPotSystem.CreerProximityPrompt,
            player, potPart, potIndex, "empty")
    end
end

-- ============================================================
-- Animation transformation BR → graine
-- ============================================================

function FlowerPotSystem.AnimerTransformation(baseIndex, potIndex, rarete)
    local bases    = Workspace:FindFirstChild("Bases")
    local base     = bases and bases:FindFirstChild("Base_" .. baseIndex)
    local potModel = base and base:FindFirstChild("FlowerPot_" .. potIndex)
    if not potModel then return end

    local potPart = getPotPart(potModel)
    if not potPart then return end

    local brainrots = ServerStorage:FindFirstChild("Brainrots")
    local dossier   = brainrots and brainrots:FindFirstChild(rarete)
    if not dossier then return end
    local modeles = dossier:GetChildren()
    if #modeles == 0 then return end

    local clone = nil
    pcall(function() clone = modeles[1]:Clone() end)
    if not clone then return end

    -- Positionner au-dessus du pot
    local rootPart = nil
    if clone:IsA("Model") then
        rootPart = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
    else
        rootPart = clone
    end

    if not rootPart then pcall(function() clone:Destroy() end) return end

    pcall(function()
        if clone:IsA("Model") then
            clone:PivotTo(CFrame.new(
                potPart.Position + Vector3.new(0, 4, 0)))
        else
            clone.CFrame = CFrame.new(
                potPart.Position + Vector3.new(0, 4, 0))
        end
    end)

    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.Anchored   = true
                part.CanCollide = false
            end)
        end
    end
    clone.Parent = Workspace

    -- Rétrécissement vers le pot
    local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad,
        Enum.EasingDirection.In)
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                TweenService:Create(part, tweenInfo, {
                    Size         = Vector3.new(0.1, 0.1, 0.1),
                    Transparency = 1,
                }):Play()
            end)
        end
    end
    if clone:IsA("BasePart") then
        pcall(function()
            TweenService:Create(clone, tweenInfo, {
                Size         = Vector3.new(0.1, 0.1, 0.1),
                Transparency = 1,
            }):Play()
        end)
    end

    task.delay(1.7, function()
        pcall(function() clone:Destroy() end)
    end)
end

-- ============================================================
-- Planter un BR plantable depuis le carry
-- ============================================================

function FlowerPotSystem.Planter(player, potIndex)
    local data    = GetData(player)
    if not data or not data.pots then return end

    local potData = data.pots[potIndex]
    if not potData then return end

    if not potData.debloque then
        notifier(player, "ERROR", "❌ Pot locked!")
        return
    end
    if potData.rarete then
        notifier(player, "ERROR", "❌ Pot already has a plant!")
        return
    end

    -- Utiliser une graine depuis l'inventaire (plus de BR depuis le carry)
    local SI = getSeedInventory()
    if not SI then
        notifier(player, "ERROR", "❌ SeedInventory indisponible!")
        return
    end

    local hasSeed, bestRarity = SI.HasAny(data)
    if not hasSeed then
        notifier(player, "ERROR",
            "❌ Aucune graine! Collecte des graines sur les arbres ou via le Daily Seed.")
        -- Ouvrir menu daily seed en fallback
        if OuvrirPot then
            pcall(function()
                OuvrirPot:FireClient(player, potIndex, "empty",
                    data.dailySeed or {})
            end)
        end
        return
    end

    -- Consommer la graine (SECRET prioritaire sur MYTHIC)
    if not SI.Use(data, bestRarity) then
        notifier(player, "ERROR", "❌ Erreur lors de la consommation de la graine!")
        return
    end

    local rarete = bestRarity

    -- Notifier le client du stock mis à jour
    SI.NotifyClient(player, data)

    -- Planter
    potData.rarete       = rarete
    potData.stage        = 0
    potData.tempsRestant = 0
    potData.instantGrow  = false

    local AS = getAssignation()
    local baseIndex = AS and AS.GetBaseIndex(player)
    if not baseIndex then
        notifier(player, "ERROR", "❌ No base assigned!")
        -- Rembourser la graine consommée
        local SI2 = getSeedInventory()
        if SI2 then SI2.Add(data, rarete) end
        potData.rarete = nil
        return
    end

    -- Animation transformation (graine → pot)
    task.spawn(function()
        pcall(FlowerPotSystem.AnimerTransformation, baseIndex, potIndex, rarete)
    end)

    -- Lancer croissance après animation
    task.delay(1.6, function()
        FlowerPotSystem.LancerCroissance(player, baseIndex, potIndex, data)
        pcall(FlowerPotSystem.ActualiserPot, player, baseIndex, potIndex, data)
    end)

    notifier(player, "SUCCESS",
        "🌱 " .. rarete .. " planted in Pot " .. potIndex .. "!")
    majHUD(player)
end

-- ============================================================
-- Croissance progressive (4 stages)
-- ============================================================

function FlowerPotSystem.LancerCroissance(player, baseIndex, potIndex, data)
    local potData   = data.pots and data.pots[potIndex]
    if not potData or not potData.rarete then return end

    local graineCfg = FPConfig.graines[potData.rarete]
    if not graineCfg then return end

    local durees = Config.TEST_MODE
        and graineCfg.dureeTest
        or  graineCfg.dureeStages

    local cleThread = player.UserId .. "_" .. potIndex

    -- Annuler thread précédent
    if _threads[cleThread] then
        pcall(function() task.cancel(_threads[cleThread]) end)
        _threads[cleThread] = nil
    end

    _threads[cleThread] = task.spawn(function()
        local aborted = false

        for stage = (potData.stage + 1), 4 do
            if aborted then break end
            if not player.Parent then break end

            local pd = GetData(player)
            if not pd or not pd.pots then break end
            local pot = pd.pots[potIndex]
            if not pot or not pot.rarete then break end

            local duree = durees[stage] or 225

            -- Reprendre depuis le temps restant sauvegardé si rejoin en cours de stage
            local dureeEffective = duree
            if stage == (potData.stage + 1) and (pot.tempsRestant or 0) > 0 and pot.tempsRestant < duree then
                dureeEffective = pot.tempsRestant
            end

            -- Initialiser tempsRestant immédiatement (fix: timer visible dès le début)
            pot.tempsRestant = dureeEffective

            -- Boucle seconde par seconde
            for t = 1, dureeEffective do
                if not player.Parent then aborted = true break end

                local pd2 = GetData(player)
                if not pd2 or not pd2.pots then aborted = true break end

                local pot2 = pd2.pots[potIndex]
                if not pot2 or not pot2.rarete then aborted = true break end

                -- Instant Grow déclenché ?
                if pot2.instantGrow then
                    pot2.instantGrow  = false
                    pot2.tempsRestant = 0
                    break
                end

                pot2.tempsRestant = dureeEffective - t

                -- Mise à jour billboard toutes les 5s (fix: was 10s — trop lent)
                if t % 5 == 0 or t == 1 then
                    local bases = Workspace:FindFirstChild("Bases")
                    local base  = bases and bases:FindFirstChild(
                        "Base_" .. baseIndex)
                    local pm    = base and base:FindFirstChild(
                        "FlowerPot_" .. potIndex)
                    if pm then
                        local pp = getPotPart(pm)
                        if pp then
                            local t2 = FlowerPotSystem.FormatTemps(
                                pot2.tempsRestant)
                            pcall(majBillboard, pp,
                                "🌱 " .. pot2.rarete .. " Stage "
                                .. pot2.stage .. "/4  ⏱ " .. t2)
                        end
                    end
                end

                -- Mise à jour HUD toutes les 10s (garde le rythme raisonnable)
                if t % 10 == 0 then
                    if PotUpdate then
                        local pd3check = GetData(player)
                        local pot3check = pd3check and pd3check.pots and pd3check.pots[potIndex]
                        if pot3check then
                            pcall(function()
                                PotUpdate:FireClient(player, potIndex, pot3check)
                            end)
                        end
                    end
                end

                task.wait(1)
            end

            if aborted then break end

            -- Avancer au stage suivant
            local pd3 = GetData(player)
            if not pd3 or not pd3.pots then break end
            local pot3 = pd3.pots[potIndex]
            if not pot3 or not pot3.rarete then break end

            pot3.stage        = stage
            pot3.tempsRestant = 0

            -- Actualiser visuels
            pcall(FlowerPotSystem.ActualiserVisuels,
                baseIndex, potIndex, stage, pot3.rarete)

            -- Actualiser prompt + billboard
            pcall(FlowerPotSystem.ActualiserPot,
                player, baseIndex, potIndex, pd3)

            if stage == 4 then
                -- Maturité
                FlowerPotSystem.PotMature(player, baseIndex, potIndex, pd3)
                pcall(function() majHUD(player) end)
            end
        end

        _threads[cleThread] = nil
    end)
end

-- ============================================================
-- Pot mature → notifier + mettre à jour visuels
-- ============================================================

function FlowerPotSystem.PotMature(player, baseIndex, potIndex, data)
    local potData   = data.pots and data.pots[potIndex]
    if not potData then return end
    local graineCfg = FPConfig.graines[potData.rarete]
    if not graineCfg then return end

    -- Notifier le joueur
    notifier(player, "SUCCESS",
        "🌟 " .. potData.rarete .. " Mutant ready!"
        .. " Press F to harvest Pot " .. potIndex .. "!")

    -- Trouver le pot dans le Workspace
    local bases    = Workspace:FindFirstChild("Bases")
    local base     = bases and bases:FindFirstChild("Base_" .. baseIndex)
    local potModel = base and base:FindFirstChild("FlowerPot_" .. potIndex)
    if not potModel then return end

    local potPart = getPotPart(potModel)
    if not potPart then return end

    -- Lumière stage 4
    pcall(function()
        local light = potPart:FindFirstChild("PotLight")
        if not light then
            light      = Instance.new("PointLight", potPart)
            light.Name = "PotLight"
        end
        light.Brightness = 8
        light.Range      = 25
        light.Color      = graineCfg.couleurStage4
    end)

    -- Créer le ProximityPrompt Harvest (garanti présent au stage 4)
    pcall(function()
        local existing = potPart:FindFirstChildOfClass("ProximityPrompt")
        if existing then existing:Destroy() end

        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText            = "Harvest"
        prompt.ObjectText            = "🌟 " .. (graineCfg.label or potData.rarete)
        prompt.HoldDuration          = 0
        prompt.MaxActivationDistance = 8
        prompt.KeyboardKeyCode       = Enum.KeyCode.F
        prompt.RequiresLineOfSight   = false
        prompt.Enabled               = true
        prompt.Parent                = potPart

        prompt.Triggered:Connect(function(triggerPlayer)
            if triggerPlayer ~= player then return end
            FlowerPotSystem.Recolter(triggerPlayer, potIndex)
        end)
    end)

    -- Billboard stage 4
    pcall(function()
        majBillboard(potPart,
            "<font color='#FFD700'>🌟 READY! Press F to Harvest!</font>")
    end)

    print("[FlowerPot] Pot " .. potIndex .. " mûr → Harvest prompt créé")
end

-- ============================================================
-- Récolter le BR Mutant
-- ============================================================

function FlowerPotSystem.Recolter(player, potIndex)
    local data = GetData(player)
    if not data or not data.pots then return end

    local potData = data.pots[potIndex]
    if not potData or not potData.rarete or potData.stage < 4 then
        notifier(player, "ERROR", "❌ Not ready yet!")
        return
    end

    local graineCfg = FPConfig.graines[potData.rarete]
    if not graineCfg then return end

    local rarete  = potData.rarete
    local multVal = graineCfg.multiplicateur

    -- Générer un BR Mutant élémentaire (COMMON/OG/RARE) via MutantGenerator
    -- La graine MYTHIC/SECRET détermine les probabilités — jamais le BR final
    local MG = getMutantGenerator()
    local CS = getCarry()

    if not MG then
        warn("[FlowerPotSystem] MutantGenerator indisponible — harvest annulé")
        return
    end

    if CS then
        local clone, finalRarity, elementType = MG.Generate(rarete)
        if clone then
            local elemCfg = MG.GetElementConfig(elementType)

            -- Tag Mutant pour IncomeSystem
            local tag = Instance.new("StringValue")
            tag.Name   = "MutantTag"
            tag.Value  = tostring(multVal)
            tag.Parent = clone

            local rareteObj = {
                nom      = finalRarity,
                dossier  = finalRarity,
                isMutant = true,
                valeur   = multVal,
                couleur  = (elemCfg and elemCfg.couleur) or graineCfg.couleurStage4,
            }

            -- Ajouter le Mutant au carry (retourne false si carry plein)
            local ok2, success = pcall(CS.AjouterAuCarry, player, clone, rareteObj)
            if not ok2 or not success then
                -- Carry plein → ne pas réinitialiser le pot, joueur réessaie
                notifier(player, "WARNING",
                    "🎒 Carry full! Deposit your Brain Rots first, then harvest.")
                pcall(function() clone:Destroy() end)
                return
            end
        else
            warn("[FlowerPotSystem] Génération mutant échouée pour graine " .. rarete)
        end
    end

    -- Reinitialiser le pot
    local graineName = rarete
    potData.rarete       = nil
    potData.stage        = 0
    potData.tempsRestant = 0
    potData.instantGrow  = false

    -- Annuler thread de croissance
    local cleThread = player.UserId .. "_" .. potIndex
    if _threads[cleThread] then
        pcall(function() task.cancel(_threads[cleThread]) end)
        _threads[cleThread] = nil
    end

    -- Actualiser visuels (effacer modeles)
    local AS = getAssignation()
    local baseIndex = AS and AS.GetBaseIndex(player)
    if baseIndex then
        NettoyerPot(baseIndex, potIndex)
        pcall(FlowerPotSystem.ActualiserPot, player, baseIndex, potIndex, data)
    end

    notifier(player, "SUCCESS",
        "🌟 " .. graineName .. " Mutant harvested!"
        .. " ×" .. multVal .. " income when deposited!")
    majHUD(player)
end

-- ============================================================
-- Débloquer un pot
-- ============================================================

function FlowerPotSystem.DebloquerPot(player, potIndex)
    local data = GetData(player)
    if not data or not data.pots then return end

    local potCfg = FPConfig.pots[potIndex]
    if not potCfg then return end

    local potData = data.pots[potIndex]
    if not potData or potData.debloque then return end

    if potCfg.prixCoins and potCfg.prixCoins > 0 then
        if (data.coins or 0) < potCfg.prixCoins then
            notifier(player, "ERROR",
                "❌ Not enough coins! ("
                .. (data.coins or 0) .. " / " .. potCfg.prixCoins .. ")")
            return
        end
        data.coins       = data.coins - potCfg.prixCoins
        potData.debloque = true

    elseif potCfg.prixRobux and potCfg.prixRobux > 0 then
        if potCfg.gamePassId and potCfg.gamePassId > 0 then
            pcall(function()
                MarketplaceService:PromptGamePassPurchase(
                    player, potCfg.gamePassId)
            end)
            return
        else
            if Config.TEST_MODE then
                potData.debloque = true
                notifier(player, "INFO",
                    "🧪 [TEST] FlowerPot " .. potIndex .. " unlocked!")
            else
                notifier(player, "ERROR",
                    "❌ Game Pass not configured!")
                return
            end
        end
    end

    if potData.debloque then
        local AS = getAssignation()
        local baseIndex = AS and AS.GetBaseIndex(player)
        if baseIndex then
            -- Supprimer les visuels cadenas/prix placés dans Studio
            local bases    = Workspace:FindFirstChild("Bases")
            local base     = bases and bases:FindFirstChild("Base_" .. baseIndex)
            local potModel = base and base:FindFirstChild("FlowerPot_" .. potIndex)
            if potModel then
                local lockIcon   = potModel:FindFirstChild("LockIcon")
                local priceLabel = potModel:FindFirstChild("PriceLabel")
                if lockIcon   then pcall(function() lockIcon:Destroy()   end) end
                if priceLabel then pcall(function() priceLabel:Destroy() end) end
            end
            pcall(FlowerPotSystem.ActualiserPot,
                player, baseIndex, potIndex, data)
        end
        notifier(player, "SUCCESS",
            "🌱 FlowerPot " .. potIndex .. " unlocked!")
        majHUD(player)
    end
end

-- ============================================================
-- Instant Grow
-- ============================================================

function FlowerPotSystem.InstantGrow(player, potIndex)
    local data = GetData(player)
    if not data or not data.pots then return end

    local potData = data.pots[potIndex]
    if not potData or not potData.rarete then
        notifier(player, "ERROR", "❌ No plant in this pot!")
        return
    end
    if potData.stage >= 4 then
        notifier(player, "ERROR", "❌ Already mature!")
        return
    end

    local igCfg = FPConfig.instantGrow
    if igCfg.gamePassId and igCfg.gamePassId > 0 then
        pcall(function()
            MarketplaceService:PromptGamePassPurchase(player, igCfg.gamePassId)
        end)
        return
    end

    if not Config.TEST_MODE then
        notifier(player, "ERROR", "❌ Instant Grow not configured!")
        return
    end

    potData.instantGrow = true
    notifier(player, "INFO",
        "⚡ Instant Growth triggered for Pot " .. potIndex .. "!")
end

-- ============================================================
-- Daily Seed System
-- ============================================================

function FlowerPotSystem.VerifierDailySeed(player, data)
    if not data or not data.dailySeed then return end

    local dsCfg   = Config.FlowerPotConfig.dailySeed
    local elapsed = os.time() - (data.dailySeed.dernieresClaim or 0)
    local seuil   = Config.TEST_MODE
        and 60  -- 1 minute en test
        or  (dsCfg.intervalleHeures * 3600)

    if elapsed >= seuil and not data.dailySeed.graineDispo then
        data.dailySeed.graineDispo = true
        notifier(player, "INFO",
            "🎁 Daily Seed available! Check your Shop!")
    end
end

-- ============================================================
-- PlanteDailySeed — plante directement dans un pot specifique
-- ============================================================
function FlowerPotSystem.PlanteDailySeed(player, potIndex, rarete, data)
    if not data or not data.pots or not data.dailySeed then return end
    local ds     = data.dailySeed
    local potData = data.pots[potIndex]
    if not potData then return end

    -- Detruire visuels existants
    local AS = getAssignation()
    local baseIndex = AS and AS.GetBaseIndex(player)
    if baseIndex then
        NettoyerPot(baseIndex, potIndex)
    end

    -- Planter
    potData.rarete       = rarete
    potData.stage        = 0
    potData.tempsRestant = 0
    potData.instantGrow  = false

    ds.graineDispo    = false
    ds.dernieresClaim = os.time()
    local jourPlante  = ds.jourActuel
    ds.jourActuel     = (ds.jourActuel % 7) + 1

    if baseIndex then
        FlowerPotSystem.LancerCroissance(player, baseIndex, potIndex, data)
        pcall(FlowerPotSystem.ActualiserPot, player, baseIndex, potIndex, data)
        GererVisuelsPlante(baseIndex, potIndex, 0)
    end

    notifier(player, "SUCCESS",
        "🎁 Day " .. jourPlante .. " seed: " .. rarete
        .. " planted in Pot " .. potIndex .. "!")
    majHUD(player)
end

-- ============================================================
-- ConfirmerEcrasement — ecrase le pot apres confirmation client
-- ============================================================
function FlowerPotSystem.ConfirmerEcrasement(player, potIndex)
    local data = GetData(player)
    if not data or not data.dailySeed then return end
    local ds    = data.dailySeed
    local dsCfg = Config.FlowerPotConfig.dailySeed
    local rarete = dsCfg.cycle[ds.jourActuel] or "MYTHIC"

    -- Annuler thread existant sur ce pot
    local cleThread = player.UserId .. "_" .. potIndex
    if _threads[cleThread] then
        pcall(function() task.cancel(_threads[cleThread]) end)
        _threads[cleThread] = nil
    end

    FlowerPotSystem.PlanteDailySeed(player, potIndex, rarete, data)
end

-- ============================================================
-- ClaimDailySeed — avec systeme anti-ecrasement
-- ============================================================
function FlowerPotSystem.ClaimDailySeed(player, potChoisi)
    local data = GetData(player)
    if not data or not data.dailySeed then return end

    local ds    = data.dailySeed
    local dsCfg = Config.FlowerPotConfig.dailySeed

    -- Verifier disponibilite
    if not ds.graineDispo then
        local seuil     = dsCfg.intervalleHeures * 3600
        local remaining = seuil - (os.time() - (ds.dernieresClaim or 0))
        notifier(player, "ERROR",
            "❌ Next seed in " .. FlowerPotSystem.FormatTemps(remaining))
        return
    end

    local rarete = dsCfg.cycle[ds.jourActuel] or "MYTHIC"

    -- Si un pot specifique est demande
    if potChoisi then
        local pot = data.pots and data.pots[potChoisi]
        if pot and pot.debloque and pot.rarete then
            -- Pot occupe : demander confirmation
            if OuvrirPot then
                pcall(function()
                    OuvrirPot:FireClient(player, potChoisi,
                        "confirmer_ecrasement", {
                            potIndex = potChoisi,
                            rarete   = rarete,
                            ancienne = pot.rarete,
                            stage    = pot.stage,
                        })
                end)
            end
            return
        elseif pot and pot.debloque then
            -- Pot libre : planter directement
            FlowerPotSystem.PlanteDailySeed(player, potChoisi, rarete, data)
            return
        end
    end

    -- Trouver un pot vide debloque
    local potLibre = nil
    for i = 1, 4 do
        local pot = data.pots and data.pots[i]
        if pot and pot.debloque and not pot.rarete then
            potLibre = i
            break
        end
    end

    if potLibre then
        FlowerPotSystem.PlanteDailySeed(player, potLibre, rarete, data)
        return
    end

    -- Aucun pot libre : proposer de choisir quel pot ecraser
    if OuvrirPot then
        local etatsPots = {}
        for i = 1, 4 do
            local pot = data.pots and data.pots[i]
            if pot then
                etatsPots[i] = {
                    debloque = pot.debloque,
                    rarete   = pot.rarete,
                    stage    = pot.stage,
                }
            end
        end
        pcall(function()
            OuvrirPot:FireClient(player, 0, "choisir_pot", {
                etatsPots    = etatsPots,
                raretyDuJour = rarete,
            })
        end)
    else
        notifier(player, "ERROR",
            "❌ No empty pot available! Harvest or unlock a pot first.")
    end
end

-- ============================================================
-- Init joueur
-- ============================================================

function FlowerPotSystem.Init(player, baseIndex, playerData)
    -- Initialiser pots si absent
    if not playerData.pots then
        playerData.pots = {}
        for i = 1, 4 do
            playerData.pots[i] = {
                debloque     = (i == 1),
                rarete       = nil,
                stage        = 0,
                tempsRestant = 0,
                instantGrow  = false,
            }
        end
    end

    -- Migrer les pots qui utilisent encore l'ancien champ "graine" → "rarete"
    for i = 1, 4 do
        local pot = playerData.pots[i]
        if pot then
            if pot.graine ~= nil and pot.rarete == nil then
                pot.rarete = pot.graine
                pot.graine = nil
            end
            -- S'assurer que tous les champs existent
            if pot.rarete == nil then pot.rarete = nil end
            if pot.stage == nil then pot.stage = 0 end
            if pot.tempsRestant == nil then pot.tempsRestant = 0 end
            if pot.instantGrow == nil then pot.instantGrow = false end
        end
    end

    -- Initialiser dailySeed si absent
    if not playerData.dailySeed then
        playerData.dailySeed = {
            jourActuel    = 1,
            dernieresClaim = 0,
            graineDispo   = true,  -- disponible dès le 1er jour
        }
    end

    -- Supprimer LockIcon/PriceLabel des pots déjà débloqués (bug rejoin)
    local bases = Workspace:FindFirstChild("Bases")
    local base  = bases and bases:FindFirstChild("Base_" .. baseIndex)
    if base then
        for i = 1, 4 do
            local pot = playerData.pots[i]
            if pot and pot.debloque then
                local potModel = base:FindFirstChild("FlowerPot_" .. i)
                if potModel then
                    local lockIcon   = potModel:FindFirstChild("LockIcon")
                    local priceLabel = potModel:FindFirstChild("PriceLabel")
                    if lockIcon   then pcall(function() lockIcon:Destroy()   end) end
                    if priceLabel then pcall(function() priceLabel:Destroy() end) end
                end
            end
        end
    end

    -- Actualiser visuels de tous les pots
    for i = 1, 4 do
        pcall(FlowerPotSystem.ActualiserPot,
            player, baseIndex, i, playerData)
    end

    -- Reprendre croissances en cours
    for i = 1, 4 do
        local pot = playerData.pots[i]
        if pot and pot.rarete and pot.stage < 4 then
            FlowerPotSystem.LancerCroissance(
                player, baseIndex, i, playerData)
        end
    end

    -- Vérifier daily seed
    pcall(FlowerPotSystem.VerifierDailySeed, player, playerData)

    -- Boucle de vérification daily seed (toutes les minutes)
    task.spawn(function()
        while player.Parent do
            task.wait(60)
            if player.Parent then
                local data = GetData(player)
                if data then
                    pcall(FlowerPotSystem.VerifierDailySeed, player, data)
                end
            end
        end
    end)

    print("[FlowerPotSystem] Base_" .. baseIndex
        .. " initialized for " .. player.Name .. " ✓")
end

-- ============================================================
-- Init serveur (appelé depuis Main.server.lua section 6)
-- ============================================================

function FlowerPotSystem.InitServeur()
    NotifEvent       = getRemote("NotifEvent")
    UpdateHUD        = getRemote("UpdateHUD")
    OuvrirPot        = getRemote("OuvrirPot")
    PotUpdate        = getRemote("PotUpdate")
    DebloquerPotEv   = getRemote("DebloquerPot")
    InstantGrowEv    = getRemote("InstantGrowPot")
    ClaimDailySeedEv = getRemote("ClaimDailySeed")

    -- Ecouter les actions client
    DebloquerPotEv.OnServerEvent:Connect(function(player, potIndex)
        if type(potIndex) ~= "number" then return end
        FlowerPotSystem.DebloquerPot(player, potIndex)
    end)

    InstantGrowEv.OnServerEvent:Connect(function(player, potIndex)
        if type(potIndex) ~= "number" then return end
        FlowerPotSystem.InstantGrow(player, potIndex)
    end)

    ClaimDailySeedEv.OnServerEvent:Connect(function(player, potChoisi)
        FlowerPotSystem.ClaimDailySeed(player, potChoisi)
    end)

    -- Anti-ecrasement : confirmation cote client
    local ConfirmerEcrasementEv = getRemote("ConfirmerEcrasement")
    ConfirmerEcrasementEv.OnServerEvent:Connect(function(player, potIndex)
        if type(potIndex) ~= "number" then return end
        FlowerPotSystem.ConfirmerEcrasement(player, potIndex)
    end)

    -- DailySeedUpdate : le serveur peut pousser les donnees daily seed au client
    getRemote("DailySeedUpdate")

    print("[FlowerPotSystem] ✓ Server initialized")
end

-- ============================================================
-- NotifierGraineDispo — appelé par MonetizationHandler (SkipSeedTimer)
-- ============================================================
function FlowerPotSystem.NotifierGraineDispo(player)
    notifier(player, "INFO", "🎁 Daily Seed is now available! Check your Shop!")
    majHUD(player)
end

-- ============================================================
-- NotifierStock — appelé par MonetizationHandler (SeedPackx3 / SecretSeed)
-- ============================================================
function FlowerPotSystem.NotifierStock(player)
    local data = GetData(player)
    if not data or not data.graines then return end
    local mythic = data.graines.MYTHIC or 0
    local secret = data.graines.SECRET or 0
    notifier(player, "SUCCESS",
        string.format("🌱 Seed stock: %d MYTHIC · %d SECRET", mythic, secret))
    majHUD(player)
end

return FlowerPotSystem
