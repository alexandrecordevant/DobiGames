-- ServerScriptService/Common/BoardSystem.lua
-- BrainRotFarm — Boards cliquables devant chaque base
-- ClickDetector → ouvre menu Rebirth côté client
-- BillboardGui → affiche le niveau Rebirth de la base
-- 0 valeur hardcodée — tout lu depuis GameConfig

local BoardSystem = {}

-- ============================================================
-- Services
-- ============================================================
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")

-- ============================================================
-- Config (Specialized — aucune valeur hardcodée ici)
-- ============================================================
local Config   = require(ReplicatedStorage.Specialized.GameConfig)
local boardCfg = Config.BoardConfig or {
    texteDefaut   = "🔄 REBIRTH\nClick to view",
    distanceClick = 20,
}

-- ============================================================
-- Lazy loaders (évite les dépendances circulaires au boot)
-- ============================================================
local _RebirthSystem = nil
local function getRebirthSystem()
    if not _RebirthSystem then
        local ok, m = pcall(require, ReplicatedStorage.SharedLib.Server.RebirthSystem)
        if ok and m then _RebirthSystem = m end
    end
    return _RebirthSystem
end

local _AssignationSystem = nil
local function getAssignationSystem()
    if not _AssignationSystem then
        local ok, m = pcall(require, ReplicatedStorage.SharedLib.Server.AssignationSystem)
        if ok and m then _AssignationSystem = m end
    end
    return _AssignationSystem
end

-- RemoteEvent OuvrirRebirth (créé par Main ou ici si absent)
local function getOuvrirRebirth()
    local ev = ReplicatedStorage:FindFirstChild("OuvrirRebirth")
    if not ev then
        ev        = Instance.new("RemoteEvent")
        ev.Name   = "OuvrirRebirth"
        ev.Parent = ReplicatedStorage
    end
    return ev
end

-- ============================================================
-- Utilitaires
-- ============================================================

-- Trouve ou crée le BillboardGui d'un Board
local function obtenirBillboard(board)
    local bb = board:FindFirstChild("BoardBillboard")
    if bb then return bb end

    bb             = Instance.new("BillboardGui", board)
    bb.Name        = "BoardBillboard"
    bb.Size        = UDim2.new(0, 280, 0, 100)
    bb.AlwaysOnTop = false
    bb.MaxDistance = 35

    -- Position au-dessus du Board (fonctionne même si Board n'a pas de Size)
    local ok, sz = pcall(function() return board.Size.Y end)
    bb.StudsOffset = Vector3.new(0, (ok and sz or 2) / 2 + 1.5, 0)

    local lblTitre = Instance.new("TextLabel", bb)
    lblTitre.Name                   = "LblTitre"
    lblTitre.Size                   = UDim2.new(1, 0, 0.6, 0)
    lblTitre.Position               = UDim2.new(0, 0, 0, 0)
    lblTitre.BackgroundTransparency = 1
    lblTitre.TextColor3             = Color3.fromRGB(255, 255, 255)
    lblTitre.Font                   = Enum.Font.GothamBold
    lblTitre.TextSize               = 18
    lblTitre.RichText               = true
    lblTitre.TextWrapped            = true
    lblTitre.Text                   = boardCfg.texteDefaut

    local lblSub = Instance.new("TextLabel", bb)
    lblSub.Name                   = "LblSub"
    lblSub.Size                   = UDim2.new(1, 0, 0.4, 0)
    lblSub.Position               = UDim2.new(0, 0, 0.6, 0)
    lblSub.BackgroundTransparency = 1
    lblSub.TextColor3             = Color3.fromRGB(255, 200, 0)
    lblSub.Font                   = Enum.Font.Gotham
    lblSub.TextSize               = 13
    lblSub.RichText               = true
    lblSub.Text                   = "<i>Click to open Rebirth menu</i>"

    return bb
end

-- ============================================================
-- API publique — Init
-- ============================================================

function BoardSystem.Init()
    local bases = Workspace:FindFirstChild("Bases")
    if not bases then
        warn("[BoardSystem] Workspace.Bases introuvable")
        return
    end

    local maxBases    = Config.MaxBases or 6
    local OuvrirRebirth = getOuvrirRebirth()

    for i = 1, maxBases do
        local base  = bases:FindFirstChild("Base_" .. i)
        local bat   = base and base:FindFirstChild("Base")
        local board = bat and bat:FindFirstChild("Board")

        if board then
            -- Supprimer l'ancien ClickDetector s'il existe
            local ancien = board:FindFirstChildOfClass("ClickDetector")
            if ancien then ancien:Destroy() end

            local cd = Instance.new("ClickDetector", board)
            cd.MaxActivationDistance = boardCfg.distanceClick

            local capturedIndex = i
            cd.MouseClick:Connect(function(player)
                -- Forcer la mise à jour du bouton avant d'ouvrir
                local RS = getRebirthSystem()
                if RS then pcall(RS.MettreAJourBouton, player) end

                -- Ouvrir le panel Rebirth côté client
                pcall(function() OuvrirRebirth:FireClient(player) end)

                print("[BoardSystem] " .. player.Name
                    .. " → panel Rebirth ouvert (Base_" .. capturedIndex .. ")")
            end)

            -- BillboardGui
            obtenirBillboard(board)

            print("[BoardSystem] Board configuré → Base_" .. i)
        else
            warn("[BoardSystem] Board introuvable dans Base_" .. i
                .. (base and bat and " (bat trouvé mais pas Board)" or ""))
        end
    end

    print("[BoardSystem] Init ✓")
end

-- ============================================================
-- API publique — Mise à jour du Board après Rebirth
-- ============================================================

function BoardSystem.MettreAJourBoard(player, niveauRebirth)
    local AS = getAssignationSystem()
    if not AS then return end
    local baseIndex = AS.GetBaseIndex(player)
    if not baseIndex then return end

    local bases = Workspace:FindFirstChild("Bases")
    if not bases then return end
    local base  = bases:FindFirstChild("Base_" .. baseIndex)
    local bat   = base and base:FindFirstChild("Base")
    local board = bat and bat:FindFirstChild("Board")
    if not board then return end

    local bb      = board:FindFirstChild("BoardBillboard")
    local lbl     = bb and bb:FindFirstChild("LblTitre")
    if lbl then
        lbl.Text = "🔄 <b>REBIRTH " .. niveauRebirth .. "</b>\n"
            .. "Floor " .. (niveauRebirth + 1) .. " unlocked!"
    end
end

return BoardSystem
