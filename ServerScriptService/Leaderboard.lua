-- @ScriptType: Script
local DS = game:GetService("DataStoreService")
local CS = game:GetService("CollectionService")
local winsDS = DS:GetDataStore("wins")


local function updateWins(val, plr)
	winsDS:SetAsync(plr.UserId, val)
end

local function plrAdded(plr: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Parent = plr
	leaderstats.Name = "leaderstats"

	local wins = Instance.new("IntValue")
	wins.Parent = leaderstats
	wins.Name = "Wins"
	wins.Value = winsDS:GetAsync(plr.UserId) or 0

	winsDS:SetAsync(plr.UserId, wins.Value)

	plr.leaderstats.Wins.Changed:Connect(updateWins, plr)
end

local function plrRemoving(plr)
	winsDS:SetAsync(plr.UserId, plr.leaderstats.Wins.Value)
end

game.Players.PlayerAdded:Connect(plrAdded)
game.Players.PlayerRemoving:Connect(plrRemoving)