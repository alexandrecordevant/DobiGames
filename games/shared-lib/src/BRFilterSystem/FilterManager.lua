-- ReplicatedStorage/SharedLib/BRFilterSystem/FilterManager.lua
-- DobiGames — Gestionnaire principal du système de filtres BR
-- Centralise TOUTES les modifications de BRs (couleur, scale, particules, billboard)

local FilterManager = {}

-- ============================================================
-- Accès au dossier Filters (relatif à ce module)
-- ============================================================
local FiltersFolder = script.Parent:FindFirstChild("Filters")
if not FiltersFolder then
    error("[FilterManager] FATAL: BRFilterSystem/Filters introuvable — vérifie le mapping Rojo")
end

-- ============================================================
-- Utilitaires internes
-- ============================================================

-- Cherche un module de filtre par nom (recherche récursive dans Filters/)
local function trouverFiltreModule(filterName)
    return FiltersFolder:FindFirstChild(filterName, true)
end

-- Applique un seul filtre à un BR
local function appliquerFiltre(brModel, config)
    local filterName = config.Name
    local params     = config.Params or {}

    local filterModule = trouverFiltreModule(filterName)
    if not filterModule then
        warn("[FilterManager] Filtre introuvable :", filterName)
        return false
    end

    -- Require protégé
    local ok, filter = pcall(require, filterModule)
    if not ok or type(filter) ~= "table" then
        warn("[FilterManager] Erreur require filtre :", filterName, filter)
        return false
    end

    -- Vérifier que Apply existe
    if type(filter.Apply) ~= "function" then
        warn("[FilterManager] Filtre sans Apply() :", filterName)
        return false
    end

    -- Appliquer
    local applyOk, err = pcall(filter.Apply, brModel, params)
    if not applyOk then
        warn("[FilterManager] Erreur lors de Apply() pour", filterName, ":", err)
        return false
    end

    return true
end

-- ============================================================
-- API publique
-- ============================================================

--[[
    Applique une liste de filtres à un BR

    @param brModel      (Model|BasePart)  — Le BR à modifier
    @param filterConfigs (table)          — Liste de configs de filtres
                                            Ex: {
                                                {Name = "RarityCOMMON"},
                                                {Name = "Normal"},
                                                {Name = "Billboard", Params = {Text = "COMMON", Color = Color3.fromRGB(200,200,200)}},
                                                {Name = "Pickupable"}
                                            }
    @return success (boolean)

    Usage normal :
        FilterManager.Apply(br, {
            {Name = "RarityCOMMON"},
            {Name = "Normal"},
            {Name = "Billboard", Params = {Text = "COMMON", Color = Color3.fromRGB(200,200,200)}}
        })

    Usage mutant :
        FilterManager.Apply(br, {
            {Name = "ElementEau"},
            {Name = "Normal"},
            {Name = "Billboard", Params = {Text = "🌊 Mutant EAU", Color = Color3.fromRGB(0,150,255)}}
        })
]]
function FilterManager.Apply(brModel, filterConfigs)
    if not brModel then
        warn("[FilterManager] brModel nil — Apply annulé")
        return false
    end

    if type(filterConfigs) ~= "table" then
        warn("[FilterManager] filterConfigs doit être une table")
        return false
    end

    -- Stocker les noms des filtres appliqués (attribut pour debug)
    local noms = {}
    for _, cfg in ipairs(filterConfigs) do
        if cfg.Name then
            table.insert(noms, cfg.Name)
        end
    end
    pcall(function()
        brModel:SetAttribute("AppliedFilters", table.concat(noms, ","))
    end)

    -- Appliquer chaque filtre dans l'ordre
    local tousReussis = true
    for _, cfg in ipairs(filterConfigs) do
        if cfg.Name then
            local ok = appliquerFiltre(brModel, cfg)
            if not ok then tousReussis = false end
        end
    end

    return tousReussis
end

--[[
    Supprime tous les effets ajoutés par des filtres (reset visuel)
    Conserve la géométrie originale du BR

    @param brModel (Model|BasePart)
]]
function FilterManager.RemoveAll(brModel)
    if not brModel then return end

    -- Supprimer effets visuels et UI créés par les filtres
    local aSupprimer = {}
    for _, desc in pairs(brModel:GetDescendants()) do
        local supprimer = false

        if desc:IsA("ParticleEmitter") then supprimer = true
        elseif desc:IsA("PointLight")  then supprimer = true
        elseif desc:IsA("Trail")       then supprimer = true
        elseif desc:IsA("Sparkles")    then supprimer = true
        elseif desc:IsA("BillboardGui") and desc.Name == "BRBillboard"  then supprimer = true
        elseif desc:IsA("ProximityPrompt") and desc.Name == "PickupPrompt" then supprimer = true
        elseif desc:IsA("Attachment") and (desc.Name == "TrailA0" or desc.Name == "TrailA1") then supprimer = true
        end

        if supprimer then
            table.insert(aSupprimer, desc)
        end
    end

    for _, desc in ipairs(aSupprimer) do
        pcall(function() desc:Destroy() end)
    end

    -- Réinitialiser l'attribut de filtres
    pcall(function()
        brModel:SetAttribute("AppliedFilters", nil)
    end)
end

--[[
    Retourne la liste des filtres actuellement appliqués à un BR

    @param brModel (Model|BasePart)
    @return table — liste de noms de filtres
]]
function FilterManager.GetApplied(brModel)
    local ok, filtersStr = pcall(function()
        return brModel:GetAttribute("AppliedFilters")
    end)
    if not ok or not filtersStr then return {} end

    local filters = {}
    for nom in string.gmatch(filtersStr, "[^,]+") do
        table.insert(filters, nom)
    end
    return filters
end

--[[
    Vérifie si un filtre spécifique a été appliqué à un BR

    @param brModel    (Model|BasePart)
    @param filterName (string)
    @return boolean
]]
function FilterManager.HasFilter(brModel, filterName)
    local applied = FilterManager.GetApplied(brModel)
    for _, nom in ipairs(applied) do
        if nom == filterName then return true end
    end
    return false
end

return FilterManager
