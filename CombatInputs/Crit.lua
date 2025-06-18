local crit = {}

local tweenService = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")

local stateHandler = require(replicatedStorage.Modules.StateHandler)
local datahandler = require(replicatedStorage.Modules.DataHandler)
local network = require(replicatedStorage.Modules.Network)
local weaponSettings = require(replicatedStorage.Modules.WeaponSettings)

local sounds = replicatedStorage.Sounds
local animations = replicatedStorage.Animations
local fx = replicatedStorage.FX

local cooldown = false

function crit.start(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildWhichIsA("Animator")
	if not animator then
		return
	end

	local state = stateHandler.new(character.StateFolder)
	local playerWeapon = datahandler.Get("Weapon").Value
	local cooldownTime = weaponSettings[playerWeapon].CritCooldown
	local hasHyperArmor = weaponSettings[playerWeapon].hyperArmor
	local animationSpeed = weaponSettings[playerWeapon].CritAnimationSpeed
	local critAnimation = animator:LoadAnimation(animations[playerWeapon].Crit)
	local stunConnection
	local keyframeConnection

	if not state:canAttack(character) or cooldown then
		return
	end

	if character:FindFirstChild("Stun") or character:FindFirstChild("TrueStun") then
		return
	end

	cooldown = true
	critAnimation.Priority = Enum.AnimationPriority.Action4
	critAnimation:Play()

	critAnimation:AdjustSpeed(animationSpeed)

	network.Fire("critReplicate", true)
	network.Fire("toggleCrit", true)

	-- Cleanup helper
	local function cleanup()
		if keyframeConnection then
			keyframeConnection:Disconnect()
			keyframeConnection = nil
		end
		if stunConnection then
			stunConnection:Disconnect()
			stunConnection = nil
		end
		critAnimation:Stop()
		network.Fire("critReplicate", false)
		network.Fire("toggleCrit", false)
		task.delay(cooldownTime, function()
			cooldown = false
		end)
	end

	-- Stun interruption logic
	stunConnection = runService.Heartbeat:Connect(function()
		local isStun = character:FindFirstChild("Stun")
		local isTrueStun = character:FindFirstChild("TrueStun")

		if isTrueStun then
			-- TrueStun always interrupts
			print("TrueStun detected → interrupting crit (bypasses hyper armor)")
			cleanup()
		elseif isStun then
			if hasHyperArmor then
				-- Stun hits but hyper-armor protects
				print("Stun detected → hyper armor active, not interrupting crit")
			else
				-- No hyper-armor so stun cancels the move
				print("Stun detected → no hyper armor, interrupting crit")
				cleanup()
			end
		end
	end)

	-- Animation keyframes BOMBOCLATTTTT
	keyframeConnection = critAnimation.KeyframeReached:Connect(function(keyframe)
		if keyframe == "Hit" then
			network.Fire("Combat", "Crit")
		elseif keyframe == "End" then
			network.Fire("critReplicate", false)
			network.Fire("toggleCrit", false)

			if keyframeConnection then
				keyframeConnection:Disconnect()
				keyframeConnection = nil
			end

			if stunConnection then
				stunConnection:Disconnect()
				stunConnection = nil
			end

			task.delay(cooldownTime, function()
				cooldown = false
			end)
		end
	end)
end

return crit
