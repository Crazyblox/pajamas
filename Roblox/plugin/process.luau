--!strict
--!native

--[[
	Pajamas plugin - process:
	
	This module is responsible for spawning new processes and
	handling communication between individual processes within
	a given pajamas project.
	
	--[=[ MODULE : API ]=]--
	
	--> Module.New( NameOfProcess: string, LaunchParams: {[number]: any} ): Process
	Creates a new process with a provided set of launch parameters.
	
	--> Module.GetProcessFromName( Name: string ): Process
	Searches for and returns the process with either the given name,
	or with the fallback 'Process_Main' if the searched process couldn't
	be found.
	
	--> Module.RequireShared( Name: string, Size: number ): SharedData
	Retrieves a SharedData with the given name if present, or creates a
	new SharedData with the given size argument in bytes if no prior entry
	exists with the given name.
	
	--> Module.Launch_Parse(
		Input: {[number]: any},
		rc_Params: {[number]: {name: string, input: string?, default: any?}}
	):	(LaunchParams, {[string]: any})
	Called by a given projects init module to sanitise and provide default
	parameters if specified via the .pajamasrc module.
	A sane list of launch parameters is returned for the init module
	to then call Process.Launch_Init().
	
	--> Module.Launch_Init = function( self: Script )
	Called by the project's init module to set up some core process
	variables that will be referred to for the duration of the life of
	the process.
	
	--> Module.ProjectDir
	The root directory of the project.
	
	--> Module.MainProcess
	Refers to the first process that was started up by pajamas
	during initialisation.
	
	--> Module.Process
	Refers to the current process.
	
	--[=[ SHAREDDATA : API ]=]--
	
	--> SharedData.Shared_Table: SharedTable
	Roblox-specific implementation of SharedData.
	Not intended for use by the end-user.
	
	--> SharedData.Buffer: buffer
	The raw buffer data associated with the SharedData.
	Can be accessed the same way as every other buffer in Luau.
		
	--> SharedData:SyncFrom( self ): self
	Pulls the global copy of the SharedData.Buffer and
	overwrites the processes local copy of SharedData.Buffer.
	
	--> SharedData:SyncTo( self ): self
	Overwrites the global copy of SharedData.Buffer with
	this processes local copy of SharedData.Buffer.
]]

export type LaunchParams = {
	[string]: 		any,
	i:				{[number]: any},
	read Path: 		string,
	read X: 		number,
	read Y: 		number,
	read Threads: 	number,
	read Resample: 	string,
	RenderNum:		number?
}

export type Process = {
	read Name:			string,
	read Instance:		Actor, -- Roblox-specific, not for the end-user
	read Run:			( Process ) -> (),					
	read Send:			( Process, ...any ) -> (),
	read Bind:			( Process, string, ...any ) -> (),
	read BindParallel:	( Process, string, ...any ) -> ()
}

-- Global buffer data accessible by all Processes
export type SharedData = {
	read Shared_Table: SharedTable,				-- SharedTable used to share buffer data across Processes
	read Buffer: buffer,						-- Shareable buffer data via :SyncTo() & :SyncFrom()
	read SyncFrom: (SharedData) -> SharedData,	-- Reads Shared_Table[1], converting to Buffer
	read SyncTo: (SharedData) -> SharedData		-- Writes Buffer to Shared_Table[1]
}

local Process = {}
--type ProcessModule = {
--	read Init: (Script) -> (),
--	read ProjectDir: Folder,
--	read MainProcess: Process,
--	read Process: Process
--}

local RunService = game:GetService("RunService")
Process.ProjectDir = ( script.Parent :: any ) --Placeholder until Process.init is run
local Process_List: { Process } = {}

-- Wraps a given Actor inside of a 'Process' object
local function IndexProcess( Actor: Actor ): Process
	-- If it exists, return the Process from the plugin's internal list of Processes
	for i = 1, #Process_List do
		if Process_List[ i ].Instance == Actor then
			return Process_List[ i ]
		end 
	end
	local Wrapper: Script? = Actor:FindFirstChildWhichIsA("Script")
	assert( Wrapper, `Wrapper does not exist for { Actor.Name }`)
	local MakeProcess = {}
	function MakeProcess:Send( ... ) Actor:SendMessage( ... ) end
	function MakeProcess:Run() Wrapper.Disabled = false end
	function MakeProcess:Bind( Topic: string, Function ) Actor:BindToMessage( Topic, Function ) end
	function MakeProcess:BindParallel( Topic: string, Function ) Actor:BindToMessageParallel( Topic, Function ) end
	MakeProcess.Instance = Actor
	MakeProcess.Name = Actor.Name
	table.freeze( MakeProcess )
	Process_List[ #Process_List + 1 ] = MakeProcess
	return MakeProcess
end

-- Spin up a brand new Process instance
function Process.New( NameOfProcess: string, LaunchParams: {[number]: any} ): Process
	-- Actor
	local Actor = Instance.new("Actor")
	Actor.Name = NameOfProcess
	-- Set launch parameters to send to wrapper
	local Wrapper =
		if RunService:IsServer() then
			script.Parent.Parent.wrapper.server:Clone()
		else
			script.Parent.Parent.wrapper.client:Clone()
	Wrapper.Disabled = true
	-- Roblox: Add parameters onto already-provided launch parameters
	for i = 1, #LaunchParams do
		Wrapper:SetAttribute( `Param_{i}`, tostring( LaunchParams[i] ) )
	end
	-- Set up methods
	Wrapper.Parent = Actor
	local NewProcess = IndexProcess( Actor )
	Actor.Parent = Process.ProjectDir
	-- Return
	return NewProcess
end

-- Gives us the ability to return a 'Process'
-- Process_Main is provided as fallback
function Process.GetProcessFromName( Name: string ): Process
	for _, Process: Process in Process_List do
		if Process.Name == Name then
			return Process
		end
	end
	warn( `Couldn't find Process with name '{ Name }'. Providing Process_Main` )
	for _, Process: Process in Process_List do
		if Process.Name == "Process_Main" then
			return Process
		end
	end
	error("Process_Main not found; this project cannot run without Process_Main!")
end

local RBX_SharedTables = game:GetService( "SharedTableRegistry" )
local SharedData_List = {} :: { [string]: SharedData }
function Process.RequireShared( Name: string, Size: number? ): SharedData
	-- Is SharedData already required in this Process?
	if SharedData_List[ Name ] then return SharedData_List[ Name ] end
	-- Returns existing or new/empty SharedTable
	local Requiring_SharedTable: SharedTable = RBX_SharedTables:GetSharedTable( Name )
	local Buffer: buffer
	-- Checks if SharedTable already existed or not
	local HasEntry = Requiring_SharedTable[1]
	if HasEntry then
		Buffer = buffer.fromstring( HasEntry )
	else
		assert( type( Size ) == "number", "Argument `Size` must be a number" )
		Buffer = buffer.create( Size )
	end
	-- Create SharedData
	local SharedData: SharedData = {
		Shared_Table = Requiring_SharedTable,
		Buffer = Buffer,
		-- Read from RBX SharedTable[1]
		SyncFrom = function( self: SharedData ): SharedData
			SharedTable.update(
				self.Shared_Table, 1,
				function( value: string ): string
					buffer.copy( self.Buffer, 0, buffer.fromstring(value) )
					return value
				end
			)
			return self
		end,
		-- Write to RBX SharedTable[1]
		SyncTo = function( self: SharedData ): SharedData
			SharedTable.update(
				self.Shared_Table, 1,
				function( value: string ): string
					return buffer.tostring(self.Buffer)
				end
			)
			return self
		end
	}
	-- Register RBX SharedTable
	if not HasEntry then
		RBX_SharedTables:SetSharedTable( Name, Requiring_SharedTable )
		SharedData:SyncTo()
	end
	-- Index in SharedData_List for future Process.RequireShared calls of the same name.
	SharedData_List[ Name ] = SharedData
	return table.freeze( SharedData )
end

-- Coerces a string into: boolean, number, string, nil
local function parse( str: string ): any
	if str == "true" or str == "false" then
		return str == "true"
	end
	return tonumber(str) or str
end

Process.Launch_Parse = function(
	Input: {[number]: any},
	rc_Params: {[number]: {name: string, input: string?, default: any?}}
):	(LaunchParams, {[string]: any})
	local Misc = { Host = Input[1] }
	table.remove(Input, 1)
	local Params = {} :: LaunchParams
	Params.i = Input -- Preserved
	for i, rc_p in rc_Params do
		-- Convert string inputs to correct output
		local val = parse( Input[i] )
		if not val then
			print(`Assigning launch default for {rc_p.name}`)
			val = rc_p.default
			Input[i] = val
		end
		local input = rc_p.input or type(val)
		assert( type(val) == input, `Launch param {i}-{rc_p.name}: Expected '{input}', was given '{ type( val ) }'` )
		Params[rc_p.name] = val
	end	
	return Params, Misc
end

-- Called by a pajamas project's init module before passing on to other modules.
local Process_IsInit: boolean = false
Process.Launch_Init = function( self: Script )
	if Process_IsInit then return end
	assert( self and self.Parent and self.Parent.Parent ) -- For the typechecker.
	Process.ProjectDir = self.Parent.Parent
	-- RBX: Listens to new Process's added in the Roblox datamodel as a child of the project directory 
	Process.ProjectDir.ChildAdded:ConnectParallel(function( New: Instance )
		if New:IsA("Actor") then IndexProcess( New ) end
	end)
	-- RBX: Adds all already-existing Processes in the project directory to the list of Processes.
	for _, c: Instance in Process.ProjectDir:GetChildren() do
		if c:IsA("Actor") then IndexProcess( c ) end
	end
	Process.MainProcess = Process.GetProcessFromName( "Process_Main" )
	Process.Process = IndexProcess( self:GetActor() )
	table.freeze( Process )
	Process_IsInit = true
end

return Process
