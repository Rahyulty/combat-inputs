local Remote = {}
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")

local stateHandler = require(replicatedStorage.Modules.StateHandler)
local network = require(replicatedStorage.Modules.Network)
local dataHandler = require(replicatedStorage.Modules.DataHandler)
local zonePlus = require(replicatedStorage.Modules.Zone)
local hitHandler = require(script.Hit)
local weaponSettings = require(replicatedStorage.Modules.WeaponSettings)
local skillSettings = require(replicatedStorage.Modules.skillSettings)

local sounds = replicatedStorage.Sounds
local animations = replicatedStorage.Animations
local fx = replicatedStorage.FX

local function playSwingSound(character, weaponName)
	local swingFolder = sounds:FindFirstChild(weaponName)
	if swingFolder and swingFolder:FindFirstChild("Swing") then
		local swings = swingFolder.Swing:GetChildren()
		if #swings > 0 then
			local chosen = swings[math.random(1, #swings)]:Clone()
			chosen.Parent = character:FindFirstChild("HumanoidRootPart")
			chosen:Play()
			game.Debris:AddItem(chosen, 3)
		end
	end
end

local function handleCooldowns(duration, resetFunc)
	task.delay(duration, resetFunc)
end

function Remote.OnServerEvent(player: Player, type, humanoidState, combo, holdingSpace)
	if type == "attack" then
		if player.Character:FindFirstChild("Stun") or player.Character:FindFirstChild("TrueStun") then
			return
		end

		local character = player.Character
		local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		local weapon = dataHandler.Get(player, "Weapon")
		local state = stateHandler.new(character.StateFolder)

		local hit = {}
		local hitbox: Part = serverStorage.Hitbox[weapon.Value].m1:Clone()
		hitbox.CFrame = HumanoidRootPart.CFrame
		hitbox.Parent = HumanoidRootPart

		local weld = Instance.new("Weld")
		weld.Part0 = HumanoidRootPart
		weld.Part1 = hitbox
		weld.C1 = require(hitbox.weldCF)
		weld.Parent = hitbox

		local hitBoxZone = zonePlus.new(hitbox)
		hitBoxZone:setAccuracy("Precise")

		playSwingSound(character, weapon.Value)

		for _, model in pairs(workspace:GetChildren()) do
			if model:IsA("Model") and model ~= character then
				local Humanoid = model:FindFirstChildWhichIsA("Humanoid")
				if Humanoid then
					hitBoxZone:trackItem(model)
				end
			end
		end

		hitBoxZone.itemEntered:Connect(function(enemyCharacter)
			if enemyCharacter:IsA("Model") and enemyCharacter ~= character then
				local humanoid = enemyCharacter:FindFirstChildWhichIsA("Humanoid")
				local stateFolder = enemyCharacter:FindFirstChild("StateFolder")
				if humanoid and stateFolder and not hit[enemyCharacter.Name] then
					local enemyState = stateHandler.new(stateFolder)
					if enemyState:canHit(enemyCharacter) then
						hitHandler.hit(enemyCharacter, character, weapon.Value, combo, holdingSpace, humanoidState)
					end
				end
			end
		end)

		handleCooldowns(0.15, function()
			hitBoxZone:destroy()
			hitbox:Destroy()
		end)
	elseif type == "Crit" then
		local character = player.Character
		local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		local weapon = dataHandler.Get(player, "Weapon")
		local state = stateHandler.new(character.StateFolder)

		state["Attacking"] = true

		if weaponSettings[weapon.Value].specialCrit then
			weaponSettings[weapon.Value].specialCrit(character)
		end

		local hit = {}
		local hitbox: Part = serverStorage.Hitbox[weapon.Value].Crit:Clone()
		hitbox.CFrame = HumanoidRootPart.CFrame
		hitbox.Parent = HumanoidRootPart

		local weld = Instance.new("Weld")
		weld.Part0 = HumanoidRootPart
		weld.Part1 = hitbox
		weld.C1 = require(hitbox.weldCF)
		weld.Parent = hitbox

		local hitBoxZone = zonePlus.new(hitbox)
		hitBoxZone:setAccuracy("Precise")

		for _, model in pairs(workspace:GetChildren()) do
			if model:IsA("Model") and model ~= character then
				local Humanoid = model:FindFirstChildWhichIsA("Humanoid")
				if Humanoid then
					hitBoxZone:trackItem(model)
				end
			end
		end

		hitBoxZone.itemEntered:Connect(function(enemyCharacter)
			if enemyCharacter:IsA("Model") and enemyCharacter ~= character then
				local humanoid = enemyCharacter:FindFirstChildWhichIsA("Humanoid")
				local stateFolder = enemyCharacter:FindFirstChild("StateFolder")
				if humanoid and stateFolder and not hit[enemyCharacter.Name] then
					local enemyState = stateHandler.new(stateFolder)
					if enemyState:canHit(enemyCharacter) then
						hitHandler.crit(enemyCharacter, character, weapon.Value)
					end
				end
			end
		end)

		handleCooldowns(0.2, function()
			hitBoxZone:destroy()
			hitbox:Destroy()
			state["Attacking"] = false
		end)
	elseif type == "Skill" then
		if player.Character:FindFirstChild("Stun") or player.Character:FindFirstChild("TrueStun") then
			return
		end

		local character = player.Character
		local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		local Family = dataHandler.Get(player, "Family")
		local state = stateHandler.new(character.StateFolder)
		local skill = humanoidState
		local variant = combo
		local mousepos = holdingSpace

		skillSettings[Family.Value][skill].skillFunction(player, variant, mousepos)
	end
end

return Remote
