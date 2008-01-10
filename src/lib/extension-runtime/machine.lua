Machine = { }
Machine.__index = Machine

--------------------------------------------------------------------------------
-- Default fields for new machine instances
--------------------------------------------------------------------------------
Machine.template = { 
   fenv          = { },
   state         = 'init',
   states        = { },
   action_code   = { } }

--------------------------------------------------------------------------------
-- Events must be one of these. If not, cause a runtime error.
--------------------------------------------------------------------------------
Machine.legal_events = table.transpose{ 'enter', 'update',  'exit' }

--------------------------------------------------------------------------------
-- Create a new machine isntance. [x] can be nil, or a table whose fields will
-- override the defaults provided by Machine.template.
--------------------------------------------------------------------------------
function Machine:new(x)
   local t = table.deep_copy (self.template)
   if x then table.override(t, x) end
   return setmetatable(t, self)
end

--------------------------------------------------------------------------------
-- [process_msg] expects the machine [self] to be waiting for a message.
-- It gets such a message, does the appropriate state transition and
-- causes the appropriate event-triggered actions to be run.
-- Called by Machine:message() a.k.a. Machine:__call().
--------------------------------------------------------------------------------
local function process_msg (self, msg)

   -- Arg checking.
   assert (type(msg)=='string', "Machine messages must be strings")
   -- When there's a queue, new msgs are queued rather than executed directly.
   self.msg_queue = { }

   ---------------------------------------------------------
   -- Determine the source and destination states.
   ---------------------------------------------------------
   local src_state = self.state
   local dst_state = self.states[src_state].transitions[msg]
   if not dst_state then 
      error("Machine has no transition from state "..src_state..
            " triggered by message "..msg)
   end

   ---------------------------------------------------------
   -- Run the appropriate actions.
   ---------------------------------------------------------
   if src_state==dst_state then 
      local update_actions = self.states[src_state].actions.update
      for idx in ivalues(update_actions) do self.action_code[idx]() end
   else
      local exit_actions  = self.states[src_state].actions.exit
      local enter_actions = self.states[dst_state].actions.enter
      for idx in ivalues(exit_actions)   do self.action_code[idx]() end
      for idx in ivalues(enter_actions)  do self.action_code[idx]() end
   end
   
   ---------------------------------------------------------
   -- Are there more messages queued? if so, process the next
   -- one; if not, allow to process more messages directly
   ---------------------------------------------------------
   local next_msg = table.remove (self.msg_queue)
   if next_msg then return process_msg (self, next_msg) -- tail call
   else self.msg_queue = nil end -- ready for direct msg accept.
end

--------------------------------------------------------------------------------
-- Send or queue a message to the machine, depending on whether it is already
-- processing a message.
-- Also registered as the machine's __call metamethod.
--------------------------------------------------------------------------------
function Machine:message (msg)
   if self.msg_queue then table.insert(self.msg_queue, msg)
   else process_msg (self, msg) end
end
Machine.__call = Machine.message

--------------------------------------------------------------------------------
-- add a new code to execute whenever one of the events is triggered from one
-- of the states. Lists of events and states can be replaced by a raw string
-- when they would have been singletions: ":add_action({x}, {y}, z)" is the
-- same as ":add_action(x, y, z)". 
--------------------------------------------------------------------------------
function Machine:add_action(states, events, code)
   if type(states)~='table' then states={states} end
   if type(events)~='table' then states={events} end
   table.insert(self.action_code, code)
   local action_idx = #self.action_code
   for state in ivalues (states) do
      for event in ivalues (events) do
         if not self.legal_events[event] then 
            error ("Illegal event "..table.tostring(event))
         elseif not self.states[state] then
            error ("No state "..table.tostring(state).." in this machine")
         else
            table.insert(self.states[state].actions, action_idx)
         end
      end
   end
end

--------------------------------------------------------------------------------
-- Add a new state. Causes a warning, but no error if the state already exists.
--------------------------------------------------------------------------------
function Machine:add_state(state_name)
   assert (type(state_name)=='string', "Machine states must be strings")
   if self.states[state_name] then
      printf ("*** Warning: state %q already exists in machine. ***", state_name)
   else
      self.states[state_name] = {
         actions     = { enter = { }, update = { }, exit = { } },
         transitions = { } } 
   end
end

--------------------------------------------------------------------------------
-- Add a new transition, from state src_state_name to dst_state_name, triggered
-- by msg. Cause a warning, but no error if there's already a transition from
-- this source state on this message, and override it.
--------------------------------------------------------------------------------
function Machine:add_transition(src_state_name, msg, dst_state_name)
   -- Check args and states existence.
   assert (type(src_state_name)=='string', "Machine states must be strings")
   assert (type(dst_state_name)=='string', "Machine states must be strings")
   local src_state = self.states[src_state_name]
   local dst_state = self.states[dst_state_name]
   if not src_state then error("No state "..src_state.." in machine") end
   if not dst_state then error("No state "..dst_state.." in machine") end

   if src_state.transitions[msg] then      
      printf ("*** Warning: overriding transition from state %s on msg %s. ***", 
              src_state_name, msg)
   end

   src_state.transitions[msg] = dst_state_name
end
