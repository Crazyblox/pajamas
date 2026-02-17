--!strict
--!native

--[[
	Pajamas plugin - task:
	
	Takes advantage of the Luau runtime's own task library.
	This plugin also considers if sync/desync support is present.
]]
assert( task, "This Luau runtime does not provide 'task'" )

local synchronize = task.synchronize or function() print("Warning: Missing sync/desync support in task") end
local function sync_func(): boolean
	synchronize()
	return true
end

local function is_synchronized(): boolean
	local sync_thread: thread = 			coroutine.create(sync_func)
	local _: boolean, sync_bool: boolean? = coroutine.resume(sync_thread)
	return									(not not sync_bool)
end

return table.freeze {
	cancel =		task.cancel,
	spawn =			task.spawn,
	defer = 		task.defer,
	wait = 			task.wait,
	synchronize = 	synchronize,
	desynchronize = task.desynchronize or synchronize,
	checksync = 	is_synchronized,
	checkdesync =	function(): boolean return not is_synchronized() end,
}
