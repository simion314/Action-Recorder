AR.Config = { 
	Cache = { }
}

function AR.Config:Parser(Data)
	for k, Object in ipairs(Data) do 
		if (not Object.noPrefix) then
			Object.Name = "action_" .. Object.Name 
		end
	
		if (SERVER) then
			self.Cache[Object.Name] = CreateConVar(
				Object.Name, 
				Object.Value, 
				Object.Flags, 
				Object.Help, 
				Object.Min, 
				Object.Max
			)
		else
			self.Cache[Object.Name] = CreateClientConVar(
				Object.Name, 
				Object.Value, 
				Object.Save, 
				Object.Shared, 
				Object.Help, 
				Object.Min, 
				Object.Max
			)
		end
		
		AR:Out("Created ConVar \"%s\"!", Object.Name)
	end
end

function AR.Config:Get(Name)
	return self.Cache[Name]
end

AR.Config:Parser(include("config/clientside.lua"))
AR.Config:Parser(include("config/serverside.lua"))