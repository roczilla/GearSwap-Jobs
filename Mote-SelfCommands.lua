-------------------------------------------------------------------------------------------------------------------
-- General functions for manipulating state values via self-commands.
-- Only handles certain specific states that we've defined, though it
-- allows the user to hook into the cycle command.
-------------------------------------------------------------------------------------------------------------------

local selfCommands = {}


-- The below table maps text commands to our handler functions.
selfCommands.selfCommandMaps = {
	['toggle']=handle_toggle,
	['activate']=handle_activate,
	['cycle']=handle_cycle,
	['set']=handle_set,
	['reset']=handle_reset,
	['update']=handle_update,
	['showset']=handle_show_set,
	['naked']=handle_naked,
	['test']=handle_test}


-- Routing function for general known self_commands.
-- Handles splitting the provided command line up into discrete words, for the other functions to use.
function selfCommands.self_command(commandArgs)
	local commandArgs = commandArgs
	if type(commandArgs) == 'string' then
		commandArgs = split(commandArgs, ' ')
		if #commandArgs == 0 then
			return
		end
	end
	
	-- init a new eventArgs
	local eventArgs = {handled = false}

	-- Allow jobs to override this code
	if job_self_command then
		job_self_command(commandArgs, eventArgs)
	end

	if not eventArgs.handled then
		-- Of the original command message passed in, remove the first word from
		-- the list (it will be used to determine which function to call), and
		-- send the remaining words are parameters for the function.
		local handleCmd = table.remove(commandArgs, 1)
		
		if selfCommands[handleCmd] then
			selfCommands[handleCmd](commandArgs)
		end
	end
end


-- Individual handling of self-commands


-- Handle toggling specific vars that we know of.
-- Valid toggles: Defense, Kiting
-- Returns true if a known toggle was handled.  Returns false if not.
-- User command format: gs c toggle [field]
function selfCommands.handle_toggle(cmdParams)
	if #cmdParams > 0 then
		-- identifier for the field we're toggling
		local toggleField = cmdParams[1]:lower()
		local toggleDesc = ''
		local toggleVal
		
		if toggleField == 'defense' then
			state.Defense.Active = not state.Defense.Active
			toggleVal = state.Defense.Active
			toggleDesc = state.Defense.Type
			if state.Defense.Type == 'Physical' then
				toggleDesc = 'Physical defense ('..state.Defense.PhysicalMode..')'
			else
				toggleDesc = 'Magical defense ('..state.Defense.MagicalMode..')'
			end
		elseif toggleField == 'kite' or toggleField == 'kiting' then
			state.Kiting = not state.Kiting
			toggleVal = state.Kiting
			toggleDesc = 'Kiting'
		elseif toggleField == 'target' then
			state.SelectNPCTargets = not state.SelectNPCTargets
			toggleVal = state.SelectNPCTargets
			toggleDesc = 'NPC targetting'
		else
			if _global.debug_mode then add_to_chat(123,'Unknown toggle field: '..toggleField) end
			return false
		end

		if job_state_change then
			job_state_change(toggleDesc, toggleVal)
		end

		add_to_chat(122,toggleDesc..' is now '..on_off_names[toggleVal]..'.')
	else
		if _global.debug_mode then add_to_chat(123,'--handle_toggle parameter failure: field not specified') end
		return false
	end
	
	handle_update({'auto'})
	return true
end


-- Function to handle turning on particular states, while possibly also setting a mode value.
-- User command format: gs c activate [field]
function selfCommands.handle_activate(cmdParams)
	if #cmdParams > 0 then
		activateState = cmdParams[1]:lower()
		local activateDesc = ''
		
		if activateState == 'physicaldefense' then
			state.Defense.Active = true
			state.Defense.Type = 'Physical'
			activateDesc = 'Physical defense ('..state.Defense.PhysicalMode..')'
		elseif activateState == 'magicaldefense' then
			state.Defense.Active = true
			state.Defense.Type = 'Magical'
			activateDesc = 'Magical defense ('..state.Defense.MagicalMode..')'
		elseif activateState == 'kite' or activateState == 'kiting' then
			state.Kiting = true
			activateDesc = 'Kiting'
		elseif activateState == 'target' then
			state.SelectNPCTargets = true
			activateDesc = 'NPC targetting'
		else
			if _global.debug_mode then add_to_chat(123,'--handle_activate unknown state to activate: '..activateState) end
			return false
		end

		-- Notify the job of the change.
		if job_state_change then
			job_state_change(activateDesc, true)
		end

		-- Display what got changed to the user.
		add_to_chat(122,activateDesc..' is now on.')
	else
		if _global.debug_mode then add_to_chat(123,'--handle_activate parameter failure: field not specified') end
		return false
	end
	
	handle_update({'auto'})
	return true
end


-- Handle cycling through the options for specific vars that we know of.
-- Valid fields: OffenseMode, DefenseMode, WeaponskillMode, IdleMode, RestingMode, CastingMode, PhysicalDefenseMode, MagicalDefenseMode
-- All fields must end in 'Mode'
-- Returns true if a known toggle was handled.  Returns false if not.
-- User command format: gs c cycle [field]
function selfCommands.handle_cycle(cmdParams)
	if #cmdParams > 0 then
		-- identifier for the field we're toggling
		local paramField = cmdParams[1]:lower()

		if paramField:endswith('mode') then
			-- Remove 'mode' from the end of the string
			local modeField = paramField:sub(1,#paramField-4)
			-- Convert WS to Weaponskill
			if modeField == "ws" then
				modeField = "weaponskill"
			end
			-- Capitalize the field (for use on output display)
			modeField = modeField:gsub("%f[%a]%a", string.upper)

			-- Get the options.XXXModes table, and the current state mode for the mode field.
			local modeTable, currentValue = get_mode_table(modeField)

			if not modeTable then
				if _global.debug_mode then add_to_chat(123,'Unknown mode : '..modeField..'.') end
				return false
			end

			-- Get the index of the current mode.  'Normal' or undefined is treated as index 0.
			local invertedTable = invert_table(modeTable)
			local index = 0
			if invertedTable[currentValue] then
				index = invertedTable[currentValue]
			end
			
			-- Increment to the next index in the available modes.
			index = index + 1
			if index > #modeTable then
				index = 1
			end
			
			-- Determine the new mode value based on the index.
			local newModeValue = ''
			if index and modeTable[index] then
				newModeValue = modeTable[index]
			else
				newModeValue = 'Normal'
			end
			
			-- And save that to the appropriate state field.
			set_mode(modeField, newModeValue)
			
			if job_state_change then
				job_state_change(modeField..'Mode', newModeValue)
			end
			
			-- Display what got changed to the user.
			add_to_chat(122,modeField..' mode is now '..newModeValue..'.')
		else
			if _global.debug_mode then add_to_chat(123,'Invalid cycle field (does not end in "mode"): '..paramField) end
			return false
		end
	else
		if _global.debug_mode then add_to_chat(123,'--handle_cycle parameter failure: field not specified') end
		return false
	end
	handle_update({'auto'})
	return true
end

-- Function to set various states to specific values directly.
-- User command format: gs c set [field] [value]
function selfCommands.handle_set(cmdParams)
	if #cmdParams > 1 then
		-- identifier for the field we're setting
		local field = cmdParams[1]
		local lowerField = field:lower()
		local setField = cmdParams[2]
		local fieldDesc = ''
		
		
		-- Check if we're dealing with a boolean
		if T{'on', 'off', 'true', 'false'}:contains(setField) then
			local setValue = T{'on', 'true'}:contains(setField)
			
			if lowerField == 'defense' then
				state.Defense.Active = setValue
				if state.Defense.Type == 'Physical' then
					fieldDesc = 'Physical defense ('..state.Defense.PhysicalMode..')'
				else
					fieldDesc = 'Magical defense ('..state.Defense.MagicalMode..')'
				end
			elseif lowerField == 'kite' or lowerField == 'kiting' then
				state.Kiting = setValue
				fieldDesc = 'Kiting'
			elseif lowerField == 'target' then
				state.SelectNPCTargets = setValue
				fieldDesc = 'NPC targetting'
			else
				if _global.debug_mode then add_to_chat(123,'Unknown field to set: '..field) end
				return false
			end


			-- Notify the job of the change.
			if job_state_change then
				job_state_change(fieldDesc, setValue)
			end
	
			-- Display what got changed to the user.
			add_to_chat(122,fieldDesc..' is now '..on_off_names[setValue]..'.')

		-- Or if we're dealing with a mode setting
		elseif lowerField:endswith('mode') then
			-- Remove 'mode' from the end of the string
			modeField = lowerField:sub(1,#lowerField-4)
			-- Convert WS to Weaponskill
			if modeField == "ws" then
				modeField = "weaponskill"
			end
			-- Capitalize the field (for use on output display)
			modeField = modeField:gsub("%a", string.upper, 1)
			
			-- Get the options.XXXModes table, and the current state mode for the mode field.
			local modeTable, currentValue = get_mode_table(modeField)
			
			if not modeTable or not modeTable[setField] then
				if _global.debug_mode then add_to_chat(123,'Unknown mode value: '..setField..' for '..modeField..' mode.') end
				return false
			end
			
			-- And save that to the appropriate state field.
			set_mode(modeField, setField)

			-- Notify the job script of the change.
			if job_state_change then
				job_state_change(modeField, setField)
			end
			
			-- Display what got changed to the user.
			add_to_chat(122,modeField..' mode is now '..setField..'.')

		-- Or issueing a command where the user may not provide the value
		elseif lowerField == 'distance' then
			if setField then
				local possibleDistance = tonumber(setField)
				if possibleDistance ~= nil then
					state.MaxWeaponskillDistance = possibleDistance
				else
					add_to_chat(123,'Invalid distance value: '..setField)
				end
				
				-- set max weaponskill distance to the current distance the player is from the mob.

				add_to_chat(123,'Using max weaponskill distance is not implemented right now.')
			else
				-- Get current player distance and use that
				add_to_chat(123,'TODO: get player distance.')
			end
		else
			if _global.debug_mode then add_to_chat(123,'Unknown set handling: '..field..' : '..setField) end
			return false
		end
	else
		if _global.debug_mode then add_to_chat(123,'--handle_set parameter failure: insufficient fields') end
		return false
	end
	
	handle_update({'auto'})
	return true
end


-- Function to turn off togglable features, or reset values to their defaults.
-- User command format: gs c reset [field]
function selfCommands.handle_reset(cmdParams)
	if #cmdParams > 0 then
		resetState = cmdParams[1]:lower()
		
		if resetState == 'defense' then
			state.Defense.Active = false
			add_to_chat(122,state.Defense.Type..' defense is now off.')
		elseif resetState == 'kite' or resetState == 'kiting' then
			state.Kiting = false
			add_to_chat(122,'Kiting is now off.')
		elseif resetState == 'melee' then
			state.OffenseMode = options.OffenseModes[1]
			state.DefenseMode = options.DefenseModes[1]
			add_to_chat(122,'Melee has been reset to defaults.')
		elseif resetState == 'casting' then
			state.CastingMode = options.CastingModes[1]
			add_to_chat(122,'Casting has been reset to default.')
		elseif resetState == 'distance' then
			state.MaxWeaponskillDistance = 0
			add_to_chat(122,'Max weaponskill distance limitations have been removed.')
		elseif resetState == 'target' then
			state.SelectNPCTargets = false
			state.PCTargetMode = 'default'
			add_to_chat(122,'Adjusting target selection has been turned off.')
		elseif resetState == 'all' then
			state.Defense.Active = false
			state.Defense.PhysicalMode = options.PhysicalDefenseModes[1]
			state.Defense.MagicalMode = options.MagicalDefenseModes[1]
			state.Kiting = false
			state.OffenseMode = options.OffenseModes[1]
			state.DefenseMode = options.DefenseModes[1]
			state.CastingMode = options.CastingModes[1]
			state.IdleMode = options.IdleModes[1]
			state.RestingMode = options.RestingModes[1]
			state.MaxWeaponskillDistance = 0
			state.SelectNPCTargets = false
			state.PCTargetMode = 'default'
			showSet = nil
			add_to_chat(122,'Everything has been reset to defaults.')
		else
			if _global.debug_mode then add_to_chat(123,'--handle_reset unknown state to reset: '..resetState) end
			return false
		end
		

		if job_state_change then
			job_state_change('Reset', resetState)
		end
	else
		if _global.debug_mode then add_to_chat(123,'--handle_activate parameter failure: field not specified') end
		return false
	end
	
	handle_update({'auto'})
	return true
end


-- User command format: gs c update [option]
-- Where [option] can be 'user' to display current state.
-- Otherwise, generally refreshes current gear used.
function selfCommands.handle_update(cmdParams)
	-- init a new eventArgs
	local eventArgs = {handled = false}

	-- Allow jobs to override this code
	if job_update then
		job_update(cmdParams, eventArgs)
	end

	if not eventArgs.handled then
		handle_equipping_gear(player.status)
	end
	
	if cmdParams[1] == 'user' then
		display_current_state()
	end
end


-- showset: equip the current TP set for examination.
function selfCommands.handle_show_set(cmdParams)
	-- If no extra parameters, or 'tp' as a parameter, show the current TP set.
	if #cmdParams == 0 or cmdParams[1]:lower() == 'tp' then
		local meleeGroups = ''
		if #classes.CustomMeleeGroups > 0 then
			meleeGroups = ' ['
			for i = 1,#classes.CustomMeleeGroups do
				meleeGroups = meleeGroups..classes.CustomMeleeGroups[i]
			end
			meleeGroups = meleeGroups..']'
		end
		
		add_to_chat(122,'Showing current TP set: ['..state.OffenseMode..'/'..state.DefenseMode..']'..meleeGroups)
		equip(get_current_melee_set())
	-- If given a param of 'precast', block equipping midcast/aftercast sets
	elseif cmdParams[1]:lower() == 'precast' then
		showSet = 'precast'
		add_to_chat(122,'GearSwap will now only equip up to precast gear for spells/actions.')
	-- If given a param of 'midcast', block equipping aftercast sets
	elseif cmdParams[1]:lower() == 'midcast' then
		showSet = 'midcast'
		add_to_chat(122,'GearSwap will now only equip up to midcast gear for spells.')
	-- With a parameter of 'off', turn off showset functionality.
	elseif cmdParams[1]:lower() == 'off' then
		showSet = nil
		add_to_chat(122,'Show Sets is turned off.')
	end
end

-- Minor variation on the GearSwap "gs equip naked" command, that ensures that
-- all slots are enabled before removing gear.
-- Command: "gs c naked"
function selfCommands.handle_naked(cmdParams)
	enable('main','sub','range','ammo','head','neck','lear','rear','body','hands','lring','rring','back','waist','legs','feet')
	equip(sets.naked)
end


------  Utility functions to support self commands. ------

-- Function to get the options.XXXModes table and the corresponding state value to make given state field.
function selfCommands.get_mode_table(field)
	local modeTable = {}
	local currentValue = ''

	if field == 'Offense' then
		modeTable = options.OffenseModes
		currentValue = state.OffenseMode
	elseif field == 'Defense' then
		modeTable = options.DefenseModes
		currentValue = state.DefenseMode
	elseif field == 'Casting' then
		modeTable = options.CastingModes
		currentValue = state.CastingMode
	elseif field == 'Weaponskill' then
		modeTable = options.WeaponskillModes
		currentValue = state.WeaponskillMode
	elseif field == 'Idle' then
		modeTable = options.IdleModes
		currentValue = state.IdleMode
	elseif field == 'Resting' then
		modeTable = options.RestingModes
		currentValue = state.RestingMode
	elseif field == 'Physicaldefense' then
		modeTable = options.PhysicalDefenseModes
		currentValue = state.Defense.PhysicalMode
	elseif field == 'Magicaldefense' then
		modeTable = options.MagicalDefenseModes
		currentValue = state.Defense.MagicalMode
	elseif field == 'Target' then
		modeTable = options.TargetModes
		currentValue = state.PCTargetMode
	elseif job_get_mode_table then
		-- Allow job scripts to expand the mode table lists
		modeTable, currentValue, err = job_get_mode_table(field)
		if err then
			if _global.debug_mode then add_to_chat(123,'Attempt to query unknown state field: '..field) end
			return nil
		end
	else
		if _global.debug_mode then add_to_chat(123,'Attempt to query unknown state field: '..field) end
		return nil
	end
	
	return modeTable, currentValue
end

-- Function to set the appropriate state value for the specified field.
function selfCommands.set_mode(field, val)
	if field == 'Offense' then
		state.OffenseMode = val
	elseif field == 'Defense' then
		state.DefenseMode = val
	elseif field == 'Casting' then
		state.CastingMode = val
	elseif field == 'Weaponskill' then
		state.WeaponskillMode = val
	elseif field == 'Idle' then
		state.IdleMode = val
	elseif field == 'Resting' then
		state.RestingMode = val
	elseif field == 'Physicaldefense' then
		state.Defense.PhysicalMode = val
	elseif field == 'Magicaldefense' then
		state.Defense.MagicalMode = val
	elseif field == 'Target' then
		state.PCTargetMode = val
	elseif job_set_mode then
		-- Allow job scripts to expand the mode table lists
		if not job_set_mode(field, val) then
			if _global.debug_mode then add_to_chat(123,'Attempt to set unknown state field: '..field) end
		end
	else
		if _global.debug_mode then add_to_chat(123,'Attempt to set unknown state field: '..field) end
	end
end


-- Function to display the current relevant user state when doing an update.
-- Uses display_current_job_state instead if that is defined in the job lua.
function selfCommands.display_current_state()
	local eventArgs = {handled = false}
	if display_current_job_state then
		display_current_job_state(eventArgs)
	end
	
	if not eventArgs.handled then
		local defenseString = ''
		if state.Defense.Active then
			local defMode = state.Defense.PhysicalMode
			if state.Defense.Type == 'Magical' then
				defMode = state.Defense.MagicalMode
			end
	
			defenseString = 'Defense: '..state.Defense.Type..' '..defMode..', '
		end
		
		local pcTarget = ''
		if state.PCTargetMode ~= 'default' then
			pcTarget = ', Target PC: '..state.PCTargetMode
		end

		local npcTarget = ''
		if state.SelectNPCTargets then
			pcTarget = ', Target NPCs'
		end
		

		add_to_chat(122,'Melee: '..state.OffenseMode..'/'..state.DefenseMode..', WS: '..state.WeaponskillMode..', '..defenseString..
			'Kiting: '..on_off_names[state.Kiting]..pcTarget..npcTarget)
	end
	
	if showSet then
		add_to_chat(122,'Show Sets it currently showing ['..showSet..'] sets.  Use "//gs c showset off" to turn it off.')
	end
end


return selfCommands