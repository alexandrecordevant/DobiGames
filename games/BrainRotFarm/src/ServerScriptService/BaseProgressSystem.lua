-- ServerScriptService/BaseProgressSystem.lua
-- Barre d'évolution de la base — 3 jauges de complétion + paliers récompensés.
--   1) base    : niveaux d'upgrades de base (somme / somme des maxNiveau)
--   2) seeds   : graines quotidiennes récupérées cette semaine (data.grainesSemaine / 7)
--   3) mutants : mutants flowerpot découverts (indexObtenu.MUTANTS / total existant)
-- Calcule les valeurs envoyées au HUD et détecte le franchissement des paliers
-- configurés dans GameConfig.BaseProgressConfig pour accorder les récompenses.
--
-- Dépendances injectées depuis Main.server.lua :
--   BaseProgressSystem.GrantLuckyBlock = function(player, tier) -> bool
--   BaseProgressSystem.Celebrer        = function(player, palier)   (optionnel : popup client)

local BaseProgressSystem = {}

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config       = require(ReplicatedStorage.GameConfig)
local AmelioConfig = require(ReplicatedStorage.SharedLib.Shared.AmelioConfig)
local Logger       = require(ServerScriptService.SharedLib.Server.Logger)

-- Dépendances injectées
BaseProgressSystem.GrantLuckyBlock = nil
BaseProgressSystem.Celebrer        = nil

-- État calculé au boot
local _totalMutants = 0   -- (#MYTHIC + #SECRET) × nb types mutants

-- Niveau max de l'Amélioration de Base (le "Base Upgrade Lvl X/30" affiché en jeu).
-- Niveau courant stocké dans data.rebirthLevel (cf. AmelioSystem.niveauActuel).
local _baseMax = #AmelioConfig
if _baseMax <= 0 then _baseMax = 30 end

-- ============================================================
-- Total mutants (calculé au boot par Main)
-- ============================================================

-- Compte le pool aplati MYTHIC+SECRET (inclut les sous-dossiers numérotés,
-- comme FlowerPotGrowthSystem.clonerBRMutant) × nombre de types mutants.
function BaseProgressSystem.CalculerTotalMutants(brainrotsFolder)
    if not brainrotsFolder then return 0 end
    local nbTypes = #(Config.MutantTypes or {})
    if nbTypes == 0 then return 0 end

    local plantables = (Config.FlowerPotConfig and Config.FlowerPotConfig.brPlantables)
        or { "MYTHIC", "SECRET" }

    local nbModeles = 0
    for _, rarity in ipairs(plantables) do
        local dossier = brainrotsFolder:FindFirstChild(rarity)
        if dossier then
            for _, enfant in ipairs(dossier:GetChildren()) do
                if enfant:IsA("Folder") and tonumber(enfant.Name) then
                    nbModeles = nbModeles + #enfant:GetChildren()
                else
                    nbModeles = nbModeles + 1
                end
            end
        end
    end
    return nbModeles * nbTypes
end

function BaseProgressSystem.SetTotalMutants(n)
    _totalMutants = math.max(0, tonumber(n) or 0)
end

-- ============================================================
-- Calcul des 3 jauges
-- ============================================================

function BaseProgressSystem.Compute(data)
    -- Jauge BASE — niveau d'Amélioration de Base (Base Upgrade Lvl X/30)
    local baseCur = math.clamp(tonumber(data.rebirthLevel) or 0, 0, _baseMax)

    -- Jauge SEEDS — graines quotidiennes récupérées cette semaine
    local seedsMax = (Config.BaseProgressConfig and Config.BaseProgressConfig.seedsParSemaine) or 7
    local seedsCur = math.clamp(tonumber(data.grainesSemaine) or 0, 0, seedsMax)

    -- Jauge MUTANTS — entrées indexObtenu.MUTANTS[brNom][type] == true
    local mutCur = 0
    local mut = data.indexObtenu and data.indexObtenu.MUTANTS
    if mut then
        for _, types in pairs(mut) do
            for _, got in pairs(types) do
                if got == true then mutCur = mutCur + 1 end
            end
        end
    end
    local mutMax = _totalMutants
    if mutMax > 0 and mutCur > mutMax then mutCur = mutMax end

    return {
        base    = { cur = baseCur,  max = _baseMax,  pct = _baseMax  > 0 and baseCur  / _baseMax  or 0 },
        seeds   = { cur = seedsCur, max = seedsMax,  pct = seedsMax  > 0 and seedsCur / seedsMax  or 0 },
        mutants = { cur = mutCur,   max = mutMax,    pct = mutMax    > 0 and mutCur   / mutMax    or 0 },
    }
end

-- ============================================================
-- Octroi d'une récompense de palier
-- ============================================================

-- Retourne true si la récompense a été accordée (sinon : retry au prochain push HUD)
local function accorder(player, data, palier)
    local r = palier.reward
    if not r then return false end

    if r.type == "luckyblock" then
        if BaseProgressSystem.GrantLuckyBlock then
            return BaseProgressSystem.GrantLuckyBlock(player, r.tier or 1) == true
        end
        return false
    elseif r.type == "coins" then
        data.coins = (data.coins or 0) + (r.montant or 0)
        return true
    end
    return false
end

-- ============================================================
-- Détection des paliers + octroi
-- Appelé à chaque push HUD (idempotent grâce à data.paliersClaims).
-- ============================================================

-- Vrai si le palier p est atteint d'après le calcul des jauges
local function palierAtteint(p, calc)
    local axe = calc[p.axe]
    if not axe then return false end
    if p.axe == "mutants" and axe.max <= 0 then return false end  -- assets non chargés
    if p.seuilVal then
        return axe.cur >= p.seuilVal
    end
    return axe.max > 0 and axe.pct >= (p.seuilPct or 1)
end

function BaseProgressSystem.CheckAndGrant(player, data, calc)
    if not data then return end
    calc = calc or BaseProgressSystem.Compute(data)

    data.paliersClaims = data.paliersClaims or {}
    local claims  = data.paliersClaims
    local paliers = (Config.BaseProgressConfig and Config.BaseProgressConfig.paliers) or {}

    -- Baseline (premier passage) : marque les paliers one-time DÉJÀ atteints comme acquis
    -- SANS rien accorder, pour ne pas dumper les récompenses au déploiement / à la 1re session.
    -- Seuls les paliers franchis APRÈS ce point déclenchent une récompense.
    if not data.baseProgressBaselined then
        data.baseProgressBaselined = true
        for _, p in ipairs(paliers) do
            if not p.recurring and palierAtteint(p, calc) then
                claims[p.key] = true
            end
        end
        return
    end

    for _, p in ipairs(paliers) do
        local axe = calc[p.axe]
        if axe then
            -- Paliers récurrents (graines hebdo) : ré-armés dès que la jauge retombe sous son max
            if p.recurring and axe.cur < axe.max then
                claims[p.key] = nil
            end

            if palierAtteint(p, calc) and not claims[p.key] then
                if accorder(player, data, p) then
                    claims[p.key] = true
                    Logger.info("BaseProgress", "%s palier atteint : %s", player.Name, p.key)
                    if BaseProgressSystem.Celebrer then
                        local ok, err = pcall(BaseProgressSystem.Celebrer, player, p)
                        if not ok then
                            Logger.warn("BaseProgress", "Celebrer échec (%s) : %s", p.key, tostring(err))
                        end
                    end
                end
                -- échec (ex : sac plein pour un Lucky Block) → non marqué, réessai au prochain push
            end
        end
    end
end

return BaseProgressSystem
