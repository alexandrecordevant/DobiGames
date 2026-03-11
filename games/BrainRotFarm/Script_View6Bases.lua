local rs = game:GetService("ReplicatedStorage")
local template = rs:FindFirstChild("BaseTemplate")
local slots = workspace:FindFirstChild("Slots")
for i = 1, 6 do
    local slot = slots:FindFirstChild("Slot_" .. i)
    if not slot then warn("Slot_"..i.." manquant") continue end
    local base = template:Clone()
    base.Name = "Base_TEST_" .. i
    for _, p in ipairs(base:GetDescendants()) do
        if p:IsA("BasePart") then p.CFrame = slot.CFrame * CFrame.new(p.Position) end
    end
    base.Parent = workspace
    print("✅ Base_TEST_"..i.." créée sur "..slot.Name)
end



for i = 1, 6 do
    local base = workspace:FindFirstChild("Base_TEST_" .. i)
    if base then base:Destroy() print("🗑️ Base_TEST_"..i.." supprimée") end
end
