-- ReplicatedStorage/Modules/BaleMotion.lua
-- Mouvement DÉTERMINISTE partagé des bales de paille.
--   • Client  → calcule la CFrame pour l'affichage fluide (60 FPS, localement)
--   • Serveur → calcule la position pour le kill (autorité)
-- La formule dépend uniquement de (index, temps serveur) → résultat IDENTIQUE
-- sur tous les clients ET le serveur, donc AUCUNE réplication de position n'est
-- nécessaire (c'est ce qui supprime le clignotement/téléportation multi-joueurs).

local BaleMotion = {}

BaleMotion.COUNT = 4

-- Bornes de l'aller-retour sur l'axe Z (cf. leaderboards du ChampCommun)
BaleMotion.Z_MIN = -327.5
BaleMotion.Z_MAX =  154

-- Vitesses FIXES par balot (studs/s). Différentes d'un balot à l'autre pour une
-- désynchronisation reproductible (remplace l'ancien math.random non déterministe).
BaleMotion.VITESSES = { 75, 61, 88, 68 }

-- Décalages de phase de départ (s) — désync supplémentaire au boot.
BaleMotion.DELAIS = { 0, 3.5, 7.0, 10.5 }

-- Calcule l'état du balot `index` au temps serveur `t` (workspace:GetServerTimeNow()).
-- `radius` = rayon du cylindre (sert uniquement au roulement).
-- Retourne :
--   z     → position monde sur l'axe Z (onde triangulaire Z_MIN ↔ Z_MAX)
--   angle → rotation de roulement en radians (roulement-sans-glissement CONTINU,
--           sans reset à chaque bord — corrige le saut visuel de l'ancien code)
function BaleMotion.Compute(index, t, radius)
    local zMin = BaleMotion.Z_MIN
    local L    = BaleMotion.Z_MAX - zMin
    local v    = BaleMotion.VITESSES[index] or 75
    local d    = BaleMotion.DELAIS[index] or 0

    -- Onde triangulaire : tau exprimé en "longueurs parcourues"
    local tau  = ((t - d) * v) / L
    local frac = tau % 2
    if frac < 0 then frac = frac + 2 end          -- robustesse si (t - d) < 0
    local posFrac = (frac < 1) and frac or (2 - frac)
    local z = zMin + posFrac * L

    -- Roulement physique : angle ∝ déplacement. En montant (z↑) la bale roule dans
    -- un sens, en descendant (z↓) elle contre-roule → continu, jamais remis à zéro.
    local angle = (z - zMin) / radius

    return z, angle
end

return BaleMotion
