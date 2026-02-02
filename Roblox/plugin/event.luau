--!strict
--!native

--[[
	Pajamas plugin - event:
	
	A simple event module that provides an agnostic interface
	for a pajamas project to hook up to a serial or parallel
	loop event determined by the host runtime.
]]

export type Hook = {
	Connect: (Hook, boolean?) -> (),
	Disconnect: (Hook) -> ()
}

local RunService = game:GetService("RunService")

local Events = {}

Events.Loop =
	if game.Players.LocalPlayer then
		RunService.PreRender
	else
		RunService.PreSimulation

return function( Function, EventName: string )
	assert( Events[EventName], `Event named '{EventName}' does not exist` )
	local Signal = Events[EventName]
	local Connection: RBXScriptConnection
	local Hook = {}
	function Hook:Connect( Parallel: boolean? )
		if Parallel == true then
			Connection = Signal:ConnectParallel(Function)
		else
			Connection = Signal:Connect(Function)
		end
	end
	function Hook:Disconnect()
		if Connection.Connected then
			Connection:Disconnect()
		end
	end
	table.freeze( Hook )
	return Hook
end
