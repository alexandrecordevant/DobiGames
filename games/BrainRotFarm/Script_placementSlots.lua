local slotsFolder = workspace:WaitForChild("Slots")

local Z_MIN = -538
local Z_MAX = -362
local slotWidth = math.abs(Z_MAX - Z_MIN) -- 176
local gap = 0

local slot1 = slotsFolder:WaitForChild("Slot_1")
local startPos = slot1.Position

for i = 2, 20 do
	local slot = slotsFolder:FindFirstChild("Slot_" .. i)
	if not slot then break end

	local newPos = Vector3.new(
		startPos.X + (i - 1) * (slotWidth + gap),
		startPos.Y,
		startPos.Z
	)

	slot.Position = newPos

	print(slot.Name .. " placé en :", newPos)
end

print("Placement terminé")