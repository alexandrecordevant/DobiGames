-- CoordPicker.client.lua
-- Coller dans StarterPlayerScripts pendant un playtest Studio
-- Clique gauche sur un objet → remonte au Model parent et prend le centre du bounding box
-- E → afficher le tableau final | Z → annuler le dernier point

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse  = player:GetMouse()
local camera = workspace.CurrentCamera

local points = {}

local function afficherPoint(pos)
	local idx = #points + 1
	table.insert(points, pos)
	print(string.format(
		"[%d] { x=%.2f, y=%.2f, z=%.2f },",
		idx, pos.X, pos.Y, pos.Z
	))
end

local function afficherTableauFinal()
	print("\nGameConfig.CommunPoints = {")
	for _, p in ipairs(points) do
		print(string.format("    { x=%.2f, y=%.2f, z=%.2f },", p.X, p.Y, p.Z))
	end
	print("}")
	print(string.format("-- Total : %d points", #points))
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- mouse.Hit donne la position exacte du curseur dans le monde
		afficherPoint(mouse.Hit.Position)

	elseif input.KeyCode == Enum.KeyCode.E then
		afficherTableauFinal()

	elseif input.KeyCode == Enum.KeyCode.Z then
		if #points > 0 then
			table.remove(points)
			print(string.format("Annulé — %d points restants", #points))
		end
	end
end)

print("=== CoordPicker actif ===")
print("Clic gauche → capturer le centre du Model cliqué")
print("E           → afficher le tableau final")
print("Z           → annuler le dernier point")
