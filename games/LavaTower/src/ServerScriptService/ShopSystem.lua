-- ServerScriptService/ShopSystem.lua
-- Système de shop pour LavaTower
-- Détecte les parts/modèles avec l'attribut "Shop", y pose un ProximityPrompt,
-- gère les achats d'upgrades et applique les effets (speed, jump, carry).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")
local Logger            = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

local ShopConfig = require(ReplicatedStorage.Modules.ShopConfig)

-- ── CarrySystem — chargement différé (évite dépendance circulaire) ────────────
local _CarrySystem = nil
local function getCarrySystem()
    if not _CarrySystem then
        local ServerScriptService = game:GetService("ServerScriptService")
        local ok, m = pcall(require, ServerScriptService.SharedLib.Server.CarrySystem)
        if ok and m then _CarrySystem = m end
    end
    return _CarrySystem
end

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
-- L'attribut "InTower" est mis à true/false par PadTP.server.lua et TourCycle.server.lua
-- directement au moment du TP, ce qui évite tout faux-positif bounding-box.
local function estDansTour(player)
    return player:GetAttribute("InTower") == true
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

    -- Synchroniser CarrySystem (source de vérité pour la limite réelle du carry)
    local CS = getCarrySystem()
    if CS then
        CS.SetCapacite(player, maxCarry)
    end
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

-- ── Helper : récupère un outil depuis ReplicatedStorage/Tools ─────────────────
local function getTool(name)
    local folder = ReplicatedStorage:FindFirstChild("Tools")
    if not folder then
        Logger.warn("Shop", "ReplicatedStorage.Tools introuvable")
        return nil
    end
    local tool = folder:FindFirstChild(name)
    if not tool then
        Logger.warn("Shop", "Tools.%s introuvable", name)
    end
    return tool
end

local function donnerOutil(player, name)
    local template = getTool(name)
    if not template then return end
    local inChar     = player.Character and player.Character:FindFirstChild(name)
    local inBackpack = player.Backpack:FindFirstChild(name)
    if not inChar and not inBackpack then
        template:Clone().Parent = player.Backpack
    end
end

-- Donne la Rocket en désancrant le Handle pour que ce soit la Rocket
-- qui vienne dans la main du joueur, et non l'inverse.
local function donnerRocket(player)
    local inChar     = player.Character and player.Character:FindFirstChild("Rocket")
    local inBackpack = player.Backpack:FindFirstChild("Rocket")
    if inChar or inBackpack then return end

    local template = getTool("Rocket")
    if not template then return end

    local clone = template:Clone()

    -- Supprimer les scripts du clone (évite qu'un script re-ancre le Handle)
    for _, s in ipairs(clone:GetDescendants()) do
        if s:IsA("Script") or s:IsA("LocalScript") or s:IsA("ModuleScript") then
            s:Destroy()
        end
    end

    -- Trouver le Handle
    local handle = clone:FindFirstChild("Handle")
    if not handle then
        for _, v in ipairs(clone:GetDescendants()) do
            if v:IsA("BasePart") then handle = v; break end
        end
    end

    if handle then
        -- Enregistrer les offsets relatifs de chaque part par rapport au Handle
        local relCFs = {}
        for _, v in ipairs(clone:GetDescendants()) do
            if v:IsA("BasePart") and v ~= handle then
                relCFs[v] = handle.CFrame:Inverse() * v.CFrame
            end
        end

        -- Déplacer toutes les parts près du joueur pour éviter le téléport
        local char = player.Character
        local hrpCF = char and char:FindFirstChild("HumanoidRootPart")
                      and char.HumanoidRootPart.CFrame or CFrame.new(0, 0, 0)

        handle.CFrame       = hrpCF
        handle.Anchored     = false
        handle.CanCollide   = false
        handle.Massless     = true

        for v, relCF in pairs(relCFs) do
            v.CFrame     = hrpCF * relCF
            v.Anchored   = false
            v.CanCollide = false
            v.Massless   = true
            local wc    = Instance.new("WeldConstraint")
            wc.Part0   = handle
            wc.Part1   = v
            wc.Parent  = handle
        end
    end

    -- Corriger l'orientation en main (+90° autour de Z)
    clone.GripForward = Vector3.new(0, 0, -1)
    clone.GripRight   = Vector3.new(0, 1, 0)
    clone.GripUp      = Vector3.new(-1, 0, 0)

    clone.Parent = player.Backpack
end

local function retirerOutil(player, name)
    local char = player.Character
    if char then
        local t = char:FindFirstChild(name)
        if t then t:Destroy() end
    end
    local t = player.Backpack:FindFirstChild(name)
    if t then t:Destroy() end
end


-- ── Payload shop envoyé au client ─────────────────────────────────────────────
local function makePayload(player)
    local data = ShopSystem.GetData(player)
    if not data then return {} end
    return {
        upgrades         = data.shopUpgrades or { carry = 0, speed = 0, jump = 0 },
        coins            = (data.coins or 0),
        hasSpeedCoil        = data.hasSpeedCoil        or false,
        speedCoilEquipped   = data.speedCoilEquipped   or false,
        hasGravityCoil      = data.hasGravityCoil      or false,
        gravityCoilEquipped = data.gravityCoilEquipped or false,
        hasCape             = data.hasCape             or false,
        capeEquipped        = data.capeEquipped        or false,
        hasRocket           = data.hasRocket           or false,
        rocketEquipped      = data.rocketEquipped      or false,
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
        local inTowerNow = estDansTour(player)
        appliquerJump(player, inTowerNow)
        local newJP = ShopConfig.GetJumpStat(upgrades.jump)
        local msg = "Saut amélioré ! Niveau " .. upgrades.jump .. "/" .. ShopConfig.Jump.MaxLevel .. " → " .. newJP .. " JP"
        if not inTowerNow then msg = msg .. " (entre dans une tour pour l'activer)" end
        return true, msg

    -- ── SPEEDCOIL ACHAT ──
    elseif upgradeType == "SpeedCoil_Buy" then
        if data.hasSpeedCoil then return false, "Vous possédez déjà le SpeedCoil !" end
        local prix = ShopConfig.SpeedCoil.Price
        if coins < prix then
            return false, "Pas assez de pièces (" .. ShopConfig.FormatNumber(prix) .. " requis)"
        end
        data.coins             = coins - prix
        data.hasSpeedCoil      = true
        data.speedCoilEquipped = true
        ShopSystem.SetData(player, data)
        ShopSystem.UpdateHUD(player)
        donnerOutil(player, "SpeedCoil")
        Logger.info("Shop", "%s a acheté le SpeedCoil (équipé)", player.Name)
        return true, "SpeedCoil acheté et équipé !"

    -- ── SPEEDCOIL ÉQUIPER ──
    elseif upgradeType == "SpeedCoil_Equip" then
        if not data.hasSpeedCoil then return false, "Vous n'avez pas le SpeedCoil !" end
        if data.speedCoilEquipped then return false, "Le SpeedCoil est déjà équipé." end
        data.speedCoilEquipped = true
        ShopSystem.SetData(player, data)
        donnerOutil(player, "SpeedCoil")
        return true, "SpeedCoil équipé !"

    -- ── SPEEDCOIL DÉSÉQUIPER ──
    elseif upgradeType == "SpeedCoil_Unequip" then
        data.speedCoilEquipped = false
        ShopSystem.SetData(player, data)
        retirerOutil(player, "SpeedCoil")
        return true, "SpeedCoil déséquipé."

    -- ── GRAVITYCOIL ACHAT ──
    elseif upgradeType == "GravityCoil_Buy" then
        if data.hasGravityCoil then return false, "Vous possédez déjà le GravityCoil !" end
        local prix = ShopConfig.GravityCoil.Price
        if coins < prix then
            return false, "Pas assez de pièces (" .. ShopConfig.FormatNumber(prix) .. " requis)"
        end
        data.coins              = coins - prix
        data.hasGravityCoil     = true
        data.gravityCoilEquipped = true
        ShopSystem.SetData(player, data)
        ShopSystem.UpdateHUD(player)
        donnerOutil(player, "GravityCoil")
        Logger.info("Shop", "%s a acheté le GravityCoil (équipé)", player.Name)
        return true, "GravityCoil acheté et équipé !"

    -- ── GRAVITYCOIL ÉQUIPER ──
    elseif upgradeType == "GravityCoil_Equip" then
        if not data.hasGravityCoil then return false, "Vous n'avez pas le GravityCoil !" end
        if data.gravityCoilEquipped then return false, "Le GravityCoil est déjà équipé." end
        data.gravityCoilEquipped = true
        ShopSystem.SetData(player, data)
        donnerOutil(player, "GravityCoil")
        return true, "GravityCoil équipé !"

    -- ── GRAVITYCOIL DÉSÉQUIPER ──
    elseif upgradeType == "GravityCoil_Unequip" then
        data.gravityCoilEquipped = false
        ShopSystem.SetData(player, data)
        retirerOutil(player, "GravityCoil")
        return true, "GravityCoil déséquipé."

    -- ── CAPE ACHAT ──
    elseif upgradeType == "Cape_Buy" then
        if data.hasCape then return false, "Vous possedez deja la Cape !" end
        local prix = ShopConfig.Cape.Price
        if coins < prix then
            return false, "Pas assez de pieces (" .. ShopConfig.FormatNumber(prix) .. " requis)"
        end
        data.coins        = coins - prix
        data.hasCape      = true
        data.capeEquipped = true
        ShopSystem.SetData(player, data)
        ShopSystem.UpdateHUD(player)
        donnerOutil(player, "Cape")
        Logger.info("Cape", "%s a achete la Cape (equipee)", player.Name)
        return true, "Cape achetee et equipee !"

    -- ── CAPE EQUIPER ──
    elseif upgradeType == "Cape_Equip" then
        if not data.hasCape then return false, "Vous n'avez pas la Cape !" end
        if data.capeEquipped then return false, "La Cape est deja equipee." end
        data.capeEquipped = true
        ShopSystem.SetData(player, data)
        donnerOutil(player, "Cape")
        return true, "Cape equipee !"

    -- ── CAPE DESEQUIPER ──
    elseif upgradeType == "Cape_Unequip" then
        data.capeEquipped = false
        ShopSystem.SetData(player, data)
        retirerOutil(player, "Cape")
        return true, "Cape desequipee."

    -- ── ROCKET ACHAT ──
    elseif upgradeType == "Rocket_Buy" then
        if data.hasRocket then return false, "Vous possedez deja la Rocket !" end
        local prix = ShopConfig.Rocket.Price
        if coins < prix then
            return false, "Pas assez de pieces (" .. ShopConfig.FormatNumber(prix) .. " requis)"
        end
        data.coins         = coins - prix
        data.hasRocket     = true
        data.rocketEquipped = true
        ShopSystem.SetData(player, data)
        ShopSystem.UpdateHUD(player)
        donnerRocket(player)
        Logger.info("Rocket", "%s a achete la Rocket", player.Name)
        return true, "Rocket achetee ! Clic pour vous propulser."

    -- ── ROCKET EQUIPER ──
    elseif upgradeType == "Rocket_Equip" then
        if not data.hasRocket then return false, "Vous n'avez pas la Rocket !" end
        if data.rocketEquipped then return false, "La Rocket est deja equipee." end
        data.rocketEquipped = true
        ShopSystem.SetData(player, data)
        donnerRocket(player)
        return true, "Rocket equipee !"

    -- ── ROCKET DESEQUIPER ──
    elseif upgradeType == "Rocket_Unequip" then
        data.rocketEquipped = false
        ShopSystem.SetData(player, data)
        retirerOutil(player, "Rocket")
        return true, "Rocket desequipee."

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

                local inTower   = estDansTour(player)
                local wasInTour = playerTowerState[player.UserId]

                if inTower ~= wasInTour then
                    playerTowerState[player.UserId] = inTower
                    appliquerJump(player, inTower)
                end
            end
        end
    end)
end

-- ── Effets Cape ───────────────────────────────────────────────────────────────
local CAPE_SPEED_BONUS  = 8
local CAPE_FADE_DURATION = 1.2

local function appliquerVisibiliteCape(character, invisible)
    local tweenInfo = TweenInfo.new(CAPE_FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local goal = { Transparency = invisible and 1 or 0 }
    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
            TweenService:Create(desc, tweenInfo, goal):Play()
        end
    end
end

local function connecterCapeEvents(player, character)
    character.ChildAdded:Connect(function(child)
        if child.Name ~= "Cape" or not child:IsA("Tool") then return end
        task.wait()
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = hum.WalkSpeed + CAPE_SPEED_BONUS end
        appliquerVisibiliteCape(character, true)
        Logger.debug("Cape", "%s a equipe la Cape (invisible)", player.Name)
    end)

    character.ChildRemoved:Connect(function(child)
        if child.Name ~= "Cape" or not child:IsA("Tool") then return end
        appliquerVisibiliteCape(character, false)
        appliquerSpeed(player)
        Logger.debug("Cape", "%s a desequipe la Cape (visible)", player.Name)
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
        player:SetAttribute("InTower", false)
        playerTowerState[player.UserId] = false
        appliquerSpeed(player)
        appliquerCarry(player)
        local data = ShopSystem.GetData(player)
        if data then
            if data.speedCoilEquipped    then donnerOutil(player, "SpeedCoil")    end
            if data.gravityCoilEquipped  then donnerOutil(player, "GravityCoil")  end
            if data.capeEquipped         then donnerOutil(player, "Cape")         end
            if data.rocketEquipped       then donnerRocket(player)       end
        end
        local char = player.Character
        if char then connecterCapeEvents(player, char) end
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
