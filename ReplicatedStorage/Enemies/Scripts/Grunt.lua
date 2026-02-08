-- @ScriptType: Script
type Enemy = {
	char: Model,
	dmg: number,
	hp: number,
	speed: number,
	target: Model?,
	canattack: boolean,

	attack: () -> (), ----> Called when enemy must attack
	scan: () -> (Model?), ----> Returns target
	damaged: () -> (boolean), ----> Runs when enemy is damaged
	periodic: (local_dt: number) -> (), ----> Runs every dt seconds
	init: () -> (), ----> Runs once @ spawn
}

local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local config = RS:WaitForChild("Game Settings")
local dt = config:GetAttribute("dt")
local attack_cooldown = config:GetAttribute("AttackCooldown")
local sight_range = config:GetAttribute("SightRange")
local cooldown_timer = 0

local raycast_params = RaycastParams.new()
raycast_params.FilterType = Enum.RaycastFilterType.Exclude

local grunt: Enemy = {
	char = script.Parent,
	dmg = script.Parent:GetAttribute("Damage"),
	hp = script.Parent:GetAttribute("Health"),
	speed = script.Parent:GetAttribute("Speed-Mult")*config:GetAttribute("BaseWalkspeed"),
	target = nil,


	attack = function(self: Enemy)

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

		return closest_avaliable
	end,

	damaged = function(self: Enemy)

	end,

	periodic = function(self: Enemy, local_dt: number)

	end,


	init = function(self: Enemy)

	end,
}

-----------------------------------------------------------------------
-- Post-definition set-up (backtracking)


-----------------------------------------------------------------------
-- Connections


-----------------------------------------------------------------------
-- Startup behavior
grunt.init()

-----------------------------------------------------------------------
-- Periodic behavior
-- (This way lets us do transition time w/o breaking anything or doing much modification)
while task.wait(dt) do
	cooldown_timer += dt

	grunt.periodic(dt)
end