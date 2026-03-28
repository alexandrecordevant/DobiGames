-- ServerScriptService/Specialized/SeedInventory.lua
-- DobiGames — Gestion des graines MYTHIC/SECRET dans l'inventaire joueur
-- Utilisé par FlowerPotSystem pour planter, ArbreSystem pour donner des graines
-- Données stockées dans playerData.graines = { MYTHIC = N, SECRET = N }

local SeedInventory = {}

-- ============================================================
-- Services
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- Valeurs par défaut
-- ============================================================
local RARITES_VALIDES = { "MYTHIC", "SECRET" }

-- Priorité pour HasAny : SECRET > MYTHIC
local PRIORITE = { SECRET = 2, MYTHIC = 1 }

-- ============================================================
-- Utilitaire interne
-- ============================================================

local function estRareteValide(rarity)
    for _, r in ipairs(RARITES_VALIDES) do
        if r == rarity then return true end
    end
    return false
end

-- ============================================================
-- API publique
-- ============================================================

--[[
    Initialise la structure graines dans playerData si absente

    @param data (table) — playerData
]]
function SeedInventory.Init(data)
    if not data.graines then
        data.graines = {
            MYTHIC = 0,
            SECRET = 0,
        }
        return
    end
    -- Migration : s'assurer que toutes les clés existent
    for _, r in ipairs(RARITES_VALIDES) do
        if data.graines[r] == nil then
            data.graines[r] = 0
        end
    end
end

--[[
    Ajoute N graines d'une rareté dans l'inventaire

    @param data     (table)  — playerData
    @param rarity   (string) — "MYTHIC" ou "SECRET"
    @param quantite (number, optionnel) — défaut 1
    @return boolean — true si succès
]]
function SeedInventory.Add(data, rarity, quantite)
    quantite = quantite or 1
    if not estRareteValide(rarity) then
        warn("[SeedInventory] Rareté invalide : " .. tostring(rarity))
        return false
    end
    SeedInventory.Init(data)
    data.graines[rarity] = (data.graines[rarity] or 0) + quantite
    return true
end

--[[
    Consomme une graine (déduit 1 du stock)

    @param data   (table)  — playerData
    @param rarity (string) — "MYTHIC" ou "SECRET"
    @return boolean — true si succès, false si stock insuffisant
]]
function SeedInventory.Use(data, rarity)
    if not estRareteValide(rarity) then
        warn("[SeedInventory] Rareté invalide : " .. tostring(rarity))
        return false
    end
    SeedInventory.Init(data)
    local stock = data.graines[rarity] or 0
    if stock <= 0 then
        return false
    end
    data.graines[rarity] = stock - 1
    return true
end

--[[
    Retourne le nombre de graines d'une rareté

    @param data   (table)  — playerData
    @param rarity (string) — "MYTHIC" ou "SECRET"
    @return number
]]
function SeedInventory.Count(data, rarity)
    if not data or not data.graines then return 0 end
    return data.graines[rarity] or 0
end

--[[
    Vérifie si le joueur a au moins une graine (toutes raretés confondues)
    Retourne la rareté avec la plus haute priorité disponible (SECRET > MYTHIC)

    @param data (table) — playerData
    @return boolean hasAny, string|nil bestRarity
]]
function SeedInventory.HasAny(data)
    if not data or not data.graines then return false, nil end

    -- Tri par priorité décroissante
    local best = nil
    for _, r in ipairs(RARITES_VALIDES) do
        if (data.graines[r] or 0) > 0 then
            if not best or (PRIORITE[r] or 0) > (PRIORITE[best] or 0) then
                best = r
            end
        end
    end

    return best ~= nil, best
end

--[[
    Retourne le total de toutes les graines

    @param data (table) — playerData
    @return number
]]
function SeedInventory.Total(data)
    if not data or not data.graines then return 0 end
    local total = 0
    for _, r in ipairs(RARITES_VALIDES) do
        total = total + (data.graines[r] or 0)
    end
    return total
end

--[[
    Notifie le client de la mise à jour de son inventaire de graines
    Déclenche l'UpdateGraines RemoteEvent si présent

    @param player (Player) — joueur cible
    @param data   (table)  — playerData contenant data.graines
]]
function SeedInventory.NotifyClient(player, data)
    if not data or not data.graines then return end
    local UpdateGraines = ReplicatedStorage:FindFirstChild("UpdateGraines")
    if UpdateGraines then
        pcall(function()
            UpdateGraines:FireClient(player, data.graines)
        end)
    end
end

--[[
    Retourne la liste des raretés valides

    @return table
]]
function SeedInventory.GetValidRarities()
    return RARITES_VALIDES
end

return SeedInventory
