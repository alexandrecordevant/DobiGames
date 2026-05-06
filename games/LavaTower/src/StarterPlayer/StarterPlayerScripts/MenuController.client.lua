-- StarterPlayerScripts/MenuController.client.lua
-- Surveille FuseSystemUI (shared-lib) et ferme les autres menus LavaTower quand il s'ouvre.
-- L'autre sens (menus LavaTower → fermer FuseSystemUI) est géré directement dans chaque script.

local Players   = game:GetService("Players")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local MENUS = { "TeleportMenuGui", "ShopMonetGui", "ShopGui", "EventVoteGui" }

local function fermerAutresMenus()
    for _, name in ipairs(MENUS) do
        local gui = playerGui:FindFirstChild(name)
        if gui then gui.Enabled = false end
    end
end

local function observerFuseGui(gui)
    gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if gui.Enabled then
            fermerAutresMenus()
        end
    end)
end

-- FuseSystemUI est créé dynamiquement par FuseSystemClient au démarrage
local existing = playerGui:FindFirstChild("FuseSystemUI")
if existing then
    observerFuseGui(existing)
else
    local conn
    conn = playerGui.ChildAdded:Connect(function(child)
        if child.Name == "FuseSystemUI" then
            conn:Disconnect()
            observerFuseGui(child)
        end
    end)
end
