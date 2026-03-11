local rs = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

local template = rs:WaitForChild("BaseTemplate")

local old = workspace:FindFirstChild("BaseTemplate_Edit")
if old then
	old:Destroy()
end

local clone = template:Clone()
clone.Name = "BaseTemplate_Edit"
clone.Parent = workspace

if clone:IsA("Model") then
	clone:PivotTo(CFrame.new(0, 5, 0))
end