--!strict
--!native

--[[
	Pajamas plugin - display:
	
	This module is responsible for providing the pajamas host runtime
	a means to display video content, and provides the interface for
	a pajamas project to setting up a video out for displaying video content.
	
	--[=[ MODULE : API ]=]--
	
	--> Module.SanitiseResolution( Intent: vector): vector
	Allows a pajamas project to sanitise the intended resolution
	by passing the value to the host runtime, taking care of instances
	when the intended resolution is either too small or too large for the
	runtime to be able to provide.
	
	--> Module.New( Settings: { [string]: any } ): Display
	Creates and returns a display in which a pajamas project can
	write to the framebuffer, submit the buffer for presenting,
	and attributing the settings which were initially provided in
	creating the display.
	
	--[=[ DISPLAY : API ]=]--
	
	--> Display.Settings: { [string]: any }
	The settings which were provided during creation of the display.
	
	--> Display.Framebuffer: buffer
	Stores the display's framebuffer content.
	The storage format is RGBAu8.
	
	--> Display.Present()
	Submits the current Display.Framebuffer to be displayed by
	the host runtime.
]]

local Display = {}

function Display.SanitiseResolution(Intent: vector): vector
	local ReturnRes: vector = vector.clamp(
		Intent,
		vector.create(1, 1),
		vector.create(1024, 1024)
	) // 1
	if ReturnRes ~= Intent then
		print( `plugin - display: Intended resolution ({Intent.x}, {Intent.y}) was sanitised at ({ReturnRes.x}, {ReturnRes.y})`)
	end
	return ReturnRes
end

function Display.New( Settings: { [string]: any } )
	local Aspect_X: number = Settings.Display_Res.x / Settings.Display_Res.y
	--Roblox: Create objects
	local LocalPlayer = game:GetService("Players").LocalPlayer
	local ScreenGui = Instance.new("ScreenGui") :: any
	local ImagePresent = Instance.new("ImageLabel") :: any
	local EditableImage: EditableImage = game:GetService("AssetService"):CreateEditableImage( { Size = Vector2.new( Settings.Display_Res.x, Settings.Display_Res.y ) } )
	
	-- ScreenGui
	for Prop: any, Value: any in {
		Name = "RenderGui",
		ClipToDeviceSafeArea = true,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		IgnoreGuiInset = true,
		AutoLocalize = false,
		DisplayOrder = -999,
		ResetOnSpawn = false,
		Archivable = false,
		Parent = if LocalPlayer then LocalPlayer.PlayerGui else game:GetService("StarterGui")
		} :: {[string]: any} do ScreenGui[ Prop ] = Value end
	ScreenGui = ScreenGui :: ScreenGui
	-- EditableImage
	assert( EditableImage, `EditableImage not created` )

	-- ImageLabel
	for Prop: any, Value: any in {
		Name = "Present",
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Size = UDim2.new(Aspect_X, 0, 1, 0),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 1,
		ZIndex = -999,
		Interactable = false,
		Active = false,
		Archivable = false,
		ImageContent = Content.fromObject( EditableImage ) :: Content,
		ResampleMode =
			if Settings.Display_Resample == "Bilinear" then Enum.ResamplerMode.Default
			elseif Settings.Display_Resample == "Nearest" then Enum.ResamplerMode.Pixelated
			else Enum.ResamplerMode.Default,
		Parent = ScreenGui
		} :: {[string]: any} do ImagePresent[ Prop ] = Value end
	ImagePresent = ImagePresent :: ImageLabel -- Exit Typecast
	
	-- This is what we will be returning to whoever calls to initialize the display
	local Expose = {}
	Expose.Settings = Settings
	Expose.Framebuffer = buffer.create( Settings.Display_Res.x * Settings.Display_Res.y * 4 )
	for c = 0, buffer.len( Expose.Framebuffer ) - 1, 4 do
		buffer.writeu32( Expose.Framebuffer, c, 0xFF000000 )
	end
	Expose.Present = function( self )
		EditableImage:WritePixelsBuffer(
			Vector2.zero,
			Vector2.new(
				Settings.Display_Res.x,
				Settings.Display_Res.y
			), Expose.Framebuffer
		)
	end
	return table.freeze( Expose )
end

return table.freeze( Display )
