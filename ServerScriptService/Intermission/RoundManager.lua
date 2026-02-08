-- @ScriptType: ModuleScript
local enemy_fldr = game:GetService("ReplicatedStorage"):WaitForChild("Enemies")
local RNG = Random.new()
local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")
local DS = game:GetService("Debris")

local manager = {}

local waves_spawned = 0
local connections: RBXScriptConnection = {}

local enemies = {
	["A"] = enemy_fldr:WaitForChild("Grunt"),
	["B"] = enemy_fldr:WaitForChild("Faller"),
	["C"] = enemy_fldr:WaitForChild("Jumper"),
	["D"] = enemy_fldr:WaitForChild("Surveyor")
}

local enemy_spawns = {
	["A"] = CS:GetTagged("A"),
	["B"] = CS:GetTagged("B"),
	["C"] = CS:GetTagged("C"),
	["D"] = CS:GetTagged("D")
}

local enemy_prices = {
	["A"] = 1,
	["B"] = 0,
	["C"] = 0,
	["D"] = 0
}

--	[Wave #] = {time_passed, {allowed_enemies}, cost, per-plr-spawn-multiplier}
local waves = {
	[1] = {5, {"A"}, 3, 1.5},
	[2] = {65, {"A", "B"}, 6, 2},
	[3] = {125, {"A", "B", "C"}, 9, 2},
	[4] = {185, {"A", "B", "C", "D"}, 10, 2.5},
	[5] = {245, {"A", "B", "C", "D"}, 10, 3},
	[6] = {305, {"A", "B", "C", "D"}, 50 , 4}
}

manager.wave_times = {
	[5] = 1,
	[65] = 2,
	[125] = 3,
	[185] = 4,
	[245] = 5,
	[305] = 6
}

local plrs_alive: Players = {}

local function distributeEnemyHealth(provider_health: number, hit: boolean) ----> Give leftover health to youngest few enemies upon natural death
	if hit then return end
end

function manager.spawnEnemy(enemy: string)
	if not enemies[enemy] then return end

	local rig = enemies[enemy]:Clone()
	rig.Parent = workspace
	rig:PivotTo(enemy_spawns[enemy][RNG:NextInteger(1, #enemy_spawns[enemy])].CFrame)
	DS:AddItem(rig, 60)
	rig.Destroying:Connect(distributeEnemyHealth, rig:GetAttribute("Health"), rig:GetAttribute("HitByPlayer"))
end

function manager.spawnWave(wave: number)
	if not waves[wave] then return end

	local wave_data = waves[wave]
	local cost = wave_data[3] + math.floor(wave_data[4]^(#plrs_alive))

	while cost > 0 do
		local new_enemy = wave_data[2][RNG:NextInteger(1, #wave_data[2])]
		
		while (enemy_prices[new_enemy] > cost) do
			new_enemy = wave_data[2][RNG:NextInteger(1, #wave_data[2])]
		end
		
		manager.spawnEnemy(new_enemy)
		
		cost -= enemy_prices[new_enemy]
		
		task.wait()
	end


	waves_spawned += 1
end

function manager.reset()
	waves_spawned = 1
	table.clear(plrs_alive)
end

function manager.initPlayers(plrs: {Player})
	for _, plr in plrs do
		if not plr.Character then continue end

		local char = plr.Character
		CS:AddTag(char, "Player")
		char:SetAttribute("Health", 10)
		table.insert(plrs_alive, plr)

		table.insert(connections, char.AttributeChanged:Connect(function()
			if not (char:GetAttribute("Health") <= 0) then return end
			table.remove(plrs_alive, table.find(plrs_alive, plr))
			char:WaitForChild("Humanoid").Health = 0
		end))
	end
end

function manager.stripPlayers()
	for _, conn in connections do
		conn:Disconnect()
	end

	for _, plr in Players:GetPlayers() do
		if not plr.Character then continue end

		local char = plr.Character
		CS:RemoveTag(char, "Player")
		char:SetAttribute("Health", nil)
		table.insert(plrs_alive, plr)
	end
end

return manager
