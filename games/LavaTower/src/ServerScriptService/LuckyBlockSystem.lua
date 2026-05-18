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
local ServerStorage       = game:GetService("ServerStorage")
local Workspace           = game:GetService("Workspace")
local CollectionService   = game:GetService("CollectionService")
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

-- Verrou par touchPart (pas par joueur) pour permettre l ouverture simultanee
-- de plusieurs Lucky Blocks differents par le meme joueur.
-- Valeur = userId du joueur qui a declenche, pour nettoyage au depart.
local locked         = {}  -- [touchPart] = userId
local promptsAjoutes = {}  -- [modele]    = true

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
    -- Retirer BrainrotCollectible avant d'entrer dans Workspace :
    -- sinon PickupSystem recrée un Collect prompt + _BRBillboard via GetInstanceAddedSignal
    pcall(function()
        if CollectionService:HasTag(clone, "BrainrotCollectible") then
            CollectionService:RemoveTag(clone, "BrainrotCollectible")
        end
    end)
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

    -- Parent temporaire dans ServerStorage (non replique au client) pour positionner
    -- le clone avant de le scaler. Le client ne verra jamais la taille initiale complete.
    -- animerGrandir deplace le clone dans Workspace apres ScaleTo initial.
    clone.Parent = ServerStorage

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

    return clone  -- toujours dans ServerStorage ici
end

-- Constantes d animation
local ANIM_SCALE_START = 0.01   -- echelle de depart (1% = vraiment minuscule)
local ANIM_MIN_STEP    = 1 / 60 -- delai minimum par step (un heartbeat a 60 fps)
local ANIM_STEPS       = 10     -- maximum de steps par phase
local ANIM_STEPS_MIN   = 6      -- minimum pour garantir une animation visible

-- Grandit un clone de ANIM_SCALE_START a 1 (ease-out quad) puis attend au pic.
-- Le clone arrive dans ServerStorage (invisible au client) depuis placerTemporaire.
-- Cette fonction le scale d abord, puis le deplace dans Workspace → le client
-- ne voit jamais la taille initiale complete (plus de "double grow").
-- Bloque le thread appelant (grow + stay).
local function animerGrandir(clone, dureeGrow, dureeStay)
    local isModel   = clone and clone:IsA("Model")
    local steps     = math.max(ANIM_STEPS_MIN, math.min(ANIM_STEPS, math.floor(dureeGrow / ANIM_MIN_STEP)))
    local stepDelay = math.max(ANIM_MIN_STEP, dureeGrow / steps)

    -- Scaler pendant que le clone est encore dans ServerStorage (non visible)
    if isModel then pcall(function() clone:ScaleTo(ANIM_SCALE_START) end) end
    -- Transferer dans Workspace : le client decouvre le clone deja a l echelle initiale
    if clone then clone.Parent = Workspace end

    for i = 1, steps do
        local scale = 1 - (1 - i / steps) ^ 2  -- ease out quad
        if isModel then
            pcall(function() if clone.Parent then clone:ScaleTo(math.max(ANIM_SCALE_START, scale)) end end)
        end
        task.wait(stepDelay)
    end
    if isModel then pcall(function() if clone.Parent then clone:ScaleTo(1) end end) end

    if dureeStay > 0 then task.wait(dureeStay) end
end

-- Retrecit un clone de 1 a ANIM_SCALE_START (ease-in quad) puis le detruit.
-- Peut etre appele en tache de fond (task.spawn).
local function animerRetrecir(clone, dureeShrink)
    local isModel   = clone and clone:IsA("Model")
    local steps     = math.max(ANIM_STEPS_MIN, math.min(ANIM_STEPS, math.floor(dureeShrink / ANIM_MIN_STEP)))
    local stepDelay = math.max(ANIM_MIN_STEP, dureeShrink / steps)

    for i = 1, steps do
        local scale = 1 - (i / steps) ^ 2      -- ease in quad
        if isModel then
            pcall(function() if clone.Parent then clone:ScaleTo(math.max(ANIM_SCALE_START, scale)) end end)
        end
        task.wait(stepDelay)
    end
    pcall(function() if clone and clone.Parent then clone:Destroy() end end)
end

-- Melange Fisher-Yates sur une copie du tableau
local function melanger(t)
    local r = {}
    for _, v in ipairs(t) do table.insert(r, v) end
    for i = #r, 2, -1 do
        local j = math.random(1, i)
        r[i], r[j] = r[j], r[i]
    end
    return r
end

local function jouerAnimation(player, touchPart, sourcesTier, sourceResultat, lbYaw)
    -- Construire la file complete d avance pour fixer les aleatoires avant l animation
    local queue = {}

    -- Phase 1 : defilement en cycle shufflé — chaque modele apparait une fois par cycle,
    -- jamais deux fois d affile. Re-shuffle en fin de cycle en s assurant que le premier
    -- element du nouveau cycle ≠ dernier element du precedent.
    local cycle    = melanger(sourcesTier)
    local cycleIdx = 1
    for _ = 1, 15 do
        if cycleIdx > #cycle then
            local dernier = cycle[#cycle]
            cycle = melanger(sourcesTier)
            -- Echanger le premier si identique au dernier du cycle precedent
            if #cycle > 1 and cycle[1] == dernier then
                cycle[1], cycle[2] = cycle[2], cycle[1]
            end
            cycleIdx = 1
        end
        table.insert(queue, { src = cycle[cycleIdx], temps = 0.20 })
        cycleIdx = cycleIdx + 1
    end

    -- Phase 2 : ralentissement progressif — on continue le meme cycle pour eviter une
    -- repetition entre la fin de la Phase 1 et le debut de la Phase 2.
    local intervalles = { 0.30, 0.50, 0.65, 0.80, 0.95 }
    for etape, intervalle in ipairs(intervalles) do
        if etape == #intervalles then
            -- Dernier = resultat definitif
            table.insert(queue, { src = sourceResultat, temps = intervalle })
        else
            if cycleIdx > #cycle then
                local dernier = cycle[#cycle]
                cycle = melanger(sourcesTier)
                if #cycle > 1 and cycle[1] == dernier then
                    cycle[1], cycle[2] = cycle[2], cycle[1]
                end
                cycleIdx = 1
            end
            table.insert(queue, { src = cycle[cycleIdx], temps = intervalle })
            cycleIdx = cycleIdx + 1
        end
    end

    -- Lecture avec overlap : le shrink du brendrot courant se lance en parallele
    -- pendant que le suivant commence deja a grandir, eliminant tout moment vide.
    for i, item in ipairs(queue) do
        local isLast      = (i == #queue)
        local dureeGrow   = item.temps * 0.50  -- 50% pour un grow vraiment visible
        local dureeShrink = item.temps * 0.40
        local dureeStay   = item.temps * 0.10

        local clone = placerTemporaire(touchPart, item.src, lbYaw)

        -- Grow + stay (thread principal bloque)
        if clone then
            animerGrandir(clone, dureeGrow, dureeStay)
        else
            task.wait(dureeGrow + dureeStay)
        end

        -- Shrink : synchrone pour le dernier (garantit fin avant recompense),
        -- asynchrone pour tous les autres (overlap avec le prochain grow).
        if isLast then
            -- Pause pour que le joueur puisse lire ce qu il a obtenu avant que ca disparaisse
            task.wait(1.5)
            animerRetrecir(clone, dureeShrink)
        else
            task.spawn(animerRetrecir, clone, dureeShrink)
        end
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
    if locked[touchPart] then return end
    locked[touchPart] = uid  -- verrou par slot, pas par joueur

    local lbOpenedRE = ReplicatedStorage:FindFirstChild("LuckyBlockOpened")
    if lbOpenedRE then pcall(function() lbOpenedRE:FireClient(player) end) end

    local tierIndex = modele:GetAttribute("Tier")
    if not tierIndex or type(tierIndex) ~= "number" then
        locked[touchPart] = nil; return
    end

    local shopCfg   = Config and Config.Shop
    local luckyList = shopCfg and shopCfg.LuckyBlocks
    if not luckyList or not luckyList[tierIndex] then
        Logger.warn("LuckyBlock", "Config LuckyBlocks[%d] introuvable", tierIndex)
        locked[touchPart] = nil; return
    end

    -- Tirage serveur avant toute animation
    local tierCfg        = luckyList[tierIndex]
    local sourceResultat = tirerModele(tierCfg)
    if not sourceResultat then
        Logger.warn("LuckyBlock", "%s : aucun resultat dans tier %d", player.Name, tierIndex)
        locked[touchPart] = nil; return
    end

    local dossierTier = resoudreDossier(tierCfg.folder)
    local sourcesTier = dossierTier and getSourcesTier(dossierTier) or {}
    if #sourcesTier == 0 then
        Logger.warn("LuckyBlock", "%s : dossier tier %d vide", player.Name, tierIndex)
        locked[touchPart] = nil; return
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
        locked[touchPart] = nil
        Logger.info("LuckyBlock", "%s Lucky Block resolu : %s", player.Name, sourceResultat.Name)
    end)
end

-- =========================================================
-- Init
-- =========================================================

function LuckyBlockSystem.Init()
    Players.PlayerRemoving:Connect(function(player)
        -- Liberer tous les slots verouilles par ce joueur
        local uid = player.UserId
        for tp, lockedUid in pairs(locked) do
            if lockedUid == uid then locked[tp] = nil end
        end
    end)
    task.spawn(scannerWorkspace)
    Logger.info("LuckyBlock", "LuckyBlockSystem initialise")
end

return LuckyBlockSystem
