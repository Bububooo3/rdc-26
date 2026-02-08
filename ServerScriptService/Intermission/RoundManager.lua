-- @ScriptType: ModuleScript
local enemy_fldr = game:GetService("ReplicatedStorage"):WaitForChild("Enemies")
local RNG = Random.new()
local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")
local DS = game:GetService("Debris")

local manager = {}

local waves_spawned = 0

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

--	[Wave #] = {time_passed, {allowed_enemies}, #spawn_base_value, per-plr-spawn-multiplier}
local waves = {
	[1] = {5, {"A"}, 3, 1.5},
	[2] = {65, {"A", "C", "D"}, 6, 2},
	[3] = {125, {"B"}, 9, 2},
	[4] = {185, {"A", "C", "D"}, 10, 2.5},
	[5] = {245, {"A", "B"}, 10, 2.5},
	[6] = {305, {"C", "D"}, 10 , 3}
}

local plrs_alive: Players = {}

local function distributeEnemyHealth(provider_health: number, hit: boolean) ----> Give leftover health to youngest enemy upon natural death
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
	local spawn_num = wave_data[3] + math.floor(wave_data[4]^(#plrs_alive))
end

return manager
