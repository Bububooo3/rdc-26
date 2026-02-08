-- @ScriptType: ModuleScript
local enemy_fldr = game:GetService("ReplicatedStorage"):WaitForChild("Enemies")
local RNG = Random.new()
local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")
local DS = game:GetService("Debris")

local manager = {}

local waves_spawned = 0
local coop_cost_dampener = 1 -- Weight for per-wave cost
local connections: RBXScriptConnection = {}

local enemies = {
	["A"] = enemy_fldr:WaitForChild("Grunt"),
	["B"] = enemy_fldr:WaitForChild("Faller"),
	["C"] = enemy_fldr:WaitForChild("Jumper"),
	["D"] = enemy_fldr:WaitForChild("Surveyor")
}

local enemy_spawns = {
	["A"] = CS:GetTagged("A"), -- Grunt
	["B"] = CS:GetTagged("B"), -- Faller
	["C"] = CS:GetTagged("C"), -- Jumper
	["D"] = CS:GetTagged("D") -- Surveyor
}

local function calcPrice(enemy: string)
	if not enemies[enemy] then return end

	local data = enemies[enemy]:GetAttributes()

	-- Multiplying stats by weights to get costs
	return math.max(3, data["Health"]*1.5 + data["Damage"]*2 + data["Speed-Mult"]*1)
end

-- TODO: figure out enemy prices
local enemy_prices: {number} = {
	["A"] = calcPrice("A"), -- Grunt
	["B"] = calcPrice("B"), -- Faller
	["C"] = calcPrice("C"), -- Jumper
	["D"] = calcPrice("D") -- Surveyor
}

--	[Wave #] = {time, {enemies}, base_cost, player_multiplier}
local waves = {							-- (cost calculations)
	[1] = {5, {"A"}, 12, 1.4},           -- Solo: 12, Duo: 16.8, Trio: 23.5, Quad: 32.9
	[2] = {65, {"A", "B"}, 28, 1.5},     -- Solo: 28, Duo: 42, Trio: 63, Quad: 94.5
	[3] = {125, {"A", "B", "C"}, 50, 1.6}, -- Solo: 50, Duo: 80, Trio: 128, Quad: 204.8
	[4] = {185, {"A", "B", "C", "D"}, 80, 1.7},   -- Solo: 80, Duo: 136, Trio: 231.2, Quad: 393
	[5] = {245, {"A", "B", "C", "D"}, 120, 1.8},  -- Solo: 120, Duo: 216, Trio: 388.8, Quad: 699.8
	[6] = {305, {"A", "B", "C", "D"}, 180, 2.0}   -- Solo: 180, Duo: 360, Trio: 720, Quad: 1440
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

	local controller = enemy_fldr["Scripts"][rig.Name]:Clone()
	controller.Parent = rig
	controller.Enabled = true

	rig.Parent = workspace
	rig:PivotTo(enemy_spawns[enemy][RNG:NextInteger(1, #enemy_spawns[enemy])].CFrame)
	DS:AddItem(rig, 60)
	rig.Destroying:Connect(distributeEnemyHealth, rig:GetAttribute("Health"), rig:GetAttribute("HitByPlayer"))
end

function manager.spawnWave(wave: number)
	if not waves[wave] then return end

	local wave_data = waves[wave]
	local cost = math.floor(wave_data[3] * wave_data[4]^(#plrs_alive - 1) * coop_cost_dampener)

	-- Find the cheapest enemy available in this wave
	local min_price = math.huge
	for _, enemy_type in wave_data[2] do
		min_price = math.min(min_price, enemy_prices[enemy_type])
	end

	while cost >= min_price do
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
