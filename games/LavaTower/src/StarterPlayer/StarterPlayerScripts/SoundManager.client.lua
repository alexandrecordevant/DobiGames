-- StarterPlayerScripts/SoundManager.client.lua
-- Musique de fond en boucle, son collecte, sons boutons menus (aléatoire)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ok, Logger = pcall(require,
    ReplicatedStorage:WaitForChild("SharedLib"):WaitForChild("Logger"))
if not ok then
    Logger = { debug = function()end, info = function()end,
               warn  = function()end, error = function()end }
end

-- ── IDs ─────────────────────────────────────────────────────────────────────
local BGM_ID      = "rbxassetid://132719056188211"
local COLLECT_ID  = "rbxassetid://79392333090964"
local BTN_ID_1    = "rbxassetid://139800881181209"
local BTN_ID_2    = "rbxassetid://138323438407619"
local TOWER_ID    = "rbxassetid://138143013427560"
local AMELIO_ID   = "rbxassetid://112485797063762"
local EVENT_ID    = "rbxassetid://7608741614865"
local LB_ID_1     = "rbxassetid://9085319375"
local LB_ID_2     = "rbxassetid://1846391824"

-- ── Musique de fond ──────────────────────────────────────────────────────────
local bgMusic = Instance.new("Sound")
bgMusic.Name    = "LavaTowerBGM"
bgMusic.SoundId = BGM_ID
bgMusic.Volume  = 0.12
bgMusic.Looped  = true
bgMusic.Parent  = SoundService
bgMusic:Play()

-- ── Son collecte / achat coins ───────────────────────────────────────────────
local collectSound = Instance.new("Sound")
collectSound.Name    = "SonCollecte"
collectSound.SoundId = COLLECT_ID
collectSound.Volume  = 0.55
collectSound.Parent  = SoundService

-- ── Sons bouton (deux variantes) ─────────────────────────────────────────────
local btnSound1 = Instance.new("Sound")
btnSound1.Name    = "SonBouton1"
btnSound1.SoundId = BTN_ID_1
btnSound1.Volume  = 0.45
btnSound1.Parent  = SoundService

local btnSound2 = Instance.new("Sound")
btnSound2.Name    = "SonBouton2"
btnSound2.SoundId = BTN_ID_2
btnSound2.Volume  = 0.45
btnSound2.Parent  = SoundService

local towerSound = Instance.new("Sound")
towerSound.Name    = "SonTour"
towerSound.SoundId = TOWER_ID
towerSound.Volume  = 0.6
towerSound.Parent  = SoundService

local amelioSound = Instance.new("Sound")
amelioSound.Name    = "SonAmelio"
amelioSound.SoundId = AMELIO_ID
amelioSound.Volume  = 0.6
amelioSound.Parent  = SoundService

-- ── Musique d'événement (Toxic / Nebula) ──────────────────────────────────────
local eventMusic = Instance.new("Sound")
eventMusic.Name    = "SonEvenement"
eventMusic.SoundId = EVENT_ID
eventMusic.Volume  = 0.35
eventMusic.Looped  = true
eventMusic.Parent  = SoundService

-- ── Sons Lucky Block (séquence) ───────────────────────────────────────────────
local lbSound1 = Instance.new("Sound")
lbSound1.Name    = "SonLB1"
lbSound1.SoundId = LB_ID_1
lbSound1.Volume  = 0.65
lbSound1.Parent  = SoundService

local lbSound2 = Instance.new("Sound")
lbSound2.Name    = "SonLB2"
lbSound2.SoundId = LB_ID_2
lbSound2.Volume  = 0.65
lbSound2.Parent  = SoundService

-- ── Lecture ───────────────────────────────────────────────────────────────────
local function playCollect()
    collectSound:Play()
end

local lastBtnPlay = 0
local function playBtn()
    local now = tick()
    if now - lastBtnPlay < 0.08 then return end
    lastBtnPlay = now
    -- Choix aléatoire entre les deux sons de clic
    if math.random(2) == 1 then
        btnSound1:Play()
    else
        btnSound2:Play()
    end
end

-- ── Son collecte : plateforme verte (IncomeCollected, distinct de NotifEvent SUCCESS) ──
task.spawn(function()
    local IncomeCollected = ReplicatedStorage:WaitForChild("IncomeCollected", 30)
    if IncomeCollected then
        IncomeCollected.OnClientEvent:Connect(playCollect)
    end
end)

-- ── Son entrée tour ───────────────────────────────────────────────────────────
task.spawn(function()
    local TowerEntered = ReplicatedStorage:WaitForChild("TowerEntered", 30)
    if TowerEntered then
        TowerEntered.OnClientEvent:Connect(function()
            towerSound:Play()
        end)
    end
end)

-- ── Son amélioration base ─────────────────────────────────────────────────────
task.spawn(function()
    local RebirthAnimation = ReplicatedStorage:WaitForChild("RebirthAnimation", 30)
    if RebirthAnimation then
        RebirthAnimation.OnClientEvent:Connect(function()
            amelioSound:Play()
        end)
    end
end)

-- ── Musique d'événement (Toxic + Nebula) ──────────────────────────────────────
task.spawn(function()
    local toxicActive  = false
    local nebulaActive = false

    local function majMusique()
        if toxicActive or nebulaActive then
            if not eventMusic.IsPlaying then eventMusic:Play() end
        else
            eventMusic:Stop()
        end
    end

    local ToxicEventState  = ReplicatedStorage:WaitForChild("ToxicEventState",  30)
    local NebulaEventState = ReplicatedStorage:WaitForChild("NebulaEventState", 30)

    if ToxicEventState then
        ToxicEventState.OnClientEvent:Connect(function(actif)
            toxicActive = actif == true
            majMusique()
        end)
    end
    if NebulaEventState then
        NebulaEventState.OnClientEvent:Connect(function(actif)
            nebulaActive = actif == true
            majMusique()
        end)
    end
end)

-- ── Sons Lucky Block (deux sons rapides à la suite) ───────────────────────────
task.spawn(function()
    local LuckyBlockOpened = ReplicatedStorage:WaitForChild("LuckyBlockOpened", 30)
    if LuckyBlockOpened then
        LuckyBlockOpened.OnClientEvent:Connect(function()
            lbSound1:Play()
            task.delay(0.4, function()
                lbSound2:Play()
            end)
        end)
    end
end)

-- ── Son boutons : tous les TextButtons du PlayerGui ───────────────────────────
-- Attributs sur les boutons :
--   btn:SetAttribute("NoSound", true)      → aucun son (achats Robux)
--   btn:SetAttribute("PlayCollect", true)  → son clic + son collecte (achats en coins)
--   (aucun attribut)                       → son clic uniquement (navigation, équip/déséquip)

local hookedBtns = {}

local function hookBtn(inst)
    if not inst:IsA("TextButton") then return end
    if hookedBtns[inst] then return end
    hookedBtns[inst] = true
    inst.MouseButton1Click:Connect(function()
        if inst:GetAttribute("NoSound") then return end
        playBtn()
        if inst:GetAttribute("PlayCollect") then playCollect() end
    end)
    inst.AncestryChanged:Connect(function()
        if not inst.Parent then hookedBtns[inst] = nil end
    end)
end

playerGui.DescendantAdded:Connect(hookBtn)
for _, desc in ipairs(playerGui:GetDescendants()) do
    hookBtn(desc)
end

Logger.info("Sound", "SoundManager LavaTower initialise")
