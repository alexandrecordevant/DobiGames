-- StarterPlayerScripts/NextEventTeaser.client.lua
-- Bannière fluo clignotante haut-centre : décompte vers le prochain event.
-- Branchée sur GetTimerData (source de vérité serveur) → JAMAIS de mensonge :
--   • affiche le vrai nom du prochain event (ex. ☄️ METEOR DROP) quand le serveur
--     l'a pré-choisi (eventProchainNom), sinon un texte générique honnête ;
--   • bascule sur "LIVE" pendant l'event actif.
-- Clignotement fluo intense les 60 premières secondes (capter l'attention dès
-- l'accueil), puis pulsation douce persistante (pas de fatigue visuelle).
-- Le dock discret RightDock (bas-droite) reste la vue détaillée permanente.

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GetTimerData = RS:WaitForChild("GetTimerData")

-- Libellés + emojis (cohérents avec TimerHUD)
local EVENT_LABELS = {
    Rain        = "🌧️ RAIN",
    NightMode   = "🌙 NIGHT MODE",
    MeteorDrop  = "☄️ METEOR DROP",
    Golden      = "✨ GOLDEN RUSH",
    LuckyHour   = "⭐ LUCKY HOUR",
    SecretSpawn = "🔴 SECRET SPAWN",
    AdminAbuse  = "🌈 ADMIN ABUSE",
}
local NEON_A = Color3.fromRGB(255, 240, 60)   -- jaune fluo
local NEON_B = Color3.fromRGB(255, 120, 40)   -- orange fluo (météore)

-- ============================================================
-- UI
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name           = "NextEventTeaser"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.DisplayOrder   = 6           -- bannière d'info : au-dessus du fond/TimerHUD(5)
                                -- mais SOUS tous les menus interactifs (ils doivent rester cliquables)
sg.Parent         = playerGui

local frame = Instance.new("Frame", sg)
frame.Name                   = "TeaserFrame"
frame.AnchorPoint            = Vector2.new(0.5, 0)
frame.Size                   = UDim2.new(0.62, 0, 0, 48)
frame.Position               = UDim2.new(0.5, 0, 0.018, 0)
frame.BackgroundColor3       = Color3.fromRGB(15, 15, 18)
frame.BackgroundTransparency = 0.18
frame.BorderSizePixel        = 0
frame.ZIndex                 = 8
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke", frame)
stroke.Color        = NEON_A
stroke.Thickness    = 2.5
stroke.Transparency = 0

local lbl = Instance.new("TextLabel", frame)
lbl.Size                   = UDim2.new(1, -16, 1, 0)
lbl.Position               = UDim2.new(0, 8, 0, 0)
lbl.BackgroundTransparency = 1
lbl.Font                   = Enum.Font.GothamBold
lbl.TextSize               = 18
lbl.RichText               = true
lbl.TextWrapped            = true
lbl.TextColor3             = NEON_A
lbl.TextStrokeTransparency = 0
lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
lbl.ZIndex                 = 9
lbl.Text                   = "⚡ Loading next event…"

-- ============================================================
-- Format temps M:SS (ou H:MM:SS)
-- ============================================================
local function formatTemps(s)
    if not s or s < 0 then return "--:--" end
    s = math.floor(s)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
    return string.format("%d:%02d", m, sec)
end

-- ============================================================
-- Texte affiché selon l'état serveur
-- ============================================================
local function texteDepuis(data, restant)
    local t = formatTemps(restant)
    if data and data.eventActif then
        local nom = EVENT_LABELS[data.eventNom] or ("🔥 " .. tostring(data.eventNom or "EVENT"))
        return "🔥 " .. nom .. " <b>LIVE</b> — catch the rare brainrots! ⏳ " .. t
    end
    local nom = data and data.eventProchainNom and EVENT_LABELS[data.eventProchainNom]
    if nom then
        return nom .. " in <b>" .. t .. "</b> — rare brainrots to catch! 🤑"
    end
    return "⚡ <b>NEXT EVENT</b> in <b>" .. t .. "</b> — rare brainrots incoming! 🤑"
end

-- ============================================================
-- Clignotement fluo : intense 60s, puis pulsation douce
-- ============================================================
local blinkTween = nil
local function relancerBlink(intense)
    if blinkTween then blinkTween:Cancel() end
    if intense then
        -- Flash rapide jaune↔orange + glow stroke marqué
        TweenService:Create(stroke,
            TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Transparency = 0.65 }):Play()
        blinkTween = TweenService:Create(lbl,
            TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { TextColor3 = NEON_B })
    else
        -- Pulsation lente, discrète mais vivante
        TweenService:Create(stroke,
            TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Transparency = 0.45 }):Play()
        blinkTween = TweenService:Create(lbl,
            TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { TextColor3 = Color3.fromRGB(255, 200, 70) })
    end
    blinkTween:Play()
end
relancerBlink(true)
-- Passage en mode doux après 60s
task.delay(60, function() relancerBlink(false) end)

-- ============================================================
-- Fondu de sortie : la bannière a fait son job (anticiper + vivre le 1er event)
-- → on fond et on détruit. Le RightDock discret (bas-droite) prend le relais.
-- ============================================================
local function fondreEtDetruire()
    if blinkTween then blinkTween:Cancel() end
    TweenService:Create(frame, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 1,
    }):Play()
    TweenService:Create(lbl, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
        TextTransparency       = 1,
        TextStrokeTransparency = 1,
    }):Play()
    TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
        Transparency = 1,
    }):Play()
    task.delay(1, function() if sg.Parent then sg:Destroy() end end)
end

-- ============================================================
-- Boucle données : fetch toutes les 5s, décompte local chaque seconde
-- ============================================================
local cached    = nil
local restant   = 0
local aVuActif  = false   -- l'event a-t-il été vécu (actif au moins une fois) ?

local function fetch()
    local ok, data = pcall(function() return GetTimerData:InvokeServer() end)
    if ok and data then
        cached  = data
        restant = data.eventTempsRestant or 0
    end
end

task.spawn(function()
    fetch()
    lbl.Text = texteDepuis(cached, restant)
    local tick = 0
    while true do
        task.wait(1)
        tick = tick + 1
        if restant > 0 then restant = restant - 1 end
        lbl.Text = texteDepuis(cached, restant)
        if tick >= 5 then
            tick = 0
            fetch()
        end
        -- Auto-masquage : dès que le 1er event vécu se termine, on fond
        if cached and cached.eventActif then
            aVuActif = true
        elseif aVuActif then
            fondreEtDetruire()
            break
        end
    end
end)
