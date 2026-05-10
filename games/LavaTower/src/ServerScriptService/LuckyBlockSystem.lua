-- ServerScriptService/LuckyBlockSystem.lua
-- Ouverture des Lucky Blocks depuis les slots de la base
--
-- Flux :
--   1. Achat -> modele "Lucky Block" du tier dans le carry (ShopMonetizationSystem)
--   2. Joueur depose sur un slot -> DropSystem enregistre, modele en Workspace
--   3. Ce systeme detecte IsLuckyBlock=true -> ProximityPrompt "Ouvrir"
--      (les prompts Sell/Retrieve sont desactives pour eviter toute confusion)
--   4. Triggered -> tirage serveur -> VendreBR -> animation monde -> resultat sur slot

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace           = game:GetService("Workspace")
local Logger              = require(ServerScriptService.SharedLib.Server.Logger)
local BrainrotPositioner  = require(ServerScriptService.SharedLib.Server.BrainrotPositioner)

local Config = require(ReplicatedStorage.Modules.GameConfig)

local LuckyBlockSystem = {}

-- Callbacks injectes depuis Main.server.lua
LuckyBlockSystem.GetData          = nil  -- function(player) -> data
LuckyBlockSystem.DataStoreManager = nil  -- module DataStoreManager
LuckyBlockSystem.GetTousLesSpots  = nil  -- function(player) -> {touchPart}
LuckyBlockSystem.VendreBR         = nil  -- function(player, touchPart)
LuckyBlockSystem.DonnerAuCarry    = nil  -- function(player, clone, rareteObj)

local locked       = {}  -- verrou anti-double-activation par userId
local promptsAjoutes = {} -- modele -> true

-- =========================================================
-- Utilitaires tirage
-- =========================================================

local function tirerLabel(weights)
    local total = 0
    for _, w in ipairs(weights) do total = total + (w.chance or 0) end
    local rand  = math.random() * total
    local cumul = 0
    for _, w in ipairs(weights) do
        cumul = cumul + (w.chance or 0)
        if rand <= cumul then return w.label end
    end
    return weights[#weights].label
end

local function resoudreDossier(chemin)
    local parties = {}
    for p in chemin:gmatch("[^%.]+") do table.insert(parties, p) end
    if #parties == 0 then return nil end
    local ok, svc = pcall(function() return game:GetService(parties[1]) end)
    if not ok or not svc then return nil end
    local noeud = svc
    for i = 2, #parties do
        if not noeud then return nil end
        noeud = noeud:FindFirstChild(parties[i])
    end
    return noeud
end

-- Liste plate des modeles Brainrots resultats (hors "Lucky Block" visuel)
local function getSourcesTier(dossierTier)
    local sources = {}
    for _, enfant in ipairs(dossierTier:GetChildren()) do
        if enfant.Name == "Lucky Block" then
            -- modele visuel du Lucky Block, pas un resultat
        elseif tonumber(enfant.Name) ~= nil then
            for _, m in ipairs(enfant:GetChildren()) do
                if m:IsA("Model") or m:IsA("BasePart") then
                    table.insert(sources, m)
                end
            end
        elseif enfant:IsA("Model") or enfant:IsA("BasePart") then
            table.insert(sources, enfant)
        end
    end
    return sources
end

local function tirerModele(tierCfg)
    local dossierTier = resoudreDossier(tierCfg.folder)
    if not dossierTier then return nil end

    local label       = tirerLabel(tierCfg.weights)
    local sousDossier = dossierTier:FindFirstChild(label)
    local modeles     = {}

    if sousDossier then
        for _, e in ipairs(sousDossier:GetChildren()) do
            if (e:IsA("Model") or e:IsA("BasePart")) and e.Name ~= "Lucky Block" then
                table.insert(modeles, e)
            end
        end
    end

    if #modeles == 0 then
        -- Fallback : tirage dans tout le dossier
        local sources = getSourcesTier(dossierTier)
        if #sources > 0 then
            return sources[math.random(1, #sources)]
        end
        return nil
    end

    return modeles[math.random(1, #modeles)]
end

-- =========================================================
-- Index
-- =========================================================

local function mettreAJourIndex(player, brNom)
    local data = LuckyBlockSystem.GetData(player)
    if not data then return end
    if not data.indexObtenu        then data.indexObtenu        = {} end
    if not data.indexObtenu.NORMAL then data.indexObtenu.NORMAL = {} end

    local liste = data.indexObtenu.NORMAL
    for _, nom in ipairs(liste) do
        if nom == brNom then return end
    end
    table.insert(liste, brNom)
    Logger.info("LuckyBlock", "%s debloque index : %s", player.Name, brNom)

    if LuckyBlockSystem.DataStoreManager then
        pcall(LuckyBlockSystem.DataStoreManager.Save, player, data)
    end
    local re = ReplicatedStorage:FindFirstChild("IndexRecevoir")
    if re and player.Parent then re:FireClient(player, data.indexObtenu) end
end

-- =========================================================
-- Trouver le touchPart le plus proche d un modele
-- =========================================================

local function trouverTouchPartProche(modele, player)
    local getTous = LuckyBlockSystem.GetTousLesSpots
    if not getTous then return nil end
    local tous    = getTous(player)
    local pos     = modele:GetPivot().Position
    local closest, minDist = nil, math.huge
    for _, tp in ipairs(tous) do
        if tp and tp.Parent then
            local d = (tp.Position - pos).Magnitude
            if d < minDist then minDist = d; closest = tp end
        end
    end
    return (minDist < 10) and closest or nil
end

-- =========================================================
-- Prompts Sell/Retrieve sur le touchPart
-- =========================================================

local function desactiverPromptsSlot(touchPart)
    -- Detruire les ancres Sell/Retrieve (et leurs ProximityPrompts)
    -- Empeche tout declenchement accidentel du flux de vente
    for _, name in ipairs({ "AnchorSell", "AnchorRetrieve", "RemplacerPrompt" }) do
        local child = touchPart:FindFirstChild(name)
        if child then pcall(function() child:Destroy() end) end
    end
end

-- =========================================================
-- Animation monde : Brainrots cyclent sur le slot
-- =========================================================

local function nettoyer(clone)
    for _, v in ipairs(clone:GetDescendants()) do
        if v:IsA("Script") or v:IsA("LocalScript")
            or v:IsA("ProximityPrompt") or v:IsA("BillboardGui")
            or v:IsA("BodyForce") or v:IsA("BodyVelocity") or v:IsA("BodyGyro")
            or v:IsA("WeldConstraint") or v:IsA("Weld") then
            pcall(function() v:Destroy() end)
        end
    end
    for _, v in ipairs(clone:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Anchored   = true
            v.CanCollide = false
        end
    end
end

-- lbYaw : angle Y (radians) du Lucky Block capture avant sa destruction
local function placerTemporaire(touchPart, source, lbYaw)
    if not source or not source.Parent then return nil end
    local clone = nil
    pcall(function() clone = source:Clone() end)
    if not clone then return nil end

    nettoyer(clone)
    clone.Parent = Workspace

    local surfY = touchPart.Position.Y + touchPart.Size.Y * 0.5
    local posX  = touchPart.Position.X
    local posZ  = touchPart.Position.Z

    if clone:IsA("Model") then
        pcall(function()
            -- BrainrotPositioner gere le calage vertical correct (pivot vs bounding box)
            BrainrotPositioner.positionnerSurSurface(clone, surfY, posX, posZ, nil, 0)
            -- Surcharger uniquement la rotation Y avec le yaw du Lucky Block
            local p = clone:GetPivot()
            clone:PivotTo(CFrame.new(p.X, p.Y, p.Z) * CFrame.Angles(0, lbYaw or 0, 0))
        end)
    elseif clone:IsA("BasePart") then
        clone.CFrame = CFrame.new(posX, surfY + clone.Size.Y * 0.5, posZ)
            * CFrame.Angles(0, lbYaw or 0, 0)
    end

    return clone
end

-- Anime un clone sur le slot avec effect grandir/retrecir puis le detruit
-- tempsTotal = duree totale d affichage (grow + attente + shrink)
local function afficherModeleAnime(touchPart, source, lbYaw, tempsTotal)
    local clone = placerTemporaire(touchPart, source, lbYaw)
    if not clone then
        task.wait(tempsTotal)
        return
    end

    local STEPS       = 6
    local dureeGrow   = math.min(0.06, tempsTotal * 0.35)
    local dureeShrink = math.min(0.05, tempsTotal * 0.28)
    local dureeStay   = math.max(0, tempsTotal - dureeGrow - dureeShrink)

    -- Partir d une echelle minuscule (invisible)
    if clone:IsA("Model") then
        pcall(function() clone:ScaleTo(0.04) end)
    end

    -- Grandir : ease Out Quad (0.04 → 1)
    for i = 1, STEPS do
        local t     = i / STEPS
        local scale = 1 - (1 - t) ^ 2   -- ease out quad
        if clone:IsA("Model") then
            pcall(function() if clone.Parent then clone:ScaleTo(math.max(0.04, scale)) end end)
        end
        task.wait(dureeGrow / STEPS)
    end
    if clone:IsA("Model") then
        pcall(function() if clone.Parent then clone:ScaleTo(1) end end)
    end

    -- Attente au pic
    if dureeStay > 0 then task.wait(dureeStay) end

    -- Retrecir : ease In Quad (1 → 0.04)
    for i = 1, STEPS do
        local t     = i / STEPS
        local scale = 1 - t ^ 2          -- ease in quad
        if clone:IsA("Model") then
            pcall(function() if clone.Parent then clone:ScaleTo(math.max(0.04, scale)) end end)
        end
        task.wait(dureeShrink / STEPS)
    end

    pcall(function() if clone and clone.Parent then clone:Destroy() end end)
end

local function jouerAnimation(player, touchPart, sourcesTier, sourceResultat, lbYaw)
    -- Phase 1 : defilement rapide (15 modeles, 0.1 s chacun)
    for _ = 1, 15 do
        local src = sourcesTier[math.random(1, #sourcesTier)]
        afficherModeleAnime(touchPart, src, lbYaw, 0.1)
    end

    -- Phase 2 : ralentissement (dernier changement = resultat)
    local intervalles = { 0.18, 0.3, 0.45, 0.65, 0.9 }
    for etape, intervalle in ipairs(intervalles) do
        local src = (etape == #intervalles) and sourceResultat
                    or sourcesTier[math.random(1, #sourcesTier)]
        afficherModeleAnime(touchPart, src, lbYaw, intervalle)
    end

    -- Phase 3 : donner le Brainrot resultat au joueur comme un vrai pickup de la tour
    if LuckyBlockSystem.DonnerAuCarry then
        local cps    = sourceResultat:GetAttribute("CashParSeconde") or 0
        local rarete = sourceResultat:GetAttribute("Rarete") or "COMMON"
        local rareteObj = { nom = rarete, dossier = rarete, isMutant = false, valeur = cps }
        local clone = nil
        pcall(function() clone = sourceResultat:Clone() end)
        if clone then
            local ok, err = pcall(LuckyBlockSystem.DonnerAuCarry, player, clone, rareteObj)
            if not ok then
                Logger.warn("LuckyBlock", "%s DonnerAuCarry : %s", player.Name, tostring(err))
                pcall(function() clone:Destroy() end)
            end
        end
    else
        Logger.warn("LuckyBlock", "DonnerAuCarry non injecte")
    end
end

-- =========================================================
-- ProximityPrompt sur le modele Lucky Block en Workspace
-- =========================================================

local function ajouterPromptSurModele(modele, player, touchPart)
    if promptsAjoutes[modele] then return end
    promptsAjoutes[modele] = true

    local cible = nil
    if modele:IsA("Model") then
        cible = modele.PrimaryPart or modele:FindFirstChildWhichIsA("BasePart")
    elseif modele:IsA("BasePart") then
        cible = modele
    end
    if not cible then promptsAjoutes[modele] = nil; return end

    -- Supprimer tout prompt existant sur la cible
    for _, v in ipairs(cible:GetChildren()) do
        if v:IsA("ProximityPrompt") then pcall(function() v:Destroy() end) end
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name                  = "LuckyBlockPrompt"
    prompt.ActionText            = "Ouvrir"
    prompt.ObjectText            = "Lucky Block"
    prompt.KeyboardKeyCode       = Enum.KeyCode.E
    prompt.HoldDuration          = 0
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = cible

    -- Desactiver Sell / Retrieve / Remplacer pour ne laisser que "Ouvrir"
    desactiverPromptsSlot(touchPart)

    prompt.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer ~= player then return end
        LuckyBlockSystem.OuvrirLuckyBlock(player, modele, touchPart)
    end)

    modele.AncestryChanged:Connect(function()
        if not modele.Parent then promptsAjoutes[modele] = nil end
    end)

    Logger.debug("LuckyBlock", "Prompt Ouvrir ajoute pour %s", player.Name)
end

-- =========================================================
-- Detection des Lucky Blocks en Workspace
-- =========================================================

local function tenterAjoutPrompt(desc)
    if not desc.Parent then return end
    if not (desc:IsA("Model") or desc:IsA("BasePart")) then return end
    if desc:GetAttribute("IsLuckyBlock") ~= true then return end

    local ownerUid = desc:GetAttribute("OwnerUserId")
    if not ownerUid then return end
    local owner = Players:GetPlayerByUserId(ownerUid)
    if not owner then return end

    -- Laisser DropSystem finir d enregistrer le slot
    task.defer(function()
        if not desc.Parent then return end
        local touchPart = trouverTouchPartProche(desc, owner)
        if touchPart then
            ajouterPromptSurModele(desc, owner, touchPart)
        else
            Logger.warn("LuckyBlock", "touchPart introuvable pour %s", owner.Name)
        end
    end)
end

local function scannerWorkspace()
    task.wait(1)
    for _, desc in ipairs(Workspace:GetDescendants()) do
        pcall(tenterAjoutPrompt, desc)
    end
    Workspace.DescendantAdded:Connect(function(desc)
        -- Attendre que DropSystem positionne le modele et cree ses anchors/prompts
        task.wait(0.1)
        pcall(tenterAjoutPrompt, desc)
    end)
    Logger.debug("LuckyBlock", "Scan workspace termine")
end

-- =========================================================
-- Ouverture
-- =========================================================

function LuckyBlockSystem.OuvrirLuckyBlock(player, modele, touchPart)
    local uid = player.UserId
    if locked[uid] then return end
    locked[uid] = true

    local tierIndex = modele:GetAttribute("Tier")
    if not tierIndex or type(tierIndex) ~= "number" then
        locked[uid] = nil; return
    end

    local shopCfg   = Config and Config.Shop
    local luckyList = shopCfg and shopCfg.LuckyBlocks
    if not luckyList or not luckyList[tierIndex] then
        Logger.warn("LuckyBlock", "Config LuckyBlocks[%d] introuvable", tierIndex)
        locked[uid] = nil; return
    end

    -- Tirage serveur avant toute animation
    local tierCfg        = luckyList[tierIndex]
    local sourceResultat = tirerModele(tierCfg)
    if not sourceResultat then
        Logger.warn("LuckyBlock", "%s : aucun resultat dans tier %d", player.Name, tierIndex)
        locked[uid] = nil; return
    end

    local dossierTier = resoudreDossier(tierCfg.folder)
    local sourcesTier = dossierTier and getSourcesTier(dossierTier) or {}
    if #sourcesTier == 0 then
        Logger.warn("LuckyBlock", "%s : dossier tier %d vide", player.Name, tierIndex)
        locked[uid] = nil; return
    end

    Logger.info("LuckyBlock", "%s ouvre Lucky Block tier %d -> %s",
        player.Name, tierIndex, sourceResultat.Name)

    -- Capturer le yaw (angle Y) du Lucky Block AVANT de le detruire
    -- pour que les Brainrots de l animation soient orientes dans le meme sens
    local lbYaw = 0
    pcall(function()
        local cf = nil
        if modele:IsA("Model") and modele.PrimaryPart then
            cf = modele.PrimaryPart.CFrame
        elseif modele:IsA("BasePart") then
            cf = modele.CFrame
        elseif modele:IsA("Model") then
            local _, _ = modele:GetBoundingBox()
            cf = modele:GetPivot()
        end
        if cf then
            lbYaw = math.atan2(cf.LookVector.X, cf.LookVector.Z)
        end
    end)

    -- Retirer le Lucky Block du slot (met a jour spotsData, declanche supprimerModeleSlot)
    if LuckyBlockSystem.VendreBR then
        pcall(LuckyBlockSystem.VendreBR, player, touchPart)
    end
    -- Destruction immediate du modele visuel (VendreBR fait un fade 0.25s, on force la suppression)
    pcall(function() if modele and modele.Parent then modele:Destroy() end end)

    task.spawn(function()
        jouerAnimation(player, touchPart, sourcesTier, sourceResultat, lbYaw + math.pi)
        mettreAJourIndex(player, sourceResultat.Name)
        locked[uid] = nil
        Logger.info("LuckyBlock", "%s Lucky Block resolu : %s", player.Name, sourceResultat.Name)
    end)
end

-- =========================================================
-- Init
-- =========================================================

function LuckyBlockSystem.Init()
    Players.PlayerRemoving:Connect(function(player)
        locked[player.UserId] = nil
    end)
    task.spawn(scannerWorkspace)
    Logger.info("LuckyBlock", "LuckyBlockSystem initialise")
end

return LuckyBlockSystem
