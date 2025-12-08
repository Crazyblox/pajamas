--!native
require( `../plugin/vm` ).Init( script )
local ClonedModule = script.Parent.Parent.init[ script:GetAttribute("Init") or "main" ]:Clone()
ClonedModule.Parent = script.Parent
require(ClonedModule)()
