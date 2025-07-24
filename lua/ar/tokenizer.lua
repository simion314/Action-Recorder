AR.Tokenizer = { }

local Base = { }

AccessorFunc(Base, "color", "Color", FORCE_COLOR)
AccessorFunc(Base, "pos", "Pos", FORCE_VECTOR)
AccessorFunc(Base, "angles", "Angles", FORCE_ANGLE)
AccessorFunc(Base, "time", "Time", FORCE_NUMBER)
AccessorFunc(Base, "renderfx", "RenderFX", FORCE_NUMBER)
AccessorFunc(Base, "rendermode", "RenderMode", FORCE_NUMBER)
AccessorFunc(Base, "collisiongroup", "CollisionGroup", FORCE_NUMBER)
AccessorFunc(Base, "solid", "Solid", FORCE_NUMBER)
AccessorFunc(Base, "skin", "Skin", FORCE_NUMBER)
AccessorFunc(Base, "material", "Material", FORCE_STRING)
AccessorFunc(Base, "bodygroups", "Bodygroups")

function AR.Tokenizer:New(ENT, Owner)
	local Token = { }
	
	setmetatable(Token, {
		__index = Base,
		__tostring = function(self)
			return string.format(
				"Token Object: %s -> %s",
				self,
				table.Count(self)
			)
		end
	})
	
	Token:SetColor(ENT:GetColor())
	Token:SetPos(ENT:GetPos())
	Token:SetAngles(ENT:GetAngles())
	Token:SetRenderFX(ENT:GetRenderFX())
	Token:SetRenderMode(ENT:GetRenderMode())
	Token:SetCollisionGroup(ENT:GetCollisionGroup())
	Token:SetSolid(ENT:GetSolid())
	Token:SetSkin(ENT:GetSkin())
	Token:SetMaterial(ENT:GetMaterial())

	local Bodygroups = { }
	
	for k,v in ipairs(ENT:GetBodyGroups()) do
		Bodygroups[v.id] = ENT:GetBodygroup(v.id)
	end
	
	Token:SetBodygroups(Bodygroups)
	Token:SetTime(CurTime())

	return Token
end

function AR.Tokenizer:Compare(Token, secondaryToken)
	local Changes = { }
	
	for k,v in pairs(Token) do 
		if (secondaryToken[k] != v) then
			Changes[k] = v
		end
	end
	
	return table.Count(Changes), Changes
end