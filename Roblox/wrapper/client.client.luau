--!strict
--!native
-- Disable
local iswrapper = script.Parent:FindFirstChild("iswrapper")
if iswrapper then
	if require(iswrapper).Disable == true then
		script.Disabled = true
		return
	end
end
-- Wrapper
local Attributes: {[string]: any} = script:GetAttributes()
local Params: {[number]: any} = {}
local i: number = 1
for _, t in Attributes do
	Params[i] = Attributes[`Param_{i}`]
	i += 1
end
table.insert( Params, 1, script )
require(`../`)( table.unpack(Params) )
