-- @ScriptType: Script
--[[
	TODO
	Might wanna switch BindableEvents with Signals?
]]

-----------------------------------------------------------------------
-- Initialize variables
local round_length = 300 -- seconds
local intermission_length = 45 -- seconds
local transition_length = 10 -- seconds
local timer = 0 -- seconds
local dt = .5 -- seconds btwn updates
local RNG = Random.new()

local intermission_spawn = workspace:WaitForChild("IntermissionSpawn").CFrame
local round_spawns = game:GetService("CollectionService"):GetTagged("RoundSpawn")
local num_round_spawns = #round_spawns
local round_ongoing = false

local RS = game:GetService("ReplicatedStorage")
local fxns, events = RS:WaitForChild("Functions"), RS:WaitForChild("Events")
local refreshTimer = fxns:WaitForChild("refreshTimer")
local displayMsg = fxns:WaitForChild("displayMsg")


-----------------------------------------------------------------------
-- Utility functions
local function moveMeTo(char: Model, cf: CFrame)
	char:PivotTo(cf)
end

local function teleportPlrs() ----> Move all plrs based on whether the game's going on
	for _, plr in game.Players:GetPlayers() do
		pcall(moveMeTo, plr.Character, (round_ongoing) and round_spawns[RNG:NextInteger(1, num_round_spawns)] or intermission_spawn)
		task.wait()
	end
end

local function postMsg(msg: string)
	for _, plr in game.Players:GetPlayers() do ----> Display new message on client-side
		pcall(displayMsg.InvokeClient, displayMsg, plr, "Server: " .. msg)
	end
end

local function updateTimer() ----> Display the new time on client-side
	for _, plr in game.Players:GetPlayers() do
		pcall(refreshTimer.InvokeClient, refreshTimer, plr, timer)
		task.wait()
	end
end

-----------------------------------------------------------------------
-- Initialize main functions
local function transitionPeriod() --> Needs a better name...
	teleportPlrs()
	task.wait(transition_length)
end

-- TP plrs, fire bindable event, fire remote event, start timer
local function initRound() --> Run once @ start of round
	round_ongoing = true
	transitionPeriod()

end

-- Start timer
local function initIntermission() --> Run once @ start of intermission
	round_ongoing = false
	transitionPeriod()

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
local function roundPeriodic(dt: number) --> Run every heartbeat while round is ongoing
	updateTimer()

	if timer < round_length then return end
	endRound()
end

local function intermissionPeriodic(dt: number) --> Run every heartbeat during intermission
	updateTimer()

	if timer < intermission_length then return end
	endIntermission()
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
-- (This way lets us do transition time w/o breaking anything or doing much modification)
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