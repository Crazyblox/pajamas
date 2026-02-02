--!strict
--!native

--[[
	Pajamas Runtime: Roblox
	
	This module is responsible for handling the Pajamas runtime.
	
		This system holds projects made for pajamas, host wrapper
	scripts for either a server or client runcontext, and plugin
	modules which act as the interface for any given project,
	enabling the ability to port Luau projects made with Pajamas
	to other runtimes where plugin support is also provided.
]]

type Pajamas = {
	init: Folder,
	lib: Folder,
	plugin: Folder,
	[".pajamasrc"]: ModuleScript
}

type pajamasrc = {
	schema: string,
	project: {
		name: string,
		author: string,
		version: string,
		launch_note: string,
	},
	runtime: {
		default: { run: boolean },
		roblox: { run_server: boolean, run_client: boolean }
	},
	plugin: {
		[string]: { include: boolean }
	}
}

-- Init
print("Starting Pajamas...")
local RunService = game:GetService("RunService")
local IsClient: boolean = RunService:IsClient()

-- Init assertions
assert( script:FindFirstChild("plugin"), "Pajamas - Can't initialise, missing 'plugin' directory" )
assert( script:FindFirstChild("wrapper"), "Pajamas - Can't initialise, missing 'wrapper' directory")
assert( script.wrapper:FindFirstChild("client"), "Pajamas - Can't initialise, missing 'client' script in wrapper directory" )
assert( script.wrapper:FindFirstChild("server"), "Pajamas - Can't initialise, missing 'server' script in wrapper directory" )

-- Script-based copies of wrapper scripts.
local Wrappers = {}
Wrappers.Server = script.wrapper.server:Clone()
Wrappers.Client = script.wrapper.client:Clone()
table.freeze( Wrappers )

-- Keeps track of running projects in the given runcontext
local RunningProjects = {}

-- Function that is called after ValidateProject() has confirmed we are good to launch.
local function StartProject( Project: Instance, pajamasrc: pajamasrc, LaunchParams: {[number]: any} ): boolean
	local Project = 		Project
	local ProjectParent = 	Project.Parent
	
	-- Insert project directory to list of running projects so duplicates can't be made accidentally.
	table.insert( RunningProjects, Project )

	-- Let the user know we are starting up a project...
	print( `Pajamas Init - { pajamasrc.project.name } by { pajamasrc.project.author } [Version { pajamasrc.project.version }]` )
	
	-- Create a copy of the host wrapper script that will begin running the project.
	local Wrapper: Script = 
		if IsClient then
			Wrappers.Client:Clone()
		else
			Wrappers.Server:Clone()
	
	-- Pass launch parameters to wrapper script and configure before enabling.
	for k,v in LaunchParams do
		Wrapper:SetAttribute(`Param_{k}`, tostring( v ) )
	end
	
	-- Create Actor instance and insert wrapper as child to enable serial/parallel capabilities.
	local Process = Instance.new( "Actor" )
	Process.Name = "Process_Main"
	Wrapper.Parent = Process
	Process.Parent = Project
	
	-- Output project name and launch note before running.
	print( `Pajamas: { pajamasrc.project.name } - { pajamasrc.project.launch_note }`)
	
	-- Run the project!
	Wrapper.Enabled = true
	
	-- Success!
	return true 
end

-- Performs checks if project is valid and can be initialised in the given runcontext.
local function ValidateProject( Project: Instance, LaunchParams: {[number]: any} ): boolean
	
	-- Check if the provided project contains a '.pajamasrc' module
	local pajamasrc = ( Project:FindFirstChild(".pajamasrc") :: any )
	if not ( pajamasrc and pajamasrc:IsA("ModuleScript") ) then
		warn( `Pajamas - '{ Project:GetFullName() }' doesn't contain .pajamasrc module, cancelling` )
		return false
	end
	
	-- Require the .pajamasrc module
	pajamasrc = require(pajamasrc) :: pajamasrc
	
	-- Check if the project is already running in this runcontext.
	if table.find( RunningProjects, Project ) then
		warn( `Pajamas - '{ Project:GetFullName() }' is already initialised, cancelling` )
		return false
	end
	
	-- Check if the .pajamasrc is configured to allow the project to run in this runcontext.
	local Server_On: boolean = pajamasrc.runtime.roblox.run_server
	local Client_On: boolean = pajamasrc.runtime.roblox.run_client
	if ( IsClient and Client_On ~= true ) or ( ( not IsClient ) and Server_On ~= true ) then
		warn( `Pajamas - '{Project:GetFullName()}' .pajamasrc has current runcontext disabled, cancelling` )
		return false
	end
		
	-- Checks passed; begin starting up the project and return the success bool result.
	return StartProject( Project, pajamasrc, LaunchParams )
end

-- Coerces a string into: boolean, number, string, nil
-- Used as all inputs to Pajamas are strings for compatibility with CLI.
local function parse( str: string ): any
	if str == "true" or str == "false" then
		return str == "true"
	end
	return tonumber(str) or str
end

-- Module function: All parameters are provided as a string type.
return function(...): boolean
	local Params: {[number]: any} = {...}
	for i = 1, #Params do
		Params[i] = parse( Params[i] )
	end
	local Name: string = Params[1]
	assert( Name, `Pajamas - No launch parameters provided. Provide project name and relevant launch parameters` )
	table.remove( Params, 1 )
	print( `Looking for '{ Name }'...` )
	local Project = script:FindFirstChild( Name )
	assert( Project, `Pajamas - Directory named '{ Name }' does not exist` )
	return ValidateProject( Project, Params )
end
