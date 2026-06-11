-- StarterPlayerScripts/CollectAllButton.client.lua
-- BrainRotKong — Bouton HUD "Collect All" (collecte tous les slots en 1 clic)
-- Mobile-compatible : gros bouton tactile, position bas-gauche

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local Logger            = require(game:GetService("ReplicatedStorage").SharedLib.Logger)

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- Constantes visuelles
-- ============================================================
-- Stack boutons gauche (tous ancrent sur Y=0.5) :
--   Shop      (0,10, 0.5,-132) h=55
--   Rebirth   (0,10, 0.5,-69)  h=~85
--   FlowerPot (0,10, 0.5,+113) h=55  → bas à +168
--   CollectAll (0,10, 0.5,+180) h=55

local BOUTON_LARGEUR  = 80
local BOUTON_HAUTEUR  = 80
local COIN_RADIUS     = 2

local COULEUR_NORMALE  = Color3.fromRGB(10,  10,  10)   -- noir panel
local COULEUR_CLIC     = Color3.fromRGB(80,  140, 80)   -- vert flash
local COULEUR_TEXTE    = Color3.fromRGB(220, 220, 220)  -- gris clair
local COULEUR_OMBRE    = Color3.fromRGB(60,  60,  60)   -- gris bordure

local DUREE_ANIMATION = 0.15   -- secondes
local COOLDOWN        = 1      -- secondes entre deux clics (anti-spam client)

-- ============================================================
-- Création du ScreenGui (immédiate — pas de WaitForChild bloquant)
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "CollectAllGui"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder   = 5
screenGui.Parent         = playerGui

-- ============================================================
-- Bouton principal
-- ============================================================
local bouton = Instance.new("TextButton")
bouton.Name                  = "CollectAllBtn"
bouton.Size                  = UDim2.new(0, BOUTON_LARGEUR, 0, BOUTON_HAUTEUR)
bouton.Position              = UDim2.new(0, 90, 0.5, 45)
bouton.AnchorPoint           = Vector2.new(0, 0)
bouton.BackgroundColor3      = COULEUR_NORMALE
bouton.BackgroundTransparency = 0.05
bouton.BorderSizePixel       = 0
bouton.Text                  = "Collect\nAll"
bouton.TextColor3            = COULEUR_TEXTE
bouton.Font                  = Enum.Font.GothamBold
bouton.TextSize              = 12
bouton.TextWrapped           = true
bouton.AutoButtonColor       = false
bouton.ZIndex                = 10
bouton.Parent                = screenGui

local coin = Instance.new("UICorner")
coin.CornerRadius = UDim.new(0, COIN_RADIUS)
coin.Parent       = bouton
local _collectConstraint = Instance.new("UISizeConstraint", bouton)
_collectConstraint.MinSize = Vector2.new(80, 80)
_collectConstraint.MaxSize = Vector2.new(80, 80)

local stroke = Instance.new("UIStroke")
stroke.Color           = COULEUR_OMBRE
stroke.Thickness       = 2
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent          = bouton

-- ============================================================
-- Animations TweenService
-- ============================================================
local tweenInfo = TweenInfo.new(DUREE_ANIMATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function animerClic()
    bouton.BackgroundColor3 = COULEUR_CLIC
    local tweenDown = TweenService:Create(bouton, tweenInfo, {
        Size = UDim2.new(0, BOUTON_LARGEUR * 0.93, 0, BOUTON_HAUTEUR * 0.93),
    })
    tweenDown:Play()
    tweenDown.Completed:Wait()

    local tweenUp = TweenService:Create(bouton, tweenInfo, {
        Size = UDim2.new(0, BOUTON_LARGEUR, 0, BOUTON_HAUTEUR),
    })
    tweenUp:Play()
    tweenUp.Completed:Wait()

    bouton.BackgroundColor3 = COULEUR_NORMALE
end

local function animerHover(active)
    local couleurCible = active
        and Color3.fromRGB(30, 30, 30)
        or  COULEUR_NORMALE
    TweenService:Create(bouton, TweenInfo.new(0.1), {
        BackgroundColor3 = couleurCible,
    }):Play()
end

-- ============================================================
-- Connexion au RemoteEvent en arrière-plan
-- Le bouton est déjà visible — on attend l'event sans bloquer l'affichage
-- ============================================================
local enCooldown = false

task.spawn(function()
    -- WaitForChild sans timeout : attend indéfiniment (le serveur crée toujours l'event)
    local CollectAllEvent = ReplicatedStorage:WaitForChild("CollectAllEvent")

    bouton.MouseButton1Click:Connect(function()
        if enCooldown then return end
        enCooldown = true

        CollectAllEvent:FireServer()
        local s = SoundService:FindFirstChild("SonUpgrade")
        if s then s:Play() end
        task.spawn(animerClic)

        task.wait(COOLDOWN)
        enCooldown = false
    end)

    -- Hover (desktop uniquement — ignoré sur mobile)
    bouton.MouseEnter:Connect(function()
        if not enCooldown then animerHover(true) end
    end)
    bouton.MouseLeave:Connect(function()
        animerHover(false)
    end)

    Logger.info("HUD", "✓ Bouton Collect All connecté au serveur")
end)

Logger.info("HUD", "✓ Bouton Collect All affiché")
