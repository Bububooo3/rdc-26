-- @ScriptType: Script
--[[
	TODO
	Might wanna switch BindableEvents with Signals?
]]

-----------------------------------------------------------------------
-- Initialize variables
local RS = game:GetService("ReplicatedStorage")
local config = RS:WaitForChild("Game Settings")
local events = RS:WaitForChild("Events")
local refreshTimer_event = events:WaitForChild("refreshTimer")
local displayMsg_event = events:WaitForChild("displayMsg")

local round_length = 15 -- seconds
local intermission_length = 5 -- seconds
local transition_length = 10 -- seconds
local timer = 0 -- seconds
local dt: number = config:GetAttribute("dt") or 0.5 -- seconds
local RNG = Random.new()

local intermission_spawn = workspace:WaitForChild("IntermissionSpawn").CFrame
local round_spawns = game:GetService("CollectionService"):GetTagged("RoundSpawn")
local num_round_spawns = #round_spawns
local round_ongoing = false

local RM = require(script:WaitForChild("RoundManager"))

-----------------------------------------------------------------------
-- Utility functions
local function teleportPlrs() ----> Move all plrs based on whether the game's going on
	for _, plr in game.Players:GetPlayers() do
		pcall(plr.Character.PivotTo, plr.Character, (round_ongoing) and round_spawns[RNG:NextInteger(1, num_round_spawns)].CFrame or intermission_spawn)
		task.wait()
	end
end

local function displayMsg(msg: string, t: number, disable: boolean)
	if not disable then disable = false end
	if not msg then msg = "" end
	t = math.max(0, t) ----> Msg will be "permanent" until a new msg with a set time = t replaces it

	pcall(displayMsg_event.FireAllClients, displayMsg_event, msg, t, disable) ----> Display new message on client-side

	return {Wait = function() ----> We can use wait if we wanna wait for the msg to leave before moving on
		task.wait(t)
	end}
end

local function refreshTimer() ----> Display the new time on client-side
	pcall(refreshTimer_event.FireAllClients, refreshTimer_event, ((round_ongoing) and round_length or intermission_length) - timer//1)
end

local function roundIntro()
	displayMsg("Attention, residents of [REPLACE ME]!", 2.5).Wait()
	displayMsg("It's been brought to my attention that aliens have invaded our town!", 2.5).Wait()
	displayMsg("Why? Don't ask me! I've never even seen one!", 2.5).Wait()
	displayMsg("Anyways, we should be fine.", 2.5).Wait()
	displayMsg("The military's on their way to extract us.", 2.5).Wait()
	displayMsg("Until then, we're under quarantine.", 2.5).Wait()
	displayMsg("Stay sharp, and stay alive!", 2.5, true).Wait()
end

local function roundEpilogue()
	displayMsg("Shortly after these events, the military arrived.", 2.5).Wait()
	displayMsg("In the end, the aliens were defeated.", 2.5).Wait()
	displayMsg("# residents made it out alive...", 2.5).Wait()
	displayMsg("...others are in critical condition, but many are dead.", 2.5).Wait()
	displayMsg("Hopefully, this is the first and last we'll time hear of an alien infiltration.", 2.5, true).Wait()
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
	RM.reset()
	RM.initPlayers(game.Players:GetPlayers())
	roundIntro()
	transitionPeriod()
	timer = 0
end

-- Start timer
local function initIntermission() --> Run once @ start of intermission
	round_ongoing = false
	transitionPeriod()
end


-----------------------------------------------------------------------
-- Reset timer, do cleanup
local function endRound() --> Run once @ end of round
	RM.stripPlayers()
	roundEpilogue()
	timer = 0
	initIntermission()
end

local function endIntermission() --> Run once @ end of intermission
	initRound()
end


-----------------------------------------------------------------------
local function roundPeriodic(local_dt: number) --> Run every heartbeat while round is ongoing
	if RM.wave_times[timer] then
		RM.spawnWave(RM.wave_times[timer])
	end

	if timer < round_length then return end
	endRound()
end

local function intermissionPeriodic(local_dt: number) --> Run every heartbeat during intermission
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
	refreshTimer()

	if round_ongoing then
		-- Round is ongoing
		roundPeriodic(dt)
	else
		-- Intermission
		intermissionPeriodic(dt)
	end
end