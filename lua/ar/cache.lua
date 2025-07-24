local Player = FindMetaTable("Player")

function Player:Set(Key, Value)
	self.AR = self.AR or { }
	
	self.AR[Key] = Value
end

function Player:Remove(Key)
	return self:Set(Key, nil)
end

function Player:Grab(Key)
	return self.AR and self.AR[Key]
end