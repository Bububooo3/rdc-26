-- @ScriptType: Script
--[[
	TODO
	Might wanna switch BindableEvents with Signals?
]]

-----------------------------------------------------------------------
-- Initialize variables
local round_length = 300 -- seconds
local intermission_length = 45 -- seconds
local timer = 0 -- seconds
local round_ongoing = false
local RNG = Random.new()
local intermission_spawn = workspace:WaitForChild("IntermissionSpawn").CFrame
local round_spawns = game:GetService("CollectionService"):GetTagged("RoundSpawn")
local num_round_spawns = #round_spawns
local dt = .5 -- seconds btwn updates


-----------------------------------------------------------------------
-- Utility functions
local function moveMeTo(char: Model, cf: CFrame)
	char:PivotTo(cf)
end

local function teleportPlrs()
	for _, plr in game.Players:GetPlayers() do
		pcall(moveMeTo, plr.Character, (round_ongoing) and round_spawns[RNG:NextInteger(1, num_round_spawns)] or intermission_spawn)
		task.wait()
	end
end


-----------------------------------------------------------------------
-- Initialize main functions
-- TP plrs, fire bindable event, fire remote event, start timer
local function initRound() --> Run once @ start of round
	round_ongoing = true


end

-- Start timer
local function initIntermission() --> Run once @ start of intermission
	round_ongoing = false

end


-----------------------------------------------------------------------
local function roundPeriodic(dt: number) --> Run every heartbeat while round is ongoing

end

local function intermissionPeriodic(dt: number) --> Run every heartbeat during intermission

end


-----------------------------------------------------------------------
-- Reset timer, do cleanup
local function endRound() --> Run once @ end of round

	timer = 0
	initIntermission()
end

local function endIntermission() --> Run once @ end of intermission

	timer = 0
	initRound()
end


-----------------------------------------------------------------------
-- Startup behavior
if round_ongoing then
	initRound()
else
	initIntermission()
end


-----------------------------------------------------------------------
-- Periodic behavior
while task.wait(dt) do
	timer += dt

	if round_ongoing then
		-- Round is ongoing
		roundPeriodic(dt)
	else
		-- Intermission
		intermissionPeriodic(dt)
	end
end