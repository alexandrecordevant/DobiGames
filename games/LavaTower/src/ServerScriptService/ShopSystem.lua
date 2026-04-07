-- ServerScriptService/ShopSystem.lua
-- Système de shop pour LavaTower
-- Détecte les parts/modèles avec l'attribut "Shop", y pose un ProximityPrompt,
-- gère les achats d'upgrades et applique les effets (speed, jump, carry).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local Logger            = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

local ShopConfig = require(ReplicatedStorage.Modules.ShopConfig)

local ShopSystem = {}

-- ── Callbacks injectés depuis Main.server.lua (même pattern que FuseMachineSystem) ──
ShopSystem.GetData    = nil  -- function(player) → data
ShopSystem.SetData    = nil  -- function(player, data)
ShopSystem.UpdateHUD  = nil  -- function(player)
ShopSystem.NotifEvent = nil  -- RemoteEvent

-- ── RemoteEvents ──────────────────────────────────────────────────────────────
local ShopOpen    -- server → client : ouvre le GUI (payload = données upgrades)
local ShopPurchase -- client → server : demande d'achat { type, amount }
local ShopRefresh  -- server → client : refresh du GUI après achat

local function creerRemoteEvent(nom)
    local e = ReplicatedStorage:FindFirstChild(nom)
    if e then return e end
    e = Instance.new("RemoteEvent")
    e.Name = nom
    e.Parent = ReplicatedStorage
    return e
end

-- ── Tour detection ────────────────────────────────────────────────────────────
-- Tours personnelles : Workspace/Bases/Base_N/Specific/Tour_1  (N = 1..8)
-- Tours communes    : Workspace/TourCommune  et  Workspace/TourVIP
local NUM_BASES = 8

local function checkModelBounds(model, pos)
    if not model then return false end
    local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
    if not ok or not cf or not size then return false end
    local rel = cf:PointToObjectSpace(pos)
    return math.abs(rel.X) <= size.X / 2
       and math.abs(rel.Y) <= size.Y / 2
       and math.abs(rel.Z) <= size.Z / 2
end

local function estDansTour(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local pos = hrp.Position

    -- Tours personnelles : Workspace/Bases/Base_N/Specific/Tour_1
    local bases = Workspace:FindFirstChild("Bases")
    if bases then
        for i = 1, NUM_BASES do
            local base = bases:FindFirstChild("Base_" .. i)
            if base then
                local specific = base:FindFirstChild("Specific")
                local tour = specific and specific:FindFirstChild("Tour_1")
                if tour and checkModelBounds(tour, pos) then
                    return true
                end
            end
        end
    end

    -- Tour commune
    if checkModelBounds(Workspace:FindFirstChild("TourCommune"), pos) then
        return true
    end

    -- Tour VIP
    if checkModelBounds(Workspace:FindFirstChild("TourVIP"), pos) then
        return true
    end

    return false
end

-- ── Capacité carry ────────────────────────────────────────────────────────────
-- Expose la capacité de carry via un NumberValue "MaxCarry" sur le personnage.
-- D'autres scripts (BrainrotPromptService, etc.) peuvent lire character.MaxCarry.Value.
-- Niveau de carry = nombre de BR portables (Niv.1 = 1 BR, Niv.10 = 10 BR)
local function appliquerCarry(player)
    local data = ShopSystem.GetData(player)
    if not data or not data.shopUpgrades then return end

    local char = player.Character
    if not char then return end

    local level    = data.shopUpgrades.carry or 0
    local maxCarry = level   -- direct : niveau = capacité

    local val = char:FindFirstChild("MaxCarry")
    if not val then
        val = Instance.new("NumberValue")
        val.Name   = "MaxCarry"
        val.Parent = char
    end
    val.Value = maxCarry
end

-- ── Application des stats ─────────────────────────────────────────────────────

-- Vitesse : formule additive — WalkSpeed = BaseSpeed + level × SpeedPerLevel
local function appliquerSpeed(player)
    local data = ShopSystem.GetData(player)
    if not data or not data.shopUpgrades then return end

    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local level = data.shopUpgrades.speed or 0
    hum.WalkSpeed = ShopConfig.GetSpeedStat(level)  -- 15 + level × 5
end

-- Saut + Anti-gravité (uniquement dans les tours)
local function appliquerJump(player, inTower)
    local data = ShopSystem.GetData(player)
    if not data or not data.shopUpgrades then return end

    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    local level = data.shopUpgrades.jump or 0

    -- Supprimer l'effet anti-gravité précédent
    local oldAttach = hrp:FindFirstChild("ShopAntiGravAttach")
    if oldAttach then oldAttach:Destroy() end

    if inTower and level > 0 then
        -- Forcer l'utilisation de JumpPower (désactivé par défaut dans Roblox)
        hum.UseJumpPower = true
        hum.JumpPower    = ShopConfig.GetJumpStat(level)

        -- Anti-gravité progressive : VectorForce vers le haut
        local factor = ShopConfig.GetAntiGravFactor(level)
        if factor > 0 then
            local attach = Instance.new("Attachment")
            attach.Name   = "ShopAntiGravAttach"
            attach.Parent = hrp

            local vf = Instance.new("VectorForce")
            vf.Attachment0  = attach
            vf.RelativeTo   = Enum.ActuatorRelativeTo.World
            local mass = hrp.AssemblyMass
            if mass <= 0 then mass = 17 end
            vf.Force  = Vector3.new(0, workspace.Gravity * mass * factor, 0)
            vf.Parent = hrp
        end
    else
        -- Hors tour : reset au défaut
        hum.UseJumpPower = true
        hum.JumpPower    = ShopConfig.Jump.BaseJump
    end
end

-- ── Payload shop envoyé au client ─────────────────────────────────────────────
local function makePayload(player)
    local data = ShopSystem.GetData(player)
    if not data then return {} end
    return {
        upgrades = data.shopUpgrades or { carry = 0, speed = 0, jump = 0 },
        coins    = (data.coins or 0),
    }
end

-- ── Logique d'achat ───────────────────────────────────────────────────────────
-- Renvoie (success: bool, message: string)
local function traiterAchat(player, upgradeType, amount)
    local data = ShopSystem.GetData(player)
    if not data then return false, "Données introuvables" end

    data.shopUpgrades = data.shopUpgrades or { carry = 0, speed = 0, jump = 0 }
    local upgrades    = data.shopUpgrades
    local coins       = data.coins or 0

    -- ── CARRY ──
    if upgradeType == "Carry" then
        local currentLevel = upgrades.carry or 0
        if currentLevel >= ShopConfig.Carry.MaxLevel then
            return false, "Carry au niveau maximum !"
        end
        local nextLevel = currentLevel + 1
        local prix      = ShopConfig.GetCarryPrice(nextLevel)
        if coins < prix then
            return false, "Pas assez de pièces (" .. ShopConfig.FormatNumber(prix) .. " requis)"
        end
        data.coins     = coins - prix
        upgrades.carry = nextLevel
        ShopSystem.SetData(player, data)
        ShopSystem.UpdateHUD(player)
        appliquerCarry(player)
        return true, "Carry amélioré ! Niveau " .. nextLevel .. "/" .. ShopConfig.Carry.MaxLevel .. " (" .. nextLevel .. " BR max)"

    -- ── SPEED ──
    elseif upgradeType == "Speed" then
        local currentLevel = upgrades.speed or 0
        if currentLevel >= ShopConfig.Speed.MaxLevel then
            return false, "Vitesse au niveau maximum !"
        end

        -- Déterminer combien de niveaux acheter
        local nbMax = ShopConfig.Speed.MaxLevel - currentLevel
        local nb
        if amount == "Max" then
            -- Calculer le maximum achetable avec les coins
            nb = 0
            local total = 0
            for i = 1, nbMax do
                local p = ShopConfig.GetSpeedPrice(currentLevel + i)
                if total + p <= coins then
                    total = total + p
                    nb    = nb + 1
                else
                    break
                end
            end
            if nb == 0 then
                return false, "Pas assez de pièces pour la prochaine amélioration"
            end
        else
            nb = math.min(tonumber(amount) or 1, nbMax)
        end

        -- Calculer le coût total
        local cout = 0
        for i = 1, nb do
            cout = cout + ShopConfig.GetSpeedPrice(currentLevel + i)
        end
        if coins < cout then
            return false, "Pas assez de pièces (" .. ShopConfig.FormatNumber(cout) .. " requis)"
        end

        data.coins     = coins - cout
        upgrades.speed = currentLevel + nb
        ShopSystem.SetData(player, data)
        ShopSystem.UpdateHUD(player)
        appliquerSpeed(player)
        local newSpeed = ShopConfig.GetSpeedStat(upgrades.speed)
        return true, "Vitesse améliorée ! Niveau " .. upgrades.speed .. "/" .. ShopConfig.Speed.MaxLevel .. " → " .. newSpeed .. " WS"

    -- ── JUMP ──
    elseif upgradeType == "Jump" then
        local currentLevel = upgrades.jump or 0
        if currentLevel >= ShopConfig.Jump.MaxLevel then
            return false, "Saut au niveau maximum !"
        end

        local nbMax = ShopConfig.Jump.MaxLevel - currentLevel
        local nb
        if amount == "Max" then
            nb = 0
            local total = 0
            for i = 1, nbMax do
                local p = ShopConfig.GetJumpPrice(currentLevel + i)
                if total + p <= coins then
                    total = total + p
                    nb    = nb + 1
                else
                    break
                end
            end
            if nb == 0 then
                return false, "Pas assez de pièces pour la prochaine amélioration"
            end
        else
            nb = math.min(tonumber(amount) or 1, nbMax)
        end

        local cout = 0
        for i = 1, nb do
            cout = cout + ShopConfig.GetJumpPrice(currentLevel + i)
        end
        if coins < cout then
            return false, "Pas assez de pièces (" .. ShopConfig.FormatNumber(cout) .. " requis)"
        end

        data.coins    = coins - cout
        upgrades.jump = currentLevel + nb
        ShopSystem.SetData(player, data)
        ShopSystem.UpdateHUD(player)
        -- Appliquer immédiatement selon l'état tour actuel du joueur
        local inTowerNow = player.Character and estDansTour(player.Character) or false
        appliquerJump(player, inTowerNow)
        local newJP = ShopConfig.GetJumpStat(upgrades.jump)
        local msg = "Saut amélioré ! Niveau " .. upgrades.jump .. "/" .. ShopConfig.Jump.MaxLevel .. " → " .. newJP .. " JP"
        if not inTowerNow then msg = msg .. " (entre dans une tour pour l'activer)" end
        return true, msg

    else
        return false, "Type d'upgrade inconnu : " .. tostring(upgradeType)
    end
end

-- ── Ajout du ProximityPrompt sur une part ─────────────────────────────────────
local function ajouterPrompt(part)
    -- Éviter les doublons
    if part:FindFirstChild("ShopPrompt") then return end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name            = "ShopPrompt"
    prompt.ActionText            = "Ouvrir"
    prompt.ObjectText            = "Shop"
    prompt.KeyboardKeyCode       = Enum.KeyCode.E
    prompt.HoldDuration          = 0
    prompt.MaxActivationDistance = 20
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = part

    prompt.Triggered:Connect(function(player)
        ShopOpen:FireClient(player, makePayload(player))
    end)

    Logger.debug("Shop", "ProximityPrompt ajouté sur %s", part:GetFullName())
end

-- ── Scan du workspace pour les instances avec attribut "Shop" ─────────────────
-- Attribut attendu : nom = "Shop" (S majuscule), type Boolean, valeur = true
local promptsAdded = {}  -- set pour éviter les doublons même inter-appels

local function trouverCible(instance)
    -- L'attribut peut être sur un Model ou directement sur une BasePart
    if instance:IsA("Model") then
        -- Priorité 1 : PrimaryPart
        if instance.PrimaryPart then
            return instance.PrimaryPart
        end
        -- Priorité 2 : n'importe quelle BasePart descendante
        local bp = instance:FindFirstChildWhichIsA("BasePart", true)
        if bp then
            return bp
        end
        Logger.warn("Shop", "Modèle sans BasePart : %s", instance:GetFullName())
        return nil
    elseif instance:IsA("BasePart") then
        return instance
    end
    return nil
end

local function verifier(instance)
    -- Vérifie l'attribut "Shop" (booléen true, S majuscule)
    local attr = instance:GetAttribute("Shop")
    if attr ~= true then return end

    local cible = trouverCible(instance)
    if not cible then return end

    -- Doublon ?
    if promptsAdded[cible] then return end
    promptsAdded[cible] = true

    ajouterPrompt(cible)
end

local function scannerWorkspace()
    -- Petit délai pour que le workspace soit entièrement peuplé côté serveur
    task.wait(1)

    Logger.debug("Shop", "Début du scan workspace...")
    local total = 0
    for _, desc in ipairs(Workspace:GetDescendants()) do
        total += 1
        verifier(desc)
    end
    Logger.debug("Shop", "Scan terminé — %d descendants parcourus", total)

    -- Écouter les nouveaux descendants (objets spawned en cours de jeu)
    Workspace.DescendantAdded:Connect(function(desc)
        -- Attendre plusieurs frames : Model → children → attributs
        task.wait(0.2)
        verifier(desc)
        -- Vérifier aussi les enfants si c'est un Model (au cas où l'attribut est sur un enfant)
        if desc:IsA("Model") then
            for _, child in ipairs(desc:GetDescendants()) do
                verifier(child)
            end
        end
    end)
end

-- ── Boucle principale : gestion du jump selon position ────────────────────────
local playerTowerState = {}  -- [userId] = bool (était dans une tour au dernier check)

local function lancerBoucleJump()
    task.spawn(function()
        while true do
            task.wait(0.5)
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                if not char then continue end

                local inTower   = estDansTour(char)
                local wasInTour = playerTowerState[player.UserId]

                if inTower ~= wasInTour then
                    playerTowerState[player.UserId] = inTower
                    appliquerJump(player, inTower)
                end
            end
        end
    end)
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function ShopSystem.Init()
    ShopOpen     = creerRemoteEvent("ShopOpen")
    ShopPurchase = creerRemoteEvent("ShopPurchase")
    ShopRefresh  = creerRemoteEvent("ShopRefresh")

    -- Appliquer speed + carry dès que le personnage spawn
    local function onCharacterAdded(player)
        task.wait(0.1)
        playerTowerState[player.UserId] = false
        appliquerSpeed(player)
        appliquerCarry(player)
    end

    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function() onCharacterAdded(player) end)
    end)
    -- Pour les joueurs déjà connectés (hot-reload studio)
    for _, player in ipairs(Players:GetPlayers()) do
        player.CharacterAdded:Connect(function() onCharacterAdded(player) end)
        if player.Character then
            appliquerSpeed(player)
            appliquerCarry(player)
        end
    end

    -- Nettoyage à la déconnexion
    Players.PlayerRemoving:Connect(function(player)
        playerTowerState[player.UserId] = nil
    end)

    -- Gérer les demandes d'achat
    ShopPurchase.OnServerEvent:Connect(function(player, upgradeType, amount)
        local success, message = traiterAchat(player, upgradeType, amount)
        -- Notif textuelle via NotifEvent existant
        if ShopSystem.NotifEvent then
            local type_ = success and "SUCCESS" or "ERREUR"
            ShopSystem.NotifEvent:FireClient(player, type_, message)
        end
        -- Refresh le GUI du joueur
        ShopRefresh:FireClient(player, makePayload(player))
    end)

    -- Scanner le workspace pour les shops
    task.spawn(scannerWorkspace)

    -- Lancer la boucle de détection des tours (pour jump)
    lancerBoucleJump()

    Logger.info("Shop", "Initialisé ✓")
end

return ShopSystem
