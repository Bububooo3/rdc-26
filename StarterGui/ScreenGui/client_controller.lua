-- @ScriptType: LocalScript
local RS = game:GetService("ReplicatedStorage")
local events = RS:WaitForChild("Events")
local displayMsg_event = events:WaitForChild("displayMsg")
local refreshTimer_event = events:WaitForChild("refreshTimer")

local UI = script.Parent
local msg_box = UI:WaitForChild("message_frame"):WaitForChild("msg_box")
local timer_box = UI:WaitForChild("round_info_frame"):WaitForChild("timer")
local last_input = 0

displayMsg_event.OnClientEvent:Connect(function(msg: string, dur: number, disable: boolean)
	last_input += 1
	local current = last_input
	
	msg_box.Text = msg
	msg_box.Parent.Visible = true
	task.wait(dur)
	
	if not (last_input == current) then return end -- prevent overwriting a new msg if server and client r async
	msg_box.Text = ""
	
	if not disable then return end -- QoL
	msg_box.Parent.Visible = false
end)

refreshTimer_event.OnClientEvent:Connect(function(t: number)
	timer_box.Text = t
end)