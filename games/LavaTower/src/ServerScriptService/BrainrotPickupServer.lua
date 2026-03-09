-- BrainrotPickupServer.lua
-- Script -> ServerScriptService
-- Gère le ramassage des brainrots (inventaire serveur) depuis le dossier
-- workspace/Brainrots/<Rarete>/<NomBrainrot>

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- Stockage temporaire côté serveur (invisible côté client)
local stockage = ServerStorage:FindFirstChild("BrainrotStockage")
    or Instance.new("Folder", ServerStorage)
stockage.Name = "BrainrotStockage"

-- RemoteEvents
local evtPickedUp = Instance.new("RemoteEvent")
evtPickedUp.Name   = "BrainrotPickedUp"
evtPickedUp.Parent = ReplicatedStorage

local evtDropped = Instance.new("RemoteEvent")
evtDropped.Name   = "BrainrotDropped"
evtDropped.Parent = ReplicatedStorage

-- ── DEBUG : liste tout ce qui est dans Workspace au démarrage ──
print("[BrainrotServer] Enfants de Workspace :")
for _, v in ipairs(workspace:GetChildren()) do
    print("  •", v.Name, "(" .. v.ClassName .. ")")
end

local folderBrainrot = workspace:WaitForChild("Brainrots", 10)
if not folderBrainrot then
    warn("[BrainrotServer] Dossier 'Brainrots' introuvable dans Workspace !")
    return
end
print("[BrainrotServer] Dossier Brainrots trouvé ! Contenu :")
for _, v in ipairs(folderBrainrot:GetChildren()) do
    print("  •", v.Name, "(" .. v.ClassName .. ") —", #v:GetChildren(), "enfant(s)")
end

-- inventaire : joueur -> brainrot (Instance)
local inventaire = {}

-- ──────────────────────────────────────────────
-- Utilitaires
-- ──────────────────────────────────────────────

local function getRootPart(obj)
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    elseif obj:IsA("BasePart") then
        return obj
    end
    return nil
end

-- ──────────────────────────────────────────────
-- Ramasser
-- ──────────────────────────────────────────────

local function ramasserBrainrot(joueur, brainrot)
    if inventaire[joueur] then return end

    -- Mémoriser la rareté (nom du sous-dossier parent)
    local dossierParent = brainrot.Parent
    local nomRarete = (dossierParent and dossierParent:IsA("Folder")) and dossierParent.Name or "Inconnue"
    brainrot:SetAttribute("DossierOrigine", nomRarete)

    -- Désactiver le prompt
    local rootPart = getRootPart(brainrot)
    if rootPart then
        local prompt = rootPart:FindFirstChildOfClass("ProximityPrompt")
        if prompt then prompt.Enabled = false end
    end

    -- Cacher dans ServerStorage
    brainrot.Parent = stockage
    inventaire[joueur] = brainrot

    evtPickedUp:FireClient(joueur, brainrot.Name, nomRarete)
    print("[BrainrotServer] " .. joueur.Name .. " a ramassé [" .. nomRarete .. "] " .. brainrot.Name)
end

-- ──────────────────────────────────────────────
-- Remettre en place (mort / déco)
-- ──────────────────────────────────────────────

local function remettreEnPlace(joueur)
    local brainrot = inventaire[joueur]
    if not brainrot then return end

    local nomRarete = brainrot:GetAttribute("DossierOrigine") or ""
    local dossierCible = folderBrainrot:FindFirstChild(nomRarete) or folderBrainrot
    brainrot.Parent = dossierCible

    local rootPart = getRootPart(brainrot)
    if rootPart then
        local prompt = rootPart:FindFirstChildOfClass("ProximityPrompt")
        if prompt then prompt.Enabled = true end
    end

    inventaire[joueur] = nil
    evtDropped:FireClient(joueur)
    print("[BrainrotServer] " .. joueur.Name .. " a perdu " .. brainrot.Name .. " → remis en place")
end

-- ──────────────────────────────────────────────
-- Setup ProximityPrompt sur un brainrot
-- ──────────────────────────────────────────────

local function ajouterPrompt(brainrot)
    if not (brainrot:IsA("Model") or brainrot:IsA("BasePart")) then
        print("[BrainrotServer] Ignoré (pas Model/BasePart) :", brainrot.Name, brainrot.ClassName)
        return
    end

    local rootPart = getRootPart(brainrot)
    if not rootPart then
        warn("[BrainrotServer] ❌ Pas de rootPart (PrimaryPart non défini ?) pour : " .. brainrot.Name)
        return
    end
    print("[BrainrotServer] ✓ Prompt ajouté sur :", brainrot.Name, "→ rootPart =", rootPart.Name)
    if rootPart:FindFirstChildOfClass("ProximityPrompt") then return end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText            = brainrot.Name
    prompt.ActionText            = "Ramasser"
    prompt.KeyboardKeyCode       = Enum.KeyCode.E
    prompt.HoldDuration          = 0
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = rootPart

    prompt.Triggered:Connect(function(joueur)
        -- Vérifier que personne n'a déjà ce brainrot
        for _, br in pairs(inventaire) do
            if br == brainrot then return end
        end
        ramasserBrainrot(joueur, brainrot)
    end)
end

-- ──────────────────────────────────────────────
-- Initialisation : itère UNIQUEMENT les enfants
-- directs de chaque sous-dossier de rareté
-- ──────────────────────────────────────────────

local function setupDossierRarete(dossierRarete)
    -- Prompts sur les brainrots déjà présents
    for _, brainrot in ipairs(dossierRarete:GetChildren()) do
        ajouterPrompt(brainrot)
    end
    -- Prompts sur les brainrots ajoutés plus tard (respawn, etc.)
    dossierRarete.ChildAdded:Connect(function(brainrot)
        task.wait()
        ajouterPrompt(brainrot)
    end)
end

local count = 0
for _, enfant in ipairs(folderBrainrot:GetChildren()) do
    if enfant:IsA("Folder") then
        -- Sous-dossier de rareté (Common, Rare, Epic…)
        setupDossierRarete(enfant)
        count = count + #enfant:GetChildren()
    elseif enfant:IsA("Model") or enfant:IsA("BasePart") then
        -- Brainrot posé directement dans Brainrots/ (sans sous-dossier)
        ajouterPrompt(enfant)
        count = count + 1
    end
end
print("[BrainrotServer] " .. count .. " brainrot(s) initialisé(s)")

-- Nouveaux sous-dossiers ajoutés à la volée
folderBrainrot.ChildAdded:Connect(function(enfant)
    if enfant:IsA("Folder") then
        task.wait()
        setupDossierRarete(enfant)
    elseif enfant:IsA("Model") or enfant:IsA("BasePart") then
        task.wait()
        ajouterPrompt(enfant)
    end
end)

-- ──────────────────────────────────────────────
-- Mort / déconnexion
-- ──────────────────────────────────────────────

Players.PlayerAdded:Connect(function(joueur)
    joueur.CharacterRemoving:Connect(function()
        remettreEnPlace(joueur)
    end)
end)

for _, joueur in ipairs(Players:GetPlayers()) do
    joueur.CharacterRemoving:Connect(function()
        remettreEnPlace(joueur)
    end)
end

Players.PlayerRemoving:Connect(function(joueur)
    remettreEnPlace(joueur)
    inventaire[joueur] = nil
end)
