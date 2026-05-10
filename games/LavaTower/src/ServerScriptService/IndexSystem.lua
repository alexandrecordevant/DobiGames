-- ServerScriptService/IndexSystem.lua
-- Suivi des Brainrots obtenus -- detecte les depots et met a jour playerData.indexObtenu

local IndexSystem = {}

local ServerScriptService = game:GetService("ServerScriptService")
local Logger = require(ServerScriptService.SharedLib.Server.Logger)

local CATEGORIES = { "NORMAL", "GOLD", "DIAMANT", "RAINBOW", "NEBULA", "TOXIC" }

-- Dependances injectees depuis Main.server.lua
IndexSystem.GetData          = nil
IndexSystem.DataStoreManager = nil
IndexSystem.IndexRecevoir    = nil

-- Assure la presence de toutes les categories dans indexObtenu
local function initialiserIndex(data)
    if not data.indexObtenu then
        data.indexObtenu = {}
    end
    for _, cat in ipairs(CATEGORIES) do
        if not data.indexObtenu[cat] then
            data.indexObtenu[cat] = {}
        end
    end
end

-- Determine la categorie d'un spot depuis ses flags de mutation
local function determinerCategorie(info)
    local mut = info.mutation
    if mut == "GOLD"    then return "GOLD"    end
    if mut == "DIAMANT" then return "DIAMANT" end
    if mut == "RAINBOW" then return "RAINBOW" end
    if info.isToxic  == true then return "TOXIC"  end
    if info.isNebula == true then return "NEBULA" end
    return "NORMAL"
end

-- Appele apres chaque changement de spot (hook depuis Main.server.lua)
-- Parcourt les spots occupes et ajoute les nouvelles entrees dans indexObtenu
function IndexSystem.OnSpotChange(player)
    local data = IndexSystem.GetData(player)
    if not data then return end
    initialiserIndex(data)

    local DropSystem = require(ServerScriptService.SharedLib.Server.DropSystem)
    local spots      = DropSystem.GetSpotsOccupesSerialisables(player)

    local nouveaux = false
    for _, info in pairs(spots) do
        local brNom = info.brNom
        if brNom and brNom ~= "" then
            local cat   = determinerCategorie(info)
            local liste = data.indexObtenu[cat]
            if liste then
                local dejaDans = false
                for _, nom in ipairs(liste) do
                    if nom == brNom then
                        dejaDans = true
                        break
                    end
                end
                if not dejaDans then
                    table.insert(liste, brNom)
                    nouveaux = true
                    Logger.info("Index", "%s debloque : %s [%s]", player.Name, brNom, cat)
                end
            end
        end
    end

    if nouveaux and IndexSystem.DataStoreManager then
        pcall(IndexSystem.DataStoreManager.Save, player, data)
    end

    if IndexSystem.IndexRecevoir and player.Parent then
        IndexSystem.IndexRecevoir:FireClient(player, data.indexObtenu)
    end
end

-- Migration des donnees existantes (appele depuis OnPlayerAdded dans Main)
function IndexSystem.MigrerData(data)
    initialiserIndex(data)
end

-- Initialise les handlers RemoteEvent
function IndexSystem.Init(indexDemander, indexRecevoir)
    IndexSystem.IndexRecevoir = indexRecevoir

    indexDemander.OnServerEvent:Connect(function(player)
        local data = IndexSystem.GetData(player)
        if not data then return end
        initialiserIndex(data)
        indexRecevoir:FireClient(player, data.indexObtenu)
        Logger.debug("Index", "Index envoye a %s", player.Name)
    end)

    Logger.info("Index", "IndexSystem initialise")
end

return IndexSystem
