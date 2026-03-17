-- ServerScriptService/Common/TracteurSystem.lua
-- DobiGames — Animation tracteur en allers-retours dans le champ
-- Activé uniquement si upgrade Tracteur acheté

local TracteurSystem = {}

-- ============================================================
-- Services
-- ============================================================
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- Config — vitesse et espacement lus depuis GameConfig
-- ============================================================
local Config       = require(ReplicatedStorage.Specialized.GameConfig)
local VITESSE_DEF  = Config.TracteurVitesse    or 12  -- studs/seconde
local ESPACEMENT   = Config.TracteurEspacement or 8   -- studs entre lignes

-- ============================================================
-- État interne — { actif=bool } par baseIndex
-- ============================================================
local tracteurData = {}

-- ============================================================
-- Calcul des lignes de labourage depuis SpawnZone
-- ============================================================
local function calculerLignes(spawnZone)
    local wallTop    = spawnZone:FindFirstChild("Wall_Top")
    local wallBottom = spawnZone:FindFirstChild("Wall_Bottom")
    local wallLeft   = spawnZone:FindFirstChild("Wall_Left")
    local wallRight  = spawnZone:FindFirstChild("Wall_Right")

    if not (wallTop and wallBottom and wallLeft and wallRight) then
        warn("[TracteurSystem] Murs SpawnZone incomplets")
        return nil
    end

    -- Bornes du champ
    local zMin = math.min(wallTop.Position.Z,    wallBottom.Position.Z)
    local zMax = math.max(wallTop.Position.Z,    wallBottom.Position.Z)
    local xMin = math.min(wallLeft.Position.X,   wallRight.Position.X)
    local xMax = math.max(wallLeft.Position.X,   wallRight.Position.X)
    local y    = math.max(
        wallTop.Position.Y, wallBottom.Position.Y,
        wallLeft.Position.Y, wallRight.Position.Y
    ) + 1.5  -- légèrement au-dessus du sol

    -- Générer les passes en X (espacement constant)
    local lignes    = {}
    local direction = 1  -- alterne chaque passe (zigzag)
    local x         = xMin + ESPACEMENT * 0.5

    while x <= xMax do
        table.insert(lignes, {
            debut = Vector3.new(x, y, direction > 0 and zMin or zMax),
            fin   = Vector3.new(x, y, direction > 0 and zMax or zMin),
        })
        x         = x + ESPACEMENT
        direction = direction * -1
    end

    return lignes
end

-- ============================================================
-- Déplacement fluide vers une position (lerp PivotTo)
-- ============================================================
local function deplacerVers(baseIndex, tracteurModel, targetPos, vitesse)
    local ok, startCF = pcall(function() return tracteurModel:GetPivot() end)
    if not ok then return end

    local startPos = startCF.Position
    local endPos   = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
    local dir      = endPos - startPos

    if dir.Magnitude < 0.3 then return end

    -- CFrames de départ et d'arrivée (tracteur orienté vers la destination)
    local startCFrame = CFrame.lookAt(startPos, endPos)
    local endCFrame   = CFrame.lookAt(endPos,   endPos + dir.Unit)

    -- Durée et pas (20 fps)
    local distance = dir.Magnitude
    local duree    = distance / vitesse
    local nbPas    = math.max(1, math.floor(duree / 0.05))
    local dtPas    = duree / nbPas

    for i = 1, nbPas do
        if not tracteurData[baseIndex] or not tracteurData[baseIndex].actif then return end
        local alpha  = i / nbPas
        local newCF  = startCFrame:Lerp(endCFrame, alpha)
        pcall(function() tracteurModel:PivotTo(newCF) end)
        task.wait(dtPas)
    end

    -- Snap final
    pcall(function() tracteurModel:PivotTo(endCFrame) end)
end

-- ============================================================
-- Boucle principale de labourage
-- ============================================================
local function boucleTracteur(baseIndex, tracteurModel, spawnZone, vitesse)
    local lignes = calculerLignes(spawnZone)
    if not lignes or #lignes == 0 then
        warn("[TracteurSystem] Lignes introuvables pour Base_" .. baseIndex)
        return
    end

    print("[TracteurSystem] Base_" .. baseIndex
        .. " — " .. #lignes .. " lignes | vitesse " .. vitesse .. " st/s")

    while tracteurData[baseIndex] and tracteurData[baseIndex].actif do
        for _, ligne in ipairs(lignes) do
            if not tracteurData[baseIndex] or not tracteurData[baseIndex].actif then
                break
            end

            -- Aller au début de la ligne
            deplacerVers(baseIndex, tracteurModel, ligne.debut, vitesse)
            if not tracteurData[baseIndex] or not tracteurData[baseIndex].actif then
                break
            end

            -- Parcourir la ligne
            deplacerVers(baseIndex, tracteurModel, ligne.fin, vitesse)

            task.wait(0.3)  -- courte pause entre lignes
        end

        -- Pause avant de recommencer le cycle
        if tracteurData[baseIndex] and tracteurData[baseIndex].actif then
            task.wait(2)
        end
    end

    print("[TracteurSystem] Base_" .. baseIndex .. " tracteur arrêté")
end

-- ============================================================
-- API publique
-- ============================================================

-- Activer le tracteur animé pour une base
function TracteurSystem.Activer(player, baseIndex)
    -- Déjà actif → skip
    if tracteurData[baseIndex] and tracteurData[baseIndex].actif then return end

    local bases = Workspace:FindFirstChild("Bases")
    if not bases then return end
    local base = bases:FindFirstChild("Base_" .. baseIndex)
    if not base then return end

    local tracteurModel = base:FindFirstChild("Tractor")
    if not tracteurModel then
        warn("[TracteurSystem] Modèle Tractor introuvable dans Base_" .. baseIndex)
        return
    end

    local spawnZone = base:FindFirstChild("SpawnZone")
    if not spawnZone then
        warn("[TracteurSystem] SpawnZone introuvable dans Base_" .. baseIndex)
        return
    end

    -- Ancrer toutes les parts pour TweenService / PivotTo fluide
    for _, part in ipairs(tracteurModel:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.Anchored   = true
                part.CanCollide = false
            end)
        end
    end
    if tracteurModel.PrimaryPart then
        pcall(function() tracteurModel.PrimaryPart.CanCollide = false end)
    end

    tracteurData[baseIndex] = { actif = true }

    task.spawn(function()
        boucleTracteur(baseIndex, tracteurModel, spawnZone, VITESSE_DEF)
    end)

    print("[TracteurSystem] Base_" .. baseIndex
        .. " tracteur activé pour " .. player.Name)
end

-- Désactiver le tracteur d'une base
function TracteurSystem.Desactiver(baseIndex)
    if tracteurData[baseIndex] then
        tracteurData[baseIndex].actif = false
        tracteurData[baseIndex]       = nil
    end
end

-- Init : aucun tracteur actif au démarrage
function TracteurSystem.Init()
    print("[TracteurSystem] ✓ Init")
end

return TracteurSystem
