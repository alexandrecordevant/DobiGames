-- ServerScriptService/FuseMachineSystem.lua
-- Système Fuse Machine — LavaTower
-- Logique serveur : 4 slots, timer 1h30, 1 fusion par machine, anti-doublon

local FuseMachineSystem = {}

-- ═══════════════════════════════════════════════
-- Services
-- ═══════════════════════════════════════════════
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- ═══════════════════════════════════════════════
-- Config
-- ═══════════════════════════════════════════════
local _RS        = game:GetService("ReplicatedStorage")
local _modules   = _RS:WaitForChild("Modules", 10)
if not _modules then
    error("[FuseMachine] FATAL : ReplicatedStorage.Modules introuvable après 10s")
end
local _fuseConfigModule = _modules:WaitForChild("FuseConfig", 10)
if not _fuseConfigModule then
    error("[FuseMachine] FATAL : FuseConfig introuvable dans Modules après 10s")
end
print("[FuseMachine] FuseConfig trouvé : " .. _fuseConfigModule:GetFullName())
local FuseConfig = require(_fuseConfigModule)

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
-- {
--   actif         : bool
--   joueurId      : number   (UserId du lanceur)
--   debutFusion   : number   (tick())
--   inputRaretes  : string[] (4 raretés)
--   outputRarete  : string   (tiré à l'avance)
--   recetteId     : string
--   promptOuvrir  : ProximityPrompt
--   promptCollecte: ProximityPrompt | nil
-- }
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

-- Retourne la BasePart sur laquelle accrocher un ProximityPrompt
local function getPartMachine(machine)
    if machine:IsA("BasePart") then return machine end
    if machine:IsA("Model") and machine.PrimaryPart then return machine.PrimaryPart end
    return machine:FindFirstChildWhichIsA("BasePart", true)  -- récursif
end

-- Trie une liste de strings (pour comparaison indépendante de l'ordre)
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

-- Trouve la recette correspondant aux 4 raretés (ordre libre)
local function trouverRecette(raretes)
    local tries = trierInputs(raretes)
    for _, recette in ipairs(FuseConfig.Recettes) do
        if inputsEgaux(tries, trierInputs(recette.inputs)) then
            return recette
        end
    end
    return nil
end

-- Tire le résultat selon les probabilités (déterminé au lancement)
local function tirerResultat(recette)
    local rand = math.random(1, 100)
    local cumul = 0
    for _, sortie in ipairs(recette.outputs) do
        cumul = cumul + sortie.chance
        if rand <= cumul then return sortie.rarete end
    end
    return recette.outputs[1].rarete
end

-- Crée un Tool résultat et le place dans le Backpack du joueur
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

    -- Nettoyer le prompt de collecte
    if etat.promptCollecte and etat.promptCollecte.Parent then
        etat.promptCollecte:Destroy()
        etat.promptCollecte = nil
    end

    -- Remettre à zéro l'état
    etat.actif         = false
    etat.joueurId      = nil
    etat.debutFusion   = nil
    etat.inputRaretes  = {}
    etat.outputRarete  = nil
    etat.recetteId     = nil

    -- Réactiver le prompt d'ouverture
    if etat.promptOuvrir and etat.promptOuvrir.Parent then
        etat.promptOuvrir.Enabled = true
    end

    -- Informer les clients que la machine est libre
    EtatUpdate:FireAllClients(machine, { actif = false })

    print("[FuseMachine] Machine réinitialisée : " .. machine.Name)
end

local function creerPromptCollecte(machine)
    local etat = machineEtats[machine]
    if not etat then return end

    -- Désactiver le prompt d'ouverture
    if etat.promptOuvrir and etat.promptOuvrir.Parent then
        etat.promptOuvrir.Enabled = false
    end

    local part = getPartMachine(machine)
    if not part then
        warn("[FuseMachine] Pas de BasePart pour le prompt collecte : " .. machine.Name)
        return
    end

    local icone = FuseConfig.IconeRarete[etat.outputRarete] or "?"
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText            = "Collecter"
    prompt.ObjectText            = icone .. " " .. etat.outputRarete .. " (Fusionné)"
    prompt.HoldDuration          = 0
    prompt.MaxActivationDistance = 10
    prompt.Parent                = part

    etat.promptCollecte = prompt

    -- Seul le lanceur peut collecter (anti-grief)
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

        -- Déconnecter immédiatement (anti-doublon)
        conn:Disconnect()
        prompt:Destroy()
        etat.promptCollecte = nil

        -- Donner le résultat
        donnerToolResultat(player, e.outputRarete)

        local iconeR = FuseConfig.IconeRarete[e.outputRarete] or ""
        notifier(player, "SUCCESS",
            iconeR .. " Fusion terminée ! Vous obtenez : " .. e.outputRarete)

        print("[FuseMachine] " .. player.Name .. " collecte : " .. e.outputRarete)

        reinitialiserMachine(machine)
    end)
end

local function demarrerTimer(machine)
    local etat = machineEtats[machine]
    if not etat then return end

    task.delay(FuseConfig.DureeFusion, function()
        local e = machineEtats[machine]
        if not e or not e.actif then return end

        print("[FuseMachine] Fusion terminée sur " .. machine.Name)

        -- Créer le prompt de collecte
        creerPromptCollecte(machine)

        -- Notifier le joueur s'il est encore connecté
        local joueur = Players:GetPlayerByUserId(e.joueurId)
        if joueur then
            local icone = FuseConfig.IconeRarete[e.outputRarete] or ""
            notifier(joueur, "INFO",
                icone .. " Fusion prête ! Retournez collecter votre " .. e.outputRarete)

            EtatUpdate:FireClient(joueur, machine, {
                actif        = true,
                termine      = true,
                outputRarete = e.outputRarete,
            })
        end
    end)
end

local function setupMachine(machine)
    print("[FuseMachine] setupMachine → " .. machine.Name
        .. " | Classe : " .. machine.ClassName
        .. " | Parent : " .. tostring(machine.Parent and machine.Parent.Name))

    local part = getPartMachine(machine)
    if not part then
        warn("[FuseMachine] ⚠ Aucune BasePart trouvée pour : " .. machine.Name
            .. " — assigne un PrimaryPart ou vérifie la structure du modèle")
        return
    end

    print("[FuseMachine] BasePart cible : " .. part.Name .. " (" .. part.ClassName .. ")")

    -- Supprimer un éventuel prompt résiduel du même nom
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("ProximityPrompt") and child.ObjectText == "🔥 Fuse Machine" then
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

    -- Prompt d'ouverture de l'UI
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText            = "Fusionner"
    prompt.ObjectText            = "🔥 Fuse Machine"
    prompt.HoldDuration          = 0
    prompt.MaxActivationDistance = 20
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = part

    machineEtats[machine].promptOuvrir = prompt

    print("[FuseMachine] ✓ ProximityPrompt créé sur " .. part:GetFullName())

    prompt.Triggered:Connect(function(player)
        print("[FuseMachine] Prompt déclenché par " .. player.Name .. " sur " .. machine.Name)
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
    -- Validation machine
    if not machine or not machine.Parent then return end
    local etat = machineEtats[machine]
    if not etat then
        warn("[FuseMachine] Machine non gérée reçue de " .. player.Name)
        return
    end

    -- Anti-doublon : machine déjà active
    if etat.actif then
        notifier(player, "ERREUR", "Cette machine est déjà en cours de fusion !")
        return
    end

    -- Validation des 4 tools
    if type(toolInstances) ~= "table" or #toolInstances ~= FuseConfig.NbSlots then
        notifier(player, "ERREUR", "Sélection invalide (4 Brainrots requis).")
        return
    end

    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return end

    local raretes = {}
    for _, tool in ipairs(toolInstances) do
        -- Sécurité : le tool DOIT être dans le backpack du joueur
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

    -- Trouver la recette
    local recette = trouverRecette(raretes)
    if not recette then
        notifier(player, "ERREUR", "Pas de recette pour cette combinaison !")
        return
    end

    -- Vérifier les coins
    local coins = FuseMachineSystem.GetCoins and FuseMachineSystem.GetCoins(player) or 0
    if coins < recette.cout then
        notifier(player, "ERREUR",
            "Pas assez de coins ! Requis : " .. recette.cout .. " · Vous avez : " .. coins)
        return
    end

    -- ═══ Tout est valide — on commence la fusion ═══

    -- Consommer les 4 tools
    for _, tool in ipairs(toolInstances) do
        tool:Destroy()
    end

    -- Déduire les coins
    if FuseMachineSystem.DeductCoins then
        FuseMachineSystem.DeductCoins(player, recette.cout)
    end
    if FuseMachineSystem.UpdateHUD then
        FuseMachineSystem.UpdateHUD(player)
    end

    -- Tirer le résultat à l'avance
    local outputRarete = tirerResultat(recette)

    -- Mettre à jour l'état machine
    etat.actif        = true
    etat.joueurId     = player.UserId
    etat.debutFusion  = tick()
    etat.inputRaretes = raretes
    etat.outputRarete = outputRarete
    etat.recetteId    = recette.id

    -- Désactiver le prompt d'ouverture
    if etat.promptOuvrir and etat.promptOuvrir.Parent then
        etat.promptOuvrir.Enabled = false
    end

    -- Fermer l'UI du lanceur
    FermerUI:FireClient(player)

    notifier(player, "INFO", "🔥 Fusion lancée ! Revenez dans 1h30 !")

    -- Informer tous les clients de l'état actif (affichage timer)
    EtatUpdate:FireAllClients(machine, {
        actif       = true,
        debutFusion = etat.debutFusion,
        dureeFusion = FuseConfig.DureeFusion,
        termine     = false,
    })

    -- Démarrer le timer serveur
    demarrerTimer(machine)

    print("[FuseMachine] Fusion lancée par " .. player.Name
        .. " | Recette : " .. recette.id
        .. " | Résultat : " .. outputRarete)
end

-- ═══════════════════════════════════════════════
-- Init
-- ═══════════════════════════════════════════════

function FuseMachineSystem.Init()
    -- Créer les RemoteEvents
    OuvrirUI   = creerRemoteEvent("FuseMachine_OuvrirUI")
    FermerUI   = creerRemoteEvent("FuseMachine_FermerUI")
    EtatUpdate = creerRemoteEvent("FuseMachine_EtatUpdate")
    Lancer     = creerRemoteEvent("FuseMachine_Lancer")

    -- Écouter les demandes de fusion client
    Lancer.OnServerEvent:Connect(onLancerFusion)

    -- Écouter les machines ajoutées (y compris taguées après le démarrage)
    CollectionService:GetInstanceAddedSignal(FuseConfig.MachineTag):Connect(function(machine)
        print("[FuseMachine] Nouvelle machine détectée via signal : " .. machine.Name)
        setupMachine(machine)
    end)
    CollectionService:GetInstanceRemovedSignal(FuseConfig.MachineTag):Connect(function(machine)
        machineEtats[machine] = nil
    end)

    -- Scanner les machines déjà taggées
    local tagged = CollectionService:GetTagged(FuseConfig.MachineTag)
    print("[FuseMachine] Scan tag '" .. FuseConfig.MachineTag .. "' → " .. #tagged .. " machine(s) trouvée(s)")

    for _, machine in ipairs(tagged) do
        -- Ignorer si déjà setup (peut arriver si le signal a tiré avant)
        if not machineEtats[machine] then
            setupMachine(machine)
        else
            print("[FuseMachine] " .. machine.Name .. " déjà setup via signal, ignoré")
        end
    end

    print("[FuseMachine] Système initialisé ✓  (" .. #tagged .. " machine(s))")
end

return FuseMachineSystem
