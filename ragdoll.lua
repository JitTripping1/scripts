local ragdoll = {}
local setstate = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("SetState"))

local activeRagdolls = {}

local jointAngleLimits = {
	Neck = 40,
	["Left Shoulder"] = 80,
	["Right Shoulder"] = 80,
	["Left Hip"] = 60,
	["Right Hip"] = 60,
	RootJoint = 25,
}

local ragdollTrNa = "RagdollTrigger"

local function getRootOffset(character)
	local torso = character:FindFirstChild("Torso")
	local rootJoint = torso and torso:FindFirstChild("RootJoint")
	if not rootJoint then
		return CFrame.new()
	end
	return rootJoint.C1 * rootJoint.C0:Inverse()
end

local function getRagdollTrigger(character)
	local trigger = character:FindFirstChild(ragdollTrNa)
	if not trigger then
		trigger = Instance.new("BoolValue")
		trigger.Name = ragdollTrNa
		trigger.Value = false
		trigger.Parent = character
	end
	return trigger
end

ragdoll.StartRagdoll = function(character, type2)
	if not character then return end
	if character:FindFirstChild("Ragdoll") then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	local torso = character:FindFirstChild("Torso")
	if not humanoidRootPart or not humanoid or not torso then return end

	for _, animationTrack in ipairs(humanoid:GetPlayingAnimationTracks()) do
		animationTrack:Stop()
	end

	local ragdollValue = Instance.new("BoolValue")
	ragdollValue.Name = "Ragdoll"
	ragdollValue.Parent = character

	local record = {
		token = 0,
		joints = {},
		requiresNeck = humanoid.RequiresNeck,
		breakJointsOnDeath = humanoid.BreakJointsOnDeath,
		rootOffset = getRootOffset(character),
	}
	activeRagdolls[character] = record

	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid.AutoRotate = false
	
	record.networkOwners = {}
	for _, part in ipairs({humanoidRootPart, torso}) do
		pcall(function()
			record.networkOwners[part] = part:GetNetworkOwner()
			part:SetNetworkOwner(nil)
		end)
	end
	setstate:AddPermanentState(character, "ragdoll")
	setstate:AddPermanentState(character, "stun")

	for _, v in ipairs(character:GetDescendants()) do
		if v:IsA("Motor6D") and v.Part0 and v.Part1 then
			local part0 = v.Part0
			local part1 = v.Part1

			local ballSocket = Instance.new("BallSocketConstraint")
			ballSocket.Name = "DeleteMe"
			local attachment0 = Instance.new("Attachment")
			local attachment1 = Instance.new("Attachment")
			attachment0.Name = "DeleteMe"
			attachment1.Name = "DeleteMe"
			attachment0.Parent = part0
			attachment0.CFrame = v.C0
			attachment1.Parent = part1
			attachment1.CFrame = v.C1

			if part1.Name == "Right Arm" then
				attachment1.Position = attachment1.Position + Vector3.new(-0.1, 0.5, 0)
			elseif part1.Name == "Left Arm" then
				attachment1.Position = attachment1.Position + Vector3.new(0.1, 0.5, 0)
			end

			local limit = jointAngleLimits[v.Name] or 45
			ballSocket.LimitsEnabled = true
			ballSocket.TwistLimitsEnabled = true
			ballSocket.UpperAngle = limit
			ballSocket.TwistUpperAngle = limit
			ballSocket.TwistLowerAngle = -limit
			ballSocket.MaxFrictionTorque = 15
			ballSocket.Restitution = 0

			ballSocket.Parent = part0
			ballSocket.Attachment0 = attachment0
			ballSocket.Attachment1 = attachment1

			table.insert(record.joints, { motor = v, part0 = part0 })
			v.Part0 = nil
		end
	end

	for _, v in ipairs(character:GetChildren()) do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			local hitbox = v:Clone()
			hitbox.Name = "DeleteMe"
			hitbox:ClearAllChildren()
			hitbox.Parent = character
			hitbox.Size = v.Size
			hitbox.Anchored = false
			hitbox.CanCollide = true
			hitbox.Massless = true
			hitbox.Transparency = 1

			local weld = Instance.new("Weld")
			weld.Parent = hitbox
			weld.Name = "DeleteMe"
			weld.Part0 = v
			weld.Part1 = hitbox
		end
	end

	local trigger = getRagdollTrigger(character)
	if not trigger.Value then
		trigger.Value = true
	end
end

ragdoll.EndRagdoll = function(character)
	if not character then return end
	local record = activeRagdolls[character]
	if not record then return end

	activeRagdolls[character] = nil

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	local torso = character:FindFirstChild("Torso")

	local ragdollValue = character:FindFirstChild("Ragdoll")
	if ragdollValue then
		ragdollValue:Destroy()
	end

	if not humanoidRootPart or not humanoid or not torso then
		return
	end

	local realParts = {}
	for _, v in ipairs(character:GetChildren()) do
		if v:IsA("BasePart") then
			table.insert(realParts, v)
		end
	end

	local savedCollide = {}
	for _, part in ipairs(realParts) do
		savedCollide[part] = part.CanCollide
		part.CanCollide = false
	end

	for _, v in ipairs(character:GetDescendants()) do
		if v:IsA("BasePart") then
			v.AssemblyLinearVelocity = Vector3.new()
			v.AssemblyAngularVelocity = Vector3.new()
		end
	end

	local flingParams = RaycastParams.new()
	flingParams.FilterType = Enum.RaycastFilterType.Exclude
	flingParams.FilterDescendantsInstances = {character}
	flingParams.RespectCanCollide = true

	for _, v in ipairs(character:GetDescendants()) do
		if v:IsA("LinearVelocity") or v:IsA("BodyVelocity") or v:IsA("VectorForce")
			or v:IsA("BodyForce") or v:IsA("BodyGyro") or v:IsA("BodyPosition")
			or v:IsA("AngularVelocity") or v:IsA("BodyAngularVelocity") then
			v:Destroy()
		end
	end

	local groundHit = workspace:Raycast(torso.Position + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), flingParams)
	if groundHit then
		local bottomY = torso.Position.Y - torso.Size.Y * 0.5
		local bury = groundHit.Position.Y - bottomY
		if bury > 0.5 then
			local lift = math.clamp(bury + 2.5, 0, 4)
			for _, v in ipairs(character:GetDescendants()) do
				if v:IsA("BasePart") then
					v.CFrame += Vector3.new(0, lift, 0)
				end
			end
		end
	end

	for _, joint in ipairs(record.joints) do
		local motor = joint.motor
		if motor.Name ~= "RootJoint" then
			local part0 = joint.part0
			local part1 = motor.Part1
			if part0 and part1 then
				part1.CFrame = part0.CFrame * motor.C0 * motor.C1:Inverse()
			end
		end
	end

	humanoidRootPart.CFrame = torso.CFrame * record.rootOffset

	for _, v in ipairs(character:GetDescendants()) do
		if v:IsA("BasePart") then
			v.AssemblyLinearVelocity = Vector3.new()
			v.AssemblyAngularVelocity = Vector3.new()
		end
	end

	setstate:RemoveState(character, "ragdoll")
	setstate:RemoveState(character, "stun")

	for _, v in ipairs(character:GetDescendants()) do
		if v.Name == "DeleteMe" then
			v:Destroy()
		end
	end

	for _, joint in ipairs(record.joints) do
		if joint.motor and joint.motor.Parent then
			joint.motor.Part0 = joint.part0
		end
	end

	for _, part in ipairs(realParts) do
		if part.Parent then
			part.AssemblyLinearVelocity = Vector3.new()
			part.AssemblyAngularVelocity = Vector3.new()
		end
	end

	humanoid.PlatformStand = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	humanoid.AutoRotate = true
	humanoid.RequiresNeck = record.requiresNeck
	humanoid.BreakJointsOnDeath = record.breakJointsOnDeath

	task.delay(0.35, function()
		for _, part in ipairs(realParts) do
			if part.Parent then
				part.CanCollide = savedCollide[part]
				part.AssemblyLinearVelocity = Vector3.new()
				part.AssemblyAngularVelocity = Vector3.new()
			end
		end
		
		
		
		for part, owner in pairs(record.networkOwners or {}) do
			pcall(function()
				if part.Parent then
					if owner then
						part:SetNetworkOwner(owner)
					else
						part:SetNetworkOwnershipAuto()
					end
				end
			end)
		end
	end)

	
	local trigger = character:FindFirstChild(ragdollTrNa)
	if trigger and trigger.Value then
		trigger.Value = false
	end
end

ragdoll.DurationRagdoll = function(character, duration)
	if not character then return end

	local existing = activeRagdolls[character]
	if existing then
		existing.token += 1
		local token = existing.token
		task.delay(duration, function()
			local record = activeRagdolls[character]
			if record and record.token == token then
				ragdoll.EndRagdoll(character)
			end
		end)
		return
	end

	ragdoll.StartRagdoll(character)
	local record = activeRagdolls[character]
	if not record then return end
	local token = record.token

	task.delay(duration, function()
		local current = activeRagdolls[character]
		if current and current.token == token then
			ragdoll.EndRagdoll(character)
		end
	end)
end

ragdoll.Init = function(character)
	if not character then return end

	local trigger = getRagdollTrigger(character)

	if not trigger:GetAttribute("_ragdollWired") then
		trigger:SetAttribute("_ragdollWired", true)
		trigger.Changed:Connect(function(value)
			if value then
				ragdoll.StartRagdoll(character)
			else
				ragdoll.EndRagdoll(character)
			end
		end)
	end

	local humanoid = character:FindFirstChild("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid and not humanoid:GetAttribute("_ragdollDiedWired") then
		humanoid:SetAttribute("_ragdollDiedWired", true)
		humanoid.Died:Connect(function()
			trigger.Value = true
		end)
	end

	return trigger
end

return ragdoll
