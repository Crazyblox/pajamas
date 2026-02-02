A lightweight project spec that enables Luau projects to be created in a platform-agnostic manner.

By reducing the dependency of a project into a set of Luau plugin modules, the burden of porting Luau code to be compatible from one environment to the next is massively reduced in scope, as only the plugin modules would need to be ported, rather than a given codebase.

The primary example of this being applied in practice is the 'penumbra' Luau graphics rendering pipeline.

Link: https://github.com/Crazyblox/Penumbra

# Project directory layout:
	 ┣━ .pajamasrc.luau
	 ┗━ init.luau
	 
# Explained:
### .pajamasrc.luau:
The Pajamas runtime starts validating a Pajamas project by looking for this file.

It contains project details, launch parameter options, and specific runtime configuration.



### Starting a pajamas project:
A project must be sat directly as a child of `pajamas/`, maintaining a siblance with the `/plugin` directory in order to be able to function as intended and interface appropriately within the host's environment.

When pajamas is told to initalise a project, it will first look for the `/.pajamasrc.luau` module, which contains information relevant to how the project should be run:
Example:
```luau
return {
	schema = "0.0.2",
	project = {
		name = "Penumbra",
		author = "Crazyblox",
		version = "26.04.0",
		launch_note = "Thanks for using Penumbra! Contributions & reports are welcome at https://github.com/Crazyblox/Penumbra"
	},
	runtime = {
		default =	{ run = true },
		roblox =	{ run_server = false, run_client = true }
	},
	plugin = {
		-- Possibly redundant for runtime purposes.
		["display"] =	{ include = true },
		["event"] =		{ include = true },
		["input"] =		{ include = true },
		["task"] =		{ include = true },
		["vm"] =		{ include = true }
	},
	params = {
		-- 'input' is used to sanitise & assert type input.
		-- 'input' value is derived from 'default' if not declared.
		-- 'default' value is used as a fallback if no launch parameter is supplied.
		[1] = { name = "Path",		input = "string" },
		[2] = { name = "X", 		default = 320 },
		[3] = { name = "Y", 		default = 240 },
		[4] = { name = "Threads", 	default = 1 },
		[5] = { name = "Resample", 	default = true },
		[6] = { name = "RenderNum", default = -1 }
	}
}
```

Once `/.pajamasrc.luau` is validated, it will then look to run the project's `/init.luau` module. At that point, pajamas has done its job, and the given project would begin to run.

Any time a new process is spawned, including on initial project startup and when a new process is created via `/plugin/process.luau`, `/init.luau` will be passed and called in order to intialise the new process.

Pajamas does NOT need to be initialised multiple times via new processes. Only 1 process should be responsible for communicating with and handling pajamas itself.

### The point of plugins:
Plugin modules are intended to handle interfacing with the Luau runtime the project is running on, enabling all Luau code within a given project to not depend on runtime instrinsics.

The goal is that, by deferring requirements for running on different platforms down to a specific set of plugin modules, developers would find themselves writing code where their logic is wholly separate from the environment they developed it in, allowing for more portability and giving Luau more opportunity for growth.

For example, Roblox/Lune's 'task' standard library would be returned under a simple plugin module, ensuring Luau purity for init and library modules and allowing other runtimes to provide their own version of 'task' when a standard library isn't provided.
