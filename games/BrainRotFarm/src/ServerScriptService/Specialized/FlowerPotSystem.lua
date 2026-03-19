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
            ServerScriptService.Common.AssignationSystem)
        if ok then _AssignationSystem = m end
    end
    return _AssignationSystem
end

local _CarrySystem = nil
local function getCarry()
    if not _CarrySystem then
        local ok, m = pcall(require,
            ServerScriptService.Common.CarrySystem)
        if ok then _CarrySystem = m end
    end
    return _CarrySystem
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
-- CreerPlanteProcedural — plante procedurale si PlantModels absent
-- ============================================================
local function CreerPlanteProcedural(stage, basePos, couleur, rarete)
    local TS    = game:GetService("TweenService")
    local model = Instance.new("Model")
    model.Name  = "PlantProc"

    local hauteurs = { [1]=1.5, [2]=2.5, [3]=3.5, [4]=4.5 }
    local hauteur  = hauteurs[stage] or 1.5

    -- Tige principale
    local tige = Instance.new("Part")
    tige.Name         = "Tige"
    tige.Size         = Vector3.new(0.2, hauteur, 0.2)
    tige.Position     = basePos + Vector3.new(0, hauteur/2, 0)
    tige.Color        = Color3.fromRGB(50, 150, 50)
    tige.Material     = Enum.Material.SmoothPlastic
    tige.Anchored     = true
    tige.CanCollide   = false
    tige.Transparency = 1
    tige.Parent       = model

    -- Feuilles
    local nbFeuilles = stage * 2
    for i = 1, nbFeuilles do
        local feuille = Instance.new("Part")
        feuille.Name         = "Feuille_" .. i
        feuille.Size         = Vector3.new(0.8, 0.1, 0.4)
        feuille.Color        = Color3.fromRGB(30, 180, 60)
        feuille.Material     = Enum.Material.SmoothPlastic
        feuille.Anchored     = true
        feuille.CanCollide   = false
        feuille.Transparency = 1
        local angle = (i / nbFeuilles) * math.pi * 2
        local yPos  = basePos.Y + (hauteur * i / nbFeuilles)
        feuille.Position = Vector3.new(
            basePos.X + math.cos(angle) * 0.6,
            yPos,
            basePos.Z + math.sin(angle) * 0.6
        )
        feuille.CFrame = feuille.CFrame * CFrame.Angles(0, angle, math.rad(30))
        feuille.Parent = model
    end

    -- Fleurs (stage 3+)
    if stage >= 3 then
        for i = 1, 4 do
            local fleur = Instance.new("Part")
            fleur.Name         = "Fleur_" .. i
            fleur.Shape        = Enum.PartType.Ball
            fleur.Size         = Vector3.new(0.4, 0.4, 0.4)
            fleur.Color        = couleur
            fleur.Material     = Enum.Material.Neon
            fleur.Anchored     = true
            fleur.CanCollide   = false
            fleur.Transparency = 1
            local angle = (i / 4) * math.pi * 2
            fleur.Position = Vector3.new(
                basePos.X + math.cos(angle) * 0.8,
                basePos.Y + hauteur,
                basePos.Z + math.sin(angle) * 0.8
            )
            fleur.Parent = model
        end
    end

    -- Fruits + effets (stage 4)
    if stage == 4 then
        for i = 1, 3 do
            local fruit = Instance.new("Part")
            fruit.Name         = "Fruit_" .. i
            fruit.Shape        = Enum.PartType.Ball
            fruit.Size         = Vector3.new(0.3, 0.3, 0.3)
            fruit.Color        = couleur
            fruit.Material     = Enum.Material.Neon
            fruit.Anchored     = true
            fruit.CanCollide   = false
            fruit.Transparency = 1
            local angle = (i / 3) * math.pi * 2
            fruit.Position = Vector3.new(
                basePos.X + math.cos(angle) * 0.5,
                basePos.Y + hauteur - 0.5,
                basePos.Z + math.sin(angle) * 0.5
            )
            fruit.Parent = model
            local fruitPos = fruit.Position
            task.spawn(function()
                while fruit.Parent do
                    TS:Create(fruit,
                        TweenInfo.new(1.5, Enum.EasingStyle.Sine,
                            Enum.EasingDirection.InOut, -1, true),
                        { Position = fruitPos + Vector3.new(0, 0.2, 0) }
                    ):Play()
                    task.wait(1.5)
                end
            end)
        end

        local light = Instance.new("PointLight", tige)
        light.Brightness = 4
        light.Range      = 12
        light.Color      = couleur

        local particles = Instance.new("ParticleEmitter", tige)
        particles.Rate     = 15
        particles.Lifetime = NumberRange.new(1, 2)
        particles.Speed    = NumberRange.new(2, 5)
        particles.Color    = ColorSequence.new(couleur)
        particles.Size     = NumberSequence.new(0.2)

        if rarete == "SECRET" then
            particles.Rate  = 25
            particles.Speed = NumberRange.new(3, 8)
            local flammes = Instance.new("ParticleEmitter", tige)
            flammes.Rate     = 10
            flammes.Lifetime = NumberRange.new(0.5, 1.0)
            flammes.Speed    = NumberRange.new(1, 3)
            flammes.Color    = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 0)),
            })
        end
    end

    -- Animation oscillation tige
    model.Parent = workspace
    task.spawn(function()
        while tige.Parent do
            TS:Create(tige,
                TweenInfo.new(2, Enum.EasingStyle.Sine,
                    Enum.EasingDirection.InOut, -1, true),
                { CFrame = tige.CFrame * CFrame.Angles(0, 0, math.rad(3)) }
            ):Play()
            task.wait(2)
        end
    end)

    FadeIn(model, 0.8)
    return model
end

-- ============================================================
-- CreerPlante — essaie PlantModels Studio, fallback procedural
-- ============================================================
local function CreerPlante(rarete, stage, basePos, couleur)
    local ok, result = pcall(function()
        local plantModels = game.ServerStorage:FindFirstChild("PlantModels")
        if plantModels then
            local rareteFolder = plantModels:FindFirstChild(rarete)
            if rareteFolder then
                local stageModel = rareteFolder:FindFirstChild("Plant_Stage" .. stage)
                if stageModel then
                    local clone = stageModel:Clone()
                    local root  = clone.PrimaryPart
                               or clone:FindFirstChildWhichIsA("BasePart")
                    if root then
                        clone:SetPrimaryPartCFrame(CFrame.new(basePos))
                    end
                    for _, part in ipairs(clone:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Anchored   = true
                            part.CanCollide = false
                        end
                    end
                    FadeIn(clone, 0.5)
                    return clone
                end
            end
        end
        return nil
    end)
    if ok and result then return result end
    return CreerPlanteProcedural(stage, basePos, couleur, rarete)
end

-- ============================================================
-- CreerBRMiniature — BR miniature synchronise avec la plante
-- ============================================================
local function CreerBRMiniature(rarete, stage, basePos, couleur)
    local ok, result = pcall(function()
        local dossier = game.ServerStorage.Brainrots:FindFirstChild(rarete)
        if not dossier or #dossier:GetChildren() == 0 then return nil end

        local clone = dossier:GetChildren()[1]:Clone()

        -- Nettoyer AVANT tout (supprime VfxInstance, FakeRootPart, constraints)
        NettoyerModeleVisuel(clone)

        local scales = { [1]=0.2, [2]=0.4, [3]=0.7, [4]=1.2 }
        local scale  = scales[stage] or 0.2

        for _, part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Size        = part.Size * scale
                part.Anchored    = true
                part.CanCollide  = false
                part.Transparency = 1
            end
        end

        local hauteurs = { [1]=1.5, [2]=2.5, [3]=3.5, [4]=4.5 }
        local yOffset  = hauteurs[stage] or 1.5

        local root = clone.PrimaryPart
                  or clone:FindFirstChild("RootPart")
                  or clone:FindFirstChildWhichIsA("BasePart")
        if root then
            clone:SetPrimaryPartCFrame(CFrame.new(
                basePos + Vector3.new(0, yOffset, 0)))
        end

        if root and stage >= 2 then
            local light = Instance.new("PointLight", root)
            light.Brightness = stage * 1.5
            light.Range      = stage * 5
            light.Color      = couleur
        end

        if stage == 4 then
            task.spawn(function()
                local TS2 = game:GetService("TweenService")
                while clone.Parent and root and root.Parent do
                    TS2:Create(root,
                        TweenInfo.new(4, Enum.EasingStyle.Linear,
                            Enum.EasingDirection.InOut, -1),
                        { CFrame = root.CFrame * CFrame.Angles(0, math.rad(360), 0) }
                    ):Play()
                    task.wait(4)
                end
            end)
        end

        FadeIn(clone, 0.8)
        return clone
    end)
    if ok then return result end
    return nil
end

-- ============================================================
-- ActualiserVisuelsSync — synchronise plante + BR dans le pot
-- ============================================================
local function ActualiserVisuelsSync(baseIndex, potIndex, stage, rarete)
    pcall(function()
        local cfg      = FPConfig
        local base     = Workspace:FindFirstChild("Bases")
                      and Workspace.Bases:FindFirstChild("Base_" .. baseIndex)
        local potModel = base and base:FindFirstChild("FlowerPot_" .. potIndex)
        if not potModel then return end

        local potPart = potModel:IsA("BasePart") and potModel
                     or potModel:FindFirstChildWhichIsA("BasePart")
        if not potPart then return end

        -- Supprimer visuels existants
        local existingPlant = potModel:FindFirstChild("PlantModel")
        local existingBR    = potModel:FindFirstChild("GrowthModel")
        if existingPlant then existingPlant:Destroy() end
        if existingBR    then existingBR:Destroy()    end

        if stage == 0 then return end

        local graineCfg = cfg.graines[rarete]
        local couleur   = graineCfg and graineCfg.couleurStage4
                       or Color3.fromRGB(180, 0, 255)

        local basePos = potPart.Position + Vector3.new(0, potPart.Size.Y / 2, 0)

        -- Couche 1 : plante
        local plantModel = CreerPlante(rarete, stage, basePos, couleur)
        if plantModel then
            plantModel.Name   = "PlantModel"
            plantModel.Parent = potModel
        end

        -- Couche 2 : BR miniature
        local brModel = CreerBRMiniature(rarete, stage, basePos, couleur)
        if brModel then
            brModel.Name   = "GrowthModel"
            brModel.Parent = potModel
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
        -- Vérifier si le joueur porte un BR plantable
        local CS = getCarry()
        local portes = CS and CS.GetPortes(player) or {}
        local hasBRPlantable = false
        for _, br in ipairs(portes) do
            if br.rarete then
                for _, r in ipairs(FPConfig.brPlantables) do
                    if br.rarete.nom == r then
                        hasBRPlantable = true
                        break
                    end
                end
            end
            if hasBRPlantable then break end
        end

        if hasBRPlantable then
            FlowerPotSystem.Planter(player, potIndex)
        else
            -- Ouvrir menu daily seed / info
            if OuvrirPot then
                local data = GetData(player)
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
    -- Deléguer vers le système synchronisé plante + BR
    ActualiserVisuelsSync(baseIndex, potIndex, stage or 0, rarete or "MYTHIC")
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

    local portePlantable = false
    for _, br in ipairs(portes) do
        if br.rarete then
            for _, r in ipairs(FPConfig.brPlantables) do
                if br.rarete.nom == r then
                    portePlantable = true
                    break
                end
            end
        end
        if portePlantable then break end
    end

    pcall(FlowerPotSystem.SetPotsIllumines,
        player, baseIndex, portePlantable, data)
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

    -- Trouver le meilleur BR plantable dans le carry
    local CS = getCarry()
    if not CS then return end
    local portes = CS.GetPortes(player)

    local brAPlanter = nil
    local priorite   = { SECRET = 2, MYTHIC = 1 }

    for _, br in ipairs(portes) do
        if br.rarete then
            local p = priorite[br.rarete.nom]
            if p then
                if not brAPlanter
                    or p > (priorite[brAPlanter.rarete.nom] or 0) then
                    brAPlanter = br
                end
            end
        end
    end

    if not brAPlanter then
        notifier(player, "ERROR",
            "❌ No MYTHIC or SECRET in your carry!")
        return
    end

    -- Retirer le BR du carry
    -- On utilise ViderCarry puis on remet les autres
    local tous = CS.ViderCarry(player)
    local rarete = brAPlanter.rarete.nom
    local modeleDepose = nil
    for _, e in ipairs(tous) do
        if e.rarete and e.rarete.nom == rarete and not modeleDepose then
            modeleDepose = e.modele  -- garder le premier du bon type
        else
            -- Remettre les autres dans le carry
            if e.rarete then
                pcall(CS.RamasserBR, player, e.rarete, e.modele)
            end
        end
    end

    -- Planter
    potData.rarete       = rarete
    potData.stage        = 0
    potData.tempsRestant = 0
    potData.instantGrow  = false

    local AS = getAssignation()
    local baseIndex = AS and AS.GetBaseIndex(player)
    if not baseIndex then
        notifier(player, "ERROR", "❌ No base assigned!")
        potData.rarete = nil
        if modeleDepose then pcall(CS.RamasserBR, player, brAPlanter.rarete, modeleDepose) end
        return
    end

    -- Détruire le modèle porté
    if modeleDepose then
        pcall(function() modeleDepose:Destroy() end)
    end

    -- Animation transformation
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

            -- Boucle seconde par seconde
            for t = 1, duree do
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

                pot2.tempsRestant = duree - t

                -- Mise à jour HUD et billboard toutes les 10s
                if t % 10 == 0 then
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
                    if PotUpdate then
                        pcall(function()
                            PotUpdate:FireClient(player, potIndex, pot2)
                        end)
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

    -- Cloner depuis Brainrots existants avec effets Mutant
    local brainrots = ServerStorage:FindFirstChild("Brainrots")
    local dossier   = brainrots and brainrots:FindFirstChild(rarete)

    local CS = getCarry()
    if CS and dossier then
        local modeles = dossier:GetChildren()
        if #modeles > 0 then
            local clone = nil
            pcall(function()
                clone = modeles[math.random(1, #modeles)]:Clone()
            end)
            if clone then
                -- Scale ×2
                for _, part in ipairs(clone:GetDescendants()) do
                    if part:IsA("BasePart") then
                        pcall(function()
                            part.Size       = part.Size * 2
                            part.Anchored   = true
                            part.CanCollide = false
                        end)
                    end
                end

                -- PointLight + particules couleur rareté
                local rootPart = nil
                if clone:IsA("Model") then
                    rootPart = clone.PrimaryPart
                            or clone:FindFirstChildWhichIsA("BasePart")
                elseif clone:IsA("BasePart") then
                    rootPart = clone
                end
                if rootPart then
                    pcall(function()
                        local light = Instance.new("PointLight", rootPart)
                        light.Brightness = 5
                        light.Range      = 20
                        light.Color      = graineCfg.couleurStage4

                        local particles = Instance.new("ParticleEmitter", rootPart)
                        particles.Rate     = 20
                        particles.Lifetime = NumberRange.new(0.5, 1.5)
                        particles.Speed    = NumberRange.new(5, 10)
                        particles.Color    = ColorSequence.new(
                            graineCfg.couleurStage4)
                    end)
                end

                -- Tag Mutant pour IncomeSystem
                local tag = Instance.new("StringValue")
                tag.Name   = "MutantTag"
                tag.Value  = tostring(multVal)
                tag.Parent = clone
                clone.Name = rarete .. "_MUTANT"

                local rareteObj = {
                    nom      = rarete,
                    dossier  = rarete,
                    isMutant = true,
                    valeur   = multVal,
                    couleur  = graineCfg.couleurStage4,
                }
                pcall(CS.RamasserBR, player, rareteObj, clone)
            end
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
        pcall(ActualiserVisuelsSync, baseIndex, potIndex, 0, "MYTHIC")
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
        pcall(ActualiserVisuelsSync, baseIndex, potIndex, 0, "MYTHIC")
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
        pcall(ActualiserVisuelsSync, baseIndex, potIndex, 0, rarete)
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

    -- Actualiser visuels de tous les pots
    for i = 1, 4 do
        pcall(FlowerPotSystem.ActualiserPot,
            player, baseIndex, i, playerData)
    end

    -- Reprendre croissances en cours
    for i = 1, 4 do
        local pot = playerData.pots[i]
        if pot and pot.rarete and pot.stage > 0 and pot.stage < 4 then
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

return FlowerPotSystem
