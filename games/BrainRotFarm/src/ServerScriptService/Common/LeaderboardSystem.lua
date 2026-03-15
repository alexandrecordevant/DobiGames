-- ServerScriptService/Common/LeaderboardSystem.lua
-- BrainRotFarm — Leaderboard serveur
-- Panneau 3D dans le monde + leaderstats natifs Roblox + broadcast client

local LeaderboardSystem = {}

-- ============================================================
-- Services
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local TweenService      = game:GetService("TweenService")

-- ============================================================
-- Config
-- ============================================================
local Config = require(ReplicatedStorage.Specialized.GameConfig)

-- Position du panneau 3D — configurable dans GameConfig
-- GameConfig.LeaderboardPosition = Vector3.new(X, Y, Z)
local PANNEAU_POSITION = Config.LeaderboardPosition or Vector3.new(0, 15, 0)
local PANNEAU_TAILLE   = Vector3.new(12, 8, 0.5)
local CANVAS_W         = 600
local CANVAS_H         = 400

-- Palmarès max affiché (6 joueurs = max serveur)
local MAX_JOUEURS = 6

-- Couleurs rangées top 3
local COULEURS_TOP = {
    [1] = { bg = Color3.fromRGB(255, 215,   0), transp = 0.75 },  -- 🥇 Doré
    [2] = { bg = Color3.fromRGB(192, 192, 192), transp = 0.75 },  -- 🥈 Argent
    [3] = { bg = Color3.fromRGB(205, 127,  50), transp = 0.75 },  -- 🥉 Bronze
}
local COULEUR_NORMALE   = Color3.fromRGB( 20,  20,  20)
local TRANSP_NORMALE    = 0.65

-- ============================================================
-- État interne
-- ============================================================
-- Callback fourni par Main.server.lua pour accéder aux données joueur
-- LeaderboardSystem.GetPlayerData = function(player) → playerData ou nil
LeaderboardSystem.GetPlayerData = nil

local classementActuel  = {}   -- table triée courante
local leaderboardEvent  = nil  -- RemoteEvent "LeaderboardUpdate"
local panneauPart       = nil  -- Part 3D dans Workspace
local rowFrames         = {}   -- { [1..6] = Frame SurfaceGui }
local footerLabel       = nil  -- TextLabel "Mis à jour il y a Xs"
local derniereMaj       = 0    -- os.time() de la dernière mise à jour

-- ============================================================
-- Icônes upgrades — lit depuis Config.ShopUpgrades (jamais hardcodé)
-- Retourne une chaîne d'emojis pour chaque upgrade MAX possédé par le joueur
-- ============================================================

local function GetIconesJoueur(playerData)
    -- Accès à ShopUpgrades (peut être nil si ajout partiel de GameConfig)
    local shopUpgrades = Config.ShopUpgrades
    if not shopUpgrades then return "" end

    -- Trier les upgrades par ordre pour un affichage cohérent
    local ordres = {}
    for nom, upgradeConfig in pairs(shopUpgrades) do
        if upgradeConfig.iconeLeaderboard then
            table.insert(ordres, { nom = nom, cfg = upgradeConfig, ordre = upgradeConfig.ordre or 99 })
        end
    end
    table.sort(ordres, function(a, b) return a.ordre < b.ordre end)

    local icones = ""
    for _, entry in ipairs(ordres) do
        local upgradeConfig = entry.cfg
        local estMax        = false

        if upgradeConfig.isGamePass then
            -- Game Pass : champ booléen dans playerData
            estMax = playerData[upgradeConfig.dataField] == true
        else
            -- Upgrade par niveaux : comparer niveau actuel vs niveau max
            local pu          = playerData.upgrades
            local niveauActuel = pu and (pu[upgradeConfig.dataField] or 0) or 0
            estMax = niveauActuel >= upgradeConfig.maxNiveau
        end

        if estMax then
            icones = icones .. upgradeConfig.icone
        end
    end

    return icones
end

-- ============================================================
-- Utilitaires — formatage
-- ============================================================

-- Formate un nombre avec des espaces (ex: 12450 → "12 450")
local function formatCoins(n)
    n = math.floor(n or 0)
    local s   = tostring(n)
    local res = ""
    local len = #s
    for i = 1, len do
        if i > 1 and (len - i + 1) % 3 == 0 then
            res = res .. " "
        end
        res = res .. s:sub(i, i)
    end
    return res
end

-- Tronque un nom à maxLen caractères
local function tronquer(nom, maxLen)
    if #nom <= maxLen then return nom end
    return nom:sub(1, maxLen - 1) .. "…"
end

-- Médaille ou numéro selon le rang
local function rangLabel(rang)
    if rang == 1 then return "🥇"
    elseif rang == 2 then return "🥈"
    elseif rang == 3 then return "🥉"
    else return " " .. tostring(rang) end
end

-- ============================================================
-- Leaderstats Roblox natifs
-- ============================================================

local function creerLeaderstats(player)
    -- Supprimer les anciens leaderstats si présents (sécurité)
    local ancien = player:FindFirstChild("leaderstats")
    if ancien then ancien:Destroy() end

    local ls = Instance.new("Folder")
    ls.Name   = "leaderstats"
    ls.Parent = player

    local coinsVal = Instance.new("IntValue")
    coinsVal.Name   = "💰 Coins"
    coinsVal.Value  = 0
    coinsVal.Parent = ls

    local rebirthVal = Instance.new("IntValue")
    rebirthVal.Name   = "🔥 Rebirth"
    rebirthVal.Value  = 0
    rebirthVal.Parent = ls

    return ls
end

local function mettreAJourLeaderstats(player, playerData)
    if not playerData then return end
    local ls = player:FindFirstChild("leaderstats")
    if not ls then ls = creerLeaderstats(player) end

    local coinsVal   = ls:FindFirstChild("💰 Coins")
    local rebirthVal = ls:FindFirstChild("🔥 Rebirth")

    if coinsVal   then pcall(function() coinsVal.Value   = math.floor(playerData.coins       or 0) end) end
    if rebirthVal then pcall(function() rebirthVal.Value = math.floor(playerData.rebirthLevel or 0) end) end
end

-- ============================================================
-- Panneau 3D — Création
-- ============================================================

local function creerPanneau()
    -- Supprimer un éventuel panneau précédent (redémarrage serveur)
    local ancien = Workspace:FindFirstChild("LeaderboardPanel")
    if ancien then ancien:Destroy() end

    -- Support physique
    local part            = Instance.new("Part")
    part.Name             = "LeaderboardPanel"
    part.Size             = PANNEAU_TAILLE
    part.Position         = PANNEAU_POSITION
    part.Anchored         = true
    part.CanCollide       = false
    part.CastShadow       = false
    part.Material         = Enum.Material.SmoothPlastic
    part.Color            = Color3.fromRGB(10, 10, 10)
    part.Parent           = Workspace

    -- SurfaceGui (face avant du panneau)
    local sg           = Instance.new("SurfaceGui")
    sg.Name            = "LeaderboardGui"
    sg.Face            = Enum.NormalId.Front
    sg.CanvasSize      = Vector2.new(CANVAS_W, CANVAS_H)
    sg.SizingMode      = Enum.SurfaceGuiSizingMode.FixedSize
    sg.LightInfluence  = 0
    sg.Parent          = part

    -- Fond principal
    local fond                    = Instance.new("Frame")
    fond.Name                     = "Fond"
    fond.Size                     = UDim2.new(1, 0, 1, 0)
    fond.BackgroundColor3         = Color3.fromRGB(8, 8, 8)
    fond.BackgroundTransparency   = 0.25
    fond.BorderSizePixel          = 0
    fond.Parent                   = sg
    Instance.new("UICorner", fond).CornerRadius = UDim.new(0, 12)

    -- Titre
    local titreFrame                  = Instance.new("Frame")
    titreFrame.Name                   = "Titre"
    titreFrame.Size                   = UDim2.new(1, 0, 0, 70)
    titreFrame.BackgroundColor3       = Color3.fromRGB(20, 20, 50)
    titreFrame.BackgroundTransparency = 0.3
    titreFrame.BorderSizePixel        = 0
    titreFrame.Parent                 = fond

    local titreLbl             = Instance.new("TextLabel")
    titreLbl.Size              = UDim2.new(1, 0, 1, 0)
    titreLbl.BackgroundTransparency = 1
    titreLbl.Text              = "🏆  CLASSEMENT  —  " .. Config.NomDuJeu
    titreLbl.Font              = Enum.Font.GothamBold
    titreLbl.TextColor3        = Color3.fromRGB(255, 215, 0)
    titreLbl.TextScaled        = true
    titreLbl.Parent            = titreFrame

    -- Ligne séparatrice sous le titre
    local sep1                      = Instance.new("Frame")
    sep1.Size                       = UDim2.new(0.92, 0, 0, 2)
    sep1.Position                   = UDim2.new(0.04, 0, 0, 72)
    sep1.BackgroundColor3           = Color3.fromRGB(255, 215, 0)
    sep1.BackgroundTransparency     = 0.5
    sep1.BorderSizePixel            = 0
    sep1.Parent                     = fond

    -- Rangées joueurs (6 max)
    local RANGEE_DEBUT  = 80   -- Y départ première rangée
    local RANGEE_HAUTEUR = 48  -- hauteur par rangée

    rowFrames = {}
    for i = 1, MAX_JOUEURS do
        local y      = RANGEE_DEBUT + (i - 1) * RANGEE_HAUTEUR
        local couleurs = COULEURS_TOP[i]

        local row                     = Instance.new("Frame")
        row.Name                      = "Row_" .. i
        row.Size                      = UDim2.new(0.96, 0, 0, RANGEE_HAUTEUR - 4)
        row.Position                  = UDim2.new(0.02, 0, 0, y)
        row.BackgroundColor3          = couleurs and couleurs.bg or COULEUR_NORMALE
        row.BackgroundTransparency    = couleurs and couleurs.transp or TRANSP_NORMALE
        row.BorderSizePixel           = 0
        row.Parent                    = fond
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        -- Rang
        local lblRang               = Instance.new("TextLabel")
        lblRang.Name                = "Rang"
        lblRang.Size                = UDim2.new(0, 80, 1, 0)
        lblRang.Position            = UDim2.new(0, 4, 0, 0)
        lblRang.BackgroundTransparency = 1
        lblRang.Text                = tostring(i)
        lblRang.Font                = Enum.Font.GothamBold
        lblRang.TextColor3          = Color3.fromRGB(255, 255, 255)
        lblRang.TextScaled          = true
        lblRang.Parent              = row

        -- Nom
        local lblNom                = Instance.new("TextLabel")
        lblNom.Name                 = "Nom"
        lblNom.Size                 = UDim2.new(0, 260, 1, 0)
        lblNom.Position             = UDim2.new(0, 88, 0, 0)
        lblNom.BackgroundTransparency = 1
        lblNom.Text                 = "—"
        lblNom.Font                 = Enum.Font.GothamBold
        lblNom.TextColor3           = Color3.fromRGB(255, 255, 255)
        lblNom.TextXAlignment       = Enum.TextXAlignment.Left
        lblNom.TextScaled           = true
        lblNom.Parent               = row

        -- Coins
        local lblCoins              = Instance.new("TextLabel")
        lblCoins.Name               = "Coins"
        lblCoins.Size               = UDim2.new(0, 120, 1, 0)
        lblCoins.Position           = UDim2.new(0, 348, 0, 0)
        lblCoins.BackgroundTransparency = 1
        lblCoins.Text               = "0 💰"
        lblCoins.Font               = Enum.Font.Gotham
        lblCoins.TextColor3         = Color3.fromRGB(255, 230, 80)
        lblCoins.TextXAlignment     = Enum.TextXAlignment.Right
        lblCoins.TextScaled         = true
        lblCoins.Parent             = row

        -- Rebirth
        local lblRebirth            = Instance.new("TextLabel")
        lblRebirth.Name             = "Rebirth"
        lblRebirth.Size             = UDim2.new(0, 55, 1, 0)
        lblRebirth.Position         = UDim2.new(0, 472, 0, 0)
        lblRebirth.BackgroundTransparency = 1
        lblRebirth.Text             = "R0"
        lblRebirth.Font             = Enum.Font.GothamBold
        lblRebirth.TextColor3       = Color3.fromRGB(200, 150, 255)
        lblRebirth.TextScaled       = true
        lblRebirth.Parent           = row

        -- Icônes upgrades MAX
        local lblIcones             = Instance.new("TextLabel")
        lblIcones.Name              = "Icones"
        lblIcones.Size              = UDim2.new(0, 66, 1, 0)
        lblIcones.Position          = UDim2.new(0, 530, 0, 0)
        lblIcones.BackgroundTransparency = 1
        lblIcones.Text              = ""
        lblIcones.Font              = Enum.Font.Gotham
        lblIcones.TextColor3        = Color3.fromRGB(255, 255, 255)
        lblIcones.TextScaled        = true
        lblIcones.Parent            = row

        rowFrames[i] = row
    end

    -- Ligne séparatrice avant footer
    local sep2                       = Instance.new("Frame")
    sep2.Size                        = UDim2.new(0.92, 0, 0, 2)
    sep2.Position                    = UDim2.new(0.04, 0, 0, RANGEE_DEBUT + MAX_JOUEURS * RANGEE_HAUTEUR + 2)
    sep2.BackgroundColor3            = Color3.fromRGB(100, 100, 100)
    sep2.BackgroundTransparency      = 0.5
    sep2.BorderSizePixel             = 0
    sep2.Parent                      = fond

    -- Footer — timestamp
    local footer                     = Instance.new("TextLabel")
    footer.Name                      = "Footer"
    footer.Size                      = UDim2.new(1, -20, 0, 28)
    footer.Position                  = UDim2.new(0, 10, 1, -32)
    footer.BackgroundTransparency    = 1
    footer.Text                      = "En attente de données..."
    footer.Font                      = Enum.Font.Gotham
    footer.TextColor3                = Color3.fromRGB(150, 150, 150)
    footer.TextScaled                = true
    footer.Parent                    = fond

    panneauPart = part
    footerLabel = footer

    print("[LeaderboardSystem] Panneau 3D créé à " .. tostring(PANNEAU_POSITION))
end

-- ============================================================
-- Panneau 3D — Mise à jour des rangées
-- ============================================================

local function mettreAJourPanneau(classement)
    if not rowFrames or #rowFrames == 0 then return end

    for i = 1, MAX_JOUEURS do
        local row  = rowFrames[i]
        if not row or not row.Parent then continue end

        local entree = classement[i]

        if entree then
            -- Couleur de fond selon le rang
            local couleurs = COULEURS_TOP[i]
            pcall(function()
                row.BackgroundColor3       = couleurs and couleurs.bg or COULEUR_NORMALE
                row.BackgroundTransparency = couleurs and couleurs.transp or TRANSP_NORMALE
            end)

            -- Contenu des labels
            local lblRang    = row:FindFirstChild("Rang")
            local lblNom     = row:FindFirstChild("Nom")
            local lblCoins   = row:FindFirstChild("Coins")
            local lblRebirth = row:FindFirstChild("Rebirth")

            local lblIcones  = row:FindFirstChild("Icones")

            if lblRang    then pcall(function() lblRang.Text    = rangLabel(i)                      end) end
            if lblNom     then pcall(function() lblNom.Text     = tronquer(entree.name, 12)         end) end
            if lblCoins   then pcall(function() lblCoins.Text   = formatCoins(entree.coins) .. " 💰" end) end
            if lblRebirth then pcall(function() lblRebirth.Text = "R" .. tostring(entree.rebirth)   end) end
            if lblIcones  then pcall(function() lblIcones.Text  = entree.icones or ""               end) end
        else
            -- Rangée vide
            pcall(function()
                row.BackgroundColor3       = COULEUR_NORMALE
                row.BackgroundTransparency = 0.85
            end)
            local lblNom = row:FindFirstChild("Nom")
            if lblNom then pcall(function() lblNom.Text = "—" end) end
            local lblCoins = row:FindFirstChild("Coins")
            if lblCoins then pcall(function() lblCoins.Text = "" end) end
            local lblRebirth = row:FindFirstChild("Rebirth")
            if lblRebirth then pcall(function() lblRebirth.Text = "" end) end
            local lblRang = row:FindFirstChild("Rang")
            if lblRang then pcall(function() lblRang.Text = tostring(i) end) end
        end
    end

    -- Footer : timestamp
    if footerLabel then
        pcall(function()
            footerLabel.Text = "🔄 Mis à jour maintenant"
        end)
        derniereMaj = os.time()
    end
end

-- ============================================================
-- Collecte et tri des données
-- ============================================================

local function collecterClassement()
    local liste = {}
    local getData = LeaderboardSystem.GetPlayerData

    for _, player in ipairs(Players:GetPlayers()) do
        local playerData = getData and getData(player)
        if playerData then
            table.insert(liste, {
                name          = player.Name,          -- clé "name" (attendue par le client HUD)
                displayName   = player.DisplayName,
                coins         = math.floor(playerData.coins or 0),
                rebirth       = math.floor(playerData.rebirthLevel or 0),
                totalCollecte = math.floor(playerData.totalCollecte or 0),
                icones        = GetIconesJoueur(playerData),
                userId        = player.UserId,
            })
            -- Mettre à jour les leaderstats pendant qu'on a les données
            pcall(mettreAJourLeaderstats, player, playerData)
        end
    end

    -- Tri par coins décroissant, à égalité par totalCollecte
    table.sort(liste, function(a, b)
        if a.coins ~= b.coins then return a.coins > b.coins end
        return a.totalCollecte > b.totalCollecte
    end)

    return liste
end

-- ============================================================
-- Broadcast complet (panneau + clients)
-- ============================================================

local function broadcastClassement()
    local classement = collecterClassement()
    classementActuel = classement

    -- Mise à jour panneau 3D
    pcall(mettreAJourPanneau, classement)

    -- Envoi aux clients — enveloppé dans {classement=...} pour le client HUD
    if leaderboardEvent then
        pcall(function()
            leaderboardEvent:FireAllClients({ classement = classement })
        end)
    end
end

-- ============================================================
-- Boucle serveur — mise à jour toutes les 5 secondes
-- ============================================================

local function boucleLeaderboard()
    while true do
        task.wait(5)
        pcall(broadcastClassement)
        -- Mettre à jour le footer avec le temps écoulé
        if footerLabel then
            task.spawn(function()
                for i = 1, 4 do
                    task.wait(1)
                    if footerLabel and footerLabel.Parent then
                        local elapsed = os.time() - derniereMaj
                        pcall(function()
                            footerLabel.Text = "🔄 Mis à jour il y a " .. elapsed .. "s"
                        end)
                    end
                end
            end)
        end
    end
end

-- ============================================================
-- API publique
-- ============================================================

-- Initialise le système (à appeler depuis Main.server.lua après init des autres modules)
function LeaderboardSystem.Init()
    -- Créer le RemoteEvent si absent
    local existing = ReplicatedStorage:FindFirstChild("LeaderboardUpdate")
    if existing then
        leaderboardEvent = existing
    else
        leaderboardEvent       = Instance.new("RemoteEvent")
        leaderboardEvent.Name  = "LeaderboardUpdate"
        leaderboardEvent.Parent = ReplicatedStorage
    end

    -- Créer les leaderstats pour les joueurs déjà connectés
    for _, player in ipairs(Players:GetPlayers()) do
        pcall(creerLeaderstats, player)
    end

    -- Créer les leaderstats pour les futurs joueurs
    Players.PlayerAdded:Connect(function(player)
        pcall(creerLeaderstats, player)
    end)

    -- Créer le panneau 3D
    pcall(creerPanneau)

    -- Lancer la boucle de mise à jour
    task.spawn(boucleLeaderboard)

    print("[LeaderboardSystem] ✓ Initialisé")
end

-- Déclenche une mise à jour immédiate (appeler après un événement majeur)
-- player et playerData sont ignorés — on recollecte tout depuis le cache
function LeaderboardSystem.MettreAJour(player, playerData)
    -- Si des données fraîches sont fournies, mettre à jour les leaderstats maintenant
    if player and playerData then
        pcall(mettreAJourLeaderstats, player, playerData)
    end
    -- Broadcast complet asynchrone pour ne pas bloquer l'appelant
    task.spawn(function()
        pcall(broadcastClassement)
    end)
end

-- Retourne le classement actuel (déjà trié)
function LeaderboardSystem.GetClassement()
    return classementActuel
end

return LeaderboardSystem
