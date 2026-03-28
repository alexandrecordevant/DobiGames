-- StarterPlayer/StarterPlayerScripts/NotificationHandler.client.lua
-- BrainRotFarm — Notifications publiques (Rebirth global, etc.)
-- Écoute NotifEvent:FireAllClients("REBIRTH_GLOBAL", message)
-- Affiche une bannière animée en haut de l'écran (slide in → 3s → fade out)
-- File d'attente : max 1 visible à la fois, 3 en attente maximum

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
    warn("[NotificationHandler] NotifEvent introuvable — script interrompu")
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

    -- Conteneur principal (hors écran en haut)
    local frame = Instance.new("Frame")
    frame.Name                   = "NotifRebirthGlobal"
    frame.Size                   = UDim2.new(0, 440, 0, 52)
    frame.Position               = UDim2.new(0.5, -220, 0, -65)  -- Hors écran
    frame.BackgroundColor3       = Color3.fromRGB(15, 15, 15)
    frame.BackgroundTransparency = 0.12
    frame.BorderSizePixel        = 0
    frame.ZIndex                 = 8
    frame.Parent                 = screenGui

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    -- Bordure colorée
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color     = couleur
    stroke.Thickness = 2

    -- Texte du message
    local label = Instance.new("TextLabel", frame)
    label.Size                   = UDim2.new(1, -18, 1, 0)
    label.Position               = UDim2.new(0, 9, 0, 0)
    label.BackgroundTransparency = 1
    label.Text                   = message
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 16
    label.TextColor3             = couleur
    label.TextXAlignment         = Enum.TextXAlignment.Left
    label.TextWrapped            = true
    label.RichText               = true
    label.ZIndex                 = 9

    -- Contour noir pour lisibilité sur fond clair
    local textStroke = Instance.new("UIStroke", label)
    textStroke.Color            = Color3.new(0, 0, 0)
    textStroke.Thickness        = 1.5
    textStroke.ApplyStrokeMode  = Enum.ApplyStrokeMode.Contextual

    -- Slide depuis le haut vers position finale (15px depuis le bord)
    local posFinale = UDim2.new(0.5, -220, 0, 15)
    TweenService:Create(
        frame,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = posFinale }
    ):Play()

    -- Maintenir 3 secondes puis fade out
    task.wait(3.4)

    local tweenFade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    TweenService:Create(frame, tweenFade, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(label, tweenFade, { TextTransparency = 1 }):Play()

    task.wait(0.45)
    if frame and frame.Parent then frame:Destroy() end

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

    elseif typeNotif == "INFO" then
        -- Infos générales (unlock floor, etc.) — affichage discret
        message = "ℹ️ " .. tostring(messageOuData)
        couleur = Color3.fromRGB(100, 200, 255)

    else
        -- Types non gérés ici (ERREUR, PROMPT_MONETISATION, etc.) → ignorer
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

print("[NotificationHandler] Initialisé ✓")
