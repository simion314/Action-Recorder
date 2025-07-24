AR.Pipeline = { 
	Cache = { }
}

function AR.Pipeline:Start(Callback, ID, Delay, ...)
	self.Cache[ID] = {
		Callback = Callback,
		Delay = Delay,
		Time = CurTime(),
		Arguments = {...}
	}
end

function AR.Pipeline:Update(Callback, ID, Delay, Time, Arguments)
	local Pipe = self.Cache[ID]
	
	if (not Pipe) then
		return
	end
	
	Pipe.Callback = Callback or Pipe.Callback
	Pipe.Delay = Delay or Pipe.Delay
	Pipe.Time = Time or Pipe.Time
	
	-- Isn't super clean but you'll have to pass arguments as a 
	-- table when updating.
	Pipe.Arguments = Arguments and unpack(Arguments) or Pipe.Arguments
	
	self.Cache[ID] = Pipe
end

function AR.Pipeline:Cancel(Callback, ID)
	self.Cache[ID] = nil
end

function AR.Pipeline:Hook()
	local Time = CurTime()
	
	for k, Pipe in pairs(self.Cache) do 
		if (Time >= Pipe.Time) then
			if (Pipe.Callback(unpack(Pipe.Arguments))) then
				self.Cache[k] = nil
				continue
			end
			
			Pipe.Time = Time + Pipe.Delay
		end
	end
end

hook.Add("Think", "AR-Pipeline", function()
	-- Technically you should use a custom hooking library to
	-- handle calling metatable functions (:).
	AR.Pipeline:Hook()
end)