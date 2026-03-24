-- ServerScriptService/Common/LeaderboardSystem.lua
-- BrainRotFarm — Leaderboard serveur
-- 4 panneaux Studio : LB1+LB3 = classement, LB2+LB4 = infos serveur (tension)

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

-- Intervalles de mise à jour (depuis GameConfig ou défauts)
local LB_CFG            = Config.Leaderboards or {}
local UPDATE_CLASSEMENT = LB_CFG.updateClassement or 5   -- secondes entre deux mises à jour classement
local UPDATE_INFOS      = LB_CFG.updateInfos      or 5   -- secondes entre classement et infos (cycle 10s total)

local COULEURS_TOP = {
    [1] = { bg = Color3.fromRGB(255, 215,   0), transp = 0.75 },
    [2] = { bg = Color3.fromRGB(192, 192, 192), transp = 0.75 },
    [3] = { bg = Color3.fromRGB(205, 127,  50), transp = 0.75 },
}
local COULEURS_RICHTEXT = { [1] = "#FFD700", [2] = "#C0C0C0", [3] = "#CD7F32" }
local COULEUR_NORMALE   = Color3.fromRGB( 20,  20,  20)
local TRANSP_NORMALE    = 0.65

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

-- Cache des Texto Studio (rempli dans Init via task.defer)
-- LB1 + LB3 = classement, LB2 + LB4 = infos
local textosClassement = {}
local textosInfos      = {}

-- ============================================================
-- Lazy-requires (évite les dépendances circulaires)
-- ============================================================
local _ChampCommunSpawner = nil
local function getChampCommunSpawner()
    if not _ChampCommunSpawner then
        local ok, m = pcall(require, ServerScriptService.Common.CommunSpawner)
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

local _SpawnManager = nil
local function getSpawnManager()
    if not _SpawnManager then
        local ok, m = pcall(require, ServerScriptService.Common.SpawnManager)
        if ok and m then _SpawnManager = m end
    end
    return _SpawnManager
end

local _EventManager = nil
local function getEventManager()
    if not _EventManager then
        local ok, m = pcall(require, ServerScriptService:FindFirstChild("EventManager", true))
        if ok and m then _EventManager = m end
    end
    return _EventManager
end

-- ============================================================
-- GetDailySeedData — donnees daily seed pour un joueur
-- ============================================================
local function GetDailySeedData(player)
    local getData = LeaderboardSystem.GetPlayerData
    if not getData then return nil end
    local ok, data = pcall(getData, player)
    if not ok or not data or not data.dailySeed then return nil end
    local ds        = data.dailySeed
    local remaining = ds.graineDispo and 0
        or math.max(0, (24 * 3600) - (os.time() - (ds.dernieresClaim or 0)))
    local cfg   = Config.FlowerPotConfig
    local cycle = cfg and cfg.dailySeed and cfg.dailySeed.cycle or {}
    return {
        graineDispo  = ds.graineDispo,
        jourActuel   = ds.jourActuel,
        tempsRestant = remaining,
        cycle        = cycle,
    }
end

-- ============================================================
-- Icones upgrades MAX
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
            local pu           = playerData.upgrades
            local niveauActuel = pu and (pu[upgradeConfig.dataField] or 0) or 0
            estMax = niveauActuel >= upgradeConfig.maxNiveau
        end
        if estMax then icones = icones .. upgradeConfig.icone end
    end

    -- Icône 🌱 si au moins un pot actif (rarete en croissance)
    if playerData.pots then
        for _, pot in ipairs(playerData.pots) do
            if pot.rarete and pot.stage > 0 then
                icones = icones .. "🌱"
                break
            end
        end
    end

    return icones
end

-- ============================================================
-- Utilitaires — formatage
-- ============================================================

-- Format K/M/B : 1 500 → 1.5K, 2 500 000 → 2.5M
local function formatCoins(n)
    n = math.floor(n or 0)
    if     n >= 1e9  then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6  then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3  then return string.format("%.0fK", n / 1e3)
    else                  return tostring(n)
    end
end

local function tronquer(nom, maxLen)
    if #nom <= maxLen then return nom end
    return nom:sub(1, maxLen - 1) .. "…"
end

local function rangLabel(rang)
    if rang == 1 then return "👑"
    elseif rang == 2 then return "🥈"
    elseif rang == 3 then return "🥉"
    else return tostring(rang) .. "." end
end

-- Compte les BR Mutants posés dans la base d'un joueur
-- Cherche un enfant "MutantTag" dans chaque spot_ de la hiérarchie Base_X/Base
local function CompterMutants(baseIndex)
    if not baseIndex then return 0 end
    local count = 0
    local bases = Workspace:FindFirstChild("Bases")
    local base  = bases and bases:FindFirstChild("Base_" .. baseIndex)
    local bat   = base and base:FindFirstChild("Base")
    if not bat then return 0 end
    for _, floor in ipairs(bat:GetChildren()) do
        for _, spot in ipairs(floor:GetChildren()) do
            if spot.Name:find("spot_") then
                local tag = spot:FindFirstChild("MutantTag")
                if not tag then
                    local bp = spot:FindFirstChildWhichIsA("BasePart")
                    tag = bp and bp:FindFirstChild("MutantTag")
                end
                if tag then count = count + 1 end
            end
        end
    end
    return count
end

-- Barre de progression pour les events actifs (10 blocs)
local function barreProgression(tempsRestant, dureeTotal)
    if dureeTotal <= 0 then return "░░░░░░░░░░" end
    local pct    = math.clamp(tempsRestant / dureeTotal, 0, 1)
    local pleins = math.floor(pct * 10)
    return string.rep("█", pleins) .. string.rep("░", 10 - pleins)
end

local function FormatTemps(secondes)
    if secondes <= 0 then return "Soon!" end
    local m = math.floor(secondes / 60)
    local s = secondes % 60
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
        print("[LeaderboardSystem] leaderstats créés pour " .. player.Name .. " ✓")
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
    titreLbl.Text              = "🏆  LEADERBOARD  —  " .. Config.NomDuJeu
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
    footer.Text                      = "Waiting for data..."
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
        pcall(function() footerLabel.Text = "🔄 Updated just now" end)
        derniereMaj = os.time()
    end
end

-- ============================================================
-- Accès aux panneaux Studio
-- ============================================================

-- Navigue : Workspace.Leaderboards.{nomPanneau}.Gui.Texto
local function GetLeaderboardTexto(nomPanneau)
    local lbFolder = Workspace:FindFirstChild("Leaderboards")
    if not lbFolder then return nil end
    local panneau = lbFolder:FindFirstChild(nomPanneau)
    if not panneau then return nil end
    local gui = panneau:FindFirstChild("Gui")
    if not gui then return nil end
    return gui:FindFirstChild("Texto")
end

-- Applique RichText + style sur un TextLabel Studio
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
-- GetTopCollecteur
-- ============================================================

local function GetTopCollecteur()
    local top     = nil
    local getData = LeaderboardSystem.GetPlayerData
    for _, player in ipairs(Players:GetPlayers()) do
        local data = getData and getData(player)
        if data and data.totalCollecte then
            if not top or data.totalCollecte > top.totalCollecte then
                top = { nom = player.Name, totalCollecte = data.totalCollecte }
            end
        end
    end
    return top
end

-- ============================================================
-- Leaderboard Classement — LB1 + LB3
-- Format : RichText, top3 coloré, ligne vide après rang 3
-- ============================================================

local function BuildTextoClassement()
    local sep   = "━━━━━━━━━━━━━━━━━━━━━"
    local lines = {
        '<b><font color="#FFD700">🏆 BRAINROTFARM — TOP FARMERS</font></b>',
        sep,
    }

    for i = 1, MAX_JOUEURS do
        local entree = classementActuel[i]
        if entree then
            local rang   = rangLabel(i)
            local nom    = tronquer(entree.name, 10)
            local coins  = "💰 " .. formatCoins(entree.coins)
            local icones = entree.icones ~= "" and entree.icones or ""
            local mutant = "🌱×" .. (entree.mutants or 0)

            -- Top 3 en couleur RichText
            local couleur = COULEURS_RICHTEXT[i]
            if couleur then
                rang  = '<font color="' .. couleur .. '"><b>' .. rang  .. '</b></font>'
                nom   = '<font color="' .. couleur .. '"><b>' .. nom   .. '</b></font>'
                coins = '<font color="' .. couleur .. '">'    .. coins .. '</font>'
            end

            local ligne = rang .. " " .. nom .. "  " .. coins
            if icones ~= "" then ligne = ligne .. "  " .. icones end
            ligne = ligne .. "  " .. mutant

            table.insert(lines, ligne)

            -- Ligne vide après le podium
            if i == 3 and #classementActuel > 3 then
                table.insert(lines, "")
            end
        else
            table.insert(lines, "  " .. i .. ".  · · ·")
        end
    end

    return table.concat(lines, "\n")
end

local function MettreAJourClassement()
    local texte = BuildTextoClassement()
    for _, texto in ipairs(textosClassement) do
        if texto and texto.Parent then
            pcall(function() texto.Text = texte end)
        end
    end
end

-- ============================================================
-- Leaderboard Infos — LB2 + LB4
-- Format : tension + envie, max 6 blocs, peu de texte
-- ============================================================

local NOMS_EVENTS = {
    NightMode   = "🌙 Night Mode",
    MeteorDrop  = "☄️ Meteor Drop",
    Rain        = "🌧️ Rain Event",
    Golden      = "✨ Golden Event",
    LuckyHour   = "⭐ Lucky Hour",
    DoubleCoins = "💰 Double Coins",
    SecretSpawn = "🔴 Secret Spawn",
}

local function BuildTextoInfos()
    local sep    = "━━━━━━━━━━━━━━━━━━━━━"
    local lignes = {
        '<b><font color="#00FFFF">⚡ LIVE — EVENTS</font></b>',
        sep,
    }

    -- ── Section ChampCommun ──────────────────────────────────────────
    local CCS = getChampCommunSpawner()
    if CCS and CCS.GetProchainSpawn then
        table.insert(lignes, "<b>🌾 ChampCommun</b>")

        local okM, mythic = pcall(CCS.GetProchainSpawn, "MYTHIC")
        if okM and mythic then
            if mythic.tempsRestant == 0 then
                table.insert(lignes, "☄️  MYTHIC   → 🟢 ACTIF!")
            else
                table.insert(lignes, "☄️  MYTHIC   → ⏳ " .. FormatTemps(mythic.tempsRestant))
            end
        end

        local okS, secret = pcall(CCS.GetProchainSpawn, "SECRET")
        if okS and secret then
            if secret.tempsRestant == 0 then
                table.insert(lignes, "🔴  SECRET   → 🟢 ACTIF!")
            else
                table.insert(lignes, "🔴  SECRET   → ⏳ " .. FormatTemps(secret.tempsRestant))
            end
        end

        table.insert(lignes, "")
    end

    -- ── Section Prochain Event automatique ──────────────────────────
    local EM = getEventManager()
    if EM and EM.GetProchainEvent then
        local ok, tempsAvant = pcall(EM.GetProchainEvent)
        if ok and tempsAvant and tempsAvant > 0 then
            table.insert(lignes, "<b>📅 PROCHAIN EVENT</b>")
            table.insert(lignes, "⚡ Next event  → dans " .. FormatTemps(tempsAvant))
            table.insert(lignes, "")
        end
    end

    -- ── Section Event actif ─────────────────────────────────────────
    local EV = getEventVisuals()
    if EV then
        local nomEvent = EV.GetEventActif and EV.GetEventActif()
        if nomEvent then
            local infoEvent    = EV.GetTempsRestantEvent and EV.GetTempsRestantEvent()
            local tempsRestant = (infoEvent and infoEvent.tempsRestant) or 0
            local dureeTotal   = (infoEvent and infoEvent.dureeTotal)   or 0
            local nomAffiche   = NOMS_EVENTS[nomEvent] or nomEvent
            local barre        = barreProgression(tempsRestant, dureeTotal)
            local pct          = dureeTotal > 0
                and math.floor((tempsRestant / dureeTotal) * 100) or 0

            table.insert(lignes, "<b>⚡ EVENT ACTIF</b>")
            table.insert(lignes, nomAffiche .. "   " .. FormatTemps(tempsRestant))
            table.insert(lignes, barre .. "  " .. pct .. "%")
            table.insert(lignes, "")
        else
            table.insert(lignes, "⏸️  Aucun event actif")
            table.insert(lignes, "")
        end
    end

    -- ── Dernier rare capturé (< 3 min) ──────────────────────────────
    local dr = LeaderboardSystem.DernierRare
    if dr and (os.time() - (dr.timestamp or 0)) < 180 then
        local nomCourt = dr.joueur:sub(1, 10)
        table.insert(lignes, '<font color="#FFD700">👑 ' .. nomCourt .. " a capturé</font>")
        table.insert(lignes, "    " .. dr.rarete .. "  🔥")
        table.insert(lignes, "")
    end

    -- ── Top collecteur ───────────────────────────────────────────────
    local top = GetTopCollecteur()
    if top then
        table.insert(lignes, "🏆 Top Farmer")
        table.insert(lignes, "  " .. top.nom:sub(1, 10) .. "  ·  " .. top.totalCollecte .. " BR")
    end

    return table.concat(lignes, "\n")
end

local function MettreAJourInfos()
    local texte = BuildTextoInfos()
    for _, texto in ipairs(textosInfos) do
        if texto and texto.Parent then
            pcall(function() texto.Text = texte end)
        end
    end
end

-- ============================================================
-- Construction de la table infosServeur pour FireAllClients
-- Envoyée aux clients HUD (LeaderboardHUD + InfoPanel)
-- ============================================================

local function construireInfosServeur()
    local infos = {}

    -- Event actif
    local EV = getEventVisuals()
    if EV then
        infos.eventActif = EV.GetEventActif and EV.GetEventActif()
        if infos.eventActif then
            local ie         = EV.GetTempsRestantEvent and EV.GetTempsRestantEvent()
            infos.eventTemps = (ie and ie.tempsRestant) or 0
        end
    end

    -- Prochain MYTHIC/SECRET
    local CCS = getChampCommunSpawner()
    if CCS and CCS.GetProchainSpawn then
        local ok,  m = pcall(CCS.GetProchainSpawn, "MYTHIC")
        if ok  and m then infos.mythicTemps = m.tempsRestant end
        local ok2, s = pcall(CCS.GetProchainSpawn, "SECRET")
        if ok2 and s then infos.secretTemps = s.tempsRestant end
    end

    -- Dernier rare capturé (âge en secondes)
    local dr = LeaderboardSystem.DernierRare
    if dr then
        infos.dernierRare = {
            rarete = dr.rarete,
            joueur = dr.joueur,
            age    = os.time() - (dr.timestamp or 0),
        }
    end

    return infos
end

-- ============================================================
-- Collecte et tri des données
-- ============================================================

local function collecterClassement()
    local liste   = {}
    local getData = LeaderboardSystem.GetPlayerData
    local SM      = getSpawnManager()

    for _, player in ipairs(Players:GetPlayers()) do
        local playerData = getData and getData(player)
        if playerData then
            local baseIndex = SM and SM.GetBase(player)
            local mutants   = CompterMutants(baseIndex)
            table.insert(liste, {
                name          = player.Name,
                displayName   = player.DisplayName,
                coins         = math.floor(playerData.coins or 0),
                rebirth       = math.floor(playerData.rebirthLevel or 0),
                totalCollecte = math.floor(playerData.totalCollecte or 0),
                icones        = GetIconesJoueur(playerData),
                mutants       = mutants,
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
-- Broadcast complet (panneau 3D custom + clients HUD)
-- ============================================================

local function broadcastClassement()
    local classement = collecterClassement()
    classementActuel = classement
    derniereMaj      = os.time()

    -- Panneau 3D custom (fallback)
    pcall(mettreAJourPanneau, classement)

    -- Envoi aux clients HUD avec infos serveur enrichies + daily seed individuel
    if leaderboardEvent then
        local infosServeur = construireInfosServeur()
        for _, player in ipairs(Players:GetPlayers()) do
            pcall(function()
                leaderboardEvent:FireClient(player, {
                    classement    = classement,
                    infosServeur  = infosServeur,
                    dailySeedInfo = GetDailySeedData(player),
                })
            end)
        end
    end
end

-- ============================================================
-- Boucle serveur : 5s classement → 5s infos (cycle 10s)
-- ============================================================

local function boucleLeaderboard()
    while true do
        -- Cycle 1 : broadcast + mise à jour classement LB1+LB3
        pcall(broadcastClassement)
        pcall(MettreAJourClassement)

        -- Footer panneau 3D (compte elapsed en live)
        if footerLabel then
            task.spawn(function()
                for _ = 1, 4 do
                    task.wait(1)
                    if footerLabel and footerLabel.Parent then
                        local elapsed = os.time() - derniereMaj
                        pcall(function()
                            footerLabel.Text = "🔄 Updated " .. elapsed .. "s ago"
                        end)
                    end
                end
            end)
        end

        task.wait(UPDATE_CLASSEMENT)

        -- Cycle 2 : mise à jour infos LB2+LB4
        pcall(MettreAJourInfos)

        task.wait(UPDATE_INFOS)
    end
end

-- ============================================================
-- API publique
-- ============================================================

-- Enregistre la capture d'un BR rare — LEGENDARY+ uniquement
function LeaderboardSystem.EnregistrerRare(player, rareteNom)
    if not player or not rareteNom then return end

    local PRIORITES = {
        BRAINROT_GOD = 5,
        SECRET       = 4,
        MYTHIC       = 3,
        LEGENDARY    = 2,
        EPIC         = 1,
    }
    local score = PRIORITES[rareteNom] or 0
    if score < 2 then return end  -- ignorer en dessous de LEGENDARY

    LeaderboardSystem.DernierRare = {
        rarete    = rareteNom,
        joueur    = player.Name,
        timestamp = os.time(),
    }
    print(string.format("[LeaderboardSystem] Rare enregistré : %s capturé par %s",
        rareteNom, player.Name))
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

    -- Leaderstats pour les futurs joueurs (attend que Main ait chargé les données)
    Players.PlayerAdded:Connect(function(player)
        task.wait(0.5)
        local playerData = LeaderboardSystem.GetPlayerData and LeaderboardSystem.GetPlayerData(player)
        pcall(CreerOuMettreAJourLeaderstats, player, playerData or {})
    end)

    -- Panneau 3D custom (fallback)
    pcall(creerPanneau)

    -- Récupérer les 4 textos Studio + remplir les caches de listes
    task.defer(function()
        -- Diagnostic : lister les panneaux présents dans Workspace.Leaderboards
        local lbFolder = Workspace:FindFirstChild("Leaderboards")
        if lbFolder then
            local enfants = {}
            for _, child in ipairs(lbFolder:GetChildren()) do
                table.insert(enfants, child.Name .. " (" .. child.ClassName .. ")")
            end
            print("[LeaderboardSystem] Workspace.Leaderboards : " .. table.concat(enfants, ", "))
        else
            warn("[LeaderboardSystem] Workspace.Leaderboards INTROUVABLE — panneaux Studio désactivés")
        end

        -- Récupérer les 4 textos
        local noms   = { "Leaderboard1", "Leaderboard2", "Leaderboard3", "Leaderboard4" }
        local textos = {}
        for _, nom in ipairs(noms) do
            local t = GetLeaderboardTexto(nom)
            textos[nom] = t
            if t then
                pcall(configurerTexto, t)
                print("[LeaderboardSystem] " .. nom .. " Texto ✓")
            else
                warn("[LeaderboardSystem] " .. nom .. " Texto INTROUVABLE")
            end
        end

        -- Textes initiaux (efface "indisponible" Studio)
        local initCls = "🏆 LEADERBOARD\n━━━━━━━━━━━━━━━━━━━━━\nWaiting..."
        local initInf = "📡 LIVE\n\nLoading..."
        if textos.Leaderboard1 then pcall(function() textos.Leaderboard1.Text = initCls end) end
        if textos.Leaderboard3 then pcall(function() textos.Leaderboard3.Text = initCls end) end
        if textos.Leaderboard2 then pcall(function() textos.Leaderboard2.Text = initInf end) end
        if textos.Leaderboard4 then pcall(function() textos.Leaderboard4.Text = initInf end) end

        -- Remplir les tables (utilisées par boucleLeaderboard)
        textosClassement = { textos.Leaderboard1, textos.Leaderboard3 }
        textosInfos      = { textos.Leaderboard2, textos.Leaderboard4 }
    end)

    -- Lancer la boucle (les textos seront nil pour les 2 premiers ticks, sans effet)
    task.spawn(boucleLeaderboard)

    print("[LeaderboardSystem] ✓ Initialisé (LB1+LB3 classement · LB2+LB4 infos · cycle 10s)")
end

-- Mise à jour immédiate (appelée après gain de coins, rebirth, etc.)
function LeaderboardSystem.MettreAJour(player, playerData)
    if player and playerData then
        pcall(CreerOuMettreAJourLeaderstats, player, playerData)
    end
    task.spawn(function()
        pcall(broadcastClassement)
        pcall(MettreAJourClassement)
    end)
end

-- Retourne le classement actuel trié
function LeaderboardSystem.GetClassement()
    return classementActuel
end

return LeaderboardSystem
