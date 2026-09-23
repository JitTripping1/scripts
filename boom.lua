local debris = game:GetService("Debris")
local replicatedStorage = game:GetService("ReplicatedStorage")

local effects = replicatedStorage:FindFirstChild("Effects")

local boom = {}

function boom.explode(position, radius, damage, attackerPlayer)
	radius = radius or 20
	damage = damage or 60

	
	local temp = Instance.new("Part")
	temp.Anchored = true
	temp.CanCollide = false
	temp.CanQuery = false
	temp.CanTouch = false
	temp.Transparency = 1
	temp.Size = Vector3.new(1, 1, 1)
	temp.CFrame = CFrame.new(position)
	temp.Parent = (workspace:FindFirstChild("Debris") or workspace)
	debris:AddItem(temp, 1)

	
	local e = Instance.new("Explosion")
	e.Position = position
	e.BlastRadius = radius
	e.BlastPressure = 0
	e.DestroyJointRadiusPercent = 0
	e.Parent = workspace
	if effects then
		effects:FireAllClients("VFX", "Finisher", { root = temp })
		effects:FireAllClients("VFX", "GroundSlam", { root = temp, heavy = true })
		effects:FireAllClients("Camera", "Shake", { root = temp, intensity = 65, shakeTime = 0.4 })
	end

	
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { temp }
	local parts = workspace:GetPartBoundsInRadius(position, radius, params)
	local done = {}
	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not done[model] then
			done[model] = true
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or part
				local dist = (root.Position - position).Magnitude
				local falloff = math.clamp(1 - (dist / radius) * 0.65, 0.3, 1)
				if attackerPlayer then
					local tag = Instance.new("ObjectValue")
					tag.Name = "creator"
					tag.Value = attackerPlayer
					tag.Parent = hum
					debris:AddItem(tag, 3)
				end
				hum:TakeDamage(damage * falloff)
				if effects and dist < radius * 0.8 then
					effects:FireAllClients("VFX", "Blood", { point = root.Position, amount = 14 })
				end
			end
		end
	end
end

return boom
