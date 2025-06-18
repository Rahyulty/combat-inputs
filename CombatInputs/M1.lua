local module = {}

local tweenService = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService  = game:GetService("UserInputService")
local runService = game:GetService('RunService')

local stateHandler = require(replicatedStorage.Modules.StateHandler)
local datahandler = require(replicatedStorage.Modules.DataHandler)
local network = require(replicatedStorage.Modules.Network)
local weaponSettings = require(replicatedStorage.Modules.WeaponSettings)

local sounds = replicatedStorage.Sounds
local animations = replicatedStorage.Animations
local fx = replicatedStorage.FX


local combo = 1
local cooldown = false
local lastHit = 0
local debounce2 = false

local COOLDOWN_RESET_TIME = 1.5
local COMBO_RESET_TIME 
local JUMP_POWER_RESET_DELAY = 0.25
local ani

local function getComboSpeed(weaponName, combo, holdingSpace)
	-- universal space-hold rule for combo 4
	if holdingSpace and combo == 4 then
		return 1.5
	end

	-- weapon-specific speed
	local weaponSpeeds = weaponSettings["Speed Map"][weaponName]
	if weaponSpeeds then
		return weaponSpeeds[combo] or weaponSpeeds.default or 1
	else
		return 1 -- fallback speed if weapon not in map
	end
end



local function handleAnimation(animation, character, state: string, holdingSpace : boolean, name : string)
	local load: AnimationTrack = character.Humanoid:LoadAnimation(animation)
	load.Priority = Enum.AnimationPriority.Action4
	
	if character:FindFirstChild("Stun") or character:FindFirstChild("TrueStun") then 
		return  
	end
	
	load:Play()
	network.Fire("toggleAttack", true)


	local speed = getComboSpeed(name, combo, holdingSpace)
	load:AdjustSpeed(speed)

	-- Disconnect logic
	local keyframeConnection
	local stunConnection
	local animationEnded = false
	
	local function cleanup()
			load:Stop()
			network.Fire("toggleAttack", false)
			cooldown = false

			if keyframeConnection then
				keyframeConnection:Disconnect()
				network.Fire("toggleAttack", false)

			end
			if stunConnection then
				stunConnection:Disconnect()
				network.Fire("toggleAttack", false)

			end
	end	

	stunConnection = runService.Heartbeat:Connect(function()
		if character:FindFirstChild("Stun") or character:FindFirstChild("TrueStun") then 
			cleanup()
		end
	end)
	

	keyframeConnection = load.KeyframeReached:Connect(function(keyframe)
		if animationEnded then return end

		if keyframe == "Hit" then
			if character:FindFirstChild("Stun") or character:FindFirstChild("TrueStun") then
				cleanup()
				return 
			end 
			
			network.Fire("Combat", "attack", state, combo, holdingSpace)
		elseif keyframe == "End" then
			animationEnded = true
			task.delay(.05, function()
				network.Fire("toggleAttack", false)
			end)
			
			if keyframeConnection then
				keyframeConnection:Disconnect()
				keyframeConnection = nil
			end

			if combo == 5 then
				cooldown = true
				combo = 1
				task.wait(COOLDOWN_RESET_TIME)
			else
				combo += 1
			end

			cooldown = false
		end
	end)
end


function module.Start(player : Player, state1, holdingSpace)
	local character = player.Character
	local state = stateHandler.new(character.StateFolder)
	local playerWeapon = datahandler.Get("Weapon")
	COMBO_RESET_TIME = weaponSettings[playerWeapon.Value].ResetTime

	if state:canAttack(character) and state["Equiped"] == true then
		if cooldown == false then
			if tick() - lastHit > COMBO_RESET_TIME and not state["Uptilt"] then
				combo = 1 
			end
			
			lastHit = tick()
			cooldown = true

			local animation

			if combo == 4 and holdingSpace then
				animation = animations[playerWeapon.Value]:FindFirstChild("Attack4a") -- uptilt version
			else
				animation = animations[playerWeapon.Value]:FindFirstChild("Attack" .. combo)
			end

			if animation then
				handleAnimation(animation, character, state1, holdingSpace, playerWeapon.Value)
			else
				warn("Animation missing for combo", combo)
				cooldown = false
			end
		end
	end
end

return module
