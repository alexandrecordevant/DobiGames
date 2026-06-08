-- StarterPlayer/StarterPlayerScripts/BaleClient.client.lua
-- Animation LOCALE et FLUIDE des bales de paille (60 FPS, sans réseau).
--
-- Chaque client calcule lui-même la CFrame de chaque bale via la formule
-- déterministe partagée BaleMotion, basée sur workspace:GetServerTimeNow().
-- Résultat : mouvement parfaitement lisse pour TOUS les joueurs. Le serveur garde
-- l'autorité sur le kill (BaleSystem.lua).
--
-- ⚠️ StreamingEnabled : les bales ne sont streamées au client que lorsqu'il
-- s'approche du ChampCommun (bien après le démarrage du script). On ne les résout
-- donc PAS une seule fois au boot : on les ré-acquiert en continu dans la boucle.
-- Dès qu'une bale est présente, on l'anime ; si elle stream dehors/dedans, ça
-- s'auto-répare (re-acquisition de la nouvelle instance).

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Logger     = require(ReplicatedStorage:WaitForChild("SharedLib"):WaitForChild("Logger"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local BaleMotion = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BaleMotion"))

local SOUND_NAME = "BaleRollSound"

Logger.info("Bale", "Client : animation locale en attente des bales (streaming)…")

-- ═══════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════

local function TrouverPart(bale)
    if bale:IsA("BasePart") then return bale end
    for _, desc in ipairs(bale:GetDescendants()) do
        if desc:IsA("BasePart") then return desc end
    end
    return nil
end

-- (Re)prépare un balot fraîchement présent côté client. Renvoie l'état ou nil.
local function PreparerBale(bale)
    local part = TrouverPart(bale)
    if not part then return nil end

    -- Ancrer localement (le serveur le fait aussi ; sécurité avant de déplacer).
    for _, desc in ipairs(bale:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Anchored = true
        end
    end
    part.Anchored = true

    local isModel = bale:IsA("Model")
    if isModel and not bale.PrimaryPart then
        bale.PrimaryPart = part
    end

    -- Orientation Studio d'origine (le serveur ne la modifie jamais).
    local rx0, ry0, rz0 = part.CFrame:ToEulerAnglesXYZ()

    -- Son de roulement spatial (suit la bale). Une seule instance par part.
    local sonId = GameConfig.SonBale
    if sonId and sonId ~= 0 and not part:FindFirstChild(SOUND_NAME) then
        local son = Instance.new("Sound")
        son.Name               = SOUND_NAME
        son.SoundId            = "rbxassetid://" .. tostring(sonId)
        son.Volume             = 0.4
        son.Looped             = true
        son.RollOffMaxDistance = 80
        son.Parent             = part
        son:Play()
    end

    return {
        model   = bale,
        part    = part,
        isModel = isModel,
        x       = part.Position.X,   -- X/Y fixes (seul Z varie)
        y       = part.Position.Y,
        rx0     = rx0, ry0 = ry0, rz0 = rz0,
        radius  = part.Size.X / 2,
    }
end

-- ═══════════════════════════════════════
-- BOUCLE D'ANIMATION (locale, 60 FPS)
-- ═══════════════════════════════════════

local cache  = {}      -- [index] = état préparé
local logged = false   -- log "actif" une seule fois

RunService.RenderStepped:Connect(function()
    local cc = Workspace:FindFirstChild("ChampCommun")
    if not cc then return end

    local now    = Workspace:GetServerTimeNow()
    local actifs = 0

    for i = 1, BaleMotion.COUNT do
        local bale = cc:FindFirstChild("Bale_" .. i)
        if bale and bale.Parent then
            local d = cache[i]
            -- (Re)acquérir si jamais vue OU si l'instance a changé (streaming).
            if not d or d.model ~= bale then
                d = PreparerBale(bale)
                cache[i] = d
            end

            if d and d.part.Parent then
                local z, angle = BaleMotion.Compute(i, now, d.radius)
                local cf = CFrame.new(d.x, d.y, z)
                    * CFrame.Angles(angle, 0, 0)            -- roulement (axe X monde)
                    * CFrame.Angles(d.rx0, d.ry0, d.rz0)    -- orientation Studio préservée
                if d.isModel and d.model.PrimaryPart then
                    d.model:SetPrimaryPartCFrame(cf)
                else
                    d.part.CFrame = cf
                end
                actifs = actifs + 1
            end
        else
            cache[i] = nil   -- streamée dehors : on oubliera l'ancienne instance
        end
    end

    if not logged and actifs > 0 then
        logged = true
        Logger.info("Bale", "Client ✓ — animation locale active (%d balots visibles)", actifs)
    end
end)
