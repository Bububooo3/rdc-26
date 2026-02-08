-- @ScriptType: Script
-----------------------------------------------------------------------
-- Outline enemy class
type Enemy = {
	char: Model,

	dmg: number,
	hp: number,
	attack_range: number,
	speed: number,

	jumpAnim: AnimationTrack,
	walkAnim: AnimationTrack,
	attackAnim: AnimationTrack,
	idleAnim: AnimationTrack,

	target: Model?,

	canattack: boolean,
	canmove: boolean,

	mover: thread,

	attack: () -> (), ----> Pretty self-explanatory
	wander: () -> (), ----> Use if there's no target rn
	move: () -> (), ----> Move towards target
	scan: () -> (), ----> Sets new target
	death: () -> (), ----> and there, in my final moments on this planet Earth, I realized the significance of it all...
	damage: () -> (), ----> Damages enemy based on what's in-range (rn it destroys them, so its projectile-only)
	periodic: (local_dt: number) -> (), ----> Runs every dt seconds
	init: () -> (), ----> Runs once @ spawn
	pathfinding: () -> (), ----> Pre-defined so we can plug it into coroutine (rather than new fxn every time)
	wanderfinding: () -> (), ----> A version of pathfinding meant for when we've got no target in mind
	animate: (anim: AnimationTrack) -> () ----> Runs this one animation, and stops all others
}

-----------------------------------------------------------------------
-- Variables
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local PS = game:GetService("PathfindingService")
local RNG = Random.new()
local config = RS:WaitForChild("Game Settings")
local dt = config:GetAttribute("dt") or 0.5
local attack_cooldown = config:GetAttribute("AttackCooldown") or 1
local sight_range = 100000 ----> Gets changed after init
local wander_distance = 30
local min_dist = 5 ----> Minimum distance between targets 1 and 2 needed to actually change trajectory
local jump_power = 50 ----> (For linearvelocity)
local drop_height = 10

local raycast_params = RaycastParams.new()
raycast_params.FilterType = Enum.RaycastFilterType.Exclude

local overlap_params = OverlapParams.new()
overlap_params.FilterType = Enum.RaycastFilterType.Exclude
overlap_params.RespectCanCollide = false

local agent_params = {
	AgentRadius = 3,
	AgentHeight = 5,
	AgentCanJump = true,
	WaypointSpacing = 4,
	Costs = {
		Water = 20
	}
}

local anim_j = Instance.new("Animation")
anim_j.Parent = script.Parent.Humanoid
anim_j.AnimationId = "rbxassetid://"..script.Parent:GetAttribute("JumpAnimID")

local anim_w = Instance.new("Animation")
anim_w.Parent = script.Parent.Humanoid
anim_w.AnimationId = "rbxassetid://"..script.Parent:GetAttribute("WalkAnimID")

local anim_a = Instance.new("Animation")
anim_a.Parent = script.Parent.Humanoid
anim_a.AnimationId = "rbxassetid://"..script.Parent:GetAttribute("AttackAnimID")

local anim_i = Instance.new("Animation")
anim_i.Parent = script.Parent.Humanoid
anim_i.AnimationId = "rbxassetid://"..script.Parent:GetAttribute("IdleAnimID")

-----------------------------------------------------------------------
-- Enemy definition
local faller: Enemy = {
	char = script.Parent,
	dmg = script.Parent:GetAttribute("Damage"),
	hp = script.Parent:GetAttribute("Health"),
	attack_range = script.Parent:GetAttribute("AttackRange"),
	speed = script.Parent:GetAttribute("Speed-Mult")*config:GetAttribute("BaseWalkspeed"),
	jumpAnim = script.Parent.Humanoid.Animator:LoadAnimation(anim_j),
	walkAnim = script.Parent.Humanoid.Animator:LoadAnimation(anim_w),
	attackAnim = script.Parent.Humanoid.Animator:LoadAnimation(anim_a),
	idleAnim = script.Parent.Humanoid.Animator:LoadAnimation(anim_i),
	target = nil,
	canattack = true,
	canmove = false, 
	mover = nil,     


	attack = function(self: Enemy)
		if not (self.canattack and self.target) then return end

		self.canattack = false
		self.canmove = false ----> It's already supposed to be false, but we're playing it safe here.

		-- Look at me. LOOK AT ME. I'm not mad at you... just- disappointed. Do better next time.
		self.char:PivotTo(CFrame.lookAt(
			self.char.PrimaryPart.Position,
			Vector3.new(self.target.HumanoidRootPart.Position.X, self.char.HumanoidRootPart.Position.Y, self.target.HumanoidRootPart.Position.Z))
		)

		self:animate(self.attackAnim)
		
		pcall(function()
			local currentHealth = self.target:GetAttribute("Health")
			self.target:SetAttribute("Health", currentHealth - self.dmg)
		end)
		
		self.attackAnim.Ended:Wait()
		
		-- Cooldown
		task.delay(attack_cooldown, function()
			self.canattack = true
		end)
	end,

	pathfinding = function(self: Enemy)
		if not self.target then return end

		local path = PS:CreatePath(agent_params)

		local success, errorMessage = pcall(function()
			path.ComputeAsync(self.char.HumanoidRootPart.Position, self.target.HumanoidRootPart.Position)
		end)

		if not success or path.Status ~= Enum.PathStatus.Success then return end

		local waypoints = path:GetWaypoints()

		local blockedConnection = path.Blocked:Connect(function(waypointIndex) ----> Basically an emergency stop
			if waypointIndex > 1 then
				self.canmove = false
			end
		end)

		-- cycle time
		for i, waypoint in ipairs(waypoints) do
			-- check every time bc it's a coroutine
			if not self.canmove then break end
			if not self.target then break end
			if self.hp <= 0 then break end

			-- Move to waypoint smoothly
			local dist_vector = (waypoint.Position - self.char.HumanoidRootPart.Position)
			local dist_scalar = dist_vector.Magnitude

			-- Jump around! I'm so clever, guys.
			-- Pack it up, pack it in, let me begin
			-- I came to win, battle me, that's a sin
			-- Hold up this writing is fire
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				self.jumpAnim:Play()
				
				self.char.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(
					self.char.HumanoidRootPart.AssemblyLinearVelocity.X,
					jump_power,
					self.char.HumanoidRootPart.AssemblyLinearVelocity.Z
				)
			end


			-- Incremental bc we want smooth movement
			while dist_scalar > 0.5 do
				self:animate(self.walkAnim)
				if not self.canmove then break end
				if not self.target then break end
				if self.hp <= 0 then break end

				dist_vector = (waypoint.Position - self.char.PrimaryPart.Position)
				dist_scalar = dist_vector.Magnitude

				local moveStep = math.min(self.speed * 0.05, dist_scalar) -- incremental movement
				self.char:PivotTo(self.char:GetPivot() * CFrame.new(0, 0, -moveStep))

				-- Watch where you're going!
				local lookAt = CFrame.lookAt(
					self.char.PrimaryPart.Position,
					Vector3.new(waypoint.Position.X, self.char.HumanoidRootPart.Position.Y, waypoint.Position.Z)
				)
				self.char:PivotTo(lookAt * CFrame.new(0, 0, 0))

				task.wait(0.05) -- Smooth movement updates
			end
		end
		
		blockedConnection:Disconnect()
		
		self:animate(self.idleAnim)
	end,

	wanderfinding = function(self: Enemy)
		-- Random location on a 2D plane within a radius
		local offset_goal = self.char.HumanoidRootPart.Position + Vector3.new(
			RNG:NextInteger(-wander_distance, wander_distance),
			0,
			RNG:NextInteger(-wander_distance, wander_distance)
		)

		local path = PS:CreatePath(agent_params)

		local success, errorMessage = pcall(function()
			path:ComputeAsync(self.char.HumanoidRootPart.Position, offset_goal)
		end)

		if not success or path.Status ~= Enum.PathStatus.Success then return end

		local waypoints = path:GetWaypoints()

		local blockedConnection = path.Blocked:Connect(function(waypointIndex) ----> e-stop
			if waypointIndex > 1 then
				self.canmove = false
			end
		end)

		-- cycle time again.
		for i, waypoint in ipairs(waypoints) do
			-- Check if we found a target (scan will set canmove to false)
			if not self.canmove then break end
			if self.target then break end -- Stop wandering if target found
			if self.hp <= 0 then break end

			local dist_vector = (waypoint.Position - self.char.HumanoidRootPart.Position)
			local dist_scalar = dist_vector.Magnitude

			if waypoint.Action == Enum.PathWaypointAction.Jump then
				self.jumpAnim:Play()
				
				self.char.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(
					self.char.HumanoidRootPart.AssemblyLinearVelocity.X,
					jump_power,
					self.char.HumanoidRootPart.AssemblyLinearVelocity.Z
				)
			end

			
			while dist_scalar > 0.5 do ----> Get within a .5 stud radius of the waypoint
				self:animate(self.walkAnim)
				if not self.canmove then break end
				if self.target then break end -- Stop if target found
				if self.hp <= 0 then break end

				dist_vector = (waypoint.Position - self.char.PrimaryPart.Position)
				dist_scalar = dist_vector.Magnitude

				local moveStep = math.min(self.speed * 0.05, dist_scalar) ----> Little steps
				self.char:PivotTo(self.char:GetPivot() * CFrame.new(0, 0, -moveStep))

				-- Watch your step, little bro...
				local lookAt = CFrame.lookAt(
					self.char.PrimaryPart.Position,
					Vector3.new(waypoint.Position.X, self.char.HumanoidRootPart.Position.Y, waypoint.Position.Z)
				)
				
				self.char:PivotTo(lookAt * CFrame.new(0, 0, 0))

				task.wait(0.05)
			end
		end

		blockedConnection:Disconnect()
		
		self:animate(self.idleAnim)

		task.wait(RNG:NextInteger(2, 5)) ----> chillax a little
		self.canmove = false ----> Time to get going again...
	end,

	wander = function(self: Enemy) ----> Ok, we did a thing.
		if not self.mover or coroutine.status(self.mover) == "dead" then
			self.canmove = true

			self.mover = coroutine.create(function()
				self:wanderfinding()
			end)

			coroutine.resume(self.mover)
		end
	end,

	move = function(self: Enemy)
		if not self.target then self:wander() return end

		-- Check if we're in attack range		
		if (self.target.HumanoidRootPart.Position - self.char.PrimaryPart.Position).Magnitude <= self.attack_range then
			self.canmove = false
			self:attack()
			return
		end

		-- Start new movement coroutine if none exists or previous finished
		if not self.mover or coroutine.status(self.mover) == "dead" then
			self.canmove = true

			self.mover = coroutine.create(function()
				self:pathfinding()
			end)

			coroutine.resume(self.mover)
		end
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

		-- Only matters if the change in location isn't neglibile by our own definition (min_dist)
		if self.target ~= closest_avaliable then 
			self.canmove = false
		elseif closest_avaliable and self.target then
			if (self.target.HumanoidRootPart.Position - closest_avaliable.HumanoidRootPart.Position).Magnitude > 10 then
				self.canmove = false -- Force recalculation of path
			end
		end

		self.target = closest_avaliable
	end,

	death = function(self: Enemy) ----> We can add stuff later
		self.canmove = false
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
		self.char.Humanoid.WalkSpeed = self.speed
		self:scan()

		if self.target then
			self.char:PivotTo(CFrame.new(self.target.HumanoidRootPart.Position + Vector3.new(0, drop_height, 0)))
		else
			self.char:PivotTo(self.char:GetPivot() * CFrame.new(0, drop_height, 0))
		end

		sight_range = config:GetAttribute("SightRange")
	end,
	
	animate = function(self: Enemy, anim: AnimationTrack)
		if anim.IsPlaying then return end
		
		for _, v in {self.attackAnim, self.idleAnim, self.walkAnim,  self.jumpAnim} do
			if v == anim then continue end
			v:Stop()
		end
		
		anim:Play()
	end,
}


-----------------------------------------------------------------------
-- Startup behavior
faller:init()

while math.abs(faller.char.HumanoidRootPart.AssemblyLinearVelocity.Y) > 1 do
	task.wait(dt)
end


-----------------------------------------------------------------------
-- Periodic behavior
while task.wait(dt) do
	if faller.hp <= 0 then break end ----> "Died" condition

	faller.periodic(dt)
end

-----------------------------------------------------------------------