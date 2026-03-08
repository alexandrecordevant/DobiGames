-- BrainrotPickupServer.lua
-- Script -> ServerScriptService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HAUTEUR = 4

-- RemoteEvents
local evtPorter = Instance.new("RemoteEvent")
evtPorter.Name = "BrainrotPorter"
evtPorter.Parent = ReplicatedStorage

local evtDeposer = Instance.new("RemoteEvent")
evtDeposer.Name = "BrainrotDeposer"
evtDeposer.Parent = ReplicatedStorage

local folderBrainrot = workspace:WaitForChild("Brainrots", 10)
if not folderBrainrot then
    warn("[BrainrotServer] Folder 'Brainrot' introuvable !")
    return
end

local brainrotsPortes = {}

local function getRootPart(obj)
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    elseif obj:IsA("BasePart") then
        return obj
    end
    return nil
end

local function setGhost(brainrot, actif)
    local liste = brainrot:IsA("Model") and brainrot:GetDescendants() or {brainrot}
    for _, part in ipairs(liste) do
        if part:IsA("BasePart") then
            part.CanCollide = not actif
            part.CanTouch   = not actif
            part.Massless   = actif
            part.Anchored   = not actif
        end
    end
end

local function attacherBrainrot(joueur, brainrot)
    local character = joueur.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local dossierParent = brainrot.Parent
    if dossierParent and dossierParent.Parent == folderBrainrot then
        brainrot:SetAttribute("DossierOrigine", dossierParent.Name)
    else
        brainrot:SetAttribute("DossierOrigine", nil)
    end

    local rootPart = getRootPart(brainrot)
    if not rootPart then return end

    local prompt = rootPart:FindFirstChildOfClass("ProximityPrompt")
    if prompt then prompt.Enabled = false end

    setGhost(brainrot, true)

    rootPart.CFrame = hrp.CFrame * CFrame.new(0, HAUTEUR, 0)

    local weld = Instance.new("WeldConstraint")
    weld.Name   = "BrainrotWeld"
    weld.Part0  = hrp
    weld.Part1  = rootPart
    weld.Parent = hrp

    brainrot.Parent = character
    brainrotsPortes[joueur] = brainrot

    -- Signaler au client de lever les bras
    evtPorter:FireClient(joueur)

    local rarete = brainrot:GetAttribute("DossierOrigine") or "Sans rarete"
    print("[BrainrotServer] " .. joueur.Name .. " porte [" .. rarete .. "] " .. brainrot.Name)
end

local function deposerBrainrot(joueur, positionDepot)
    local brainrot = brainrotsPortes[joueur]
    if not brainrot then return end

    local character = joueur.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")

    if hrp then
        local weld = hrp:FindFirstChild("BrainrotWeld")
        if weld then weld:Destroy() end
    end

    setGhost(brainrot, false)

    local rootPart = getRootPart(brainrot)
    if rootPart then
        rootPart.Anchored = true
        if positionDepot then
            rootPart.CFrame = CFrame.new(positionDepot)
        elseif hrp then
            rootPart.CFrame = hrp.CFrame * CFrame.new(0, 0, -4)
        end
        local prompt = rootPart:FindFirstChildOfClass("ProximityPrompt")
        if prompt then prompt.Enabled = true end
    end

    local nomDossier = brainrot:GetAttribute("DossierOrigine")
    local dossierCible = (nomDossier and folderBrainrot:FindFirstChild(nomDossier)) or folderBrainrot
    brainrot.Parent = dossierCible

    -- Signaler au client de baisser les bras
    evtDeposer:FireClient(joueur)

    brainrotsPortes[joueur] = nil
    print("[BrainrotServer] " .. joueur.Name .. " a depose " .. brainrot.Name)
end

local function setupZoneDepot(zone)
    if not zone:IsA("BasePart") then return end
    zone.Transparency = 0.6
    zone.CanCollide   = false
    zone.Anchored     = true
    zone.BrickColor   = BrickColor.new("Bright green")
    zone.Material     = Enum.Material.Neon

    local bg = Instance.new("BillboardGui")
    bg.Size        = UDim2.new(0, 200, 0, 50)
    bg.StudsOffset = Vector3.new(0, 3, 0)
    bg.Parent      = zone

    local label = Instance.new("TextLabel")
    label.Size                   = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text                   = "DEPOSER ICI"
    label.TextColor3             = Color3.fromRGB(255, 255, 255)
    label.TextScaled             = true
    label.Font                   = Enum.Font.GothamBold
    label.Parent                 = bg

    zone.Touched:Connect(function(hit)
        local joueur = Players:GetPlayerFromCharacter(hit.Parent)
        if not joueur or not brainrotsPortes[joueur] then return end
        local posDepot = zone.Position + Vector3.new(0, zone.Size.Y / 2 + 1, 0)
        deposerBrainrot(joueur, posDepot)
    end)
end

local function ajouterEtSetupPrompt(brainrot)
    local rootPart = getRootPart(brainrot)
    if not rootPart then return end
    if rootPart:FindFirstChildOfClass("ProximityPrompt") then return end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText            = brainrot.Name
    prompt.ActionText            = "Porter"
    prompt.KeyboardKeyCode       = Enum.KeyCode.E
    prompt.HoldDuration          = 3
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight   = false
    prompt.Parent                = rootPart

    prompt.Triggered:Connect(function(joueur)
        if brainrotsPortes[joueur] then return end
        for autreJoueur, brainrotPorte in pairs(brainrotsPortes) do
            if brainrotPorte == brainrot then
                deposerBrainrot(autreJoueur, nil)
                break
            end
        end
        attacherBrainrot(joueur, brainrot)
    end)
end

local function initialiserDossier(dossier)
    local count = 0
    for _, obj in ipairs(dossier:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and obj.Parent ~= nil then
            local root = getRootPart(obj)
            if root and not root:FindFirstChildOfClass("ProximityPrompt") then
                ajouterEtSetupPrompt(obj)
                count = count + 1
            end
        end
    end
    print("[BrainrotServer] " .. count .. " prompt(s) ajouté(s)")
end

initialiserDossier(folderBrainrot)

folderBrainrot.DescendantAdded:Connect(function(descendant)
    if (descendant:IsA("Model") or descendant:IsA("BasePart"))
        and descendant:IsDescendantOf(folderBrainrot) then
        task.wait()
        ajouterEtSetupPrompt(descendant)
    end
end)

for _, obj in ipairs(workspace:GetDescendants()) do
    if obj.Name == "ZoneDepot" and obj:IsA("BasePart") then
        setupZoneDepot(obj)
    end
end

workspace.DescendantAdded:Connect(function(obj)
    if obj.Name == "ZoneDepot" and obj:IsA("BasePart") then
        setupZoneDepot(obj)
    end
end)

Players.PlayerAdded:Connect(function(joueur)
    joueur.CharacterRemoving:Connect(function()
        if brainrotsPortes[joueur] then deposerBrainrot(joueur, nil) end
    end)
end)

for _, joueur in ipairs(Players:GetPlayers()) do
    joueur.CharacterRemoving:Connect(function()
        if brainrotsPortes[joueur] then deposerBrainrot(joueur, nil) end
    end)
end

Players.PlayerRemoving:Connect(function(joueur)
    if brainrotsPortes[joueur] then deposerBrainrot(joueur, nil) end
end)