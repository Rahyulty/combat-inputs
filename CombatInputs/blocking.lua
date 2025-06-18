local block = {}
local tweenService = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")

local stateHandler = require(replicatedStorage.Modules.StateHandler)
local datahandler = require(replicatedStorage.Modules.DataHandler)
local network = require(replicatedStorage.Modules.Network)

local sounds = replicatedStorage.Sounds
local animations = replicatedStorage.Animations
local fx = replicatedStorage.FX

local blocking = false
local cooldown = false

function block.start(player: Player, weaponName: string)
	local character: Model = player.Character
	local humanoid: Humanoid = character:FindFirstChildWhichIsA("Humanoid")
	local animator: Animator = humanoid:FindFirstChildWhichIsA("Animator")
	local state = stateHandler.new(character.StateFolder)

	if cooldown == false and character and state:canBlock(character) then
		block = true
		cooldown = true

		local blockingAnimation = animator:LoadAnimation(animations[weaponName].Block)
		blockingAnimation.Priority = Enum.AnimationPriority.Action4
		blockingAnimation:Play()

		network.Fire("toggleBlock", true)
		network.Fire("perfectBlockWindow")
		repeat
			task.wait()
		until block == false
		blockingAnimation:Stop()

		task.delay(1, function()
			cooldown = false
		end)
	end
end

function block.stop()
	block = false
	network.Fire("toggleBlock", false)
end

return block
