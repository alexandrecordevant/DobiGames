-- ServerScriptService/BaleSystem.lua
-- 4 balots de paille qui roulent dans le ChampCommun (allers-retours sur axe Z).
-- Mort au contact.
--
-- ⚠️ ARCHITECTURE (corrige le clignotement/téléportation multi-joueurs) :
--   • Le mouvement VISUEL est calculé CÔTÉ CLIENT (BaleClient.client.lua), à 60 FPS,
--     depuis la formule déterministe partagée BaleMotion → fluide pour tous, 0 réseau.
--   • Le serveur NE BOUGE PLUS les parts (ancrées, immobiles côté serveur). Il garde
--     l'AUTORITÉ sur le kill : il recalcule la position via la MÊME formule et teste
--     la distance aux joueurs (anti-triche, indépendant du client).
-- Les parts ancrées déplacées par réplication serveur ne s'interpolent pas côté
-- client (Roblox les "snap" à fréquence throttlée) → c'était la cause du bug.

local BaleSystem = {}
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Logger            = require(game:GetService("ServerScriptService").SharedLib.Server.Logger)

local BaleMotion = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BaleMotion"))

-- ═══════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════

-- Marge ajoutée au rayon de la bale pour la zone de mort. Le contact réel a lieu
-- quand le CENTRE du perso est à ~(rayon bale + demi-largeur perso ≈ 2) du centre
-- de la bale. Au-delà (l'ancien +5) on tue 3-5 studs AVANT que la bale touche le
-- joueur → "je me fais écraser sans toucher la bale". On colle donc au contact réel.
local KILL_MARGIN = 2       -- studs ajoutés au rayon (≈ demi-largeur du perso)
local KILL_HZ     = 0.05    -- intervalle de la boucle de détection (~20 Hz)

-- ═══════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════

local function TrouverPart(model)
    if model:IsA("BasePart") then return model end
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then return desc end
    end
    return nil
end

local function TuerJoueur(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid.Health = 0
        local player = Players:GetPlayerFromCharacter(character)
        if player then
            Logger.info("Bale", "💀 %s écrasé par une bale !", player.Name)
        end
    end
end

-- ═══════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════

function BaleSystem.Init()
    local cc = Workspace:FindFirstChild("ChampCommun")
    if not cc then
        Logger.warn("Bale", "ChampCommun introuvable")
        return
    end

    -- Préparer chaque balot : ancrer + mémoriser sa position fixe (X, Y) et son rayon.
    local bales = {}
    for i = 1, BaleMotion.COUNT do
        local bale = cc:FindFirstChild("Bale_" .. i)
        if bale then
            local part = TrouverPart(bale)
            if part then
                -- Ancrer toutes les parts : le serveur ne les anime plus, c'est le
                -- client qui déplace sa copie locale. CanCollide off (kill par distance).
                for _, desc in ipairs(bale:GetDescendants()) do
                    if desc:IsA("BasePart") then
                        desc.Anchored   = true
                        desc.CanCollide = false
                    end
                end
                if part:IsA("BasePart") then
                    part.Anchored   = true
                    part.CanCollide = false
                end

                bales[#bales + 1] = {
                    index  = i,
                    x      = part.Position.X,   -- X/Y fixes (seul Z varie)
                    y      = part.Position.Y,
                    radius = part.Size.X / 2,   -- ~20 studs
                }
            else
                Logger.warn("Bale", "Aucune BasePart dans %s", bale.Name)
            end
        else
            Logger.warn("Bale", "Bale_%d introuvable dans ChampCommun", i)
        end
    end

    if #bales == 0 then
        Logger.warn("Bale", "Aucun balot actif")
        return
    end

    -- ═══ BOUCLE DE DÉTECTION (autorité serveur) ═══
    -- Recalcule la position de chaque bale via la formule partagée et teste la
    -- distance réelle aux joueurs (évite les faux positifs de bounding box).
    local accum = 0
    RunService.Heartbeat:Connect(function(dt)
        accum = accum + dt
        if accum < KILL_HZ then return end
        accum = 0

        local now = Workspace:GetServerTimeNow()

        -- Positions courantes des bales
        local positions = {}
        for _, b in ipairs(bales) do
            local z = BaleMotion.Compute(b.index, now, b.radius)
            positions[#positions + 1] = {
                pos = Vector3.new(b.x, b.y, z),
                kill = b.radius + KILL_MARGIN,
            }
        end

        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                local root     = char:FindFirstChild("HumanoidRootPart")
                if humanoid and root and humanoid.Health > 0 then
                    for _, bp in ipairs(positions) do
                        if (root.Position - bp.pos).Magnitude <= bp.kill then
                            TuerJoueur(char)
                            break
                        end
                    end
                end
            end
        end
    end)

    Logger.info("Bale", "Init ✓ — %d/4 balots actifs (anim client, kill serveur)", #bales)
end

return BaleSystem
