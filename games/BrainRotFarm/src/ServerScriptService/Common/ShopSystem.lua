-- ServerScriptService/Common/ShopSystem.lua
-- DobiGames — Système de Shop
-- LOGIQUE UNIQUEMENT — toutes les données viennent de GameConfig.ShopUpgrades
-- Supports : ProximityPrompt sur le modèle Shop de chaque base + menu RemoteEvent

local ShopSystem = {}

-- ============================================================
-- Services
-- ============================================================
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService  = game:GetService("MarketplaceService")

-- ============================================================
-- Config — données uniquement, aucune logique ici
-- ============================================================
local Config = require(ReplicatedStorage.Specialized.GameConfig)

-- ============================================================
-- Callback fourni par Main.server.lua (évite les dépendances circulaires)
-- ShopSystem.GetPlayerData = function(player) → playerData ou nil
-- ============================================================
ShopSystem.GetPlayerData = nil

-- ============================================================
-- RemoteEvents (créés dans Init)
-- ============================================================
local OuvrirShop          = nil   -- FireClient(player, donneesShop)
local FermerShop          = nil   -- FireClient(player)
local AchatUpgrade        = nil   -- OnServerEvent(player, nomUpgrade, niveau)
local ShopUpdate          = nil   -- FireClient(player, donneesShop)
local DemandeAchatRobux   = nil   -- OnServerEvent(player, nomUpgrade, niveau) → PromptGamePassPurchase
local ConfirmerGamePass   = nil   -- OnServerEvent(player, gamePassId) → vérification + application
local ChangerSeuilTracteur = nil  -- OnServerEvent(player, seuilNom) → change tracteurSeuilMin

local function creerRemoteEvent(nom)
    local existing = ReplicatedStorage:FindFirstChild(nom)
    if existing then return existing end
    local re = Instance.new("RemoteEvent")
    re.Name   = nom
    re.Parent = ReplicatedStorage
    return re
end

-- ============================================================
-- Ordre de rareté pour comparaisons Tracteur
-- ============================================================
local RARETE_ORDRE = {
    COMMON=1, OG=2, RARE=3, EPIC=4,
    LEGENDARY=5, MYTHIC=6, SECRET=7, BRAINROT_GOD=8,
}

-- ============================================================
-- Chargement différé — évite les dépendances circulaires
-- ============================================================
local _CarrySystem = nil
local function getCarrySystem()
    if not _CarrySystem then
        local ok, m = pcall(require, ServerScriptService.Common.CarrySystem)
        if ok and m then _CarrySystem = m end
    end
    return _CarrySystem
end

local _BrainRotSpawner = nil
local function getBrainRotSpawner()
    if not _BrainRotSpawner then
        local ok, m = pcall(require, ServerScriptService.Specialized.BrainRotSpawner)
        if ok and m then _BrainRotSpawner = m end
    end
    return _BrainRotSpawner
end

local _DropSystem = nil
local function getDropSystem()
    if not _DropSystem then
        local ok, m = pcall(require, ServerScriptService.Common.DropSystem)
        if ok and m then _DropSystem = m end
    end
    return _DropSystem
end

local _CollectSystem = nil
local function getCollectSystem()
    if not _CollectSystem then
        local ok, m = pcall(require, ReplicatedStorage.Common.CollectSystem)
        if ok and m then _CollectSystem = m end
    end
    return _CollectSystem
end

-- ============================================================
-- Accès données joueur (raccourci interne)
-- ============================================================
local function getData(player)
    return ShopSystem.GetPlayerData and ShopSystem.GetPlayerData(player) or nil
end

-- S'assure que la sous-table upgrades existe
local function assurerUpgrades(playerData)
    if not playerData.upgrades then
        playerData.upgrades = {}
    end
end

-- Retourne le niveau actuel d'un upgrade (0 si non acheté)
local function getNiveauActuel(playerData, upgradeConfig)
    if upgradeConfig.isGamePass then
        return playerData[upgradeConfig.dataField] and 1 or 0
    end
    assurerUpgrades(playerData)
    return playerData.upgrades[upgradeConfig.dataField] or 0
end

-- ============================================================
-- Construction des données shop pour le client
-- ============================================================
local function construireDonneesShop(player, playerData)
    assurerUpgrades(playerData)
    return {
        upgrades          = Config.ShopUpgrades,
        playerCoins       = playerData.coins           or 0,
        playerUpgrades    = playerData.upgrades,
        hasTracteur       = playerData.hasTracteur     or false,
        hasLuckyCharm     = playerData.hasLuckyCharm   or false,
        tracteurSeuilMin  = playerData.tracteurSeuilMin or "RARE",
    }
end

-- ============================================================
-- Application des effets — lit depuis niveauConfig.effet (0 valeur hardcodée)
-- ============================================================
local function appliquerEffet(player, playerData, niveauConfig)
    local effet = niveauConfig.effet
    if not effet then return end

    -- WalkSpeed
    if effet.walkSpeed then
        local char = player.Character
        if char and char:FindFirstChild("Humanoid") then
            pcall(function() char.Humanoid.WalkSpeed = effet.walkSpeed end)
        end
        playerData.walkSpeedActuel = effet.walkSpeed
    end

    -- Capacité de carry (délégué à CarrySystem)
    if effet.carryCapacite then
        local CS = getCarrySystem()
        if CS and CS.SetCapacite then
            pcall(CS.SetCapacite, player, effet.carryCapacite)
        end
    end

    -- Multiplicateur spawn (Arroseur — délégué à BrainRotSpawner)
    if effet.spawnRateMultiplier then
        local BRS = getBrainRotSpawner()
        if BRS and BRS.SetSpawnRateMultiplier then
            pcall(BRS.SetSpawnRateMultiplier, player, effet.spawnRateMultiplier)
        end
    end

    -- Rayon de collecte (Aimant — délégué à CarrySystem)
    if effet.rayonCollecte then
        local CS = getCarrySystem()
        if CS and CS.SetRayonAimant then
            pcall(CS.SetRayonAimant, player, effet.rayonCollecte)
        end
    end

    -- Tracteur (démarrer la boucle auto-collect)
    if effet.tracteurActif then
        ShopSystem.ActiverTracteur(player, playerData)
    end

    -- Lucky Charm (délégué à CollectSystem)
    if effet.luckyBonus then
        local ColSys = getCollectSystem()
        if ColSys and ColSys.SetLuckyBonus then
            pcall(ColSys.SetLuckyBonus, player, effet.luckyBonus)
        end
    end
end

-- ============================================================
-- Tracteur — boucle auto-collect
-- ============================================================
local tracteurThreads = {}  -- [userId] = task handle

-- Vérifie si le tracteur peut déposer (spots libres > 0)
local function TracteurPeutDeposer(player)
    local DS = getDropSystem()
    if not DS then return false end
    local libres = DS.GetSpotsLibres(player)
    return libres and #libres > 0
end

function ShopSystem.ActiverTracteur(player, playerData)
    local uid = player.UserId
    if tracteurThreads[uid] then return end  -- déjà actif

    tracteurThreads[uid] = task.spawn(function()
        while player.Parent and playerData.hasTracteur do
            task.wait(3)
            if not player.Parent then break end

            local BRS = getBrainRotSpawner()
            local DS  = getDropSystem()
            if not BRS or not DS then continue end

            -- Vérifier qu'il y a des spots libres
            if not TracteurPeutDeposer(player) then continue end

            -- Trouver le seuil de rareté du joueur
            local seuilNom   = playerData.tracteurSeuilMin or "RARE"
            local seuilOrdre = RARETE_ORDRE[seuilNom] or RARETE_ORDRE["RARE"]

            -- Trouver le BR éligible le plus proche (rareté ≥ seuil)
            local cible = nil
            local ok, res = pcall(BRS.GetPlusProcheEligible, player, seuilOrdre)
            if ok then cible = res end
            if not cible then continue end

            -- Supprimer le BR du terrain
            pcall(BRS.SupprimerCollectible, cible.id, cible.baseIndex)

            -- Trouver un spot libre et y déposer directement
            local libres = DS.GetSpotsLibres(player)
            if #libres == 0 then continue end

            local spot = libres[1]  -- prend le premier spot libre
            pcall(DS.DeposerBRDirect, player, spot, cible.rarete)
        end
        tracteurThreads[uid] = nil
    end)
end

-- ============================================================
-- Réapplication de tous les upgrades achetés
-- Appelé au join et à chaque respawn
-- ============================================================
function ShopSystem.AppliquerTousUpgrades(player, playerData)
    if not playerData then return end
    assurerUpgrades(playerData)

    for _, upgradeConfig in pairs(Config.ShopUpgrades) do
        local niveauActuel = getNiveauActuel(playerData, upgradeConfig)
        if niveauActuel > 0 then
            local niveauConfig = upgradeConfig.niveaux[niveauActuel]
            if niveauConfig then
                pcall(appliquerEffet, player, playerData, niveauConfig)
            end
        end
    end
end

-- ============================================================
-- Confirmation d'achat Game Pass
-- Appelé par MonetizationHandler.CheckGamePasses ou handler ConfirmerGamePass
-- ============================================================
function ShopSystem.ConfirmerAchatGamePass(player, gamePassId)
    local playerData = getData(player)
    if not playerData then return end

    -- Parcourir Config pour trouver l'upgrade lié à ce gamePassId
    for _, upgradeConfig in pairs(Config.ShopUpgrades) do
        for niveau, niveauConfig in pairs(upgradeConfig.niveaux) do
            if type(niveauConfig.gamePassId) == "number"
               and niveauConfig.gamePassId == gamePassId
               and gamePassId > 0 then

                -- Appliquer selon le type (game pass ou upgrade à niveaux)
                if upgradeConfig.isGamePass then
                    playerData[upgradeConfig.dataField] = true
                else
                    assurerUpgrades(playerData)
                    local niveauActuel = playerData.upgrades[upgradeConfig.dataField] or 0
                    if niveau > niveauActuel then
                        playerData.upgrades[upgradeConfig.dataField] = niveau
                    end
                end

                pcall(appliquerEffet, player, playerData, niveauConfig)

                -- Notifier le joueur
                local notif = ReplicatedStorage:FindFirstChild("NotifEvent")
                if notif then
                    pcall(function()
                        notif:FireClient(player, "SUCCESS",
                            "✅ " .. upgradeConfig.icone .. " " .. upgradeConfig.nom .. " activé !")
                    end)
                end

                -- Mettre à jour le shop côté client
                if ShopUpdate then
                    pcall(function()
                        ShopUpdate:FireClient(player, construireDonneesShop(player, playerData))
                    end)
                end

                -- Mettre à jour le HUD
                local UpdateHUD = ReplicatedStorage:FindFirstChild("UpdateHUD")
                if UpdateHUD then
                    pcall(function() UpdateHUD:FireClient(player, playerData) end)
                end

                return  -- trouvé, on arrête
            end
        end
    end
end

-- ============================================================
-- Getter données shop (API publique — pour usage externe)
-- ============================================================
function ShopSystem.GetDonneesShop(player)
    local playerData = getData(player)
    if not playerData then return nil end
    return construireDonneesShop(player, playerData)
end

-- ============================================================
-- Validation et traitement d'un achat en coins (tout validé serveur)
-- ============================================================
local function traiterAchatCoins(player, nomUpgrade, niveauDemande)
    local playerData = getData(player)
    if not playerData then return false, "Données introuvables" end

    -- 1. Lire l'upgrade depuis Config (jamais depuis le client)
    local upgradeConfig = Config.ShopUpgrades[nomUpgrade]
    if not upgradeConfig then return false, "Upgrade inconnu" end

    local niveauConfig = upgradeConfig.niveaux[niveauDemande]
    if not niveauConfig then return false, "Niveau invalide" end

    -- 2. Type doit être "coins" (pas de paiement R$ ici)
    if niveauConfig.type ~= "coins" then
        return false, "Cet upgrade nécessite R$"
    end

    -- 3. Joueur n'a pas déjà ce niveau ou supérieur
    assurerUpgrades(playerData)
    local niveauActuel = playerData.upgrades[upgradeConfig.dataField] or 0
    if niveauActuel >= niveauDemande then
        return false, "Niveau déjà atteint"
    end

    -- 4. Niveau précédent requis (pas de saut de niveau)
    if niveauDemande > 1 and niveauActuel < niveauDemande - 1 then
        return false, "Achète d'abord le niveau précédent"
    end

    -- 5. Vérification des coins
    local prix = niveauConfig.prix
    if (playerData.coins or 0) < prix then
        return false, "Coins insuffisants (" .. prix .. " requis)"
    end

    -- 6. Déduire les coins et sauvegarder le niveau
    playerData.coins = playerData.coins - prix
    playerData.upgrades[upgradeConfig.dataField] = niveauDemande

    -- 7. Appliquer l'effet immédiatement
    pcall(appliquerEffet, player, playerData, niveauConfig)

    return true,
        upgradeConfig.icone .. " " .. upgradeConfig.nom ..
        " Niv." .. niveauDemande .. " acheté !"
end

-- ============================================================
-- ProximityPrompt — Shop dans chaque base
-- ============================================================
local function ajouterPromptShop(shopPart)
    -- Supprimer un prompt existant
    local ancien = shopPart:FindFirstChildOfClass("ProximityPrompt")
    if ancien then ancien:Destroy() end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText            = "Ouvrir"
    prompt.ObjectText            = "🛒 Shop"
    prompt.KeyboardKeyCode       = Enum.KeyCode.E
    prompt.MaxActivationDistance = 8
    prompt.HoldDuration          = 0
    prompt.Parent                = shopPart

    prompt.Triggered:Connect(function(player)
        local playerData = getData(player)
        if not playerData then return end
        if OuvrirShop then
            pcall(function()
                OuvrirShop:FireClient(player, construireDonneesShop(player, playerData))
            end)
        end
    end)
end

local function trouverShopPart(baseModel)
    local shopModel = baseModel:FindFirstChild("Shop")
    if not shopModel then return nil end

    -- Part directe
    if shopModel:IsA("BasePart") then return shopModel end

    -- TouchPart / Trigger nommé
    for _, nomCible in ipairs({ "TouchPart", "Trigger", "Base", "Hit" }) do
        local tp = shopModel:FindFirstChild(nomCible)
        if tp and tp:IsA("BasePart") then return tp end
    end

    -- PrimaryPart du modèle
    if shopModel.PrimaryPart then return shopModel.PrimaryPart end

    -- Première BasePart descendante
    for _, d in ipairs(shopModel:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end

    return nil
end

local function initialiserShopsBases()
    local basesFolder = workspace:FindFirstChild("Bases")
    if not basesFolder then
        warn("[ShopSystem] Dossier 'Bases' introuvable dans Workspace")
        return
    end

    local nb = 0
    for _, baseModel in ipairs(basesFolder:GetChildren()) do
        if baseModel.Name:match("^Base_%d+$") then
            local shopPart = trouverShopPart(baseModel)
            if shopPart then
                ajouterPromptShop(shopPart)
                nb = nb + 1
            else
                warn("[ShopSystem] ⚠ Pas de modèle Shop dans " .. baseModel.Name)
            end
        end
    end

    print("[ShopSystem] " .. nb .. " ProximityPrompt(s) Shop initialisés")
end

-- ============================================================
-- Init
-- ============================================================
function ShopSystem.Init()
    -- Créer les RemoteEvents
    OuvrirShop           = creerRemoteEvent("OuvrirShop")
    FermerShop           = creerRemoteEvent("FermerShop")
    AchatUpgrade         = creerRemoteEvent("AchatUpgrade")
    ShopUpdate           = creerRemoteEvent("ShopUpdate")
    DemandeAchatRobux    = creerRemoteEvent("DemandeAchatRobux")
    ConfirmerGamePass    = creerRemoteEvent("ConfirmerGamePass")
    ChangerSeuilTracteur = creerRemoteEvent("ChangerSeuilTracteur")

    -- Ajouter ProximityPrompts après un court délai (laisse le temps au Workspace de charger)
    task.spawn(function()
        task.wait(1)
        initialiserShopsBases()
    end)

    -- Handler : achat en coins
    AchatUpgrade.OnServerEvent:Connect(function(player, nomUpgrade, niveauDemande)
        -- Validation des types (jamais faire confiance au client)
        if type(nomUpgrade) ~= "string" then return end
        if type(niveauDemande) ~= "number" then return end
        niveauDemande = math.floor(niveauDemande)

        local ok, message = traiterAchatCoins(player, nomUpgrade, niveauDemande)
        local playerData  = getData(player)
        local notif       = ReplicatedStorage:FindFirstChild("NotifEvent")

        if ok then
            if notif then
                pcall(function() notif:FireClient(player, "SUCCESS", "✅ " .. message) end)
            end
            local UpdateHUD = ReplicatedStorage:FindFirstChild("UpdateHUD")
            if UpdateHUD and playerData then
                pcall(function() UpdateHUD:FireClient(player, playerData) end)
            end
            if playerData then
                pcall(function()
                    ShopUpdate:FireClient(player, construireDonneesShop(player, playerData))
                end)
            end
        else
            if notif then
                pcall(function() notif:FireClient(player, "ERREUR", "❌ " .. message) end)
            end
        end
    end)

    -- Handler : demande de prompt d'achat R$ (déclenché par le client)
    DemandeAchatRobux.OnServerEvent:Connect(function(player, nomUpgrade, niveauDemande)
        if type(nomUpgrade) ~= "string" then return end
        if type(niveauDemande) ~= "number" then return end
        niveauDemande = math.floor(niveauDemande)

        local upgradeConfig = Config.ShopUpgrades[nomUpgrade]
        if not upgradeConfig then return end

        local niveauConfig = upgradeConfig.niveaux[niveauDemande]
        if not niveauConfig or niveauConfig.type ~= "robux" then return end

        local gamePassId = niveauConfig.gamePassId
        if type(gamePassId) ~= "number" or gamePassId <= 0 then
            local notif = ReplicatedStorage:FindFirstChild("NotifEvent")
            if notif then
                pcall(function()
                    notif:FireClient(player, "INFO", "🔜 " .. upgradeConfig.nom .. " bientôt disponible !")
                end)
            end
            return
        end

        pcall(function()
            MarketplaceService:PromptGamePassPurchase(player, gamePassId)
        end)
    end)

    -- Handler : confirmation d'achat Game Pass (envoyé par le client après PromptGamePassPurchaseFinished)
    ConfirmerGamePass.OnServerEvent:Connect(function(player, gamePassId)
        if type(gamePassId) ~= "number" then return end
        -- Vérification serveur indépendante — jamais faire confiance au client
        local ok, owns = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
        end)
        if ok and owns then
            ShopSystem.ConfirmerAchatGamePass(player, gamePassId)
        end
    end)

    -- Réappliquer les upgrades après chaque respawn
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            task.wait(0.5)
            local playerData = getData(player)
            if playerData then
                pcall(ShopSystem.AppliquerTousUpgrades, player, playerData)
            end
        end)
    end)

    -- Handler : changer le seuil de rareté du Tracteur
    ChangerSeuilTracteur.OnServerEvent:Connect(function(player, seuilNom)
        if type(seuilNom) ~= "string" then return end

        local playerData = getData(player)
        if not playerData then return end
        if not playerData.hasTracteur then return end

        -- Vérifier que le seuil est dans seuilsDisponibles
        local tracteurConfig = Config.ShopUpgrades.Tracteur
        if not tracteurConfig or not tracteurConfig.seuilsDisponibles then return end

        local seuilValide = nil
        for _, s in ipairs(tracteurConfig.seuilsDisponibles) do
            if s.rareteMin == seuilNom then seuilValide = s break end
        end
        if not seuilValide then return end

        -- Payer les coins si nécessaire (prix > 0 = seuil premium)
        local prix = seuilValide.prix or 0
        if prix > 0 then
            if (playerData.coins or 0) < prix then
                local notif = ReplicatedStorage:FindFirstChild("NotifEvent")
                if notif then
                    pcall(function()
                        notif:FireClient(player, "ERREUR",
                            "❌ Coins insuffisants (" .. prix .. " requis)")
                    end)
                end
                return
            end
            playerData.coins = playerData.coins - prix
        end

        playerData.tracteurSeuilMin = seuilNom

        -- Notifier + mettre à jour HUD + shop
        local notif = ReplicatedStorage:FindFirstChild("NotifEvent")
        if notif then
            pcall(function()
                notif:FireClient(player, "SUCCESS",
                    "🚜 Tracteur : seuil changé à " .. seuilValide.label)
            end)
        end
        if ShopUpdate then
            pcall(function()
                ShopUpdate:FireClient(player, construireDonneesShop(player, playerData))
            end)
        end
        local UpdateHUD = ReplicatedStorage:FindFirstChild("UpdateHUD")
        if UpdateHUD then
            pcall(function() UpdateHUD:FireClient(player, playerData) end)
        end
    end)

    -- Nettoyer la boucle tracteur à la déconnexion
    Players.PlayerRemoving:Connect(function(player)
        tracteurThreads[player.UserId] = nil
    end)

    -- Compter les upgrades chargés
    local n = 0
    for _ in pairs(Config.ShopUpgrades) do n = n + 1 end
    print("[ShopSystem] ✓ Initialisé — " .. n .. " upgrades chargés depuis GameConfig")
end

return ShopSystem
