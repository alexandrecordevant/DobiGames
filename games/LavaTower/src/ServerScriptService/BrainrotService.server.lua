-- ============================================================
-- BrainrotService.server.lua
-- Service unifié : Billboard + Timer + Pickup → Tool / Backpack
-- ============================================================
--
-- REMPLACE : BrainrotBillboard, BrainrotPromptService, BrainrotInventoryService
--
-- FONCTIONNEMENT :
--   Écoute le tag CollectionService "BrainrotCollectible".
--   Pour chaque brainrot taggué, exécute SetupBrainrot() :
--     1. Un seul BillboardGui  (Nom / Rareté / Timer intégré)
--     2. Un ProximityPrompt    (pickup validé côté serveur)
--     3. GiveBrainrotTool()   → Tool dans le Backpack du joueur
--
-- INTÉGRATION PlatformSpawner :
--   Avant CollectionService:AddTag(clone, TAG), définir :
--     clone:SetAttribute("Rarete",       "COMMON")   -- string rareté
--     clone:SetAttribute("LifeTime",     60)          -- secondes avant despawn
--     clone:SetAttribute("OriginalName", modele.Name) -- nom original du modèle source
--     (optionnel) clone:SetAttribute("Prix",          0)
--     (optionnel) clone:SetAttribute("CashParSeconde",0)
--
-- BRAINROTS EN STUDIO :
--   Tagguez-les avec le tag "BrainrotCollectible" via les CollectionService tags
--   et définissez les attributs "Rarete" et éventuellement "LifeTime".
-- ============================================================

local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

-- ─────────────────────────────────────────────────────────────
-- ⚙️  CONFIGURATION  — modifier librement
-- ─────────────────────────────────────────────────────────────

local TAG = "BrainrotCollectible"   -- tag CollectionService à poser sur chaque brainrot

local PICKUP_HOLD_DURATION  = 0     -- secondes à maintenir le bouton (0 = clic simple)
local PICKUP_MAX_DISTANCE   = 10    -- studs d'activation du ProximityPrompt
local DEFAULT_LIFETIME      = 60    -- durée (s) si l'attribut "LifeTime" est absent

-- Hauteur (studs) du billboard au-dessus du brainrot
local BILLBOARD_STUDS_Y     = 6

-- ─────────────────────────────────────────────────────────────
-- 🎨 COULEURS PAR RARETÉ
-- ─────────────────────────────────────────────────────────────

local RARETE_COULEURS = {
    COMMON    = Color3.fromRGB(200, 200, 200),
    RARE      = Color3.fromRGB(0,   120, 255),
    EPIC      = Color3.fromRGB(150, 0,   255),
    LEGENDARY = Color3.fromRGB(255, 200, 0  ),
    MYTHIC    = Color3.fromRGB(255, 50,  50 ),
    GOD       = Color3.fromRGB(255, 140, 0  ),  -- arc-en-ciel en animation
    SECRET    = Color3.fromRGB(255, 255, 255),  -- clignotant blanc/noir
    OG        = Color3.fromRGB(100, 220, 255),
}

-- Couleur de fond du Handle Tool (sphère visible dans la main)
local RARETE_COULEURS_HANDLE = RARETE_COULEURS   -- identique aux couleurs billboard

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
    if m > 0 then
        return ("%d:%02d"):format(m, s)
    else
        return ("%ds"):format(s)
    end
end

-- ─────────────────────────────────────────────────────────────
-- BILLBOARD — NETTOYAGE (évite les doublons)
-- ─────────────────────────────────────────────────────────────

local function CleanupBillboardsOnPart(part)
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("BillboardGui") then
            child:Destroy()
        end
    end
end

-- ─────────────────────────────────────────────────────────────
-- BILLBOARD — CRÉATION (1 seul Gui, 4 lignes : Nom/Rareté/CPS/Timer)
-- ─────────────────────────────────────────────────────────────

local BILLBOARD_NAME = "_BRBillboard"

local function MakeLabel(parent, name, text, posY, color)
    local label = Instance.new("TextLabel")
    label.Name                  = name
    label.Text                  = text
    label.Size                  = UDim2.new(1, 0, 0.25, 0)
    label.Position              = UDim2.new(0, 0, posY, 0)
    label.TextColor3            = color or Color3.new(1, 1, 1)
    label.TextScaled            = true
    label.Font                  = Enum.Font.GothamBold
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = 0.4
    label.TextStrokeColor3      = Color3.new(0, 0, 0)
    label.Parent                = parent
    return label
end

--[[
    SetupBillboard(brainrot, duration)
    Crée un unique BillboardGui sur la root part du brainrot.
    Lignes : Nom (blanc) / Rareté (couleur) / CPS (jaune) / Timer (rouge)
    Retourne le BillboardGui créé.
--]]
local function SetupBillboard(brainrot, duration)
    local root = GetRootPart(brainrot)
    if not root then return nil end

    -- Supprimer tous les BillboardGui existants sur cette part (évite les doublons)
    CleanupBillboardsOnPart(root)

    local rarete  = brainrot:GetAttribute("Rarete")         or "COMMON"
    local nomAff  = brainrot:GetAttribute("OriginalName")   or brainrot.Name
    local cps     = brainrot:GetAttribute("CashParSeconde") or 0
    local couleur = RARETE_COULEURS[rarete] or Color3.new(1, 1, 1)

    local bb = Instance.new("BillboardGui")
    bb.Name          = BILLBOARD_NAME
    bb.Size          = UDim2.new(5, 0, 2.5, 0)
    bb.StudsOffset   = Vector3.new(0, BILLBOARD_STUDS_Y, 0)
    bb.AlwaysOnTop   = false
    bb.ResetOnSpawn  = false
    bb.Parent        = root

    -- Ligne 0 : Nom
    MakeLabel(bb, "LNom",    nomAff,                                    0,    Color3.new(1, 1, 1))
    -- Ligne 1 : Rareté (couleur + animation si GOD/SECRET)
    local lRarete = MakeLabel(bb, "LRarete", "✦ " .. rarete .. " ✦",   0.25, couleur)
    -- Ligne 2 : CPS (jaune — 0 si non défini)
    MakeLabel(bb, "LCPS", "⚡ " .. FormatNombre(cps) .. "/s",           0.50, Color3.fromRGB(255, 215, 0))
    -- Ligne 3 : Timer (rouge — mis à jour par UpdateBillboardTimer)
    MakeLabel(bb, "LTimer", "⏱ " .. FormatTimer(duration),             0.75, Color3.fromRGB(220, 60, 60))

    -- Animation GOD : arc-en-ciel
    if rarete == "GOD" then
        local hue  = 0
        local conn
        conn = RunService.Heartbeat:Connect(function(dt)
            if not lRarete or not lRarete.Parent then
                conn:Disconnect()
                return
            end
            hue = (hue + dt * 0.5) % 1
            lRarete.TextColor3 = Color3.fromHSV(hue, 1, 1)
        end)

    -- Animation SECRET : blanc ↔ noir
    elseif rarete == "SECRET" then
        lRarete.TextColor3 = Color3.fromRGB(255, 255, 255)
        local ti = TweenInfo.new(0.3, Enum.EasingStyle.Linear,
            Enum.EasingDirection.Out, -1, true)
        TweenService:Create(lRarete, ti,
            { TextColor3 = Color3.fromRGB(20, 20, 20) }):Play()
    end

    return bb
end

-- ─────────────────────────────────────────────────────────────
-- BILLBOARD — MISE À JOUR TIMER
-- ─────────────────────────────────────────────────────────────

--[[
    UpdateBillboardTimer(brainrot, t)
    Met à jour le label "LTimer" dans le billboard existant.
    t : secondes restantes (number)
--]]
local function UpdateBillboardTimer(brainrot, t)
    local root = GetRootPart(brainrot)
    if not root then return end
    local bb = root:FindFirstChild(BILLBOARD_NAME)
    if not bb then return end
    local label = bb:FindFirstChild("LTimer")
    if not label then return end

    label.Text = "⏱ " .. FormatTimer(t)
    -- Rouge vif dans les 10 dernières secondes
    if t <= 10 then
        label.TextColor3 = Color3.fromRGB(255, 30, 30)
    end
end

-- ─────────────────────────────────────────────────────────────
-- TOOL — CRÉATION
-- ─────────────────────────────────────────────────────────────

--[[
    CreateBrainrotTool(brainrot)
    Crée un Tool Roblox représentant le brainrot.
    Structure :
      Tool
      ├── Handle  (BasePart sphérique colorée selon la rareté)
      │   └── WeldConstraints vers les parts du visuel
      └── [clone du modèle brainrot, désancré, soudé au Handle]

    Le Handle est une sphère Neon de 1 stud, couleur de la rareté.
    Le visuel du brainrot est cloné, pivoté à l'origine, et soudé au Handle.
    Les BillboardGui, ProximityPrompt et Scripts du clone sont supprimés.
--]]
local function CreateBrainrotTool(brainrot)
    local rarete  = brainrot:GetAttribute("Rarete")         or "COMMON"
    local nomOrig = brainrot:GetAttribute("OriginalName")   or brainrot.Name
    local prix    = brainrot:GetAttribute("Prix")           or 0
    local cps     = brainrot:GetAttribute("CashParSeconde") or 0
    local couleur = RARETE_COULEURS_HANDLE[rarete] or Color3.new(1, 1, 1)

    -- ── Créer le Tool ────────────────────────────────────────────────────────
    local tool = Instance.new("Tool")
    tool.Name           = nomOrig
    tool.ToolTip        = "[" .. rarete .. "] " .. nomOrig
    tool.CanBeDropped   = false
    tool.RequiresHandle = true
    -- Attributs utiles pour systèmes externes (HUD, DataStore, etc.)
    tool:SetAttribute("Rarete",          rarete)
    tool:SetAttribute("BrainrotName",    nomOrig)
    tool:SetAttribute("Prix",            prix)
    tool:SetAttribute("CashParSeconde",  cps)

    -- ── Créer le Handle (sphère colorée, 1 stud) ─────────────────────────────
    local handle = Instance.new("Part")
    handle.Name         = "Handle"
    handle.Shape        = Enum.PartType.Ball
    handle.Size         = Vector3.new(1, 1, 1)
    handle.Color        = couleur
    handle.Material     = Enum.Material.Neon
    handle.Transparency = 0
    handle.Anchored     = false
    handle.CanCollide   = false
    handle.CFrame       = CFrame.new(0, 0, 0)
    handle.Parent       = tool

    -- ── Cloner le visuel du brainrot et le souder au Handle ──────────────────
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
        -- Supprimer billboards, prompts et scripts du clone
        for _, desc in ipairs(visualClone:GetDescendants()) do
            if desc:IsA("BillboardGui")
            or desc:IsA("ProximityPrompt")
            or desc:IsA("Script")
            or desc:IsA("LocalScript") then
                desc:Destroy()
            end
        end

        -- Pivoter à l'origine pour que le visuel soit centré sur le Handle
        local okPivot = pcall(function()
            visualClone:PivotTo(CFrame.new(0, 0, 0))
        end)

        if okPivot then
            -- Désancrer toutes les parts et les souder au Handle
            for _, part in ipairs(visualClone:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored   = false
                    part.CanCollide = false
                    local wc   = Instance.new("WeldConstraint")
                    wc.Part0   = handle
                    wc.Part1   = part
                    wc.Parent  = handle
                end
            end
            visualClone.Parent = tool
        else
            -- Fallback : impossible de pivoter, on abandonne le visuel
            visualClone:Destroy()
            warn("[BrainrotService] PivotTo échoué pour", nomOrig,
                 "— Tool sans visuel (Handle coloré uniquement)")
        end
    end

    return tool
end

-- ─────────────────────────────────────────────────────────────
-- TOOL — DONNER AU JOUEUR
-- ─────────────────────────────────────────────────────────────

--[[
    GiveBrainrotTool(player, brainrot)
    Crée le Tool et le place dans le Backpack du joueur.
    Retourne true si succès, false sinon.
--]]
local function GiveBrainrotTool(player, brainrot)
    local ok, result = pcall(CreateBrainrotTool, brainrot)
    if not ok or not result then
        warn("[BrainrotService] Erreur création Tool :", result)
        return false
    end

    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        warn("[BrainrotService] Backpack introuvable pour", player.Name)
        result:Destroy()
        return false
    end

    result.Parent = backpack
    print(("[BrainrotService] %s a collecté %s [%s]")
        :format(player.Name, result.Name, result:GetAttribute("Rarete") or "?"))
    return true
end

-- ─────────────────────────────────────────────────────────────
-- PICKUP — SETUP DU PROXIMITYPROMPT
-- ─────────────────────────────────────────────────────────────

--[[
    SetupPickup(brainrot)
    Ajoute un ProximityPrompt sur la root part du brainrot.
    La logique de collecte est entièrement côté serveur :
      1. Verrou anti-race (_Collecting)
      2. Validation distance (anti-exploit téléportation)
      3. GiveBrainrotTool → Tool dans le Backpack
      4. Destroy du brainrot dans le monde
--]]
local function SetupPickup(brainrot)
    local root = GetRootPart(brainrot)
    if not root then
        warn("[BrainrotService] Aucune BasePart sur", brainrot.Name, "— pickup ignoré")
        return
    end

    -- Supprimer les prompts existants (évite les doublons sur modèles Studio)
    for _, child in ipairs(root:GetChildren()) do
        if child:IsA("ProximityPrompt") then child:Destroy() end
    end

    local rarete  = brainrot:GetAttribute("Rarete")       or "COMMON"
    local nomAff  = brainrot:GetAttribute("OriginalName") or brainrot.Name

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText            = "Collect"
    prompt.ObjectText            = "[" .. rarete .. "] " .. nomAff
    prompt.HoldDuration          = PICKUP_HOLD_DURATION
    prompt.MaxActivationDistance = PICKUP_MAX_DISTANCE
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = root

    -- ── Collecte (logique serveur) ────────────────────────────────────────────
    prompt.Triggered:Connect(function(player)
        -- Guard 1 : brainrot encore valide
        if not brainrot or not brainrot.Parent then return end

        -- Guard 2 : anti-race (deux joueurs ou double-clic simultané)
        if brainrot:GetAttribute("_Collecting") then return end
        brainrot:SetAttribute("_Collecting", true)

        -- Guard 3 : validation distance joueur (anti-exploit)
        local char = player.Character
        if char and char.PrimaryPart then
            local dist = (char.PrimaryPart.Position - root.Position).Magnitude
            if dist > PICKUP_MAX_DISTANCE + 5 then
                brainrot:SetAttribute("_Collecting", nil)
                return
            end
        end

        -- Guard 4 : Backpack présent (joueur pas en train de respawn)
        if not player:FindFirstChildOfClass("Backpack") then
            brainrot:SetAttribute("_Collecting", nil)
            return
        end

        -- Donner le Tool
        local success = GiveBrainrotTool(player, brainrot)
        if not success then
            brainrot:SetAttribute("_Collecting", nil)
            return
        end

        -- Détruire le brainrot du monde
        brainrot:Destroy()
    end)
end

-- ─────────────────────────────────────────────────────────────
-- COUNTDOWN + AUTO-DESPAWN
-- ─────────────────────────────────────────────────────────────

--[[
    StartCountdown(brainrot, duration)
    Lance le décompte affiché dans le Billboard.
    Détruit le brainrot quand le timer atteint 0 (s'il n'a pas été ramassé).
--]]
local function StartCountdown(brainrot, duration)
    task.spawn(function()
        for t = duration, 0, -1 do
            if not brainrot or not brainrot.Parent then return end
            UpdateBillboardTimer(brainrot, t)
            if t > 0 then task.wait(1) end
        end
        -- Auto-despawn si toujours présent
        if brainrot and brainrot.Parent then
            brainrot:Destroy()
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- SETUP COMPLET D'UN BRAINROT
-- ─────────────────────────────────────────────────────────────

--[[
    SetupBrainrot(brainrot)
    Point d'entrée pour chaque instance taggée "BrainrotCollectible".
    Exécuté dans task.spawn — attend 1 frame pour que les attributs
    soient définis avant d'agir (cas spawn dynamique).
--]]
local function SetupBrainrot(brainrot)
    -- Attendre 1 frame : le tag est souvent ajouté juste avant SetAttribute
    -- dans les spawners dynamiques, cette pause garantit la lecture correcte
    task.wait()

    if not brainrot or not brainrot.Parent then return end

    local duration = brainrot:GetAttribute("LifeTime") or DEFAULT_LIFETIME

    SetupBillboard(brainrot, duration)
    SetupPickup(brainrot)
    StartCountdown(brainrot, duration)
end

-- ─────────────────────────────────────────────────────────────
-- POINT D'ENTRÉE — CollectionService
-- ─────────────────────────────────────────────────────────────

-- Instances déjà taggées (placées à la main en Studio)
for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
    task.spawn(SetupBrainrot, inst)
end

-- Instances taggées dynamiquement (spawnées en cours de jeu par PlatformSpawner etc.)
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
    task.spawn(SetupBrainrot, inst)
end)

print("[BrainrotService] ✓ Démarré — tag : '" .. TAG .. "'")
