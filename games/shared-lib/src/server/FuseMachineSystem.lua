-- shared-lib/src/server/FuseMachineSystem.lua
-- Système Fuse Machine — partagé entre jeux
-- Logique serveur : 4 slots, timer configurable, 1 fusion par machine, anti-doublon
-- FuseConfig injecté via Init(fuseConfig)

local FuseMachineSystem = {}

-- ═══════════════════════════════════════════════
-- Services
-- ═══════════════════════════════════════════════
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Logger            = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

-- ═══════════════════════════════════════════════
-- Config (injectée via Init)
-- ═══════════════════════════════════════════════
local FuseConfig = nil

-- ═══════════════════════════════════════════════
-- Callbacks injectés par Main.server.lua
-- ═══════════════════════════════════════════════
-- function(player) → number (coins actuels)
FuseMachineSystem.GetCoins    = nil
-- function(player, montant) → nil
FuseMachineSystem.DeductCoins = nil
-- function(player) → nil  (rafraîchit le HUD)
FuseMachineSystem.UpdateHUD   = nil

-- ═══════════════════════════════════════════════
-- État interne par machine (clé = Instance machine)
-- ═══════════════════════════════════════════════
local machineEtats = {}

-- RemoteEvents (assignés dans Init)
local OuvrirUI    -- server → client : ouvre l'UI
local FermerUI    -- server → client : ferme l'UI
local EtatUpdate  -- server → client : mise à jour timer/état
local Lancer      -- client → server : lance une fusion

-- ═══════════════════════════════════════════════
-- Utilitaires
-- ═══════════════════════════════════════════════

local function creerRemoteEvent(nom)
    local existing = ReplicatedStorage:FindFirstChild(nom)
    if existing then return existing end
    local re = Instance.new("RemoteEvent")
    re.Name   = nom
    re.Parent = ReplicatedStorage
    return re
end

local function notifier(player, type_, msg)
    local ev = ReplicatedStorage:FindFirstChild("NotifEvent")
    if ev then pcall(function() ev:FireClient(player, type_, msg) end) end
end

local function getPartMachine(machine)
    if machine:IsA("BasePart") then return machine end
    if machine:IsA("Model") and machine.PrimaryPart then return machine.PrimaryPart end
    return machine:FindFirstChildWhichIsA("BasePart", true)
end

local function trierInputs(liste)
    local copie = {}
    for _, v in ipairs(liste) do copie[#copie + 1] = v end
    table.sort(copie)
    return copie
end

local function inputsEgaux(a, b)
    if #a ~= #b then return false end
    for i, v in ipairs(a) do
        if v ~= b[i] then return false end
    end
    return true
end

local function trouverRecette(raretes)
    local tries = trierInputs(raretes)
    for _, recette in ipairs(FuseConfig.Recettes) do
        if inputsEgaux(tries, trierInputs(recette.inputs)) then
            return recette
        end
    end
    return nil
end

local function tirerResultat(recette)
    local rand = math.random(1, 100)
    local cumul = 0
    for _, sortie in ipairs(recette.outputs) do
        cumul = cumul + sortie.chance
        if rand <= cumul then return sortie.rarete end
    end
    return recette.outputs[1].rarete
end

local function donnerToolResultat(player, rarete)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return end

    local couleur = FuseConfig.CouleurRarete[rarete] or Color3.fromRGB(200, 200, 200)
    local nom     = "Fused " .. rarete

    local tool = Instance.new("Tool")
    tool.Name           = nom
    tool.ToolTip        = "[" .. rarete .. "] " .. nom
    tool.CanBeDropped   = false
    tool.RequiresHandle = true
    tool:SetAttribute("Rarete",       rarete)
    tool:SetAttribute("BrainrotName", nom)
    tool:SetAttribute("IsFused",      true)

    local handle = Instance.new("Part")
    handle.Name         = "Handle"
    handle.Shape        = Enum.PartType.Ball
    handle.Size         = Vector3.new(1, 1, 1)
    handle.Color        = couleur
    handle.Material     = Enum.Material.Neon
    handle.Transparency = 0
    handle.Anchored     = false
    handle.CanCollide   = false
    handle.Parent       = tool

    local sparkles = Instance.new("Sparkles")
    sparkles.SparkleColor = couleur
    sparkles.Parent       = handle

    tool.Parent = backpack
    return tool
end

-- ═══════════════════════════════════════════════
-- Gestion cycle de vie d'une machine
-- ═══════════════════════════════════════════════

local function reinitialiserMachine(machine)
    local etat = machineEtats[machine]
    if not etat then return end

    if etat.promptCollecte and etat.promptCollecte.Parent then
        etat.promptCollecte:Destroy()
        etat.promptCollecte = nil
    end

    etat.actif         = false
    etat.joueurId      = nil
    etat.debutFusion   = nil
    etat.inputRaretes  = {}
    etat.outputRarete  = nil
    etat.recetteId     = nil

    if etat.promptOuvrir and etat.promptOuvrir.Parent then
        etat.promptOuvrir.Enabled = true
    end

    EtatUpdate:FireAllClients(machine, { actif = false })

    Logger.debug("Fuse", "Machine réinitialisée : %s", machine.Name)
end

local function creerPromptCollecte(machine)
    local etat = machineEtats[machine]
    if not etat then return end

    if etat.promptOuvrir and etat.promptOuvrir.Parent then
        etat.promptOuvrir.Enabled = false
    end

    local part = getPartMachine(machine)
    if not part then
        Logger.warn("Fuse", "Pas de BasePart pour le prompt collecte : %s", machine.Name)
        return
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText            = "Collecter"
    prompt.ObjectText            = etat.outputRarete .. " (Fusionné)"
    prompt.HoldDuration          = 0
    prompt.MaxActivationDistance = 10
    prompt.Parent                = part

    etat.promptCollecte = prompt

    local conn
    conn = prompt.Triggered:Connect(function(player)
        local e = machineEtats[machine]
        if not e or e.promptCollecte ~= prompt then
            conn:Disconnect()
            return
        end

        if player.UserId ~= e.joueurId then
            notifier(player, "ERREUR", "Ce n'est pas votre fusion !")
            return
        end

        conn:Disconnect()
        prompt:Destroy()
        etat.promptCollecte = nil

        donnerToolResultat(player, e.outputRarete)

        notifier(player, "SUCCESS",
            "Fusion terminée ! Vous obtenez : " .. e.outputRarete)

        Logger.info("Fuse", "%s collecte : %s", player.Name, e.outputRarete)

        reinitialiserMachine(machine)
    end)
end

local function demarrerTimer(machine)
    local etat = machineEtats[machine]
    if not etat then return end

    task.delay(FuseConfig.DureeFusion, function()
        local e = machineEtats[machine]
        if not e or not e.actif then return end

        Logger.info("Fuse", "Fusion terminée sur %s", machine.Name)

        creerPromptCollecte(machine)

        local joueur = Players:GetPlayerByUserId(e.joueurId)
        if joueur then
            notifier(joueur, "INFO",
                "Fusion prête ! Retournez collecter votre " .. e.outputRarete)

            EtatUpdate:FireClient(joueur, machine, {
                actif        = true,
                termine      = true,
                outputRarete = e.outputRarete,
            })
        end
    end)
end

local function setupMachine(machine)
    Logger.debug("Fuse", "setupMachine → %s | Classe : %s | Parent : %s",
        machine.Name, machine.ClassName, tostring(machine.Parent and machine.Parent.Name))

    local part = getPartMachine(machine)
    if not part then
        Logger.warn("Fuse", "Aucune BasePart trouvée pour : %s", machine.Name)
        return
    end

    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("ProximityPrompt") and child.ObjectText == "Fuse Machine" then
            child:Destroy()
        end
    end

    machineEtats[machine] = {
        actif          = false,
        joueurId       = nil,
        debutFusion    = nil,
        inputRaretes   = {},
        outputRarete   = nil,
        recetteId      = nil,
        promptOuvrir   = nil,
        promptCollecte = nil,
    }

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText            = "Fusionner"
    prompt.ObjectText            = "Fuse Machine"
    prompt.HoldDuration          = 0
    prompt.MaxActivationDistance = 20
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = part

    machineEtats[machine].promptOuvrir = prompt

    prompt.Triggered:Connect(function(player)
        Logger.debug("Fuse", "Prompt déclenché par %s sur %s", player.Name, machine.Name)
        local etat = machineEtats[machine]
        if not etat then return end

        OuvrirUI:FireClient(player, machine, {
            actif        = etat.actif,
            debutFusion  = etat.debutFusion,
            dureeFusion  = FuseConfig.DureeFusion,
            inputRaretes = etat.inputRaretes,
            outputRarete = etat.outputRarete,
            recetteId    = etat.recetteId,
            joueurId     = etat.joueurId,
        }, FuseConfig.Recettes)
    end)
end

-- ═══════════════════════════════════════════════
-- Gestionnaire client → serveur : lancer une fusion
-- ═══════════════════════════════════════════════

local function onLancerFusion(player, machine, toolInstances)
    if not machine or not machine.Parent then return end
    local etat = machineEtats[machine]
    if not etat then
        Logger.warn("Fuse", "Machine non gérée reçue de %s", player.Name)
        return
    end

    if etat.actif then
        notifier(player, "ERREUR", "Cette machine est déjà en cours de fusion !")
        return
    end

    if type(toolInstances) ~= "table" or #toolInstances ~= FuseConfig.NbSlots then
        notifier(player, "ERREUR", "Sélection invalide (4 Brainrots requis).")
        return
    end

    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return end

    local raretes = {}
    for _, tool in ipairs(toolInstances) do
        if not tool or not tool:IsA("Tool") or tool.Parent ~= backpack then
            notifier(player, "ERREUR", "Un Brainrot sélectionné est invalide.")
            return
        end
        local rarete = tool:GetAttribute("Rarete")
        if not rarete then
            notifier(player, "ERREUR", "Un Brainrot n'a pas d'attribut Rareté.")
            return
        end
        raretes[#raretes + 1] = rarete
    end

    local recette = trouverRecette(raretes)
    if not recette then
        notifier(player, "ERREUR", "Pas de recette pour cette combinaison !")
        return
    end

    local coins = FuseMachineSystem.GetCoins and FuseMachineSystem.GetCoins(player) or 0
    if coins < recette.cout then
        notifier(player, "ERREUR",
            "Pas assez de coins ! Requis : " .. recette.cout .. " · Vous avez : " .. coins)
        return
    end

    -- ═══ Tout est valide — on commence la fusion ═══

    for _, tool in ipairs(toolInstances) do
        tool:Destroy()
    end

    if FuseMachineSystem.DeductCoins then
        FuseMachineSystem.DeductCoins(player, recette.cout)
    end
    if FuseMachineSystem.UpdateHUD then
        FuseMachineSystem.UpdateHUD(player)
    end

    local outputRarete = tirerResultat(recette)

    etat.actif        = true
    etat.joueurId     = player.UserId
    etat.debutFusion  = tick()
    etat.inputRaretes = raretes
    etat.outputRarete = outputRarete
    etat.recetteId    = recette.id

    if etat.promptOuvrir and etat.promptOuvrir.Parent then
        etat.promptOuvrir.Enabled = false
    end

    FermerUI:FireClient(player)

    notifier(player, "INFO", "Fusion lancée ! Revenez dans 1h30 !")

    EtatUpdate:FireAllClients(machine, {
        actif       = true,
        debutFusion = etat.debutFusion,
        dureeFusion = FuseConfig.DureeFusion,
        termine     = false,
    })

    demarrerTimer(machine)

    Logger.info("Fuse", "Fusion lancée par %s | Recette : %s | Résultat : %s",
        player.Name, recette.id, outputRarete)
end

-- ═══════════════════════════════════════════════
-- Init
-- ═══════════════════════════════════════════════

function FuseMachineSystem.Init(fuseConfig)
    assert(fuseConfig, "[FuseMachineSystem] fuseConfig requis — passer require(FuseConfig) dans Init()")
    FuseConfig = fuseConfig

    OuvrirUI   = creerRemoteEvent("FuseMachine_OuvrirUI")
    FermerUI   = creerRemoteEvent("FuseMachine_FermerUI")
    EtatUpdate = creerRemoteEvent("FuseMachine_EtatUpdate")
    Lancer     = creerRemoteEvent("FuseMachine_Lancer")

    Lancer.OnServerEvent:Connect(onLancerFusion)

    CollectionService:GetInstanceAddedSignal(FuseConfig.MachineTag):Connect(function(machine)
        Logger.debug("Fuse", "Nouvelle machine détectée : %s", machine.Name)
        setupMachine(machine)
    end)
    CollectionService:GetInstanceRemovedSignal(FuseConfig.MachineTag):Connect(function(machine)
        machineEtats[machine] = nil
    end)

    local tagged = CollectionService:GetTagged(FuseConfig.MachineTag)
    Logger.debug("Fuse", "Scan tag '%s' → %d machine(s)", FuseConfig.MachineTag, #tagged)

    for _, machine in ipairs(tagged) do
        if not machineEtats[machine] then
            setupMachine(machine)
        end
    end

    Logger.info("Fuse", "Système initialisé ✓ (%d machine(s))", #tagged)
end

return FuseMachineSystem
