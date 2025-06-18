local players = game:GetService("Players")
local contextActionService = game:GetService("ContextActionService")
local replicatedStorage = game:GetService("ReplicatedStorage")

-- Cache the bomboclatt player
local player = players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:FindFirstChildWhichIsA("Humanoid")

-- Modules & State
local stateHandler = require(replicatedStorage.Modules.StateHandler)
local dataHandler = require(replicatedStorage.Modules.DataHandler)
local network = require(replicatedStorage.Modules.Network)

local M1 = require(script.M1)
local Block = require(script.Blocking)
local Crit = require(script.Crit)
local humanoidState = require(script.State)

local state = stateHandler.new(character.StateFolder)
local spaceDown = false
local weapon: StringValue = dataHandler.Get("Weapon")

--Handle Respawning
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = newCharacter:FindFirstChildWhichIsA("Humanoid")
	state:reset(newCharacter.StateFolder)
end)

local function isReadyForAction()
	return humanoid and humanoid.Health > 0 and state["Equiped"] == true
end

local function onSpace(_, inputState)
	spaceDown = (inputState == Enum.UserInputState.Begin)
end

local function onAttack(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	if not isReadyForAction() then
		return
	end
	if not state:canAttack(character) then
		return
	end

	M1.Start(player, humanoidState.getState(), spaceDown)
	network.Fire("disableJump")
end

local function onBlock(_, inputState)
	if not isReadyForAction() then
		return
	end

	if inputState == Enum.UserInputState.Begin then
		if state:canBlock(character) then
			Block.start(player, weapon.Value)
		end
	elseif inputState == Enum.UserInputState.End then
		Block.stop()
	end
end

local function onCrit(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	if not isReadyForAction() then
		return
	end
	if not state:canAttack(character) then
		return
	end

	Crit.start(player)
end

contextActionService:BindAction("SpaceHold", onSpace, false, Enum.KeyCode.Space)
contextActionService:BindAction("PrimaryAttack", onAttack, false, Enum.UserInputType.MouseButton1)
contextActionService:BindAction("BlockAction", onBlock, false, Enum.KeyCode.F)
contextActionService:BindAction("CritAction", onCrit, false, Enum.KeyCode.R)

replicatedStorage.Remotes.UnBlock.OnClientEvent:Connect(function()
	if not isReadyForAction() then
		return
	end

	Block.stop()
end)
