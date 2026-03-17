-- ServerScriptService/Common/FlowerPotSystem.lua
-- DobiGames — Système de pots de fleurs, graines et BR Mutants
-- Activé par défaut, pot 1 débloqué, pots 2-4 nécessitent coins/R$

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
local Config    = require(ReplicatedStorage.Specialized.GameConfig)
local FPConfig  = Config.FlowerPotConfig

-- ============================================================
-- Lazy loaders (éviter dépendances circulaires)
-- ============================================================
local _AssignationSystem = nil
local function getAssignation()
    if not _AssignationSystem then
        local ok, m = pcall(require, ServerScriptService.Common.AssignationSystem)
        if ok then _AssignationSystem = m end
    end
    return _AssignationSystem
end

local _CarrySystem = nil
local function getCarry()
    if not _CarrySystem then
        local ok, m = pcall(require, ServerScriptService.Common.CarrySystem)
        if ok then _CarrySystem = m end
    end
    return _CarrySystem
end

-- ============================================================
-- RemoteEvents
-- ============================================================
local NotifEvent  = nil
local UpdateHUD   = nil
local OuvrirPot   = nil
local PlanterGraine  = nil
local DebloquerPotEv = nil
local InstantGrowEv  = nil

local function getRemote(nom)
    local existing = ReplicatedStorage:FindFirstChild(nom)
    if existing then return existing end
    local re = Instance.new("RemoteEvent")
    re.Name   = nom
    re.Parent = ReplicatedStorage
    return re
end

-- ============================================================
-- Données joueur — clé d'accès fournie par Main
-- ============================================================
local _getData = nil
function FlowerPotSystem.SetGetData(fn) _getData = fn end

local function GetData(player)
    return _getData and _getData(player)
end

-- ============================================================
-- Utilitaires internes
-- ============================================================

local function notifier(player, type_, msg)
    if not NotifEvent then return end
    pcall(function() NotifEvent:FireClient(player, type_, msg) end)
end

local function majHUD(player)
    local data = GetData(player)
    if data and UpdateHUD then
        pcall(function() UpdateHUD:FireClient(player, data) end)
    end
end

-- Trouver le Part principal d'un modèle de pot
local function getPotPart(potModel)
    if potModel:IsA("BasePart") then return potModel end
    return potModel:FindFirstChildWhichIsA("BasePart")
end

-- ============================================================
-- Visuels — Billboard verrouillé
-- ============================================================

local function afficherBillboardVerrouille(potModel, potIndex)
    local potPart = getPotPart(potModel)
    if not potPart then return end

    -- Supprimer l'ancien
    local ancien = potPart:FindFirstChild("PotLockBB")
    if ancien then ancien:Destroy() end

    local potCfg = FPConfig.pots[potIndex]
    local bb = Instance.new("BillboardGui")
    bb.Name        = "PotLockBB"
    bb.Size        = UDim2.new(0, 140, 0, 55)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = false
    bb.Adornee     = potPart
    bb.Parent      = potPart

    local cadre = Instance.new("Frame", bb)
    cadre.Size                   = UDim2.new(1, 0, 1, 0)
    cadre.BackgroundColor3       = Color3.fromRGB(60, 0, 80)
    cadre.BackgroundTransparency = 0.3
    cadre.BorderSizePixel        = 0
    Instance.new("UICorner", cadre).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", cadre)
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = Color3.new(1, 1, 1)
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextScaled             = true

    if potCfg.prixCoins and potCfg.prixCoins > 0 then
        lbl.Text = "🔒 " .. potCfg.prixCoins .. " 💰"
    elseif potCfg.prixRobux and potCfg.prixRobux > 0 then
        lbl.Text = "🔒 " .. potCfg.prixRobux .. " R$"
    else
        lbl.Text = "🔒 Locked"
    end
end

local function supprimerBillboardVerrouille(potModel)
    local potPart = getPotPart(potModel)
    if not potPart then return end
    local bb = potPart:FindFirstChild("PotLockBB")
    if bb then pcall(function() bb:Destroy() end) end
end

-- ============================================================
-- Visuels — Modèle de croissance
-- ============================================================

function FlowerPotSystem.ActualiserVisuels(player, baseIndex, potIndex, data)
    local potData  = data.pots and data.pots[potIndex]
    if not potData then return end

    local bases = Workspace:FindFirstChild("Bases")
    if not bases then return end
    local base = bases:FindFirstChild("Base_" .. baseIndex)
    if not base then return end
    local potModel = base:FindFirstChild("FlowerPot_" .. potIndex)
    if not potModel then return end

    -- Supprimer l'ancien modèle de croissance
    local existing = potModel:FindFirstChild("GrowthModel")
    if existing then pcall(function() existing:Destroy() end) end

    if not potData.graine or potData.stage == 0 then return end

    -- Cloner un modèle BR depuis ServerStorage.Brainrots
    local brainrots = ServerStorage:FindFirstChild("Brainrots")
    if not brainrots then return end
    local dossier = brainrots:FindFirstChild(potData.graine)
    if not dossier then return end
    local modeles = dossier:GetChildren()
    if #modeles == 0 then return end

    local clone = nil
    pcall(function() clone = modeles[math.random(1, #modeles)]:Clone() end)
    if not clone then return end
    clone.Name = "GrowthModel"

    -- Scale selon le stage
    local scale = FPConfig.stageScales[potData.stage] or 0.3
    pcall(function()
        if clone:IsA("Model") then
            clone:ScaleTo(scale)
        else
            clone.Size = clone.Size * scale
        end
    end)

    -- Ancrer toutes les parts
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.Anchored   = true
                part.CanCollide = false
            end)
        end
    end
    if clone:IsA("BasePart") then
        pcall(function()
            clone.Anchored   = true
            clone.CanCollide = false
        end)
    end

    -- Positionner au-dessus du pot
    local potPart = getPotPart(potModel)
    if potPart then
        local yOffset = potPart.Size.Y * 0.5 + 1
        pcall(function()
            if clone:IsA("Model") then
                clone:PivotTo(CFrame.new(
                    potPart.Position + Vector3.new(0, yOffset, 0)))
            else
                clone.CFrame = CFrame.new(
                    potPart.Position + Vector3.new(0, yOffset, 0))
            end
        end)
    end

    clone.Parent = potModel

    -- Teinte du stage (tween doux)
    local couleur = FPConfig.stageCouleurs[potData.stage]
    if couleur then
        for _, part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency < 0.9 then
                pcall(function()
                    TweenService:Create(part, TweenInfo.new(0.5),
                        { Color = couleur }):Play()
                end)
            end
        end
        if clone:IsA("BasePart") then
            pcall(function()
                TweenService:Create(clone, TweenInfo.new(0.5),
                    { Color = couleur }):Play()
            end)
        end
    end

    -- Stage 4 : PointLight + ParticleEmitter
    if potData.stage == 4 then
        local rootPart = nil
        if clone:IsA("Model") then
            rootPart = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
        elseif clone:IsA("BasePart") then
            rootPart = clone
        end
        if rootPart then
            pcall(function()
                local light = Instance.new("PointLight", rootPart)
                light.Brightness = 3
                light.Range      = 15
                light.Color      = couleur or Color3.fromRGB(255, 215, 0)

                local particles = Instance.new("ParticleEmitter", rootPart)
                particles.Rate     = 20
                particles.Lifetime = NumberRange.new(0.5, 1.5)
                particles.Speed    = NumberRange.new(5, 10)
                particles.Color    = ColorSequence.new(
                    couleur or Color3.fromRGB(255, 215, 0))
            end)
        end
    end
end

-- ============================================================
-- ProximityPrompt
-- ============================================================

function FlowerPotSystem.CreerProximityPrompt(player, potModel, potIndex, baseIndex)
    local potPart = getPotPart(potModel)
    if not potPart then return end

    local existing = potPart:FindFirstChildOfClass("ProximityPrompt")
    if existing then pcall(function() existing:Destroy() end) end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText            = "Plant"
    prompt.ObjectText            = "🌱 Pot " .. potIndex
    prompt.KeyboardKeyCode       = Enum.KeyCode.F
    prompt.MaxActivationDistance = 8
    prompt.HoldDuration          = 0
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = potPart

    prompt.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer ~= player then return end

        local data    = GetData(player)
        if not data or not data.pots then return end
        local potData = data.pots[potIndex]
        if not potData then return end

        if not potData.debloque then
            -- Proposer déblocage
            if OuvrirPot then
                pcall(function()
                    OuvrirPot:FireClient(player, potIndex, "debloque", {})
                end)
            end
        elseif potData.stage == 4 then
            -- Récolter directement
            FlowerPotSystem.Recolter(player, potIndex)
        elseif potData.graine then
            -- Infos croissance
            if OuvrirPot then
                local graineCfg = FPConfig.graines[potData.graine]
                pcall(function()
                    OuvrirPot:FireClient(player, potIndex, "infos", {
                        graine       = potData.graine,
                        stage        = potData.stage,
                        tempsRestant = potData.tempsRestant or 0,
                        prixInstant  = FPConfig.instantGrow.prixRobux,
                    })
                end)
            end
        else
            -- Ouvrir menu plantation
            if OuvrirPot then
                pcall(function()
                    OuvrirPot:FireClient(player, potIndex, "planter",
                        data.graines or {})
                end)
            end
        end
    end)
end

-- Met à jour le texte du ProximityPrompt selon l'état du pot
local function majPromptPot(potModel, potData, potIndex)
    local potPart = getPotPart(potModel)
    if not potPart then return end
    local prompt = potPart:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then return end

    if potData.stage == 4 then
        prompt.ActionText = "Harvest"
        prompt.ObjectText = "🌟 " .. (potData.graine or "") .. " Mutant"
    elseif potData.graine then
        prompt.ActionText = "Check"
        prompt.ObjectText = "🌿 Pot " .. potIndex .. " (Stage "
            .. potData.stage .. "/4)"
    else
        prompt.ActionText = "Plant"
        prompt.ObjectText = "🌱 Pot " .. potIndex
    end
end

-- ============================================================
-- Croissance progressive
-- ============================================================

-- Table des threads de croissance actifs par joueur+pot
local _threads = {}  -- [userId.."_"..potIndex] = thread

function FlowerPotSystem.LancerCroissance(player, baseIndex, potIndex, data)
    local potData = data.pots and data.pots[potIndex]
    if not potData or not potData.graine then return end

    local graineCfg = FPConfig.graines[potData.graine]
    if not graineCfg then return end

    local durees = Config.TEST_MODE
        and graineCfg.dureeTest
        or  graineCfg.dureeStages

    local cleThread = player.UserId .. "_" .. potIndex

    -- Annuler thread précédent si existant
    if _threads[cleThread] then
        pcall(function() task.cancel(_threads[cleThread]) end)
        _threads[cleThread] = nil
    end

    _threads[cleThread] = task.spawn(function()
        local aborted = false

        for stage = (potData.stage + 1), 4 do
            if aborted then break end

            -- Vérifier que le joueur est toujours connecté et a toujours sa graine
            if not player.Parent then break end
            local pd = GetData(player)
            if not pd or not pd.pots then break end
            local pot = pd.pots[potIndex]
            if not pot or not pot.graine then break end

            local duree = durees[stage] or 120

            -- Boucle seconde par seconde
            for t = 1, duree do
                if not player.Parent then aborted = true break end

                local pd2 = GetData(player)
                if not pd2 or not pd2.pots then aborted = true break end

                local pot2 = pd2.pots[potIndex]
                if not pot2 or not pot2.graine then aborted = true break end

                -- Croissance instantanée déclenchée ?
                if pot2.instantGrow then
                    pot2.instantGrow  = false
                    pot2.tempsRestant = 0
                    break
                end

                pot2.tempsRestant = duree - t
                task.wait(1)
            end

            if aborted then break end

            -- Avancer au stage
            local pd3 = GetData(player)
            if not pd3 or not pd3.pots then break end
            local pot3 = pd3.pots[potIndex]
            if not pot3 or not pot3.graine then break end

            pot3.stage        = stage
            pot3.tempsRestant = 0

            -- Actualiser visuels
            pcall(FlowerPotSystem.ActualiserVisuels, player, baseIndex, potIndex, pd3)

            -- Mettre à jour le prompt
            local bases = Workspace:FindFirstChild("Bases")
            local base  = bases and bases:FindFirstChild("Base_" .. baseIndex)
            local pm    = base and base:FindFirstChild("FlowerPot_" .. potIndex)
            if pm then pcall(majPromptPot, pm, pot3, potIndex) end

            if stage == 4 then
                -- Maturité
                notifier(player, "SUCCESS",
                    "🌟 " .. pot3.graine .. " Mutant ready in Pot "
                    .. potIndex .. "! Harvest it!")
                pcall(function() majHUD(player) end)
            end
        end

        _threads[cleThread] = nil
    end)
end

-- ============================================================
-- API publique — Débloquer un pot
-- ============================================================

function FlowerPotSystem.DebloquerPot(player, potIndex)
    local data    = GetData(player)
    if not data or not data.pots then return end

    local potCfg  = FPConfig.pots[potIndex]
    if not potCfg then return end

    local potData = data.pots[potIndex]
    if not potData then return end
    if potData.debloque then return end

    if potCfg.prixCoins and potCfg.prixCoins > 0 then
        if (data.coins or 0) < potCfg.prixCoins then
            notifier(player, "ERROR",
                "❌ Not enough coins! ("
                .. (data.coins or 0) .. " / " .. potCfg.prixCoins .. ")")
            return
        end
        data.coins    = data.coins - potCfg.prixCoins
        potData.debloque = true

    elseif potCfg.prixRobux and potCfg.prixRobux > 0 then
        if potCfg.gamePassId and potCfg.gamePassId > 0 then
            pcall(function()
                MarketplaceService:PromptGamePassPurchase(player, potCfg.gamePassId)
            end)
            return
        else
            -- TEST_MODE seulement si gamePassId = 0
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
            local bases = Workspace:FindFirstChild("Bases")
            local base  = bases and bases:FindFirstChild("Base_" .. baseIndex)
            local pm    = base and base:FindFirstChild("FlowerPot_" .. potIndex)
            if pm then
                pcall(supprimerBillboardVerrouille, pm)
                pcall(FlowerPotSystem.CreerProximityPrompt,
                    player, pm, potIndex, baseIndex)
            end
        end
        notifier(player, "SUCCESS",
            "🌱 FlowerPot " .. potIndex .. " unlocked!")
        majHUD(player)
    end
end

-- ============================================================
-- API publique — Planter une graine
-- ============================================================

function FlowerPotSystem.Planter(player, potIndex, rareteGraine)
    local data = GetData(player)
    if not data or not data.pots then return end

    local potData   = data.pots[potIndex]
    local graineCfg = FPConfig.graines[rareteGraine]

    if not potData then
        notifier(player, "ERROR", "❌ Invalid pot!")
        return
    end
    if not potData.debloque then
        notifier(player, "ERROR", "❌ Pot locked!")
        return
    end
    if potData.graine then
        notifier(player, "ERROR", "❌ Pot already has a seed!")
        return
    end
    if not graineCfg then
        notifier(player, "ERROR", "❌ Unknown seed: " .. tostring(rareteGraine))
        return
    end
    if not data.graines or (data.graines[rareteGraine] or 0) <= 0 then
        notifier(player, "ERROR", "❌ No " .. rareteGraine .. " seed in inventory!")
        return
    end

    -- Déduire la graine de l'inventaire
    data.graines[rareteGraine] = data.graines[rareteGraine] - 1

    potData.graine       = rareteGraine
    potData.stage        = 0
    potData.tempsRestant = 0

    local AS = getAssignation()
    local baseIndex = AS and AS.GetBaseIndex(player)
    if not baseIndex then
        notifier(player, "ERROR", "❌ No base assigned!")
        -- Rembourser la graine
        data.graines[rareteGraine] = (data.graines[rareteGraine] or 0) + 1
        potData.graine = nil
        return
    end

    FlowerPotSystem.LancerCroissance(player, baseIndex, potIndex, data)

    -- Mettre à jour le prompt
    local bases = Workspace:FindFirstChild("Bases")
    local base  = bases and bases:FindFirstChild("Base_" .. baseIndex)
    local pm    = base and base:FindFirstChild("FlowerPot_" .. potIndex)
    if pm then pcall(majPromptPot, pm, potData, potIndex) end

    notifier(player, "INFO",
        "🌱 " .. rareteGraine .. " seed planted in Pot " .. potIndex .. "!")
    majHUD(player)
end

-- ============================================================
-- API publique — Récolter le BR Mutant
-- ============================================================

function FlowerPotSystem.Recolter(player, potIndex)
    local data = GetData(player)
    if not data or not data.pots then return end

    local potData   = data.pots[potIndex]
    if not potData or not potData.graine or potData.stage < 4 then
        notifier(player, "ERROR", "❌ Mutant not ready yet!")
        return
    end

    local graineCfg = FPConfig.graines[potData.graine]
    if not graineCfg then
        notifier(player, "ERROR", "❌ Invalid seed config!")
        return
    end

    local rarete  = graineCfg.rareteResult
    local multVal = graineCfg.multiplicateur

    -- Clone un BR depuis Brainrots existants avec effets Mutant appliqués par script
    local function clonerBRMutant(rareteNom)
        local brainrots = ServerStorage:FindFirstChild("Brainrots")
        local dossier   = brainrots and brainrots:FindFirstChild(rareteNom)
        if not dossier then
            warn("[FlowerPot] Dossier Brainrots/" .. rareteNom .. " introuvable")
            return nil
        end
        local modeles = dossier:GetChildren()
        if #modeles == 0 then
            warn("[FlowerPot] Aucun modèle dans Brainrots/" .. rareteNom)
            return nil
        end

        local clone = nil
        pcall(function() clone = modeles[math.random(1, #modeles)]:Clone() end)
        if not clone then return nil end

        -- Scale ×2 + ancrer toutes les parts
        for _, part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.Size       = part.Size * 2
                    part.Anchored   = true
                    part.CanCollide = false
                end)
            end
        end

        -- Teinte arc-en-ciel aléatoire (3 couleurs Mutant)
        local couleurs = {
            Color3.fromRGB(255, 215, 0),   -- doré
            Color3.fromRGB(255, 100, 255), -- rose
            Color3.fromRGB(100, 200, 255), -- bleu clair
        }
        for _, part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.Color = couleurs[math.random(1, #couleurs)]
                end)
            end
        end

        -- PointLight doré + particules sur la part principale
        local rootPart = nil
        if clone:IsA("Model") then
            rootPart = clone.PrimaryPart
                    or clone:FindFirstChild("RootPart")
                    or clone:FindFirstChildWhichIsA("BasePart")
        elseif clone:IsA("BasePart") then
            rootPart = clone
        end
        if rootPart then
            pcall(function()
                local light = Instance.new("PointLight", rootPart)
                light.Brightness = 4
                light.Range      = 20
                light.Color      = Color3.fromRGB(255, 215, 0)

                local particles = Instance.new("ParticleEmitter", rootPart)
                particles.Rate     = 15
                particles.Lifetime = NumberRange.new(0.5, 1.0)
                particles.Speed    = NumberRange.new(3, 8)
                particles.Color    = ColorSequence.new(
                    Color3.fromRGB(255, 215, 0))
            end)
        end

        -- Tag Mutant pour IncomeSystem
        local tag = Instance.new("StringValue")
        tag.Name   = "MutantTag"
        tag.Value  = "true"
        tag.Parent = clone

        clone.Name = rareteNom .. "_MUTANT"
        return clone
    end

    -- Tenter d'ajouter au carry
    local CS = getCarry()
    if CS then
        local clone = clonerBRMutant(rarete)
        if clone then
            local rareteObj = {
                nom      = rarete,
                dossier  = rarete,
                isMutant = true,
                valeur   = multVal,
            }
            pcall(CS.RamasserBR, player, rareteObj, clone)
        end
    end

    -- Réinitialiser le pot
    local graineName = potData.graine
    potData.graine       = nil
    potData.stage        = 0
    potData.tempsRestant = 0
    potData.instantGrow  = false

    -- Annuler thread de croissance
    local cleThread = player.UserId .. "_" .. potIndex
    if _threads[cleThread] then
        pcall(function() task.cancel(_threads[cleThread]) end)
        _threads[cleThread] = nil
    end

    -- Actualiser visuels
    local AS = getAssignation()
    local baseIndex = AS and AS.GetBaseIndex(player)
    if baseIndex then
        pcall(FlowerPotSystem.ActualiserVisuels, player, baseIndex, potIndex, data)
        local bases = Workspace:FindFirstChild("Bases")
        local base  = bases and bases:FindFirstChild("Base_" .. baseIndex)
        local pm    = base and base:FindFirstChild("FlowerPot_" .. potIndex)
        if pm then
            pcall(majPromptPot, pm, potData, potIndex)
        end
    end

    notifier(player, "SUCCESS",
        "🌟 " .. graineName .. " Mutant harvested! ×" .. multVal .. " income!")
    majHUD(player)
end

-- ============================================================
-- API publique — Croissance instantanée
-- ============================================================

function FlowerPotSystem.InstantGrow(player, potIndex)
    local data = GetData(player)
    if not data or not data.pots then return end

    local potData = data.pots[potIndex]
    if not potData or not potData.graine then
        notifier(player, "ERROR", "❌ No seed in this pot!")
        return
    end
    if potData.stage >= 4 then
        notifier(player, "ERROR", "❌ Already mature!")
        return
    end

    -- Vérification R$ (gamePassId = 0 = TEST seulement)
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

    -- Déclencher croissance instantanée
    potData.instantGrow = true
    notifier(player, "INFO", "⚡ Instant Growth activated for Pot " .. potIndex .. "!")
end

-- ============================================================
-- API publique — Drop de graine lors d'une collecte
-- ============================================================

function FlowerPotSystem.TenterDropGraine(player, rarete)
    local chance = FPConfig.dropChances and FPConfig.dropChances[rarete]
    if not chance then return end
    if math.random() > chance then return end

    local data = GetData(player)
    if not data then return end

    if not data.graines then data.graines = {} end
    data.graines[rarete] = (data.graines[rarete] or 0) + 1

    notifier(player, "INFO", "🌱 " .. rarete .. " Seed dropped!")
    print("[FlowerPotSystem] " .. rarete .. " seed dropped for " .. player.Name)
end

-- ============================================================
-- API publique — Init joueur
-- ============================================================

function FlowerPotSystem.Init(player, baseIndex, playerData)
    -- Initialiser playerData.pots si absent
    if not playerData.pots then
        playerData.pots = {}
        for i = 1, 4 do
            playerData.pots[i] = {
                debloque     = (i == 1),
                graine       = nil,
                stage        = 0,
                tempsRestant = 0,
                instantGrow  = false,
            }
        end
    end

    -- Initialiser playerData.graines si absent
    if not playerData.graines then
        playerData.graines = {
            COMMON    = 0,
            RARE      = 0,
            EPIC      = 0,
            LEGENDARY = 0,
        }
    end

    local bases = Workspace:FindFirstChild("Bases")
    if not bases then return end
    local base = bases:FindFirstChild("Base_" .. baseIndex)
    if not base then return end

    for i = 1, 4 do
        local potModel = base:FindFirstChild("FlowerPot_" .. i)
        if potModel then
            local potData = playerData.pots[i]
            if not potData then
                playerData.pots[i] = {
                    debloque     = (i == 1),
                    graine       = nil,
                    stage        = 0,
                    tempsRestant = 0,
                    instantGrow  = false,
                }
                potData = playerData.pots[i]
            end

            if potData.debloque then
                -- Supprimer billboard verrou si présent
                pcall(supprimerBillboardVerrouille, potModel)
                -- Visuels de croissance
                pcall(FlowerPotSystem.ActualiserVisuels,
                    player, baseIndex, i, playerData)
                -- ProximityPrompt
                pcall(FlowerPotSystem.CreerProximityPrompt,
                    player, potModel, i, baseIndex)
                -- Reprendre croissance si en cours
                if potData.graine and potData.stage < 4 then
                    FlowerPotSystem.LancerCroissance(
                        player, baseIndex, i, playerData)
                end
            else
                -- Afficher verrouillage + prompt déblocage
                pcall(afficherBillboardVerrouille, potModel, i)
                pcall(FlowerPotSystem.CreerProximityPromptDebloque,
                    player, potModel, i, baseIndex)
            end
        end
    end

    print("[FlowerPotSystem] Base_" .. baseIndex
        .. " initialized for " .. player.Name .. " ✓")
end

-- ProximityPrompt de déblocage (pots non débloqués)
function FlowerPotSystem.CreerProximityPromptDebloque(
    player, potModel, potIndex, baseIndex)

    local potPart = getPotPart(potModel)
    if not potPart then return end

    local existing = potPart:FindFirstChildOfClass("ProximityPrompt")
    if existing then pcall(function() existing:Destroy() end) end

    local potCfg = FPConfig.pots[potIndex]
    local prompt = Instance.new("ProximityPrompt")
    local prixLabel = ""
    if potCfg.prixCoins and potCfg.prixCoins > 0 then
        prixLabel = potCfg.prixCoins .. " 💰"
    elseif potCfg.prixRobux and potCfg.prixRobux > 0 then
        prixLabel = potCfg.prixRobux .. " R$"
    end
    prompt.ActionText            = "Unlock"
    prompt.ObjectText            = "🔒 Pot " .. potIndex .. " — " .. prixLabel
    prompt.KeyboardKeyCode       = Enum.KeyCode.F
    prompt.MaxActivationDistance = 8
    prompt.HoldDuration          = 0
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = potPart

    prompt.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer ~= player then return end
        if OuvrirPot then
            pcall(function()
                OuvrirPot:FireClient(player, potIndex, "debloque", {})
            end)
        end
    end)
end

-- ============================================================
-- Init serveur (appelé depuis Main.server.lua section 6)
-- ============================================================

function FlowerPotSystem.InitServeur()
    -- Créer les RemoteEvents
    NotifEvent     = getRemote("NotifEvent")
    UpdateHUD      = getRemote("UpdateHUD")
    OuvrirPot      = getRemote("OuvrirPot")
    PlanterGraine  = getRemote("PlanterGraine")
    DebloquerPotEv = getRemote("DebloquerPot")
    InstantGrowEv  = getRemote("InstantGrowPot")

    -- Écouter les actions client
    PlanterGraine.OnServerEvent:Connect(function(player, potIndex, rarete)
        if type(potIndex) ~= "number" or type(rarete) ~= "string" then return end
        FlowerPotSystem.Planter(player, potIndex, rarete)
    end)

    DebloquerPotEv.OnServerEvent:Connect(function(player, potIndex)
        if type(potIndex) ~= "number" then return end
        FlowerPotSystem.DebloquerPot(player, potIndex)
    end)

    InstantGrowEv.OnServerEvent:Connect(function(player, potIndex)
        if type(potIndex) ~= "number" then return end
        FlowerPotSystem.InstantGrow(player, potIndex)
    end)

    print("[FlowerPotSystem] ✓ Server initialized")
end

return FlowerPotSystem
