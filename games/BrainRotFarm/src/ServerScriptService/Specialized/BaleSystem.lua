-- ServerScriptService/Common/BaleSystem.lua
-- 4 balots de paille qui roulent dans le ChampCommun
-- Allers-retours désynchronisés sur axe Z
-- Mort au contact

local BaleSystem = {}
local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

-- ═══════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════

local Z_MIN   = -253   -- limite Z min du ChampCommun
local Z_MAX   = 105    -- limite Z max du ChampCommun
local VITESSE = 22     -- studs/seconde (ajustable)

-- Délais de départ désynchronisés
local DELAIS = { 0, 3.5, 7.0, 10.5 }

-- Pauses aléatoires au bord (secondes)
local PAUSE_MIN = 0.3
local PAUSE_MAX = 1.5

-- ═══════════════════════════════════════
-- HELPER — Trouver la Part principale
-- ═══════════════════════════════════════

local function TrouverPart(model)
    if model:IsA("BasePart") then return model end
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then return desc end
    end
    return nil
end

-- ═══════════════════════════════════════
-- TUER LE JOUEUR
-- ═══════════════════════════════════════

local function TuerJoueur(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid.Health = 0
        local player = Players:GetPlayerFromCharacter(character)
        if player then
            print("[BaleSystem] 💀 " .. player.Name .. " écrasé par une bale !")
        end
    end
end

-- ═══════════════════════════════════════
-- DÉMARRER UNE BALE
-- ═══════════════════════════════════════

local function DemarrerBale(bale, delai)
    task.spawn(function()
        task.wait(delai)

        -- Trouver la Part du cylindre
        local part = TrouverPart(bale)
        if not part then
            warn("[BaleSystem] Aucune BasePart dans " .. bale.Name)
            return
        end

        -- Assigner PrimaryPart
        local innerModel = bale:FindFirstChildOfClass("Model") or bale
        if not innerModel.PrimaryPart then
            innerModel.PrimaryPart = part
        end
        if not bale.PrimaryPart then
            bale.PrimaryPart = part
        end

        -- Ancrer toutes les parts
        for _, desc in ipairs(bale:GetDescendants()) do
            if desc:IsA("BasePart") then
                desc.Anchored   = true
                desc.CanCollide = false
            end
        end

        -- Connecter mort sur toutes les parts
        local dejaConnecte = {}
        for _, desc in ipairs(bale:GetDescendants()) do
            if desc:IsA("BasePart") and not dejaConnecte[desc] then
                dejaConnecte[desc] = true
                desc.Touched:Connect(function(hit)
                    local character = hit.Parent
                    if character:FindFirstChildOfClass("Humanoid") then
                        TuerJoueur(character)
                    end
                end)
            end
        end

        -- Sauvegarder CFrame original AVANT toute modification
        -- (préserve l'orientation Studio : RX=180, RY=-1, RZ=-91 ou autre)
        local cfOriginal        = part.CFrame
        local rx0, ry0, rz0    = cfOriginal:ToEulerAnglesXYZ()

        -- Rayon du cylindre pour calculer rotation
        local rayon     = part.Size.X / 2  -- ~20 studs
        local direction = 1  -- 1 = vers Z_MAX, -1 = vers Z_MIN

        print("[BaleSystem] " .. bale.Name .. " démarre (délai " .. delai .. "s)")

        -- ═══ BOUCLE ALLERS-RETOURS ═══
        while bale.Parent do
            local posActuelle = part.Position
            local targetZ     = direction == 1 and Z_MAX or Z_MIN
            local distance    = math.abs(targetZ - posActuelle.Z)
            local duree       = distance / VITESSE
            local steps       = math.max(1, math.floor(duree / 0.03))

            -- Angle total de rotation (roulement)
            local angleTotal = (distance / (2 * math.pi * rayon))
                * 2 * math.pi * direction * -1

            for s = 1, steps do
                if not bale.Parent then break end

                local t     = s / steps
                local newZ  = posActuelle.Z + (targetZ - posActuelle.Z) * t
                local angle = angleTotal * t

                -- Déplacer le Model en combinant :
                --   1. roulement autour de l'axe X MONDE (appliqué en premier)
                --   2. orientation originale préservée (rx0, ry0, rz0) appliquée après
                -- Ordre critique : roulement avant orientation pour rester en espace monde
                -- posActuelle.X et posActuelle.Y fixes — seul Z varie
                bale:SetPrimaryPartCFrame(
                    CFrame.new(posActuelle.X, posActuelle.Y, newZ)
                    * CFrame.Angles(angle, 0, 0)
                    * CFrame.Angles(rx0, ry0, rz0)
                )

                task.wait(0.03)
            end

            -- Inverser direction
            direction = -direction

            -- Pause aléatoire au bord
            task.wait(PAUSE_MIN + math.random() * (PAUSE_MAX - PAUSE_MIN))
        end
    end)
end

-- ═══════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════

function BaleSystem.Init()
    local cc = workspace:FindFirstChild("ChampCommun")
    if not cc then
        warn("[BaleSystem] ChampCommun introuvable")
        return
    end

    local count = 0
    for i = 1, 4 do
        local bale = cc:FindFirstChild("Bale_" .. i)
        if bale then
            DemarrerBale(bale, DELAIS[i])
            count = count + 1
        else
            warn("[BaleSystem] Bale_" .. i .. " introuvable dans ChampCommun")
        end
    end

    print("[BaleSystem] Init ✓ — " .. count .. "/4 balots actifs")
end

return BaleSystem