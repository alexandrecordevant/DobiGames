-- StarterPlayerScripts/ObjectifHUD.client.lua
-- HUD permanent "Prochain Objectif" — barre de progression vers le prochain upgrade coins
-- Met à jour en temps réel via UpdateHUD ; notification clignotante à 90%

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")
local GameConfig = require(RS:WaitForChild("GameConfig"))

local UpdateHUD  = RS:WaitForChild("UpdateHUD")

-- Formatage compact des grands nombres
local function fmt(n)
    if n >= 1e9 then     return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.0fK", n / 1e3)
    else                 return tostring(math.floor(n)) end
end

-- Trouver le prochain upgrade coins le moins cher non encore acheté
local function trouverProchainUpgrade(playerData)
    local upgrades     = playerData.upgrades or {}
    local meilleur     = nil
    local meilleurCout = math.huge

    for _, cfg in pairs(GameConfig.ShopUpgrades) do
        if not cfg.niveaux or not cfg.dataField or cfg.isGamePass then continue end

        -- Niveau actuel : dans upgrades{} (coins) ou champ top-level (game passes déjà filtrés)
        local dataVal      = upgrades[cfg.dataField]
        if dataVal == nil then dataVal = playerData[cfg.dataField] end
        if type(dataVal) == "boolean" then continue end

        local niveauActuel  = tonumber(dataVal) or 0
        local prochainNiv   = niveauActuel + 1
        local niveauCfg     = cfg.niveaux[prochainNiv]

        if niveauCfg and niveauCfg.type == "coins" and niveauCfg.prix then
            if niveauCfg.prix < meilleurCout then
                meilleurCout = niveauCfg.prix
                meilleur = {
                    label = (cfg.nom or cfg.dataField) .. " " .. (niveauCfg.label or ("Lv." .. prochainNiv)),
                    cout  = niveauCfg.prix,
                }
            end
        end
    end

    return meilleur
end

-- === CRÉATION HUD ===

local sg = Instance.new("ScreenGui")
sg.Name           = "ObjectifHUD"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.DisplayOrder   = 14
sg.IgnoreGuiInset = true
sg.Parent         = playerGui

local panneau = Instance.new("Frame", sg)
panneau.Name                  = "Panneau"
panneau.Size                  = UDim2.new(0, 230, 0, 68)
panneau.Position              = UDim2.new(0, 5, 0, 5)
panneau.BackgroundColor3      = Color3.fromRGB(15, 15, 15)
panneau.BackgroundTransparency = 0.15
panneau.BorderSizePixel       = 0
Instance.new("UICorner", panneau).CornerRadius = UDim.new(0, 10)

local labelTitre = Instance.new("TextLabel", panneau)
labelTitre.Name             = "Titre"
labelTitre.Size             = UDim2.new(1, -10, 0, 22)
labelTitre.Position         = UDim2.new(0, 6, 0, 4)
labelTitre.BackgroundTransparency = 1
labelTitre.Text             = "🎯 Next: —"
labelTitre.Font             = Enum.Font.GothamBold
labelTitre.TextSize         = 14
labelTitre.TextColor3       = Color3.fromRGB(255, 220, 50)
labelTitre.TextXAlignment   = Enum.TextXAlignment.Left
labelTitre.TextTruncate     = Enum.TextTruncate.AtEnd

local barreFond = Instance.new("Frame", panneau)
barreFond.Name                  = "BarreFond"
barreFond.Size                  = UDim2.new(1, -12, 0, 14)
barreFond.Position              = UDim2.new(0, 6, 0, 30)
barreFond.BackgroundColor3      = Color3.fromRGB(40, 40, 40)
barreFond.BorderSizePixel       = 0
Instance.new("UICorner", barreFond).CornerRadius = UDim.new(0, 6)

local barreFill = Instance.new("Frame", barreFond)
barreFill.Name                  = "Fill"
barreFill.Size                  = UDim2.new(0, 0, 1, 0)
barreFill.BackgroundColor3      = Color3.fromRGB(100, 200, 100)
barreFill.BorderSizePixel       = 0
Instance.new("UICorner", barreFill).CornerRadius = UDim.new(0, 6)

local labelMontant = Instance.new("TextLabel", panneau)
labelMontant.Name             = "Montant"
labelMontant.Size             = UDim2.new(1, -10, 0, 16)
labelMontant.Position         = UDim2.new(0, 6, 0, 48)
labelMontant.BackgroundTransparency = 1
labelMontant.Text             = ""
labelMontant.Font             = Enum.Font.Gotham
labelMontant.TextSize         = 11
labelMontant.TextColor3       = Color3.fromRGB(180, 180, 180)
labelMontant.TextXAlignment   = Enum.TextXAlignment.Left

-- Notification 90% : une seule fois par objectif (clé = label de l'objectif)
local _notifFaite = {}

local function mettreAJourHUD(playerData)
    local coins    = playerData.coins or 0
    local prochain = trouverProchainUpgrade(playerData)

    if not prochain then
        labelTitre.Text             = "🎯 All upgrades done!"
        labelTitre.TextColor3       = Color3.fromRGB(100, 200, 100)
        barreFill.Size              = UDim2.new(1, 0, 1, 0)
        barreFill.BackgroundColor3  = Color3.fromRGB(100, 200, 100)
        labelMontant.Text           = ""
        return
    end

    local cout     = prochain.cout
    local progress = math.min(1, coins / cout)
    local pct      = math.floor(progress * 100)
    local restant  = math.max(0, cout - coins)

    labelTitre.Text = "🎯 Next: " .. prochain.label

    -- Couleur barre et texte selon la progression
    if progress >= 1 then
        barreFill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
        labelMontant.Text          = "✅ Ready to buy!"
        labelMontant.TextColor3    = Color3.fromRGB(100, 200, 100)
    elseif progress >= 0.9 then
        barreFill.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
        labelMontant.Text          = "🔥 " .. fmt(restant) .. " left!"
        labelMontant.TextColor3    = Color3.fromRGB(255, 180, 50)
    else
        barreFill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
        labelMontant.Text          = fmt(coins) .. " / " .. fmt(cout) .. " (" .. pct .. "%)"
        labelMontant.TextColor3    = Color3.fromRGB(180, 180, 180)
    end

    -- Animation barre
    TweenService:Create(barreFill,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad),
        { Size = UDim2.new(progress, 0, 1, 0) }
    ):Play()

    -- Notification clignotante à 90% (une seule fois par objectif)
    if progress >= 0.9 and progress < 1 and not _notifFaite[prochain.label] then
        _notifFaite[prochain.label] = true
        task.spawn(function()
            for _ = 1, 3 do
                if not labelTitre.Parent then return end
                labelTitre.TextColor3 = Color3.fromRGB(255, 80, 50)
                task.wait(0.3)
                if not labelTitre.Parent then return end
                labelTitre.TextColor3 = Color3.fromRGB(255, 220, 50)
                task.wait(0.3)
            end
        end)
    end

    -- Reset notification si l'objectif a changé
    if _notifFaite[prochain.label] == nil then
        _notifFaite = {}
        _notifFaite[prochain.label] = false
    end
end

UpdateHUD.OnClientEvent:Connect(mettreAJourHUD)
