-- ServerScriptService/BrainrotSpawnManager.server.lua
-- Système de spawn hybride :
--   • Champ individuel  → Common + Epic   (base de chaque joueur)
--   • Champ commun      → Legendary + Mythic + God (Workspace.ChampCommun)
--
-- Intégration économie : fire le BindableEvent "_BrainrotReward" dans
-- ServerScriptService → à connecter dans Main.server.lua (voir bas de fichier)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService   = game:GetService("TextChatService")

-- ── Dépendances ────────────────────────────────────────────────
-- BaseSpawner DOIT être un ModuleScript dans ServerScriptService
local BaseSpawner = require(ServerScriptService:WaitForChild("BaseSpawner"))
local Config      = require(ReplicatedStorage.Modules:WaitForChild("BrainrotSpawnConfig"))

-- Dossier de modèles optionnel (fallback sphère colorée si absent)
local brainrotModels = ReplicatedStorage:FindFirstChild("BrainrotModels")

-- Champ commun dans Workspace (Model contenant une Part "SpawnArea")
local champCommunModel = workspace:WaitForChild("ChampCommun")

-- ── BindableEvent pour récompenser le joueur ───────────────────
-- Main.server.lua doit écouter cet event (voir snippet en bas de fichier)
local rewardEvent = ServerScriptService:FindFirstChild("_BrainrotReward")
if not rewardEvent then
    rewardEvent        = Instance.new("BindableEvent")
    rewardEvent.Name   = "_BrainrotReward"
    rewardEvent.Parent = ServerScriptService
end

-- ── Lookup rapide raretés par nom ─────────────────────────────
local rareteMap = {}
for _, r in ipairs(Config.Raretes) do
    rareteMap[r.nom] = r
end

-- ══════════════════════════════════════════════════════════════
-- UTILITAIRES COMMUNS
-- ══════════════════════════════════════════════════════════════

-- Tire une rareté aléatoire dans une liste de noms autorisés
-- (renormalise automatiquement les probabilités sur le sous-ensemble)
local function TirerRarete(nomsAutorises)
    local pool       = {}
    local totalChance = 0
    for _, nom in ipairs(nomsAutorises) do
        local r = rareteMap[nom]
        if r then
            table.insert(pool, r)
            totalChance = totalChance + r.chance
        end
    end
    if #pool == 0 then return rareteMap["Common"] end

    local rand  = math.random() * totalChance
    local cumul = 0
    for _, r in ipairs(pool) do
        cumul = cumul + r.chance
        if rand <= cumul then return r end
    end
    return pool[#pool]
end

-- Retourne un clone depuis BrainrotModels/<NOM> ou une sphère de fallback
local function GetObjet(rarete)
    if brainrotModels then
        local dossier = brainrotModels:FindFirstChild(rarete.nom)
                     or brainrotModels:FindFirstChild(rarete.nom:upper())
        if dossier then
            local enfants = dossier:GetChildren()
            if #enfants > 0 then
                return enfants[math.random(1, #enfants)]:Clone()
            end
        end
    end
    -- Fallback : Part sphérique colorée
    local part          = Instance.new("Part")
    part.Shape          = Enum.PartType.Ball
    part.Size           = Vector3.one * rarete.taille
    part.Color          = rarete.couleur
    part.Material       = Enum.Material.Neon
    part.CanCollide     = false
    part.Anchored       = true
    part.CastShadow     = false
    part.Name           = "Brainrot_" .. rarete.nom
    return part
end

-- Retourne la BasePart d'ancrage d'un objet (Part ou Model)
local function GetAnchorPart(objet)
    if objet:IsA("BasePart") then return objet end
    return objet.PrimaryPart or objet:FindFirstChildWhichIsA("BasePart", true)
end

-- Positionne un objet au centre d'une zone avec offset aléatoire XZ
local function PoserDansZone(objet, zone)
    local cf   = zone.CFrame
    local size = zone.Size
    local rx   = (math.random() - 0.5) * size.X * 0.9
    local rz   = (math.random() - 0.5) * size.Z * 0.9
    local cible = cf * CFrame.new(rx, size.Y * 0.5, rz)

    if objet:IsA("BasePart") then
        objet.CFrame   = cible
        objet.Anchored = true
    else
        objet:PivotTo(cible)
        -- Ancrer toutes les parts pour éviter la physique
        for _, p in ipairs(objet:GetDescendants()) do
            if p:IsA("BasePart") then p.Anchored = true end
        end
    end
end

-- Ajoute un BillboardGui avec le nom de la rareté sur l'anchorPart
local function AjouterBillboard(anchorPart, rarete)
    local bb           = Instance.new("BillboardGui")
    bb.Size            = UDim2.new(0, 130, 0, 40)
    bb.StudsOffset     = Vector3.new(0, rarete.taille + 1.5, 0)
    bb.AlwaysOnTop     = false
    bb.Parent          = anchorPart

    local lbl                   = Instance.new("TextLabel", bb)
    lbl.Size                    = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency  = 1
    lbl.TextColor3              = rarete.couleur
    lbl.TextStrokeTransparency  = 0
    lbl.TextStrokeColor3        = Color3.new(0, 0, 0)
    lbl.TextScaled              = true
    lbl.Font                    = Enum.Font.GothamBold
    lbl.Text                    = rarete.nom
end

-- Crée un ProximityPrompt sur anchorPart
local function CreerPrompt(anchorPart, holdDuration, actionText)
    local prompt                   = Instance.new("ProximityPrompt")
    prompt.ActionText              = actionText or "Ramasser"
    prompt.ObjectText              = "Brainrot"
    prompt.HoldDuration            = holdDuration or 0
    prompt.MaxActivationDistance   = 8
    prompt.RequiresLineOfSight     = false
    prompt.Parent                  = anchorPart
    return prompt
end

-- Annonce dans le chat serveur (compatible TextChatService)
local function AnnoncerChat(message)
    pcall(function()
        local channels = TextChatService:FindFirstChildOfClass("TextChannel")
        if channels then
            channels:DisplaySystemMessage(message)
        end
    end)
    print("[ChampCommun] " .. message)
end

-- ══════════════════════════════════════════════════════════════
-- CHAMP INDIVIDUEL
-- ══════════════════════════════════════════════════════════════

local champsIndividuels = {}  -- [Player] = { actifs = {} }
local cfgInd            = Config.ChampIndividuel

-- Spawn un brainrot sur la SpawnArea de la base du joueur
local function SpawnerIndividuel(player, spawnArea, actifs)
    if #actifs >= cfgInd.MaxActifs then return end

    local rarete = TirerRarete(cfgInd.Raretes)
    local objet  = GetObjet(rarete)

    PoserDansZone(objet, spawnArea)
    objet.Parent = workspace

    local anchorPart = GetAnchorPart(objet)
    if not anchorPart then objet:Destroy() return end

    AjouterBillboard(anchorPart, rarete)

    local expireAt = os.time() + (cfgInd.Expiration[rarete.nom] or 45)
    local entry    = { objet = objet, expireAt = expireAt }
    table.insert(actifs, entry)

    local prompt = CreerPrompt(anchorPart, 0)

    prompt.Triggered:Connect(function(triggerPlayer)
        -- Seul le propriétaire peut ramasser
        if triggerPlayer ~= player then return end

        -- Retirer de la liste active
        for i, e in ipairs(actifs) do
            if e == entry then table.remove(actifs, i) break end
        end

        -- Récompenser via BindableEvent → Main.server.lua
        rewardEvent:Fire(player, rarete.valeur, rarete)
        objet:Destroy()
    end)
end

-- Boucle de spawn pour un joueur (tourne tant que le joueur est connecté)
local function BoucleChampIndividuel(player)
    while player and player.Parent do
        task.wait(cfgInd.SpawnInterval)

        -- Vérifier que le joueur est toujours là
        local data = champsIndividuels[player]
        if not data then break end

        -- Nettoyer les brainrots expirés
        local now      = os.time()
        local nouveaux = {}
        for _, entry in ipairs(data.actifs) do
            if entry.expireAt <= now then
                if entry.objet and entry.objet.Parent then
                    entry.objet:Destroy()
                end
            else
                table.insert(nouveaux, entry)
            end
        end
        data.actifs = nouveaux

        -- Récupérer la SpawnArea de la base
        local spawnArea = BaseSpawner.GetSpawnArea(player)
        if not spawnArea then continue end

        SpawnerIndividuel(player, spawnArea, data.actifs)
    end
end

local function DemarrerChampIndividuel(player)
    -- Délai pour laisser BaseSpawner créer la base
    task.delay(3, function()
        if not player or not player.Parent then return end
        champsIndividuels[player] = { actifs = {} }
        task.spawn(BoucleChampIndividuel, player)
        print("[BrainrotSpawn] Champ individuel démarré → " .. player.Name)
    end)
end

local function ArreterChampIndividuel(player)
    local data = champsIndividuels[player]
    if not data then return end

    -- Détruire tous les brainrots actifs
    for _, entry in ipairs(data.actifs) do
        if entry.objet and entry.objet.Parent then
            entry.objet:Destroy()
        end
    end

    champsIndividuels[player] = nil
end

-- ══════════════════════════════════════════════════════════════
-- CHAMP COMMUN
-- ══════════════════════════════════════════════════════════════

local actifsCommun = {}  -- liste de { rarete, objet, expireAt }
local cfgCom       = Config.ChampCommun

-- Compte les brainrots actifs par rareté sur le champ commun
local function CompterParRarete()
    local compte = {}
    for _, entry in ipairs(actifsCommun) do
        local nom     = entry.rarete.nom
        compte[nom]   = (compte[nom] or 0) + 1
    end
    return compte
end

-- Tire une rareté en respectant les limites MaxParRarete
local function TirerRareteCommune()
    local compte    = CompterParRarete()
    local autorises = {}
    for _, nom in ipairs(cfgCom.Raretes) do
        local max    = cfgCom.MaxParRarete[nom] or 1
        local actuel = compte[nom] or 0
        if actuel < max then
            table.insert(autorises, nom)
        end
    end
    if #autorises == 0 then return nil end
    return TirerRarete(autorises)
end

local function SpawnerCommun()
    if #actifsCommun >= cfgCom.MaxActifs then return end

    local rarete = TirerRareteCommune()
    if not rarete then return end

    -- Trouver la SpawnArea du ChampCommun
    local spawnArea = champCommunModel:FindFirstChild("SpawnArea")
                   or champCommunModel:FindFirstChildWhichIsA("BasePart", true)
    if not spawnArea then
        warn("[ChampCommun] Pas de Part 'SpawnArea' dans ChampCommun !")
        return
    end

    local objet = GetObjet(rarete)
    PoserDansZone(objet, spawnArea)
    objet.Parent = workspace

    local anchorPart = GetAnchorPart(objet)
    if not anchorPart then objet:Destroy() return end

    -- Billboard avec style renforcé pour le champ commun
    local bb           = Instance.new("BillboardGui")
    bb.Size            = UDim2.new(0, 160, 0, 50)
    bb.StudsOffset     = Vector3.new(0, rarete.taille + 2, 0)
    bb.AlwaysOnTop     = false
    bb.Parent          = anchorPart
    local lbl                   = Instance.new("TextLabel", bb)
    lbl.Size                    = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency  = 1
    lbl.TextColor3              = rarete.couleur
    lbl.TextStrokeTransparency  = 0
    lbl.TextStrokeColor3        = Color3.new(0, 0, 0)
    lbl.TextScaled              = true
    lbl.Font                    = Enum.Font.GothamBold
    lbl.Text                    = "⭐ " .. rarete.nom:upper() .. " ⭐"

    -- Expiration : God ne disparaît jamais
    local expireAt
    if rarete.nom == "God" and cfgCom.GodNeverExpires then
        expireAt = math.huge
    else
        expireAt = os.time() + cfgCom.Expiration
    end

    local entry = { rarete = rarete, objet = objet, expireAt = expireAt }
    table.insert(actifsCommun, entry)

    -- ProximityPrompt avec HoldDuration selon la rareté
    local holdDuration = cfgCom.HoldDuration[rarete.nom] or 0
    local prompt       = CreerPrompt(anchorPart, holdDuration, "Attraper")

    -- Annonce spawn dans le chat
    AnnoncerChat(string.format(
        "🌟 Un Brainrot [%s] vient d'apparaître sur le Champ Commun !",
        rarete.nom:upper()
    ))

    prompt.Triggered:Connect(function(player)
        -- Retirer de la liste active
        for i, e in ipairs(actifsCommun) do
            if e == entry then table.remove(actifsCommun, i) break end
        end

        -- Récompenser via BindableEvent → Main.server.lua
        rewardEvent:Fire(player, rarete.valeur, rarete)

        -- Annonce du vainqueur
        AnnoncerChat(string.format(
            "🏆 %s a ramassé un Brainrot [%s] ! (+%d coins)",
            player.Name, rarete.nom, rarete.valeur
        ))

        objet:Destroy()
    end)
end

-- Boucle du champ commun (tourne indéfiniment)
local function BoucleChampCommun()
    while true do
        task.wait(cfgCom.SpawnInterval)

        -- Nettoyer les expirés
        local now      = os.time()
        local nouveaux = {}
        for _, entry in ipairs(actifsCommun) do
            if entry.expireAt <= now then
                if entry.objet and entry.objet.Parent then
                    entry.objet:Destroy()
                end
            else
                table.insert(nouveaux, entry)
            end
        end
        actifsCommun = nouveaux

        SpawnerCommun()
    end
end

-- ══════════════════════════════════════════════════════════════
-- CONNEXIONS & DÉMARRAGE
-- ══════════════════════════════════════════════════════════════

Players.PlayerAdded:Connect(DemarrerChampIndividuel)
Players.PlayerRemoving:Connect(ArreterChampIndividuel)

-- Joueurs déjà connectés
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(DemarrerChampIndividuel, player)
end

-- Démarrer le champ commun
task.spawn(BoucleChampCommun)

print("[BrainrotSpawnManager] ✓ Système hybride démarré (individuel + commun)")

--[[
══════════════════════════════════════════════════════════════════
À AJOUTER DANS Main.server.lua (section 6 - INIT DES SYSTÈMES)
══════════════════════════════════════════════════════════════════

-- Connexion récompenses Brainrot (champs individuel + commun)
local BrainrotReward = ServerScriptService:WaitForChild("_BrainrotReward")
BrainrotReward.Event:Connect(function(player, montant, rarete)
    local data = GetData(player)
    if not data then return end
    local multiplier  = CollectSystem.GetMultiplier(data)
    local coinsGagnes = math.floor(montant * multiplier)
    data.coins        = data.coins + coinsGagnes
    data.totalCollecte = (data.totalCollecte or 0) + 1
    UpdateHUD:FireClient(player, data)
    CollectVFX:FireClient(player, coinsGagnes, rarete)
end)

══════════════════════════════════════════════════════════════════
]]
