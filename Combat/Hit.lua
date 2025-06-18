local hit = {}

local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local tweenService = game:GetService("TweenService")
local players = game:GetService("Players")

local remotes = replicatedStorage.Remotes

local stateHandler = require(replicatedStorage.Modules.StateHandler)
local network = require(replicatedStorage.Modules.Network)
local dataHandler = require(replicatedStorage.Modules.DataHandler)
local bodymover = require(replicatedStorage.Modules.BodyMovers)
local ragdoll = require(replicatedStorage.Modules.Ragdoll)

local weaponSettings = require(replicatedStorage.Modules.WeaponSettings)

local sounds = replicatedStorage.Sounds
local animations = replicatedStorage.Animations
local fx = replicatedStorage.FX
local replicate = replicatedStorage.Remotes.Replicate

local function getRandomHitAnimation(weaponName)
	local hitAnimations = animations:FindFirstChild(weaponName)
	if hitAnimations and hitAnimations:FindFirstChild("Hit") then
		local hitFolder = hitAnimations.Hit
		local hitAnimation = hitFolder:GetChildren()[math.random(1, #hitFolder:GetChildren())]
		return hitAnimation
	end
end

local function handleCooldowns(duration, resetFunc)
	task.delay(duration, resetFunc)
end

local function createStun(character, duration)
	local stun = Instance.new("BoolValue")
	stun.Parent = character
	stun.Name = "Stun"

	game.Debris:AddItem(stun, duration)
end

local function createTrueStun(character, duration)
	local stun = Instance.new("BoolValue")
	stun.Parent = character
	stun.Name = "TrueStun"

	game.Debris:AddItem(stun, duration)
end

function enemyCharacterFaceCharacter(enemyCharacter, character)
	enemyCharacter:FindFirstChild("HumanoidRootPart").CFrame = CFrame.lookAlong(
		enemyCharacter:FindFirstChild("HumanoidRootPart").Position,
		character:FindFirstChild("HumanoidRootPart").CFrame.LookVector
	) * CFrame.Angles(0, math.rad(180), 0)
end

local function CanCharacterBeAttackedWhilstBlocking(character, enemyCharacter)
	local userHumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local enemyHumanoidRootPart = enemyCharacter:FindFirstChild("HumanoidRootPart")

	if
		(userHumanoidRootPart.Position - enemyHumanoidRootPart.Position).Unit:Dot(
			enemyHumanoidRootPart.CFrame.LookVector
		) > 0.5
	then
		return false
	end

	return true
end

local function Effect(weaponName, enemyHumanoidRootPart, character)
	if weaponName == "Fist" then
		replicate:FireAllClients("Combat", "HitFX", enemyHumanoidRootPart, "Fist Hit", character)
	elseif weaponName == "Hammer" then
		replicate:FireAllClients("Combat", "HitFX", enemyHumanoidRootPart, "Hammer Hit", character)
	elseif weaponName == "Spear" then
		replicate:FireAllClients("Combat", "HitFX", enemyHumanoidRootPart, "Spear Hit", character)
	end
end

function hit.hit(
	enemyCharacter: Model,
	Character: Model,
	weaponName: string,
	combo: string,
	holdingSpace: boolean,
	HumanoidState
)
	local enemyHumanoidRootPart: Part = enemyCharacter:FindFirstChild("HumanoidRootPart")
	local enemyHumanoid = enemyCharacter:FindFirstChildWhichIsA("Humanoid")
	local enemyAnimator = enemyHumanoid:FindFirstChildWhichIsA("Animator")

	local HumanoidRootPart: Part = Character:FindFirstChild("HumanoidRootPart")

	local enemyState = stateHandler.new(enemyCharacter.StateFolder)
	local characterState = stateHandler.new(Character.StateFolder)

	if enemyState["Blocking"] == true then
		if CanCharacterBeAttackedWhilstBlocking(Character, enemyCharacter) == false then
			replicate:FireAllClients("Combat", "HitFX", enemyHumanoidRootPart, "Block Hit", Character)
			return
		end
	elseif enemyState["Perfect Block Window"] then
		if CanCharacterBeAttackedWhilstBlocking(Character, enemyCharacter) == false then
			replicate:FireAllClients("Combat", "HitFX", enemyHumanoidRootPart, "Perfect Block", Character)
			createTrueStun(Character, 2)
			return
		end
	end

	Effect(weaponName, enemyHumanoidRootPart, Character)

	if players:GetPlayerFromCharacter(enemyCharacter) then
		remotes.UnBlock:FireClient(players:GetPlayerFromCharacter(enemyCharacter))
	else
		enemyState["Blocking"] = false
	end

	if combo == 4 and holdingSpace == true then
		enemyHumanoidRootPart.Anchored = true
		HumanoidRootPart.Anchored = true
		enemyState["Uptilt"] = true
		characterState["Uptilt"] = true
		createStun(enemyCharacter, weaponSettings[weaponName].StunTime)

		local hrp = HumanoidRootPart -- the player’s root
		local enemyHrp = enemyHumanoidRootPart -- the enemy’s root
		local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		local playerTarget = hrp.CFrame * CFrame.new(0, 15, 0)
		tweenService:Create(hrp, tweenInfo, { CFrame = playerTarget }):Play()

		local lookAtCFrame = CFrame.new(enemyHrp.Position, hrp.Position)

		local enemyTarget = lookAtCFrame * CFrame.new(0, 16, 1.5)

		local ends = tweenService:Create(enemyHrp, tweenInfo, { CFrame = enemyTarget })

		ends:Play()

		ends.Completed:Wait()
		task.wait(0.6)

		enemyCharacterFaceCharacter(enemyCharacter, Character)

		enemyHumanoidRootPart.Anchored = false
		HumanoidRootPart.Anchored = false
		enemyState["Uptilt"] = false
		characterState["Uptilt"] = false
	elseif (combo == 1 or combo == 2 or combo == 3 or combo == 4) and not characterState["Uptilt"] then
		createStun(enemyCharacter, weaponSettings[weaponName].StunTime)
	end

	if combo == 5 and characterState["Uptilt"] == true then
		createStun(enemyCharacter, 2)
		ragdoll.Start(enemyCharacter, 2.5, true, false)

		local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)
		local tween = tweenService:Create(
			enemyHumanoidRootPart,
			tweenInfo,
			{ CFrame = HumanoidRootPart.CFrame * CFrame.new(0, 0, -20) }
		)
		tween:Play()

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { Character, enemyCharacter }
		rayParams.IgnoreWater = true

		-- Calculate the expected CFrame after moving -20 studs forward (local Z)
		local projectedCFrame = HumanoidRootPart.CFrame * CFrame.new(0, 0, -20)
		local rayOrigin = projectedCFrame.Position + Vector3.new(0, 5, 0) -- raycast from above
		local rayDirection = Vector3.new(0, -100, 0)

		local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)

		local targetCFrame
		if result then
			local groundY = result.Position.Y + enemyHumanoidRootPart.Size.Y / 2 + 1.5
			targetCFrame = CFrame.new(projectedCFrame.Position.X, groundY, projectedCFrame.Position.Z)
		end

		local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = tweenService:Create(enemyHumanoidRootPart, tweenInfo, { CFrame = targetCFrame })
		tween:Play()

		-- Tween enemy down to target position
		local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = tweenService:Create(enemyHumanoidRootPart, tweenInfo, { CFrame = targetCFrame })
		tween:Play()
		tween.Completed:Wait()
		replicate:FireAllClients("Combat", "AirDown", targetCFrame, Character, enemyCharacter)
	elseif combo == 5 and characterState["Uptilt"] == false then
		replicate:FireAllClients("Combat", "KnockBack", enemyCharacter, Character)
		bodymover.KnockBackM1(Character, enemyCharacter, weaponSettings[weaponName].KnockBackDistance)
		ragdoll.Start(enemyCharacter, 2, true, true, 1)
		createStun(enemyCharacter, 1.5)
	end
end

function hit.crit(enemyCharacter: Model, Character: Model, weaponName: string)
	local enemyHumanoidRootPart: Part = enemyCharacter:FindFirstChild("HumanoidRootPart")
	local enemyHumanoid = enemyCharacter:FindFirstChildWhichIsA("Humanoid")
	local enemyAnimator = enemyHumanoid:FindFirstChildWhichIsA("Animator")

	local HumanoidRootPart: Part = Character:FindFirstChild("HumanoidRootPart")

	local enemyState = stateHandler.new(enemyCharacter.StateFolder)
	local characterState = stateHandler.new(Character.StateFolder)

	if enemyState["Blocking"] == true then
		if CanCharacterBeAttackedWhilstBlocking(Character, enemyCharacter) == false then
			replicate:FireAllClients("Combat", "HitFX", enemyHumanoidRootPart, "BlockBreak", Character)
			if players:GetPlayerFromCharacter(enemyCharacter) then
				remotes.UnBlock:FireClient(players:GetPlayerFromCharacter(enemyCharacter))
			else
				enemyState["Blocking"] = false
			end

			createStun(enemyCharacter, 2)
			return
		end
	elseif enemyState["Perfect Block Window"] then
		if CanCharacterBeAttackedWhilstBlocking(Character, enemyCharacter) == false then
			replicate:FireAllClients("Combat", "HitFX", enemyHumanoidRootPart, "Perfect Block", Character)
			createTrueStun(Character, 2)
			return
		end
	end

	Effect(weaponName, enemyHumanoidRootPart, Character)

	replicate:FireAllClients("Combat", "HitFX", enemyHumanoidRootPart, weaponName .. " Crit", Character)

	if weaponSettings[weaponName].CritKnockback == true then
		bodymover.KnockBackM1(Character, enemyCharacter, weaponSettings[weaponName].CritKnockBackDistance)
	end

	ragdoll.Start(enemyCharacter, 2, true)
	createStun(enemyCharacter, 2)
end

return hit
