--!strict
--!native

--[[
	Pajamas plugin - input:
	
	A simple keyboard input module providing an agnostic interface
	for a pajamas project to react to keyboard user intent.
	
	Note:
	No method for disconnection keyboard input yet.
	It is currently assumed that a pajamas project runs for as
	long as the host runtime is also running.
]]

local Input = {}
local UIS = game:GetService("UserInputService")

function Input:KeyDown( Listen_KeyCode: string, func )
	UIS.InputBegan:Connect(function( input: InputObject )
		if ( string.split( tostring( input.KeyCode ), `.` )[3] or `` ) == Listen_KeyCode then
			func()
		end
	end)
end

function Input:KeyUp( Listen_KeyCode: string, func )
	UIS.InputEnded:Connect(function( input: InputObject )
		if ( string.split( tostring( input.KeyCode ), `.` )[3] or `` ) == Listen_KeyCode then
			func()
		end
	end)
end

return Input
