-- @ScriptType: Script
-----------------------------------------------------------------------
-- Outline enemy class
type Enemy = {
	char: Model,
	dmg: number,
	hp: number,
	speed: number,
	target: Model?,
	canattack: boolean,
	canmove: boolean,

	attack: () -> (), ----> Pretty self-explanatory
	wander: () -> (), ----> Use if there's no target rn
	move: () -> (), ----> Move towards target
	scan: () -> (Model?), ----> Sets new target
	death: () -> (), ----> and there, in my final moments on this planet Earth, I realized the significance of it all...
	damage: () -> (), ----> Damages enemy based on what's in-range (rn it destroys them, so its projectile-only)
	periodic: (local_dt: number) -> (), ----> Runs every dt seconds
	init: () -> (), ----> Runs once @ spawn
}

-----------------------------------------------------------------------
-- Variables
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local config = RS:WaitForChild("Game Settings")
local dt = config:GetAttribute("dt") or 0.5
local attack_cooldown = config:GetAttribute("AttackCooldown") or 1
local sight_range = config:GetAttribute("SightRange") or 10
local cooldown_timer = 0

local raycast_params = RaycastParams.new()
raycast_params.FilterType = Enum.RaycastFilterType.Exclude

local overlap_params = OverlapParams.new()
overlap_params.FilterType = Enum.RaycastFilterType.Exclude
overlap_params.RespectCanCollide = false

-----------------------------------------------------------------------
-- Enemy definition
local grunt: Enemy = {
	char = script.Parent,
	dmg = script.Parent:GetAttribute("Damage"),
	hp = script.Parent:GetAttribute("Health"),
	speed = script.Parent:GetAttribute("Speed-Mult")*config:GetAttribute("BaseWalkspeed"),
	target = nil,


	attack = function(self: Enemy)
		if not (self.canattack and self.target) then return end
		
		self.canattack = false
		
		-- Cooldown
		task.delay(attack_cooldown, function()
			self.canattack = true
		end)
	end,
	
	wander = function(self: Enemy) ----> Do later if we have time. rn, no wandering. essentials come first.
		return
	end,

	move = function(self: Enemy)
		if not self.target then self:wander() return end
		
	end,

	scan = function(self: Enemy)
		local closest_avaliable = nil
		local dist = sight_range

		for _, unknown in workspace:GetChildren() do
			-- R u a player?
			if not (CS:HasTag(unknown, "Player")) then continue end

			local dist_vector = (unknown.HumanoidRootPart.Position - self.char.PrimaryPart.Position)

			-- Can I see you? (radar effect)
			if CS:HasTag(unknown, "Tagged") and (dist_vector.Magnitude <= sight_range) and (dist_vector.Magnitude < dist) then
				closest_avaliable = unknown
				continue
			end

			-- Update params to ignore all enemies
			raycast_params.FilterDescendantsInstances = CS:GetTagged("Enemy")

			-- Do the raycast (obstacle check)
			local raycast_result = workspace:Raycast(
				self.char.PrimaryPart.Position, ----> From head
				dist_vector.Unit*sight_range,
				raycast_params
			)

			-- Out of range?
			if not raycast_result then continue end

			-- Did we hit this specific player, or some random thing?
			if not(raycast_result.Instance:IsDescendantOf(unknown)) then continue end

			if (dist_vector.Magnitude < dist) then closest_avaliable = unknown end
		end

		self.target = closest_avaliable
	end,
	
	death = function(self: Enemy) ----> We can add stuff later
		self.char:Destroy()
	end,

	damage = function(self: Enemy)
		overlap_params.FilterDescendantsInstances = CS:GetTagged("Enemy")

		for _, hit in workspace:GetPartBoundsInBox(self.char:GetPivot(), self.char:GetExtentsSize(), overlap_params) do
			if not (CS:HasTag(hit, "Damager")) then continue end

			self.hp -= hit:GetAttribute("Damage")
			hit:Destroy()

			if (self.hp <= 0) then break end
		end
		
		if (self.hp <= 0) then self:death() end
	end,

	periodic = function(self: Enemy, local_dt: number)
		self:damage()
		self:scan()
		self:move()
	end,


	init = function(self: Enemy) ----> Runs assuming char has just been placed @ a spawn location in the workspace
		self:scan()
	end,
}


-----------------------------------------------------------------------
-- Startup behavior
grunt.init()


-----------------------------------------------------------------------
-- Periodic behavior
while task.wait(dt) do
	cooldown_timer += dt

	if grunt.hp <= 0 then break end ----> "Died" condition

	grunt.periodic(dt)
end

-----------------------------------------------------------------------