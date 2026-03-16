-- ServerScriptService/Common/LeaderboardSystem.lua
-- BrainRotFarm — Leaderboard serveur
-- Panneau 3D custom + branchement panneaux Studio + leaderstats natifs Roblox

local LeaderboardSystem = {}

-- ============================================================
-- Services
-- ============================================================
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")
local TweenService        = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- Config
-- ============================================================
local Config = require(ReplicatedStorage.Specialized.GameConfig)

-- Position du panneau 3D custom (fallback si panneaux Studio absents)
local PANNEAU_POSITION = Config.LeaderboardPosition or Vector3.new(0, 15, 0)
local PANNEAU_TAILLE   = Vector3.new(12, 8, 0.5)
local CANVAS_W         = 600
local CANVAS_H         = 400

local MAX_JOUEURS = 6

local COULEURS_TOP = {
    [1] = { bg = Color3.fromRGB(255, 215,   0), transp = 0.75 },  -- 🥇 Doré
    [2] = { bg = Color3.fromRGB(192, 192, 192), transp = 0.75 },  -- 🥈 Argent
    [3] = { bg = Color3.fromRGB(205, 127,  50), transp = 0.75 },  -- 🥉 Bronze
}
local COULEURS_RICHTEXT = { [1] = "#FFD700", [2] = "#C0C0C0", [3] = "#CD7F32" }
local COULEUR_NORMALE  = Color3.fromRGB( 20,  20,  20)
local TRANSP_NORMALE   = 0.65

-- ============================================================
-- État interne
-- ============================================================
-- Callback fourni par Main.server.lua
LeaderboardSystem.GetPlayerData = nil

-- Dernier BR rare capturé { rarete, joueur, timestamp }
LeaderboardSystem.DernierRare = nil

local classementActuel = {}
local leaderboardEvent = nil
local panneauPart      = nil
local rowFrames        = {}
local footerLabel      = nil
local derniereMaj      = 0

-- Warn affiché une seule fois si Texto introuvable
local _lb1Warn = false
local _lb2Warn = false

-- ============================================================
-- Lazy-requires (évite les dépendances circulaires)
-- ============================================================
local _ChampCommunSpawner = nil
local function getChampCommunSpawner()
    if not _ChampCommunSpawner then
        local ok, m = pcall(require, ServerScriptService.Specialized.ChampCommunSpawner)
        if ok and m then _ChampCommunSpawner = m end
    end
    return _ChampCommunSpawner
end

local _EventVisuals = nil
local function getEventVisuals()
    if not _EventVisuals then
        local ok, m = pcall(require, ServerScriptService.Common.EventVisuals)
        if ok and m then _EventVisuals = m end
    end
    return _EventVisuals
end

-- ============================================================
-- Icônes upgrades MAX
-- ============================================================
local function GetIconesJoueur(playerData)
    local shopUpgrades = Config.ShopUpgrades
    if not shopUpgrades then return "" end

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
            estMax = playerData[upgradeConfig.dataField] == true
        else
            local pu          = playerData.upgrades
            local niveauActuel = pu and (pu[upgradeConfig.dataField] or 0) or 0
            estMax = niveauActuel >= upgradeConfig.maxNiveau
        end
        if estMax then icones = icones .. upgradeConfig.icone end
    end
    return icones
end

-- ============================================================
-- Utilitaires — formatage
-- ============================================================

local function formatCoins(n)
    n = math.floor(n or 0)
    local s   = tostring(n)
    local res = ""
    local len = #s
    for i = 1, len do
        if i > 1 and (len - i + 1) % 3 == 0 then res = res .. " " end
        res = res .. s:sub(i, i)
    end
    return res
end

local function tronquer(nom, maxLen)
    if #nom <= maxLen then return nom end
    return nom:sub(1, maxLen - 1) .. "…"
end

local function rangLabel(rang)
    if rang == 1 then return "🥇"
    elseif rang == 2 then return "🥈"
    elseif rang == 3 then return "🥉"
    else return tostring(rang) end
end

local function FormatTemps(secondes)
    if secondes <= 0 then return "Bientôt !" end
    local m = math.floor(secondes / 60)
    local s  = secondes % 60
    if m > 0 then
        return m .. "m " .. string.format("%02d", s) .. "s"
    else
        return s .. "s"
    end
end

-- ============================================================
-- Leaderstats Roblox natifs — création + mise à jour combinées
-- ============================================================

local function CreerOuMettreAJourLeaderstats(player, playerData)
    local ls = player:FindFirstChild("leaderstats")
    if not ls then
        ls        = Instance.new("Folder")
        ls.Name   = "leaderstats"
        ls.Parent = player
    end

    local coins = ls:FindFirstChild("💰 Coins")
    if not coins then
        coins        = Instance.new("IntValue")
        coins.Name   = "💰 Coins"
        coins.Parent = ls
    end
    pcall(function() coins.Value = math.floor(playerData and playerData.coins or 0) end)

    local rebirth = ls:FindFirstChild("🔥 Rebirth")
    if not rebirth then
        rebirth        = Instance.new("IntValue")
        rebirth.Name   = "🔥 Rebirth"
        rebirth.Parent = ls
    end
    pcall(function() rebirth.Value = math.floor(playerData and playerData.rebirthLevel or 0) end)

    local collected = ls:FindFirstChild("🧺 Collectés")
    if not collected then
        collected        = Instance.new("IntValue")
        collected.Name   = "🧺 Collectés"
        collected.Parent = ls
    end
    pcall(function() collected.Value = math.floor(playerData and playerData.totalCollecte or 0) end)
end

-- ============================================================
-- Panneau 3D custom — Création (fallback si panneaux Studio absents)
-- ============================================================

local function creerPanneau()
    local ancien = Workspace:FindFirstChild("LeaderboardPanel")
    if ancien then ancien:Destroy() end

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

    local sg           = Instance.new("SurfaceGui")
    sg.Name            = "LeaderboardGui"
    sg.Face            = Enum.NormalId.Front
    sg.CanvasSize      = Vector2.new(CANVAS_W, CANVAS_H)
    sg.SizingMode      = Enum.SurfaceGuiSizingMode.FixedSize
    sg.LightInfluence  = 0
    sg.Parent          = part

    local fond                    = Instance.new("Frame")
    fond.Name                     = "Fond"
    fond.Size                     = UDim2.new(1, 0, 1, 0)
    fond.BackgroundColor3         = Color3.fromRGB(8, 8, 8)
    fond.BackgroundTransparency   = 0.25
    fond.BorderSizePixel          = 0
    fond.Parent                   = sg
    Instance.new("UICorner", fond).CornerRadius = UDim.new(0, 12)

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

    local sep1                      = Instance.new("Frame")
    sep1.Size                       = UDim2.new(0.92, 0, 0, 2)
    sep1.Position                   = UDim2.new(0.04, 0, 0, 72)
    sep1.BackgroundColor3           = Color3.fromRGB(255, 215, 0)
    sep1.BackgroundTransparency     = 0.5
    sep1.BorderSizePixel            = 0
    sep1.Parent                     = fond

    local RANGEE_DEBUT   = 80
    local RANGEE_HAUTEUR = 48

    rowFrames = {}
    for i = 1, MAX_JOUEURS do
        local y        = RANGEE_DEBUT + (i - 1) * RANGEE_HAUTEUR
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

    local sep2                       = Instance.new("Frame")
    sep2.Size                        = UDim2.new(0.92, 0, 0, 2)
    sep2.Position                    = UDim2.new(0.04, 0, 0, RANGEE_DEBUT + MAX_JOUEURS * RANGEE_HAUTEUR + 2)
    sep2.BackgroundColor3            = Color3.fromRGB(100, 100, 100)
    sep2.BackgroundTransparency      = 0.5
    sep2.BorderSizePixel             = 0
    sep2.Parent                      = fond

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

    print("[LeaderboardSystem] Panneau 3D custom créé à " .. tostring(PANNEAU_POSITION))
end

-- ============================================================
-- Panneau 3D custom — Mise à jour des rangées
-- ============================================================

local function mettreAJourPanneau(classement)
    if not rowFrames or #rowFrames == 0 then return end

    for i = 1, MAX_JOUEURS do
        local row    = rowFrames[i]
        if not row or not row.Parent then continue end
        local entree = classement[i]

        if entree then
            local couleurs = COULEURS_TOP[i]
            pcall(function()
                row.BackgroundColor3       = couleurs and couleurs.bg or COULEUR_NORMALE
                row.BackgroundTransparency = couleurs and couleurs.transp or TRANSP_NORMALE
            end)
            local lblRang    = row:FindFirstChild("Rang")
            local lblNom     = row:FindFirstChild("Nom")
            local lblCoins   = row:FindFirstChild("Coins")
            local lblRebirth = row:FindFirstChild("Rebirth")
            local lblIcones  = row:FindFirstChild("Icones")
            if lblRang    then pcall(function() lblRang.Text    = rangLabel(i) end) end
            if lblNom     then pcall(function() lblNom.Text     = tronquer(entree.name, 12) end) end
            if lblCoins   then pcall(function() lblCoins.Text   = formatCoins(entree.coins) .. " 💰" end) end
            if lblRebirth then pcall(function() lblRebirth.Text = "R" .. tostring(entree.rebirth) end) end
            if lblIcones  then pcall(function() lblIcones.Text  = entree.icones or "" end) end
        else
            pcall(function()
                row.BackgroundColor3       = COULEUR_NORMALE
                row.BackgroundTransparency = 0.85
            end)
            local lblNom     = row:FindFirstChild("Nom")
            local lblCoins   = row:FindFirstChild("Coins")
            local lblRebirth = row:FindFirstChild("Rebirth")
            local lblRang    = row:FindFirstChild("Rang")
            if lblNom     then pcall(function() lblNom.Text     = "—" end) end
            if lblCoins   then pcall(function() lblCoins.Text   = "" end) end
            if lblRebirth then pcall(function() lblRebirth.Text = "" end) end
            if lblRang    then pcall(function() lblRang.Text    = tostring(i) end) end
        end
    end

    if footerLabel then
        pcall(function() footerLabel.Text = "🔄 Mis à jour maintenant" end)
        derniereMaj = os.time()
    end
end

-- ============================================================
-- Panneaux Studio — accès au TextLabel Texto
-- ============================================================

-- Navigue le chemin "Workspace.Leaderboards.Leaderboard1.Gui.Texto"
-- et retourne l'instance finale, ou nil si introuvable
local function trouverTexto(chemin)
    if not chemin then return nil end
    local parties = chemin:split(".")
    local obj = game
    for _, partie in ipairs(parties) do
        if partie == "game" then
            obj = game
        elseif partie == "Workspace" then
            obj = Workspace
        else
            obj = obj and obj:FindFirstChild(partie)
        end
        if not obj then return nil end
    end
    return obj
end

-- Applique les propriétés RichText sur un TextLabel (une seule fois suffit)
local function configurerTexto(texto)
    pcall(function()
        texto.RichText               = true
        texto.TextScaled             = true
        texto.Font                   = Enum.Font.GothamBold
        texto.TextColor3             = Color3.fromRGB(255, 255, 255)
        texto.BackgroundTransparency = 1
        texto.TextXAlignment         = Enum.TextXAlignment.Left
    end)
end

-- ============================================================
-- Leaderboard1 — Texte classement (RichText)
-- ============================================================

local function construireTexteLeaderboard1(classement)
    local sep = "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local lines = {
        "🏆 CLASSEMENT  " .. Config.NomDuJeu,
        sep,
    }

    for i = 1, MAX_JOUEURS do
        local entree = classement[i]
        if entree then
            local rang   = rangLabel(i)
            local nom    = tronquer(entree.name, 12)
            -- Couleur RichText pour le top 3
            if COULEURS_RICHTEXT[i] then
                nom = '<font color="' .. COULEURS_RICHTEXT[i] .. '">' .. nom .. '</font>'
            end
            local coins   = formatCoins(entree.coins)
            local rebirth = "R" .. tostring(entree.rebirth)
            local icones  = entree.icones or ""
            local ligne   = rang .. " " .. nom .. "  " .. coins .. " 💰  " .. rebirth
            if icones ~= "" then ligne = ligne .. "  " .. icones end
            table.insert(lines, ligne)
        else
            table.insert(lines, tostring(i) .. "  —")
        end
    end

    table.insert(lines, sep)
    local elapsed = derniereMaj > 0 and (os.time() - derniereMaj) or 0
    table.insert(lines, "⏱ MàJ il y a " .. elapsed .. "s")

    return table.concat(lines, "\n")
end

local function MettreAJourLeaderboard1()
    local lbCfg = Config.Leaderboards and Config.Leaderboards.Leaderboard1
    if not lbCfg then return end

    local texto = trouverTexto(lbCfg.chemin)
    if not texto then
        if not _lb1Warn then
            warn("[LeaderboardSystem] Leaderboard1.Gui.Texto introuvable : " .. tostring(lbCfg.chemin))
            _lb1Warn = true
        end
        return
    end

    configurerTexto(texto)
    pcall(function() texto.Text = construireTexteLeaderboard1(classementActuel) end)
end

-- ============================================================
-- Leaderboard2 — Texte infos serveur (RichText)
-- ============================================================

local function construireTexteLeaderboard2()
    local sep   = "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local lbCfg = Config.Leaderboards
    local lines = {
        "📋 INFOS SERVEUR",
        sep,
    }

    -- Prochain MYTHIC + SECRET
    local CCS = getChampCommunSpawner()
    if CCS and CCS.GetProchainSpawn then
        local types = { { nom = "MYTHIC", emoji = "⚠️" }, { nom = "SECRET", emoji = "🔴" } }
        for _, t in ipairs(types) do
            local ok, info = pcall(CCS.GetProchainSpawn, t.nom)
            if ok and info and info.tempsRestant >= 0 then
                local pointsNoms = lbCfg and lbCfg.PointsNoms
                local nomPoint   = (pointsNoms and info.point and pointsNoms[info.point])
                    or (info.point and ("Point " .. info.point) or "?")
                table.insert(lines, t.emoji .. " PROCHAIN " .. t.nom)
                table.insert(lines, "⏱ dans " .. FormatTemps(info.tempsRestant))
                table.insert(lines, "📍 " .. nomPoint)
            end
        end
    end

    -- Event en cours
    local EV = getEventVisuals()
    if EV then
        local nomEvent = EV.GetEventActif and EV.GetEventActif()
        if nomEvent then
            local infoEvent = EV.GetTempsRestantEvent and EV.GetTempsRestantEvent()
            local tempsRestant = (infoEvent and infoEvent.tempsRestant) or 0
            local cfgEv    = Config.EventsVisuels and Config.EventsVisuels[nomEvent]
            local msg      = (cfgEv and cfgEv.message) or nomEvent
            table.insert(lines, "⚡ EVENT EN COURS")
            table.insert(lines, "✨ " .. msg)
            table.insert(lines, "⏱ encore " .. FormatTemps(tempsRestant))
        end
    end

    -- Dernier rare capturé
    local dr = LeaderboardSystem.DernierRare
    if dr and dr.rarete then
        local elapsed = os.time() - (dr.timestamp or 0)
        local tempsStr
        if elapsed < 60 then
            tempsStr = elapsed .. "s"
        elseif elapsed < 3600 then
            tempsStr = math.floor(elapsed / 60) .. "m"
        else
            tempsStr = math.floor(elapsed / 3600) .. "h"
        end
        table.insert(lines, "🎯 DERNIER RARE CAPTURÉ")
        table.insert(lines, "👑 " .. dr.rarete)
        table.insert(lines, "par " .. (dr.joueur or "?") .. " · il y a " .. tempsStr)
    end

    -- Top collecteur
    local top = classementActuel[1]
    if top then
        table.insert(lines, "🏆 TOP COLLECTEUR")
        table.insert(lines, top.name .. " · " .. top.totalCollecte .. " BR")
    end

    -- Admin Abuse Hebdo
    local horaire = lbCfg and lbCfg.AdminAbuseHoraire
    if not horaire then
        -- Construire à partir de GameConfig.AdminAbuseHebdo
        local aah = Config.AdminAbuseHebdo
        if aah then
            local jours = { "Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam" }
            horaire = (jours[aah.jourSemaine] or "?") .. " " .. (aah.heureUTC or "?") .. "h UTC"
        end
    end
    if horaire then
        table.insert(lines, "📅 ADMIN ABUSE HEBDO")
        table.insert(lines, horaire)
    end

    table.insert(lines, sep)
    return table.concat(lines, "\n")
end

local function MettreAJourLeaderboard2()
    local lbCfg = Config.Leaderboards and Config.Leaderboards.Leaderboard2
    if not lbCfg then return end

    local texto = trouverTexto(lbCfg.chemin)
    if not texto then
        if not _lb2Warn then
            warn("[LeaderboardSystem] Leaderboard2.Gui.Texto introuvable : " .. tostring(lbCfg.chemin))
            _lb2Warn = true
        end
        return
    end

    configurerTexto(texto)
    pcall(function() texto.Text = construireTexteLeaderboard2() end)
end

-- ============================================================
-- Collecte et tri des données
-- ============================================================

local function collecterClassement()
    local liste  = {}
    local getData = LeaderboardSystem.GetPlayerData

    for _, player in ipairs(Players:GetPlayers()) do
        local playerData = getData and getData(player)
        if playerData then
            table.insert(liste, {
                name          = player.Name,
                displayName   = player.DisplayName,
                coins         = math.floor(playerData.coins or 0),
                rebirth       = math.floor(playerData.rebirthLevel or 0),
                totalCollecte = math.floor(playerData.totalCollecte or 0),
                icones        = GetIconesJoueur(playerData),
                userId        = player.UserId,
            })
            -- Mettre à jour leaderstats pendant qu'on a les données fraîches
            pcall(CreerOuMettreAJourLeaderstats, player, playerData)
        end
    end

    table.sort(liste, function(a, b)
        if a.coins ~= b.coins then return a.coins > b.coins end
        return a.totalCollecte > b.totalCollecte
    end)

    return liste
end

-- ============================================================
-- Broadcast complet (panneau custom + clients)
-- ============================================================

local function broadcastClassement()
    local classement = collecterClassement()
    classementActuel = classement
    derniereMaj      = os.time()

    -- Panneau 3D custom
    pcall(mettreAJourPanneau, classement)

    -- Envoi aux clients HUD
    if leaderboardEvent then
        pcall(function()
            leaderboardEvent:FireAllClients({ classement = classement })
        end)
    end
end

-- ============================================================
-- Boucle serveur (5s → LB1 classement, 5s → LB2 infos)
-- ============================================================

local function boucleLeaderboard()
    while true do
        task.wait(5)
        pcall(broadcastClassement)
        pcall(MettreAJourLeaderboard1)

        -- Footer elapsed (panneau custom)
        if footerLabel then
            task.spawn(function()
                for _ = 1, 4 do
                    task.wait(1)
                    if footerLabel and footerLabel.Parent then
                        local elapsed = os.time() - derniereMaj
                        pcall(function()
                            footerLabel.Text = "🔄 MàJ il y a " .. elapsed .. "s"
                        end)
                    end
                end
            end)
        end

        task.wait(5)
        pcall(MettreAJourLeaderboard2)
    end
end

-- ============================================================
-- API publique
-- ============================================================

-- Enregistre la capture d'un BR rare (appelé par BrainRotSpawner / ChampCommunSpawner)
function LeaderboardSystem.EnregistrerRare(player, rareteNom)
    if not player or not rareteNom then return end
    LeaderboardSystem.DernierRare = {
        rarete    = rareteNom,
        joueur    = player.Name,
        timestamp = os.time(),
    }
    print(string.format("[LeaderboardSystem] Rare enregistré : %s capturé par %s", rareteNom, player.Name))
end

-- Initialise le système
function LeaderboardSystem.Init()
    -- RemoteEvent
    local existing = ReplicatedStorage:FindFirstChild("LeaderboardUpdate")
    if existing then
        leaderboardEvent = existing
    else
        leaderboardEvent        = Instance.new("RemoteEvent")
        leaderboardEvent.Name   = "LeaderboardUpdate"
        leaderboardEvent.Parent = ReplicatedStorage
    end

    -- Leaderstats pour les joueurs déjà connectés
    for _, player in ipairs(Players:GetPlayers()) do
        local playerData = LeaderboardSystem.GetPlayerData and LeaderboardSystem.GetPlayerData(player)
        pcall(CreerOuMettreAJourLeaderstats, player, playerData or {})
    end

    -- Leaderstats pour les futurs joueurs (attendre que Main ait chargé les données)
    Players.PlayerAdded:Connect(function(player)
        task.wait(0.5)
        local playerData = LeaderboardSystem.GetPlayerData and LeaderboardSystem.GetPlayerData(player)
        pcall(CreerOuMettreAJourLeaderstats, player, playerData or {})
    end)

    -- Panneau 3D custom (fallback)
    pcall(creerPanneau)

    -- Initialiser les panneaux Studio avec un texte de démarrage (efface "indisponible")
    task.defer(function()
        local lbCfg = Config.Leaderboards
        if lbCfg and lbCfg.Leaderboard1 then
            local t1 = trouverTexto(lbCfg.Leaderboard1.chemin)
            if t1 then
                configurerTexto(t1)
                pcall(function() t1.Text = "🏆 CLASSEMENT\n━━━━━━━━━━━━━━━━━━━━━━━━━━\nEn attente..." end)
            end
        end
        if lbCfg and lbCfg.Leaderboard2 then
            local t2 = trouverTexto(lbCfg.Leaderboard2.chemin)
            if t2 then
                configurerTexto(t2)
                pcall(function() t2.Text = "📋 INFOS SERVEUR\n━━━━━━━━━━━━━━━━━━━━━━━━━━\nChargement..." end)
            end
        end
    end)

    -- Lancer la boucle
    task.spawn(boucleLeaderboard)

    print("[LeaderboardSystem] ✓ Initialisé (panneau custom + Studio LB1/LB2)")
end

-- Mise à jour immédiate (appeler après gain de coins, rebirth, etc.)
function LeaderboardSystem.MettreAJour(player, playerData)
    if player and playerData then
        pcall(CreerOuMettreAJourLeaderstats, player, playerData)
    end
    task.spawn(function()
        pcall(broadcastClassement)
        pcall(MettreAJourLeaderboard1)
    end)
end

-- Retourne le classement actuel trié
function LeaderboardSystem.GetClassement()
    return classementActuel
end

return LeaderboardSystem
