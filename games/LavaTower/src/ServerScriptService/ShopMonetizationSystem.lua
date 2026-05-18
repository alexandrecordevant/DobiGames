-- ServerScriptService/ShopMonetizationSystem.lua
-- Shop monetisation LavaTower : Cash, Lucky Blocks, Pack Demarrage, Luck
-- Declencheur : Part/Model avec attribut booleen "ShopMonet" = true dans le workspace

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerStorage       = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace           = game:GetService("Workspace")
local Logger              = require(ServerScriptService.SharedLib.Server.Logger)

local Config = require(ReplicatedStorage.Modules.GameConfig)

local ShopMonetizationSystem = {}

-- -- Callbacks injectes depuis Main.server.lua ---------------------------------
ShopMonetizationSystem.GetData        = nil  -- function(player) -> data
ShopMonetizationSystem.SetData        = nil  -- function(player, data)
ShopMonetizationSystem.UpdateHUD      = nil  -- function(player)
ShopMonetizationSystem.NotifEvent     = nil  -- RemoteEvent
ShopMonetizationSystem.GetBaseJoueur  = nil  -- function(player) -> baseIndex
ShopMonetizationSystem.GetSpotsActifs = nil  -- function(player) -> liste de spots
ShopMonetizationSystem.AjouterAuCarry             = nil  -- function(player, clone, rareteObj)
ShopMonetizationSystem.GetSpotsLibres             = nil  -- function(player) -> {touchPart}
ShopMonetizationSystem.DeposerBRDirect            = nil  -- function(player, tp, rarete, cps) -> bool
ShopMonetizationSystem.GetSpotsOccupesSerialisables = nil  -- function(player) -> {[key] = {valeurSec,...}}
ShopMonetizationSystem.GetCarryLibres             = nil  -- function(player) -> number (slots carry libres)
ShopMonetizationSystem.OnVIPAchete                = nil  -- function(player) -> appelé après achat VIP

-- -- RemoteEvents --------------------------------------------------------------
local ShopMonetOpen
local ShopMonetPurchase
local ShopMonetRefresh
local LuckTimerUpdate

-- -- Etat serveur global Luck --------------------------------------------------
local serverLuck            = 1
local luckSecondesRestantes = 0
local luckPalierActuel      = 0   -- index dans Config.Shop.Luck.Paliers (0 = aucun)

local promptsAjoutes = {}  -- eviter les doublons de ProximityPrompt

-- -- Utilitaires ---------------------------------------------------------------

local function creerRemoteEvent(nom)
    local e = ReplicatedStorage:FindFirstChild(nom)
    if e then return e end
    e = Instance.new("RemoteEvent")
    e.Name   = nom
    e.Parent = ReplicatedStorage
    return e
end

-- Resoudre un chemin de dossier separe par des points
-- ex: "ReplicatedStorage.LuckyBlocks.Tier_1" -> Instance
local function resoudreDossier(chemin)
    local parties = {}
    for partie in chemin:gmatch("[^%.]+") do
        table.insert(parties, partie)
    end
    if #parties == 0 then return nil end
    local ok, svc = pcall(function() return game:GetService(parties[1]) end)
    if not ok or not svc then return nil end
    local noeud = svc
    for i = 2, #parties do
        if not noeud then return nil end
        noeud = noeud:FindFirstChild(parties[i])
    end
    return noeud
end

-- Revenu/s = somme des valeurSec de tous les spots occupes
local function calculerRevenuParSeconde(player)
    local getSpotsOccupes = ShopMonetizationSystem.GetSpotsOccupesSerialisables
    if not getSpotsOccupes then return 0 end
    local spots = getSpotsOccupes(player)
    local total = 0
    for _, info in pairs(spots) do
        total = total + (info.valeurSec or 0)
    end
    return total
end

-- Set des touchParts actifs (debloques) pour ce joueur
local function getSetActifs(player)
    local actifs = ShopMonetizationSystem.GetSpotsActifs and
                   ShopMonetizationSystem.GetSpotsActifs(player) or {}
    local set = {}
    for _, tp in ipairs(actifs) do set[tp] = true end
    return set
end

-- Premier touchPart actif (debloque) + libre selon DropSystem
local function trouverSlotLibre(player)
    local getLibres = ShopMonetizationSystem.GetSpotsLibres
    local libres    = getLibres and getLibres(player) or {}
    local setActifs = getSetActifs(player)
    -- Priorite : slot actif debloque
    for _, tp in ipairs(libres) do
        if setActifs[tp] then return tp end
    end
    -- Repli si GetSpotsActifs vide
    if #libres > 0 then return libres[1] end
    return nil
end

-- Nombre de modeles dans le dossier Pack (cache apres premier appel)
local _packNbItems = nil
local function compterItemsPack()
    if _packNbItems then return _packNbItems end
    local shopCfg = Config and Config.Shop
    if not shopCfg or not shopCfg.PackDemarrage then return 0 end
    local dossier = resoudreDossier(shopCfg.PackDemarrage.BrainrotsFolder)
    if not dossier then return 0 end
    local n = 0
    for _, enfant in ipairs(dossier:GetChildren()) do
        if enfant:IsA("Model") or enfant:IsA("BasePart") then n = n + 1 end
    end
    _packNbItems = n
    return n
end

-- Nombre de slots actifs libres
local function calculerSlotsLibres(player)
    local getLibres = ShopMonetizationSystem.GetSpotsLibres
    local libres    = getLibres and getLibres(player) or {}
    local setActifs = getSetActifs(player)
    local n = 0
    for _, tp in ipairs(libres) do
        if setActifs[tp] then n = n + 1 end
    end
    return n > 0 and n or #libres
end

-- Construire le payload envoye au client
local function makePayload(player)
    local data = ShopMonetizationSystem.GetData(player)
    if not data then return {} end

    return {
        coins            = data.coins or 0,
        packAchete       = data.packAchete or false,
        hasVIP           = data.hasVIP or false,
        serverLuck       = serverLuck,
        luckSecondes     = luckSecondesRestantes,
        luckPalierActuel = luckPalierActuel,
        revenuParSeconde = calculerRevenuParSeconde(player),
        slotsLibres      = calculerSlotsLibres(player),
        carryLibres      = ShopMonetizationSystem.GetCarryLibres and ShopMonetizationSystem.GetCarryLibres(player) or 0,
        packNbItems      = compterItemsPack(),
    }
end

-- -- Achat CASH ----------------------------------------------------------------

local function traiterAchatCash(player, index)
    local shopCfg = Config.Shop
    if not shopCfg or not shopCfg.Cash then return false, "Config Cash manquante" end
    local cfg = shopCfg.Cash[index]
    if not cfg then return false, "Offre Cash invalide" end

    local data = ShopMonetizationSystem.GetData(player)
    if not data then return false, "Donnees introuvables" end

    local revenu  = calculerRevenuParSeconde(player)
    local montant = math.max(cfg.minCash or 0, math.floor(revenu * cfg.multiplicateur))

    data.coins = (data.coins or 0) + montant
    ShopMonetizationSystem.SetData(player, data)
    ShopMonetizationSystem.UpdateHUD(player)

    Logger.info("Shop", "%s achat Cash [%s] : +%d coins (revenu %d/s)",
        player.Name, cfg.label, montant, revenu)
    return true, "+" .. tostring(montant) .. " coins !"
end

-- -- Achat LUCKY BLOCK ---------------------------------------------------------

local function traiterAchatLuckyBlock(player, index)
    local shopCfg = Config.Shop
    if not shopCfg or not shopCfg.LuckyBlocks then return false, "Config LuckyBlocks manquante" end
    local cfg = shopCfg.LuckyBlocks[index]
    if not cfg then return false, "Lucky Block invalide" end

    local data = ShopMonetizationSystem.GetData(player)
    if not data then return false, "Donnees introuvables" end

    local ajouterAuCarry = ShopMonetizationSystem.AjouterAuCarry
    if not ajouterAuCarry then
        Logger.warn("Shop", "[LuckyBlock] AjouterAuCarry non injecte")
        return false, "Systeme non initialise"
    end

    local getCarryLibres = ShopMonetizationSystem.GetCarryLibres
    if getCarryLibres and getCarryLibres(player) <= 0 then
        return false, "Carry plein"
    end

    -- Modele Lucky Block : ReplicatedStorage/LuckyBlocks/Tier_[index]/LuckyBlock
    local lbFolder   = ReplicatedStorage:FindFirstChild("LuckyBlocks")
    local tierFolder = lbFolder and lbFolder:FindFirstChild("Tier_" .. index)
    local lbSource   = tierFolder and tierFolder:FindFirstChild("Lucky Block")

    if not lbSource then
        Logger.warn("Shop", "LuckyBlock introuvable : LuckyBlocks/Tier_%d/LuckyBlock", index)
        return false, "Modele Lucky Block introuvable"
    end

    local clone = nil
    pcall(function() clone = lbSource:Clone() end)
    if not clone then
        return false, "Erreur clonage Lucky Block"
    end

    -- Attributs lus par LuckyBlockSystem quand le modele est depose sur un slot
    clone:SetAttribute("IsLuckyBlock", true)
    clone:SetAttribute("Tier",         index)
    clone:SetAttribute("OwnerUserId",  player.UserId)
    clone.Parent = ReplicatedStorage

    -- "LuckyBlock_N" encode le tier dans la rarete pour permettre la restauration precise
    -- des slots et du carry lors d un rejoin. Evite le SellConfirmCallback.
    local rareteObj = { nom = "LuckyBlock_" .. index, dossier = "LuckyBlock_" .. index, isMutant = false, valeur = 0 }
    local ok, err = pcall(ajouterAuCarry, player, clone, rareteObj)
    if not ok then
        pcall(function() clone:Destroy() end)
        Logger.warn("Shop", "%s LuckyBlock carry echec : %s", player.Name, tostring(err))
        return false, "Carry plein"
    end

    Logger.info("Shop", "%s achat Lucky Block [%s] -> carry", player.Name, cfg.nom)
    return true, "Lucky Block " .. cfg.nom .. " dans votre toolbar !"
end

-- -- Achat PACK DEMARRAGE -----------------------------------------------------

local function traiterAchatPack(player)
    local shopCfg = Config.Shop
    if not shopCfg or not shopCfg.PackDemarrage then return false, "Config Pack manquante" end
    local cfg = shopCfg.PackDemarrage

    local data = ShopMonetizationSystem.GetData(player)
    if not data then return false, "Donnees introuvables" end

    if data.packAchete then
        return false, "Pack deja achete"
    end

    -- Resoudre le dossier Pack
    local dossier = resoudreDossier(cfg.BrainrotsFolder)
    if not dossier then
        Logger.warn("Shop", "Dossier Pack introuvable : %s", tostring(cfg.BrainrotsFolder))
        return false, "Dossier Pack introuvable"
    end

    local getCarryLibres = ShopMonetizationSystem.GetCarryLibres
    local nbItems = compterItemsPack()
    if getCarryLibres and getCarryLibres(player) < nbItems then
        return false, "Inventory full"
    end

    local ajouterAuCarry = ShopMonetizationSystem.AjouterAuCarry
    -- Donner les Brainrots directement dans la toolbar du joueur
    local nbDonnes = 0
    for _, enfant in ipairs(dossier:GetChildren()) do
        if enfant:IsA("Model") or enfant:IsA("BasePart") then
            local rarete = enfant:GetAttribute("Rarete") or "Common"
            local cps    = enfant:GetAttribute("CashParSeconde") or 0
            local clone  = nil
            pcall(function() clone = enfant:Clone() end)
            if clone and ajouterAuCarry then
                clone.Parent = ReplicatedStorage
                local rareteObj = { nom = rarete, dossier = rarete, isMutant = false, valeur = cps }
                local ok = pcall(ajouterAuCarry, player, clone, rareteObj)
                if ok then
                    nbDonnes = nbDonnes + 1
                else
                    pcall(function() clone:Destroy() end)
                    Logger.warn("Shop", "Pack AjouterAuCarry echec pour %s", player.Name)
                end
            end
        end
    end

    -- Ajouter les coins et marquer comme achete
    data.coins     = (data.coins or 0) + cfg.Cash
    data.packAchete = true
    ShopMonetizationSystem.SetData(player, data)
    ShopMonetizationSystem.UpdateHUD(player)

    Logger.info("Shop", "%s achat Pack Demarrage : +%d coins + %d brainrots",
        player.Name, cfg.Cash, nbDonnes)
    return true, "Pack obtenu ! +" .. tostring(cfg.Cash) .. " coins + Brainrots !"
end

-- -- Achat PACK VIP ------------------------------------------------------------

local function traiterAchatPackVIP(player)
    local shopCfg = Config and Config.Shop
    if not shopCfg or not shopCfg.PackVIP then return false, "Config PackVIP manquante" end
    local cfg = shopCfg.PackVIP

    local data = ShopMonetizationSystem.GetData(player)
    if not data then return false, "Donnees introuvables" end

    if data.hasVIP then
        return false, "Pack VIP deja obtenu"
    end

    data.hasVIP = true
    data.coins  = (data.coins or 0) + cfg.Cash
    ShopMonetizationSystem.SetData(player, data)
    ShopMonetizationSystem.UpdateHUD(player)

    if ShopMonetizationSystem.OnVIPAchete then
        pcall(ShopMonetizationSystem.OnVIPAchete, player)
    end

    Logger.info("Shop", "%s achat PackVIP : VIP + %d coins", player.Name, cfg.Cash)
    return true, "Pack VIP obtenu ! Acces Tour VIP debloque + " .. tostring(cfg.Cash) .. " coins !"
end

-- -- Achat LUCK ----------------------------------------------------------------

local function traiterAchatLuck(player, palierIndex)
    local shopCfg = Config.Shop
    if not shopCfg or not shopCfg.Luck then return false, "Config Luck manquante" end
    local cfg = shopCfg.Luck

    if palierIndex < 1 or palierIndex > #cfg.Paliers then
        return false, "Palier invalide"
    end

    -- Le palier doit etre superieur au palier actuellement actif
    if palierIndex <= luckPalierActuel then
        return false, "Palier deja atteint ou depasse"
    end

    local data = ShopMonetizationSystem.GetData(player)
    if not data then return false, "Donnees introuvables" end

    -- Simuler l'achat (pas de vrai Robux pour l'instant)
    serverLuck            = cfg.Paliers[palierIndex]
    luckSecondesRestantes = cfg.Duree
    luckPalierActuel      = palierIndex
    ServerStorage:SetAttribute("ServerLuck", serverLuck)

    LuckTimerUpdate:FireAllClients(serverLuck, luckSecondesRestantes, luckPalierActuel)

    Logger.info("Shop", "%s achat Luck x%d (palier %d) -- timer %ds",
        player.Name, serverLuck, palierIndex, luckSecondesRestantes)
    return true, "Luck x" .. serverLuck .. " active !"
end

-- -- Boucle timer Luck ---------------------------------------------------------

local function lancerBoucleTimerLuck()
    task.spawn(function()
        while true do
            task.wait(1)
            if luckSecondesRestantes > 0 then
                luckSecondesRestantes = luckSecondesRestantes - 1
                if luckSecondesRestantes <= 0 then
                    luckSecondesRestantes = 0
                    serverLuck            = 1
                    luckPalierActuel      = 0
                    ServerStorage:SetAttribute("ServerLuck", 1)
                    Logger.info("Shop", "Timer Luck expire -- serverLuck reset a 1")
                end
                LuckTimerUpdate:FireAllClients(serverLuck, luckSecondesRestantes, luckPalierActuel)
            end
        end
    end)
end

-- -- Ajout d'un ProximityPrompt sur une Part -----------------------------------

local function ajouterPromptMonet(part)
    if promptsAjoutes[part] then return end
    promptsAjoutes[part] = true

    if part:FindFirstChild("ShopMonetPrompt") then return end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name                  = "ShopMonetPrompt"
    prompt.ActionText            = "Ouvrir"
    prompt.ObjectText            = "Boutique"
    prompt.KeyboardKeyCode       = Enum.KeyCode.F
    prompt.HoldDuration          = 0
    prompt.MaxActivationDistance = 20
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = part

    prompt.Triggered:Connect(function(player)
        ShopMonetOpen:FireClient(player, makePayload(player))
        Logger.debug("Shop", "%s ouverture ShopMonet", player.Name)
    end)

    Logger.debug("Shop", "ShopMonet ProximityPrompt ajoute sur %s", part:GetFullName())
end

-- Trouver la Part cible d'un Model ou BasePart
local function trouverCibleMonet(instance)
    if instance:IsA("Model") then
        if instance.PrimaryPart then return instance.PrimaryPart end
        return instance:FindFirstChildWhichIsA("BasePart", true)
    elseif instance:IsA("BasePart") then
        return instance
    end
    return nil
end

local function verifierAttributMonet(instance)
    if instance:GetAttribute("ShopMonet") ~= true then return end
    local cible = trouverCibleMonet(instance)
    if cible then ajouterPromptMonet(cible) end
end

local function scannerWorkspaceMonet()
    task.wait(1)
    for _, desc in ipairs(Workspace:GetDescendants()) do
        verifierAttributMonet(desc)
    end
    Workspace.DescendantAdded:Connect(function(desc)
        task.wait(0.2)
        verifierAttributMonet(desc)
        if desc:IsA("Model") then
            for _, child in ipairs(desc:GetDescendants()) do
                verifierAttributMonet(child)
            end
        end
    end)
    Logger.debug("Shop", "Scan workspace ShopMonet termine")
end

-- -- Init ---------------------------------------------------------------------

-- Active la luck x2 serveur pour la durée PackVIP (appelé au join VIP et à l'achat)
-- Ne fait rien si le serveur a déjà un palier égal ou supérieur.
function ShopMonetizationSystem.AppliquerLuckVIP()
    local shopCfg = Config and Config.Shop
    if not shopCfg or not shopCfg.Luck then return end
    if luckPalierActuel >= 1 then return end  -- ne pas downgrader

    local duree = shopCfg.PackVIP and shopCfg.PackVIP.LuckDureeSecondes or 900
    serverLuck            = shopCfg.Luck.Paliers[1] or 2
    luckSecondesRestantes = duree
    luckPalierActuel      = 1
    ServerStorage:SetAttribute("ServerLuck", serverLuck)

    if LuckTimerUpdate then
        LuckTimerUpdate:FireAllClients(serverLuck, luckSecondesRestantes, luckPalierActuel)
    end
    Logger.info("Shop", "[VIP] Luck serveur x%d activée pour %ds", serverLuck, duree)
end

function ShopMonetizationSystem.Init()
    local shopCfg = Config and Config.Shop
    if not shopCfg then
        Logger.error("Shop", "Config.Shop manquant -- ShopMonetizationSystem non initialise")
        return
    end

    ShopMonetOpen        = creerRemoteEvent("ShopMonetOpen")
    ShopMonetPurchase    = creerRemoteEvent("ShopMonetPurchase")
    ShopMonetRefresh     = creerRemoteEvent("ShopMonetRefresh")
    LuckTimerUpdate      = creerRemoteEvent("LuckTimerUpdate")
    local ShopMonetOpenRequest = creerRemoteEvent("ShopMonetOpenRequest")

    -- Le client peut demander l'ouverture via le bouton HUD
    ShopMonetOpenRequest.OnServerEvent:Connect(function(player)
        ShopMonetOpen:FireClient(player, makePayload(player))
        Logger.debug("Shop", "%s ouverture ShopMonet (bouton HUD)", player.Name)
    end)

    -- Recevoir les achats du client
    ShopMonetPurchase.OnServerEvent:Connect(function(player, achatType, achatIndex)
        local success, message = false, "Type inconnu"

        if achatType == "Cash" then
            success, message = traiterAchatCash(player, achatIndex)
        elseif achatType == "LuckyBlock" then
            success, message = traiterAchatLuckyBlock(player, achatIndex)
        elseif achatType == "Pack" then
            success, message = traiterAchatPack(player)
        elseif achatType == "PackVIP" then
            success, message = traiterAchatPackVIP(player)
        elseif achatType == "Luck" then
            success, message = traiterAchatLuck(player, achatIndex)
        end

        if ShopMonetizationSystem.NotifEvent then
            local typeNotif = success and "SUCCESS" or "ERREUR"
            ShopMonetizationSystem.NotifEvent:FireClient(player, typeNotif, message)
        end

        ShopMonetRefresh:FireClient(player, makePayload(player))
    end)

    lancerBoucleTimerLuck()
    task.spawn(scannerWorkspaceMonet)

    Logger.info("Shop", "ShopMonetizationSystem initialise")
end

return ShopMonetizationSystem
