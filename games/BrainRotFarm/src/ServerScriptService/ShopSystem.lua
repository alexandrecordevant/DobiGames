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
local Logger = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)
local Config = require(ReplicatedStorage.GameConfig)

-- ============================================================
-- Callback fourni par Main.server.lua (évite les dépendances circulaires)
-- ShopSystem.GetPlayerData = function(player) → playerData ou nil
-- ShopSystem.FireUpdateHUD = function(player, data) — envoie le HUD avec extraCoins inclus
-- ============================================================
ShopSystem.GetPlayerData = nil
ShopSystem.FireUpdateHUD = nil

-- ============================================================
-- RemoteEvents (créés dans Init)
-- ============================================================
local OuvrirShop          = nil   -- FireClient(player, donneesShop)
local FermerShop          = nil   -- FireClient(player)
local AchatUpgrade        = nil   -- OnServerEvent(player, nomUpgrade, niveau)
local ShopUpdate          = nil   -- FireClient(player, donneesShop)
local DemandeAchatRobux   = nil   -- OnServerEvent(player, nomUpgrade, niveau) → PromptGamePassPurchase
local ConfirmerGamePass   = nil   -- OnServerEvent(player, gamePassId) → vérification + application

local function creerRemoteEvent(nom)
    local existing = ReplicatedStorage:FindFirstChild(nom)
    if existing then return existing end
    local re = Instance.new("RemoteEvent")
    re.Name   = nom
    re.Parent = ReplicatedStorage
    return re
end

-- ============================================================
-- Chargement différé — évite les dépendances circulaires
-- ============================================================
local _AssignationSystem = nil
local function getAssignationSystem()
    if not _AssignationSystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SharedLib.Server.AssignationSystem)
        if ok and m then _AssignationSystem = m end
    end
    return _AssignationSystem
end

local _SprinklerSystem = nil
local function getSprinklerSystem()
    if not _SprinklerSystem then
        local ok, m = pcall(require, ServerScriptService.SprinklerSystem)
        if ok and m then _SprinklerSystem = m end
    end
    return _SprinklerSystem
end

local _CarrySystem = nil
local function getCarrySystem()
    if not _CarrySystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SharedLib.Server.CarrySystem)
        if ok and m then _CarrySystem = m end
    end
    return _CarrySystem
end

-- Common car renommé et déplacé
local _SpawnManager = nil
local function getBrainRotSpawner()
    if not _SpawnManager then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SpawnManager)
        if ok and m then _SpawnManager = m end
    end
    return _SpawnManager
end

local _DropSystem = nil
local function getDropSystem()
    if not _DropSystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SharedLib.Server.DropSystem)
        if ok and m then _DropSystem = m end
    end
    return _DropSystem
end

local _CollectSystem = nil
local function getCollectSystem()
    if not _CollectSystem then
        local ok, m = pcall(require, game:GetService("ServerScriptService").SharedLib.Shared.CollectSystem)
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

    -- Multiplicateur spawn (Arroseur — délégué à BrainRotSpawner + SprinklerSystem)
    if effet.spawnRateMultiplier then
        local BRS = getBrainRotSpawner()
        if BRS and BRS.SetSpawnRateMultiplier then
            pcall(BRS.SetSpawnRateMultiplier, player, effet.spawnRateMultiplier)
        end

        -- Activer le sprinkler au niveau correspondant à l'upgrade Arroseur
        local SS = getSprinklerSystem()
        local AS = getAssignationSystem()
        if SS and AS then
            local baseIndex = AS.GetBaseIndex(player)
            if baseIndex then
                local niveauArroseur = playerData.upgrades
                    and playerData.upgrades.upgradeArroseur or 0
                pcall(SS.ActiverBase, baseIndex, niveauArroseur)
            end
        end
    end

    -- Rayon de collecte (Aimant — délégué à CarrySystem)
    if effet.rayonCollecte then
        local CS = getCarrySystem()
        if CS and CS.SetRayonAimant then
            pcall(CS.SetRayonAimant, player, effet.rayonCollecte)
        end
    end

    -- Tracteur : comportement passif géré dans SpawnManager (Lucky Spawn) — aucun effet à appliquer ici

    -- Lucky Charm (délégué à CollectSystem)
    if effet.luckyBonus then
        local ColSys = getCollectSystem()
        if ColSys and ColSys.SetLuckyBonus then
            pcall(ColSys.SetLuckyBonus, player, effet.luckyBonus)
        end
    end
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
                            "✅ " .. upgradeConfig.icone .. " " .. upgradeConfig.nom .. " activated!")
                    end)
                end

                -- Mettre à jour le shop côté client
                if ShopUpdate then
                    pcall(function()
                        ShopUpdate:FireClient(player, construireDonneesShop(player, playerData))
                    end)
                end

                -- Mettre à jour le HUD
                if ShopSystem.FireUpdateHUD then
                    pcall(ShopSystem.FireUpdateHUD, player, playerData)
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
    if not playerData then return false, "Data not found" end

    -- 1. Lire l'upgrade depuis Config (jamais depuis le client)
    local upgradeConfig = Config.ShopUpgrades[nomUpgrade]
    if not upgradeConfig then return false, "Unknown upgrade" end

    local niveauConfig = upgradeConfig.niveaux[niveauDemande]
    if not niveauConfig then return false, "Invalid level" end

    -- 2. Type doit être "coins" (pas de paiement R$ ici)
    if niveauConfig.type ~= "coins" then
        return false, "This upgrade requires R$"
    end

    -- 3. Joueur n'a pas déjà ce niveau ou supérieur
    assurerUpgrades(playerData)
    local niveauActuel = playerData.upgrades[upgradeConfig.dataField] or 0
    if niveauActuel >= niveauDemande then
        return false, "Level already reached"
    end

    -- 4. Niveau précédent requis (pas de saut de niveau)
    if niveauDemande > 1 and niveauActuel < niveauDemande - 1 then
        return false, "Purchase the previous level first"
    end

    -- 5. Vérification des coins
    local prix = niveauConfig.prix
    if (playerData.coins or 0) < prix then
        return false, "Not enough coins (" .. prix .. " required)"
    end

    -- 6. Déduire les coins et sauvegarder le niveau
    playerData.coins = playerData.coins - prix
    playerData.upgrades[upgradeConfig.dataField] = niveauDemande

    -- 7. Appliquer l'effet immédiatement
    pcall(appliquerEffet, player, playerData, niveauConfig)

    return true,
        upgradeConfig.icone .. " " .. upgradeConfig.nom ..
        " Lv." .. niveauDemande .. " purchased!"
end

-- ============================================================
-- ProximityPrompt — Shop dans chaque base
-- ============================================================
-- baseIndex : index de la base concernée (pour vérifier l'ownership)
local function ajouterPromptShop(shopPart, baseIndex)
    -- Supprimer un prompt existant
    local ancien = shopPart:FindFirstChildOfClass("ProximityPrompt")
    if ancien then ancien:Destroy() end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText            = "Open"
    prompt.ObjectText            = "🛒 Shop"
    prompt.KeyboardKeyCode       = Enum.KeyCode.E
    prompt.MaxActivationDistance = 8
    prompt.HoldDuration          = 0
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = shopPart

    prompt.Triggered:Connect(function(player)
        -- Vérification ownership : seul le propriétaire de la base peut ouvrir son shop
        local AS = getAssignationSystem()
        if AS and baseIndex then
            local baseJoueur = AS.GetBaseIndex(player)
            if baseJoueur ~= baseIndex then
                local notif = ReplicatedStorage:FindFirstChild("NotifEvent")
                if notif then
                    pcall(function()
                        notif:FireClient(player, "ERREUR",
                            "❌ This shop is not yours!")
                    end)
                end
                return
            end
        end

        local playerData = getData(player)
        if not playerData then return end
        if OuvrirShop then
            pcall(function()
                OuvrirShop:FireClient(player, construireDonneesShop(player, playerData))
            end)
        end
    end)
end

-- Trouve la BasePart d'accroche dans un Model Shop
-- Priorité : TouchPart nommé → PrimaryPart → enfant direct BasePart
--            → descendant non-Lantern (fallback)
local function trouverShopPart(shopModel)
    -- 1. TouchPart explicitement nommé
    for _, nomCible in ipairs({ "TouchPart", "Trigger", "Base", "Hit" }) do
        local tp = shopModel:FindFirstChild(nomCible)
        if tp and tp:IsA("BasePart") then return tp end
    end

    -- 2. PrimaryPart du modèle Shop
    if shopModel.PrimaryPart then return shopModel.PrimaryPart end

    -- 3. Enfants directs BasePart (évite les sous-modèles décoratifs comme Lantern)
    for _, child in ipairs(shopModel:GetChildren()) do
        if child:IsA("BasePart") then return child end
    end

    -- 4. Descendant BasePart en évitant les sous-modèles Lantern et décoratifs
    for _, desc in ipairs(shopModel:GetDescendants()) do
        if desc:IsA("BasePart") then
            -- Remonter jusqu'à shopModel pour détecter un ancêtre "Lantern"
            local ancestor = desc.Parent
            local dansDecor = false
            while ancestor and ancestor ~= shopModel do
                if ancestor.Name == "Lantern"
                or ancestor.Name:find("Lantern")
                or ancestor.Name:find("Text") then
                    dansDecor = true
                    break
                end
                ancestor = ancestor.Parent
            end
            if not dansDecor then return desc end
        end
    end

    return nil
end

-- Initialise le ProximityPrompt d'un Shop (Model) pour une base donnée
function ShopSystem.InitShop(baseIndex, shopModel)
    -- Supprimer tout PP existant dans le shop
    for _, desc in ipairs(shopModel:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            desc:Destroy()
        end
    end
    local ancien = shopModel:FindFirstChildOfClass("ProximityPrompt")
    if ancien then ancien:Destroy() end

    local touchPart = trouverShopPart(shopModel)
    if not touchPart then
        Logger.warn("Shop", "⚠ Aucune BasePart trouvée dans Shop de Base_%s", tostring(baseIndex))
        return
    end

    ajouterPromptShop(touchPart, baseIndex)
    Logger.debug("Shop", "PP créé → Base_%s sur %s", tostring(baseIndex), touchPart.Name)
end

local function initialiserShopsBases()
    -- Attendre que le dossier Bases soit présent (max 15s — modèles Studio lents à charger)
    local basesFolder = workspace:FindFirstChild("Bases")
    if not basesFolder then
        local t = 0
        repeat
            task.wait(0.5)
            t = t + 0.5
            basesFolder = workspace:FindFirstChild("Bases")
        until basesFolder or t >= 15
    end

    if not basesFolder then
        Logger.warn("Shop", "⚠ Dossier 'Bases' introuvable après 15s — ProximityPrompts non créés")
        return
    end

    local nb = 0
    for i = 1, (Config.MaxBases or 6) do
        local baseModel = basesFolder:FindFirstChild("Base_" .. i)
        if baseModel then
            -- Shop dans Shared/ (structure Shared/Specific)
            local sharedFolder = baseModel:FindFirstChild("Shared")
            local shopModel    = sharedFolder and sharedFolder:FindFirstChild("Shop")
            if shopModel then
                ShopSystem.InitShop(i, shopModel)
                nb = nb + 1
            else
                Logger.warn("Shop", "⚠ Pas de modèle Shop dans Base_%d", i)
            end
        end
    end

    Logger.info("Shop", "%d ProximityPrompt(s) Shop initialisés", nb)
end

-- API publique : recréer les ProximityPrompts (ex: après rechargement de carte)
function ShopSystem.InitTousShops()
    initialiserShopsBases()
end

-- ============================================================
-- Init
-- ============================================================
function ShopSystem.Init()
    Logger.info("Shop", "Init() démarré…")

    -- Créer les RemoteEvents (creerRemoteEvent est idempotent)
    OuvrirShop           = creerRemoteEvent("OuvrirShop")
    FermerShop           = creerRemoteEvent("FermerShop")
    AchatUpgrade         = creerRemoteEvent("AchatUpgrade")
    ShopUpdate           = creerRemoteEvent("ShopUpdate")
    DemandeAchatRobux    = creerRemoteEvent("DemandeAchatRobux")
    ConfirmerGamePass    = creerRemoteEvent("ConfirmerGamePass")
    Logger.debug("Shop", "RemoteEvents créés")

    -- Ajouter ProximityPrompts (initialiserShopsBases attend jusqu'à 15s)
    task.spawn(initialiserShopsBases)

    -- Handler : achat coins
    AchatUpgrade.OnServerEvent:Connect(function(player, nomUpgrade, niveauDemande)
        -- Validation des types (jamais faire confiance au client)
        if type(nomUpgrade) ~= "string" then return end
        if type(niveauDemande) ~= "number" then return end
        niveauDemande = math.floor(niveauDemande)

        local ok, message = traiterAchatCoins(player, nomUpgrade, niveauDemande)

        local playerData = getData(player)
        local notif      = ReplicatedStorage:FindFirstChild("NotifEvent")

        if ok then
            if notif then
                pcall(function() notif:FireClient(player, "SUCCESS", "✅ " .. message) end)
            end
            if ShopSystem.FireUpdateHUD and playerData then
                pcall(ShopSystem.FireUpdateHUD, player, playerData)
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
                    notif:FireClient(player, "INFO", "🔜 " .. upgradeConfig.nom .. " coming soon!")
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

    -- Compter les upgrades chargés
    local n = 0
    for _ in pairs(Config.ShopUpgrades) do n = n + 1 end
    Logger.info("Shop", "✓ Init terminé — %d upgrades | ProximityPrompts en cours…", n)
end

return ShopSystem
