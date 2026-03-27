-- ReplicatedStorage/SharedLib/BRFilterSystem/Filters/Template.lua
-- TEMPLATE DE FILTRE — Copier ce fichier pour créer un nouveau filtre
--
-- ÉTAPES :
--   1. Copier dans la catégorie appropriée (Scale/, Rarity/, Element/, Visual/, State/)
--   2. Renommer le fichier ET le module (NomDuFiltre)
--   3. Implémenter Apply(brModel, params)
--   4. Ajouter le nom dans FilterRegistry.lua (liste FILTRES_VALIDES)
--   5. Tester via FilterManager.Apply(br, {{Name="NomDuFiltre"}})

local NomDuFiltre = {}

-- ============================================================
-- Configuration par défaut
-- ============================================================
NomDuFiltre.Config = {
    -- Exemples (à adapter) :
    -- Couleur    = Color3.fromRGB(255, 255, 255),
    -- Intensite  = 1.0,
    -- Taille     = 1.0,
}

-- ============================================================
-- Fonction d'application
-- ============================================================

--[[
    Applique le filtre à un BR

    @param brModel (Model|BasePart) — Le BR à modifier
    @param params  (table, optionnel) — Surcharge Config au runtime
                                        Ex: {Couleur = Color3.fromRGB(255, 0, 0)}

    RÈGLES OBLIGATOIRES :
    ✅ Toujours utiliser pcall() pour les opérations sur les instances
    ✅ Vérifier que primaryPart existe avant de l'utiliser
    ✅ Nommer les instances créées (évite doublons, facilite RemoveAll)
    ✅ Commentaires en français
    ❌ Jamais détruire les parts originales du BR
    ❌ Jamais modifier le Parent du brModel
]]
function NomDuFiltre.Apply(brModel, params)
    params = params or {}

    -- Trouver la racine (toujours vérifier avant utilisation)
    local primaryPart = brModel.PrimaryPart
                     or brModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        warn("[NomDuFiltre] PrimaryPart introuvable sur", brModel.Name)
        return
    end

    -- ── EXEMPLE : Modifier couleur de toutes les parts ───────
    -- local couleur = params.Couleur or NomDuFiltre.Config.Couleur
    -- for _, part in ipairs(brModel:GetDescendants()) do
    --     if part:IsA("BasePart") then
    --         pcall(function() part.Color = couleur end)
    --     end
    -- end

    -- ── EXEMPLE : Ajouter un PointLight ──────────────────────
    -- pcall(function()
    --     local light = Instance.new("PointLight")
    --     light.Name       = "NomDuFiltreLight"  -- Nom unique pour retrouver/supprimer
    --     light.Brightness = params.Intensite or NomDuFiltre.Config.Intensite
    --     light.Color      = params.Couleur   or NomDuFiltre.Config.Couleur
    --     light.Range      = 15
    --     light.Parent     = primaryPart
    -- end)

    -- ── EXEMPLE : Ajouter ParticleEmitter ────────────────────
    -- pcall(function()
    --     local emitter = Instance.new("ParticleEmitter")
    --     emitter.Name   = "NomDuFiltreParticles"
    --     emitter.Rate   = 10
    --     emitter.Parent = primaryPart
    -- end)

    -- ── EXEMPLE : Stocker attribut custom ────────────────────
    -- pcall(function()
    --     brModel:SetAttribute("MonAttribut", "maValeur")
    -- end)
end

return NomDuFiltre
