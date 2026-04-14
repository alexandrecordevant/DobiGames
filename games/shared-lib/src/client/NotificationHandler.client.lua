-- StarterPlayer/StarterPlayerScripts/NotificationHandler.client.lua
-- BrainRotFarm — Notifications publiques (Rebirth global, etc.)
-- Écoute NotifEvent:FireAllClients("REBIRTH_GLOBAL", message)
-- Affiche une bannière animée en haut de l'écran (slide in → 3s → fade out)
-- File d'attente : max 1 visible à la fois, 3 en attente maximum

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Logger       = require(game:GetService("ReplicatedStorage").SharedLib.Logger)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Réutiliser MainGui si existant (évite un double ScreenGui)
local screenGui = playerGui:FindFirstChild("MainGui")
if not screenGui then
    screenGui = Instance.new("ScreenGui")
    screenGui.Name         = "MainGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent       = playerGui
end

-- Attendre le RemoteEvent créé par Main.server.lua
local NotifEvent = RS:WaitForChild("NotifEvent", 15)
if not NotifEvent then
    Logger.warn("Notif", "NotifEvent introuvable — script interrompu")
    return
end

-- ============================================================
-- File d'attente des notifications
-- ============================================================
local estEnAffichage = false
local file           = {}  -- { message, couleur }

-- ============================================================
-- Affichage d'une notification
-- ============================================================

local function afficherNotification(message, couleur)
    estEnAffichage = true
    couleur = couleur or Color3.fromRGB(255, 215, 0)

    -- Texte flottant sans fond (slide depuis le haut)
    local label = Instance.new("TextLabel")
    label.Name                   = "NotifRebirthGlobal"
    label.Size                   = UDim2.new(0, 500, 0, 52)
    label.Position               = UDim2.new(0.5, -250, 0, -65)  -- Hors écran
    label.BackgroundTransparency = 1
    label.Text                   = message
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 18
    label.TextColor3             = couleur
    label.TextXAlignment         = Enum.TextXAlignment.Center
    label.TextWrapped            = true
    label.RichText               = true
    label.ZIndex                 = 9
    label.Parent                 = screenGui

    local textStroke = Instance.new("UIStroke", label)
    textStroke.Color            = Color3.new(0, 0, 0)
    textStroke.Thickness        = 2
    textStroke.ApplyStrokeMode  = Enum.ApplyStrokeMode.Contextual

    -- Slide depuis le haut vers position finale
    local posFinale = UDim2.new(0.5, -250, 0, 15)
    TweenService:Create(
        label,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = posFinale }
    ):Play()

    -- Maintenir 3 secondes puis fade out
    task.wait(3.4)

    TweenService:Create(label,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { TextTransparency = 1 }
    ):Play()

    task.wait(0.45)
    if label and label.Parent then label:Destroy() end

    estEnAffichage = false

    -- Traiter la prochaine notification en attente
    if #file > 0 then
        local suivante = table.remove(file, 1)
        task.spawn(afficherNotification, suivante.message, suivante.couleur)
    end
end

-- ============================================================
-- Réception des événements
-- ============================================================

NotifEvent.OnClientEvent:Connect(function(typeNotif, messageOuData)
    -- Traitement selon le type de notification
    local message = nil
    local couleur = nil

    if typeNotif == "REBIRTH_GLOBAL" then
        -- Format envoyé par RebirthSystem : "⚡ NomJoueur just performed their Rebirth I! (×1.5)"
        message = "🔄 " .. tostring(messageOuData)
        couleur = Color3.fromRGB(255, 215, 0)

    elseif typeNotif == "RARE" then
        -- Capture d'un MYTHIC/SECRET dans la zone commune
        message = tostring(messageOuData)
        couleur = Color3.fromRGB(255, 80, 220)

    else
        -- INFO et autres types : gérés par HUDController → ignorer ici (évite le double affichage)
        return
    end

    if not message then return end

    -- Mettre en file si une notification est déjà visible (max 3 en attente)
    if estEnAffichage then
        if #file < 3 then
            table.insert(file, { message = message, couleur = couleur })
        end
    else
        task.spawn(afficherNotification, message, couleur)
    end
end)

Logger.info("Notif", "Initialisé ✓")
