if (SERVER) then
	AddCSLuaFile()
end

function AR:Out(Text, ...)
	MsgC(
		Color(255,0,0), 
		"[AR] ",
		color_white,
		string.format(
			Text,
			...
		)
	)
end

include("config.lua")
include("tokenizer.lua")
include("cache.lua")
include("capture.lua")
include("replay.lua")

MsgC(Color(255,0,0), [[
   \         |   _)                _ \                          |           
  _ \    _|   _|  |   _ \    \       /   -_)   _|   _ \   _| _` |   -_)   _|
_/  _\ \__| \__| _| \___/ _| _|   _|_\ \___| \__| \___/ _| \__,_| \___| _|  
]])