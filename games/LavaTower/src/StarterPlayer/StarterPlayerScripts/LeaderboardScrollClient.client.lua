-- StarterPlayerScripts/LeaderboardScrollClient.client.lua
-- Scroll du billboard leaderboard :
--   · PC    : clic gauche maintenu + glisser (drag)
--   · Mobile: toucher + glisser
-- Raycast pour détecter le clic/toucher sur la Part billboard.

local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")

local player = Players.LocalPlayer

-- ── helpers ────────────────────────────────────────────────────

local function getLeaderbordPart()
    local model = Workspace:FindFirstChild("Leaderboard")
    return model and model:FindFirstChild("Leaderbord")
end

local function getScrollFrame()
    local part = getLeaderbordPart()
    if not part then return nil end
    local gui  = part:FindFirstChild("LeaderboardGui")
    if not gui then return nil end
    local bg   = gui:FindFirstChild("BG")
    if not bg  then return nil end
    return bg:FindFirstChild("Scroll")
end

-- Renvoie true si le point écran (Vector2) touche la Part billboard via raycast
local function estSurBillboard(screenPos)
    local camera = Workspace.CurrentCamera
    if not camera then return false end
    local ray    = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
    local result = Workspace:Raycast(ray.Origin, ray.Direction * 500)
    if not result then return false end
    local part = getLeaderbordPart()
    return result.Instance == part
end

-- ── état du drag ───────────────────────────────────────────────

local dragging      = false
local dragStartY    = 0
local canvasStartY  = 0

local function demarrerDrag(screenY)
    local scroll = getScrollFrame()
    if not scroll then return end
    dragging     = true
    dragStartY   = screenY
    canvasStartY = scroll.CanvasPosition.Y
end

local function majDrag(screenY)
    if not dragging then return end
    local scroll = getScrollFrame()
    if not scroll then return end
    local delta = dragStartY - screenY          -- glisser vers le haut = scroll vers le bas
    local maxY  = math.max(0, scroll.CanvasSize.Y.Offset - scroll.AbsoluteSize.Y)
    scroll.CanvasPosition = Vector2.new(0, math.clamp(canvasStartY + delta, 0, maxY))
end

local function arreterDrag()
    dragging = false
end

-- ── PC : clic gauche + molette ─────────────────────────────────

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if estSurBillboard(Vector2.new(input.Position.X, input.Position.Y)) then
            demarrerDrag(input.Position.Y)
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        majDrag(input.Position.Y)

    elseif input.UserInputType == Enum.UserInputType.MouseWheel then
        -- Molette : fonctionne si la souris est sur le billboard
        if not estSurBillboard(UserInputService:GetMouseLocation()) then return end
        local scroll = getScrollFrame()
        if not scroll then return end
        local maxY = math.max(0, scroll.CanvasSize.Y.Offset - scroll.AbsoluteSize.Y)
        local newY = math.clamp(
            scroll.CanvasPosition.Y - input.Position.Z * 160, 0, maxY)
        scroll.CanvasPosition = Vector2.new(0, newY)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        arreterDrag()
    end
end)

-- ── Mobile : touch ─────────────────────────────────────────────

UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
    if gameProcessed then return end
    if estSurBillboard(Vector2.new(touch.Position.X, touch.Position.Y)) then
        demarrerDrag(touch.Position.Y)
    end
end)

UserInputService.TouchMoved:Connect(function(touch)
    majDrag(touch.Position.Y)
end)

UserInputService.TouchEnded:Connect(function()
    arreterDrag()
end)
