-- ============================================================
-- BrainrotPickupModule.lua
-- ModuleScript — Collecte de Brainrots : Billboard + Timer + Pickup → Tool / Backpack
-- ============================================================
--
-- RÉUTILISABLE dans n'importe quel projet Roblox.
-- Il suffit de le require depuis un ServerScript et d'appeler Init().
--
-- USAGE :
--   local BrainrotPickup = require(script.Parent.BrainrotPickupModule)
--   BrainrotPickup.Init()
--
-- PRÉREQUIS sur chaque brainrot dans le workspace :
--   • Tag CollectionService  "BrainrotCollectible"   (posez-le via Studio ou code)
--   • Attribut "Rarete"          string   "COMMON" | "RARE" | "EPIC" | "LEGENDARY"
--                                         "MYTHIC" | "GOD" | "SECRET" | "OG"
--   • Attribut "LifeTime"        number   secondes avant auto-despawn  (défaut : 60)
--   • Attribut "OriginalName"    string   nom affiché                  (défaut : instance.Name)
--   • Attribut "CashParSeconde"  number   optionnel, ligne CPS dans le billboard
--   • Attribut "Prix"            number   optionnel, stocké dans le Tool
--
-- SPAWNER DYNAMIQUE — avant CollectionService:AddTag(clone, "BrainrotCollectible") :
--   clone:SetAttribute("Rarete",       "COMMON")
--   clone:SetAttribute("LifeTime",     60)
--   clone:SetAttribute("OriginalName", modele.Name)
-- ============================================================

local BrainrotPickupModule = {}

-- ─────────────────────────────────────────────────────────────
-- Services
-- ─────────────────────────────────────────────────────────────

local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

-- ─────────────────────────────────────────────────────────────
-- ⚙️  CONFIGURATION — modifier librement
-- ─────────────────────────────────────────────────────────────

local TAG                  = "BrainrotCollectible"   -- tag CollectionService à poser sur chaque brainrot
local PICKUP_HOLD_DURATION = 3                        -- secondes à maintenir
local PICKUP_MAX_DISTANCE  = 10                       -- studs d'activation du ProximityPrompt
local DEFAULT_LIFETIME     = 60                       -- durée (s) si attribut "LifeTime" absent
local BILLBOARD_STUDS_Y    = 7                        -- hauteur du billboard au-dessus du brainrot

-- ─────────────────────────────────────────────────────────────
-- 🎨 COULEURS PAR RARETÉ
-- ─────────────────────────────────────────────────────────────

local RARETE_COULEURS = {
    COMMON    = Color3.fromRGB(200, 200, 200),
    RARE      = Color3.fromRGB(0,   120, 255),
    EPIC      = Color3.fromRGB(150,   0, 255),
    LEGENDARY = Color3.fromRGB(255, 200,   0),
    MYTHIC    = Color3.fromRGB(255,  50,  50),
    GOD       = Color3.fromRGB(255, 140,   0),  -- arc-en-ciel animé
    SECRET    = Color3.fromRGB(255, 255, 255),  -- blanc↔noir animé
    OG        = Color3.fromRGB(100, 220, 255),
}

-- ─────────────────────────────────────────────────────────────
-- UTILITAIRES
-- ─────────────────────────────────────────────────────────────

local function GetRootPart(instance)
    if instance:IsA("Model") then
        return instance.PrimaryPart
            or instance:FindFirstChildWhichIsA("BasePart", true)
    elseif instance:IsA("BasePart") then
        return instance
    end
    return nil
end

local function FormatNombre(n)
    n = tonumber(n) or 0
    if     n >= 1e12 then return ("%.1fT"):format(n / 1e12)
    elseif n >= 1e9  then return ("%.1fB"):format(n / 1e9)
    elseif n >= 1e6  then return ("%.1fM"):format(n / 1e6)
    elseif n >= 1e3  then return ("%.1fK"):format(n / 1e3)
    else                  return tostring(math.floor(n))
    end
end

local function FormatTimer(t)
    t = math.max(0, math.floor(t))
    local m = math.floor(t / 60)
    local s = t % 60
    return m > 0 and ("%d:%02d"):format(m, s) or ("%ds"):format(s)
end

-- ─────────────────────────────────────────────────────────────
-- BILLBOARD
-- ─────────────────────────────────────────────────────────────

local BILLBOARD_NAME = "_BRBillboard"

local function MakeLabel(parent, name, text, posY, color)
    local label = Instance.new("TextLabel")
    label.Name                   = name
    label.Text                   = text
    label.Size                   = UDim2.new(1, 0, 0.20, 0)
    label.Position               = UDim2.new(0, 0, posY, 0)
    label.TextColor3             = color or Color3.new(1, 1, 1)
    label.TextScaled             = true
    label.Font                   = Enum.Font.GothamBold
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3       = Color3.new(1, 1, 1)
    label.Parent                 = parent
    return label
end

local function SetupBillboard(brainrot, duration)
    local root = GetRootPart(brainrot)
    if not root then return nil end

    -- Supprimer tous les BillboardGui existants (évite les doublons si script relancé)
    for _, child in ipairs(root:GetChildren()) do
        if child:IsA("BillboardGui") then child:Destroy() end
    end

    local rarete  = brainrot:GetAttribute("Rarete")         or "COMMON"
    local nomAff  = brainrot:GetAttribute("OriginalName")   or brainrot.Name
    local prix    = brainrot:GetAttribute("Prix")           or 0
    local cps     = brainrot:GetAttribute("CashParSeconde") or 0
    local couleur = RARETE_COULEURS[rarete] or Color3.new(1, 1, 1)

    local bb = Instance.new("BillboardGui")
    bb.Name         = BILLBOARD_NAME
    bb.Size         = UDim2.new(5, 0, 2.5, 0)
    bb.StudsOffset  = Vector3.new(0, BILLBOARD_STUDS_Y, 0)
    bb.AlwaysOnTop  = false
    bb.ResetOnSpawn = false
    bb.Parent       = root

    -- 5 lignes (chacune 20 % de hauteur) : Nom / Rarete / Prix / CPS / Timer
    MakeLabel(bb, "LNom",   nomAff,                              0,    Color3.fromRGB(0, 0, 0))
    local lRarete =
    MakeLabel(bb, "LRarete", rarete,                             0.20, couleur)
    MakeLabel(bb, "LPrix",  "$" .. FormatNombre(prix),           0.40, Color3.fromRGB(0, 220, 0))
    MakeLabel(bb, "LCPS",   "$" .. FormatNombre(cps) .. "/s",   0.60, Color3.fromRGB(255, 215, 0))
    MakeLabel(bb, "LTimer", FormatTimer(duration),               0.80, Color3.fromRGB(220, 60, 60))

    -- Animation arc-en-ciel (GOD ou BRAINROT_GOD)
    if rarete == "GOD" or rarete == "BRAINROT_GOD" then
        local hue, conn = 0, nil
        conn = RunService.Heartbeat:Connect(function(dt)
            if not lRarete or not lRarete.Parent then conn:Disconnect() return end
            hue = (hue + dt * 0.5) % 1
            lRarete.TextColor3 = Color3.fromHSV(hue, 1, 1)
        end)
    -- Animation blanc/noir (SECRET)
    elseif rarete == "SECRET" then
        lRarete.TextColor3 = Color3.fromRGB(255, 255, 255)
        TweenService:Create(lRarete,
            TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, true),
            { TextColor3 = Color3.fromRGB(20, 20, 20) }
        ):Play()
    end

    return bb
end

local function UpdateBillboardTimer(brainrot, t)
    local root = GetRootPart(brainrot)
    if not root then return end
    local bb = root:FindFirstChild(BILLBOARD_NAME)
    if not bb then return end
    local label = bb:FindFirstChild("LTimer")
    if not label then return end
    label.Text = FormatTimer(t)
    if t <= 10 then label.TextColor3 = Color3.fromRGB(255, 30, 30) end
end

-- ─────────────────────────────────────────────────────────────
-- TOOL — CRÉATION
-- ─────────────────────────────────────────────────────────────

local function CreateBrainrotTool(brainrot)
    local rarete  = brainrot:GetAttribute("Rarete")         or "COMMON"
    local nomOrig = brainrot:GetAttribute("OriginalName")   or brainrot.Name
    local prix    = brainrot:GetAttribute("Prix")           or 0
    local cps     = brainrot:GetAttribute("CashParSeconde") or 0
    local couleur = RARETE_COULEURS[rarete] or Color3.new(1, 1, 1)

    local tool = Instance.new("Tool")
    tool.Name           = nomOrig
    tool.ToolTip        = "[" .. rarete .. "] " .. nomOrig
    tool.CanBeDropped   = false
    tool.RequiresHandle = true
    tool:SetAttribute("Rarete",         rarete)
    tool:SetAttribute("BrainrotName",   nomOrig)
    tool:SetAttribute("Prix",           prix)
    tool:SetAttribute("CashParSeconde", cps)

    -- Handle : sphère Neon colorée selon la rareté (1 stud)
    local handle = Instance.new("Part")
    handle.Name         = "Handle"
    handle.Shape        = Enum.PartType.Ball
    handle.Size         = Vector3.new(1, 1, 1)
    handle.Color        = couleur
    handle.Material     = Enum.Material.Neon
    handle.Transparency = 1   -- invisible : seul le visuel cloné est affiché dans la main
    handle.Anchored     = false
    handle.CanCollide   = false
    handle.CFrame       = CFrame.new(0, 0, 0)
    handle.Parent       = tool

    -- Clone du visuel soudé au Handle
    local visualClone
    if brainrot:IsA("Model") then
        visualClone = brainrot:Clone()
    elseif brainrot:IsA("BasePart") then
        local m = Instance.new("Model")
        m.Name = brainrot.Name
        local p = brainrot:Clone()
        p.Parent = m
        visualClone = m
    end

    if visualClone then
        -- Retirer le tag BrainrotCollectible du clone et de tous ses descendants
        -- pour éviter que CollectionService ne re-déclenche SetupBrainrot sur le Tool
        CollectionService:RemoveTag(visualClone, TAG)
        for _, desc in ipairs(visualClone:GetDescendants()) do
            CollectionService:RemoveTag(desc, TAG)
        end

        -- Nettoyer billboards, prompts et scripts du clone
        for _, desc in ipairs(visualClone:GetDescendants()) do
            if desc:IsA("BillboardGui")
            or desc:IsA("ProximityPrompt")
            or desc:IsA("Script")
            or desc:IsA("LocalScript") then
                desc:Destroy()
            end
        end

        -- Centrer le visuel à l'origine et souder au Handle
        local ok = pcall(function() visualClone:PivotTo(CFrame.new(0, 0, 0)) end)
        if ok then
            for _, part in ipairs(visualClone:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored   = false
                    part.CanCollide = false
                    local wc = Instance.new("WeldConstraint")
                    wc.Part0  = handle
                    wc.Part1  = part
                    wc.Parent = handle
                end
            end
            visualClone.Parent = tool
        else
            visualClone:Destroy()
            warn("[BrainrotPickup] PivotTo échoué pour", nomOrig, "— Tool sans visuel")
        end
    end

    return tool
end

-- ─────────────────────────────────────────────────────────────
-- CARRY CAPACITY — état par joueur
-- ─────────────────────────────────────────────────────────────

local DEFAULT_CARRY_CAPACITY = 1   -- capacité de départ

-- capacité max de chaque joueur  { [userId] = number }
local carryCapacity = {}

local function GetCapacity(player)
    return carryCapacity[player.UserId] or DEFAULT_CARRY_CAPACITY
end

-- Compte les Brainrots Tools portés (Backpack + main)
local function CountCarried(player)
    local count = 0
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("Rarete") then
                count += 1
            end
        end
    end
    local char = player.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("Rarete") then
                count += 1
            end
        end
    end
    return count
end

local function IsAtCapacity(player)
    return CountCarried(player) >= GetCapacity(player)
end

-- RemoteEvents partagés avec le client
local function GetOrCreate(class, name)
    local e = ReplicatedStorage:FindFirstChild(name)
    if e then return e end
    local inst = Instance.new(class)
    inst.Name   = name
    inst.Parent = ReplicatedStorage
    return inst
end

local CarryUpdateEvent  = GetOrCreate("RemoteEvent", "BrainrotCarryUpdate")   -- serveur → client : {carried, capacity}
local CarryErrorEvent   = GetOrCreate("RemoteEvent", "BrainrotCarryError")    -- serveur → client : message
local UpgradeCarryEvent = GetOrCreate("RemoteEvent", "BrainrotUpgradeCarry")  -- client → serveur : demande upgrade

-- Traitement de la demande d'upgrade (gratuit pour l'instant)
UpgradeCarryEvent.OnServerEvent:Connect(function(player)
    carryCapacity[player.UserId] = GetCapacity(player) + 1
    CarryUpdateEvent:FireClient(player, CountCarried(player), GetCapacity(player))
    print(("[BrainrotPickup] %s : capacité → %d"):format(player.Name, GetCapacity(player)))
end)

-- ─────────────────────────────────────────────────────────────
-- TOOL — DONNER AU JOUEUR
-- (déclaré ici pour accéder à CarryUpdateEvent, CountCarried, GetCapacity)
-- ─────────────────────────────────────────────────────────────

local function GiveBrainrotTool(player, brainrot)
    local ok, result = pcall(CreateBrainrotTool, brainrot)
    if not ok or not result then
        warn("[BrainrotPickup] Erreur création Tool :", result)
        return false
    end

    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        warn("[BrainrotPickup] Backpack introuvable pour", player.Name)
        result:Destroy()
        return false
    end

    result.Parent = backpack
    print(("[BrainrotPickup] %s a collecté %s [%s]")
        :format(player.Name, result.Name, result:GetAttribute("Rarete") or "?"))
    -- Mettre à jour la jauge côté client
    CarryUpdateEvent:FireClient(player, CountCarried(player), GetCapacity(player))
    return true
end

-- ─────────────────────────────────────────────────────────────
-- PICKUP — PROXIMITYPROMPT
-- ─────────────────────────────────────────────────────────────

local function SetupPickup(brainrot)
    local root = GetRootPart(brainrot)
    if not root then
        warn("[BrainrotPickup] Aucune BasePart sur", brainrot.Name, "— pickup ignoré")
        return
    end

    -- Supprimer les prompts existants (évite les doublons)
    for _, child in ipairs(root:GetChildren()) do
        if child:IsA("ProximityPrompt") then child:Destroy() end
    end

    local rarete = brainrot:GetAttribute("Rarete")       or "COMMON"
    local nomAff = brainrot:GetAttribute("OriginalName") or brainrot.Name

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText            = "Collect"
    prompt.ObjectText            = "[" .. rarete .. "] " .. nomAff
    prompt.HoldDuration          = PICKUP_HOLD_DURATION
    prompt.MaxActivationDistance = PICKUP_MAX_DISTANCE
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = root

    -- Dès que le joueur commence à maintenir : bloquer immédiatement
    -- si la capacité est atteinte (feedback immédiat + prompt masqué brièvement)
    prompt.PromptButtonHoldBegan:Connect(function(player)
        if IsAtCapacity(player) then
            CarryErrorEvent:FireClient(player, "Vous ne pouvez pas porter plus de Brainrots")
            prompt.Enabled = false
            task.delay(0.15, function()
                if prompt and prompt.Parent then
                    prompt.Enabled = true
                end
            end)
        end
    end)

    prompt.Triggered:Connect(function(player)
        -- Guard 1 : brainrot encore présent
        if not brainrot or not brainrot.Parent then return end
        -- Guard 2 : anti-race (deux joueurs ou double-clic)
        if brainrot:GetAttribute("_Collecting") then return end
        brainrot:SetAttribute("_Collecting", true)
        -- Guard 3 : capacité de portage atteinte
        if IsAtCapacity(player) then
            local cap = GetCapacity(player)
            CarryErrorEvent:FireClient(player,
                ("Vous ne pouvez pas porter plus de Brainrots (%d/%d)"):format(CountCarried(player), cap))
            brainrot:SetAttribute("_Collecting", nil)
            return
        end
        -- Guard 4 : validation distance (anti-exploit téléportation)
        local char = player.Character
        if char and char.PrimaryPart then
            local dist = (char.PrimaryPart.Position - root.Position).Magnitude
            if dist > PICKUP_MAX_DISTANCE + 5 then
                brainrot:SetAttribute("_Collecting", nil)
                return
            end
        end
        -- Guard 5 : Backpack présent (joueur pas en train de respawn)
        if not player:FindFirstChildOfClass("Backpack") then
            brainrot:SetAttribute("_Collecting", nil)
            return
        end
        -- Donner le Tool puis détruire le brainrot
        local success = GiveBrainrotTool(player, brainrot)
        if not success then
            brainrot:SetAttribute("_Collecting", nil)
            return
        end
        brainrot:Destroy()
    end)
end

-- ─────────────────────────────────────────────────────────────
-- COUNTDOWN + AUTO-DESPAWN
-- ─────────────────────────────────────────────────────────────

local function StartCountdown(brainrot, duration)
    task.spawn(function()
        for t = duration, 0, -1 do
            if not brainrot or not brainrot.Parent then return end
            UpdateBillboardTimer(brainrot, t)
            if t > 0 then task.wait(1) end
        end
        if brainrot and brainrot.Parent then
            brainrot:Destroy()
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- SETUP COMPLET D'UN BRAINROT
-- ─────────────────────────────────────────────────────────────

local function SetupBrainrot(brainrot)
    -- Attendre 1 frame : garantit que les attributs sont définis avant lecture
    -- (les spawners posent souvent le tag juste avant SetAttribute)
    task.wait()
    if not brainrot or not brainrot.Parent then return end

    local duration = brainrot:GetAttribute("LifeTime") or DEFAULT_LIFETIME
    SetupBillboard(brainrot, duration)
    SetupPickup(brainrot)
    StartCountdown(brainrot, duration)
end

-- ─────────────────────────────────────────────────────────────
-- API PUBLIQUE
-- ─────────────────────────────────────────────────────────────

--[[
    BrainrotPickupModule.Init(config)

    À appeler une seule fois depuis un ServerScript ou un ModuleScript boot.
    Toutes les clés de `config` sont optionnelles — les valeurs par défaut
    définies en haut de ce fichier sont utilisées si absentes.

    config = {
        Tag                  = "BrainrotCollectible",  -- tag CollectionService
        HoldDuration         = 3,        -- secondes à maintenir le prompt
        MaxDistance          = 10,       -- studs d'activation
        DefaultLifetime      = 60,       -- secondes avant auto-despawn
        BillboardStudsY      = 7,        -- hauteur du billboard
        DefaultCarryCapacity = 1,        -- slots de portage initiaux
        RarityColors         = { ... },  -- table { RARETE = Color3 }
    }
--]]
function BrainrotPickupModule.Init(config)
    -- Appliquer les overrides de config (toutes les clés sont optionnelles)
    config = config or {}
    if config.Tag                  then TAG                   = config.Tag                  end
    if config.HoldDuration         ~= nil then PICKUP_HOLD_DURATION  = config.HoldDuration  end
    if config.MaxDistance          ~= nil then PICKUP_MAX_DISTANCE   = config.MaxDistance   end
    if config.DefaultLifetime      ~= nil then DEFAULT_LIFETIME      = config.DefaultLifetime end
    if config.BillboardStudsY      ~= nil then BILLBOARD_STUDS_Y     = config.BillboardStudsY end
    if config.DefaultCarryCapacity ~= nil then DEFAULT_CARRY_CAPACITY = config.DefaultCarryCapacity end
    if config.RarityColors              then RARETE_COULEURS         = config.RarityColors  end

    -- Instances déjà taggées (placées en Studio)
    for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
        task.spawn(SetupBrainrot, inst)
    end
    -- Instances taggées dynamiquement en cours de jeu
    CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
        task.spawn(SetupBrainrot, inst)
    end)
    -- Envoyer la capacité initiale dès qu'un joueur arrive
    Players.PlayerAdded:Connect(function(player)
        task.delay(1, function()
            if player and player.Parent then
                CarryUpdateEvent:FireClient(player, CountCarried(player), GetCapacity(player))
            end
        end)
    end)
    -- Nettoyage à la déconnexion
    Players.PlayerRemoving:Connect(function(player)
        carryCapacity[player.UserId] = nil
    end)
    print("[BrainrotPickup] ✓ Démarré — tag : '" .. TAG .. "'"
        .. " | hold:" .. PICKUP_HOLD_DURATION .. "s"
        .. " | dist:" .. PICKUP_MAX_DISTANCE .. " studs")
end

return BrainrotPickupModule
