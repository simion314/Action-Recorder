AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Action Playback Box"
ENT.Category = "Utility"
ENT.Spawnable = false
ENT.SoundPath = "buttons/button1.wav"

function ENT:Initialize()
    self:SetSolid(SOLID_VPHYSICS)
    if SERVER then
        self:SetUseType(SIMPLE_USE)
    end
    self.PlaybackData = {} 
    self.PlaybackTimers = {}
    self.PlaybackSpeed = 1
    self.LoopMode = 0
    self.PlaybackDirection = 1
    self.PlaybackType = "absolute"
    self.Easing = "Linear"
    self.EasingAmplitude = 1
    self.EasingFrequency = 1
    self.EasingInvert = false
    self.EasingOffset = 0
    self.PlaybackCounter = 0
    self.IsPlayingBack = false
    self.LastIsPlayingBack = false
    self.BoxID = "Box"
    self.NumpadKey = self.NumpadKey or 5
    self.IsOneTimeSmoothReturn = false
    self.IsActivated = false
    self.InitialPositions = {}
    self.InitialAngles = {}
    self.ShouldSmoothReturn = false
    self.PhysicslessTeleport = false

    if SERVER and not self:GetNWString("OwnerName", nil) then
        self:SetNWString("OwnerName", "Unknown")
    end

    if SERVER then
        self:SetupNumpad()
        if WireLib then
            self.Inputs = WireLib.CreateInputs(self, { "Play", "Stop", "PlaybackSpeed", "LoopMode" })
            self.Outputs = WireLib.CreateOutputs(self, { "IsPlaying", "PlaybackSpeed", "Frame" })
        end
    end
end

function ENT:SetupNumpad()
    if not IsValid(self:GetOwner()) or not self.NumpadKey then return end

    if self.NumpadBind then
        numpad.Remove(self.NumpadBind)
        self.NumpadBind = nil
    end
    if self.NumpadUpBind then
        numpad.Remove(self.NumpadUpBind)
        self.NumpadUpBind = nil
    end

    self.NumpadBind = numpad.OnDown(self:GetOwner(), self.NumpadKey, "ActionRecorder_Playback", self)
    self.NumpadUpBind = numpad.OnUp(self:GetOwner(), self.NumpadKey, "ActionRecorder_Playback_Release", self)
end


function ENT:OnRemove()
    if self.PlaybackTimers then
        for _, timerName in pairs(self.PlaybackTimers) do
            if timerName then timer.Remove(timerName) end
        end
        self.PlaybackTimers = nil
    end
    if self.NumpadBind then
        numpad.Remove(self.NumpadBind)
        self.NumpadBind = nil
    end
    if self.NumpadUpBind then
        numpad.Remove(self.NumpadUpBind)
        self.NumpadUpBind = nil
    end
end

function ENT:SetModelPath(model)
    if not model or model == "" or not util.IsValidModel(model) then
        model = "models/props_c17/oildrum001.mdl"
    end
    if SERVER then
        self:SetModel(model)
    end
end

function ENT:SetPlaybackData(data)
    self.PlaybackData = data or {}
end

function ENT:SetPlaybackSettings(speed, loopMode, playbackType, easing, easing_amplitude, easing_frequency, easing_invert, easing_offset)
    self.PlaybackSpeed = speed or 1
    self.LoopMode = loopMode or 0
    self.PlaybackType = playbackType or "absolute"
    self.Easing = easing or "Linear"
    self.EasingAmplitude = easing_amplitude or 1
    self.EasingFrequency = easing_frequency or 1
    self.EasingInvert = easing_invert or false
    self.EasingOffset = easing_offset or 0
end

function ENT:SetBoxID(id)
    self.BoxID = id or "Box"
    if SERVER then self:SetNWString("BoxID", self.BoxID) end
end

function ENT:SetOwnerName(name)
    if SERVER then self:SetNWString("OwnerName", name or "Unknown") end
end

function ENT:SetSoundPath(soundpath)
    self.SoundPath = soundpath
end

function ENT:SetPhysicslessTeleport(state)
    self.PhysicslessTeleport = tobool(state)
    if SERVER then
        self:SetNWBool("PhysicslessTeleport", self.PhysicslessTeleport)
    end
end


function ENT:UpdateSettings(
    speed, loopMode, playbackType, model, boxid, soundpath,
    easing, easing_amplitude, easing_frequency, easing_invert, easing_offset, physicsless, freezeonend
)
    self:StopPlayback()
    self:SetPlaybackSettings(
        speed, loopMode, playbackType,
        easing, easing_amplitude, easing_frequency, easing_invert, easing_offset, physicsless
    )
    self:SetModelPath(model)
    self:SetBoxID(boxid)
    self:SetSoundPath(soundpath)
    self:SetPhysicslessTeleport(physicsless)
	self:SetNWBool("FreezeOnEnd", freezeonend)
    self:SetupNumpad() 
    self:StartPlayback()
end



function ENT:Use(activator, caller)
    if not self.PlaybackData then return end
    self:EmitSound(self.SoundPath or "buttons/button3.wav")
    self:StartPlayback(false)
end

local function IsPropControlledByOtherBox(prop, myBox)
    for _, box in pairs(ents.FindByClass("action_playback_box")) do
        if IsValid(box) and box ~= myBox and box.IsPlayingBack and istable(box.PlaybackData) and box.BoxID ~= myBox.BoxID then
            for k, _ in pairs(box.PlaybackData) do
                if k == prop:EntIndex() then
                    return true
                end
            end
        end
    end
    return false
end

function ENT:StopPlayback(forceReturn)
    if not self.IsPlayingBack and not forceReturn then return end
    if not self.PlaybackTimers then return end

    
    for _, oldTimerName in pairs(self.PlaybackTimers) do
        if oldTimerName then 
            timer.Remove(oldTimerName) 
        end
    end

    self.PlaybackTimers = {}
    self.IsPlayingBack = false
    self.IsActivated = false

    
    local freezeOnEnd = self:GetNWBool("FreezeOnEnd", false)

    
    if freezeOnEnd and (self.LoopMode == 0 or self.LoopMode == 3) then
        for entIndex, _ in pairs(self.PlaybackData or {}) do
            local ent = Entity(entIndex)
            if IsValid(ent) then
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    phys:EnableMotion(false)
                end
            end
        end
    end
end






function ENT:StartPlayback()



    -- Capture initial positions/angles when playback starts
    if not self.IsPlayingBack then -- Only capture if not already playing
        self.InitialPositions = {}
        self.InitialAngles = {}
        for entIndex, frames in pairs(self.PlaybackData or {}) do
            local ent = Entity(entIndex)
            if IsValid(ent) then
                self.InitialPositions[entIndex] = ent:GetPos()
                self.InitialAngles[entIndex] = ent:GetAngles()
            end
        end
    end

    if not self.PlaybackTimers then self.PlaybackTimers = {} end
    for _, oldTimerName in pairs(self.PlaybackTimers) do
        if oldTimerName then timer.Remove(oldTimerName) end
    end
    self.PlaybackTimers = {}
    self.PlaybackCounter = (self.PlaybackCounter or 0) + 1
    self.IsPlayingBack = true
    self.PlaybackDirection = 1

    self.IsActivated = true

    local freezeOnEnd = self:GetNWBool("FreezeOnEnd", false) 

    for entIndex, frames in pairs(self.PlaybackData or {}) do
        local ent = Entity(entIndex)
        if not IsValid(ent) then continue end
        --if IsPropControlledByOtherBox(ent, self) then continue end -- This is only for replaying one box at a time.
        local phys = ent:GetPhysicsObject()
        if not IsValid(phys) then continue end

        local frameCount = #frames
        if frameCount == 0 then continue end

        
        if not (freezeOnEnd and (self.LoopMode == 0 or self.LoopMode == 3)) then
            phys:EnableMotion(true)
        end

        ent:SetCollisionGroup(COLLISION_GROUP_NONE)

        local i = (self.PlaybackSpeed < 0) and frameCount or 1
        self.i = i
        local timerName = "Playback_" .. self:EntIndex() .. "_" .. entIndex .. "_" .. self.PlaybackCounter
        self.PlaybackTimers[entIndex] = timerName

        local basePos = (self.PlaybackType == "relative" and frames[i] and frames[i].pos) and (ent:GetPos() - frames[i].pos) or Vector(0,0,0)

        if ent.IsBeingPlayedBack and ent.PlaybackBox and ent.PlaybackBox ~= self then
            ent.IsBeingPlayedBack = false
            ent.PlaybackBox = nil
        end

        
        if frames[i].pos and frames[i].ang then
            ent.TargetPos = frames[i].pos + basePos
            ent.TargetAng = frames[i].ang
        else
            ent.TargetPos = ent:GetPos()
            ent.TargetAng = ent:GetAngles()
        end

        ent.LastFrameTime = CurTime()
        ent.NextFrameTime = CurTime() + math.abs(0.02 / (self.PlaybackSpeed or 1))
        ent.IsBeingPlayedBack = true
        ent.PlaybackBox = self

        if false then
            self.InitialPositions[entIndex] = ent:GetPos()
            self.InitialAngles[entIndex] = ent:GetAngles()
        end

        timer.Create(timerName, math.abs(0.02 / (self.PlaybackSpeed or 1)), 0, function()
            if not IsValid(self) or not self.PlaybackSpeed or not self.PlaybackTimers then
                timer.Remove(timerName)
                if ent then
                    ent.IsBeingPlayedBack = false
                    ent.PlaybackBox = nil
                end
                return
            end

            if not IsValid(ent) or not IsValid(phys) then
                timer.Remove(timerName)
                if self.PlaybackTimers then self.PlaybackTimers[entIndex] = nil end
                if ent then
                    ent.IsBeingPlayedBack = false
                    ent.PlaybackBox = nil
                end
                return
            end

            local frame = frames[i]
            if not frame then
                if self.LoopMode == 1 then -- Loop
                    i = (self.PlaybackSpeed < 0) and frameCount or 1
                    frame = frames[i]
                    basePos = (frame and frame.pos and self.PlaybackType == "relative") and (ent:GetPos() - frame.pos) or Vector(0,0,0)
                elseif self.LoopMode == 2 then -- Ping-Pong
                    self.PlaybackDirection = self.PlaybackDirection * -1
                    i = i + (self.PlaybackDirection * (self.PlaybackSpeed < 0 and -1 or 1) * 2)
                    frame = frames[i]
                    basePos = (frame and frame.pos and self.PlaybackType == "relative") and (ent:GetPos() - frame.pos) or Vector(0,0,0)
                elseif self.LoopMode == 3 then -- No Loop (Smooth)
                    if self.PlaybackDirection == 1 then -- Finished forward playback, start reverse
                        self.PlaybackDirection = -1
                        i = frameCount -- Start from the end for reverse
                        frame = frames[i]
                        basePos = (frame and frame.pos and self.PlaybackType == "relative") and (ent:GetPos() - frame.pos) or Vector(0,0,0)
                    else -- Finished reverse playback
                        timer.Remove(timerName)
                        if self.PlaybackTimers then self.PlaybackTimers[entIndex] = nil end
                        ent.IsBeingPlayedBack = false
                        ent.PlaybackBox = nil
                        local allDone = true
                        if self.PlaybackTimers then
                            for _, v in pairs(self.PlaybackTimers) do
                                if v then allDone = false break end
                            end
                        end
                        if allDone then
                            self.IsPlayingBack = false
                            self.PlaybackDirection = 1 -- Reset direction for next playback
                            self.IsOneTimeSmoothReturn = false -- Reset flag
                        end
                        return
                    end
                else -- No Loop (original)
                    timer.Remove(timerName)
                    if self.PlaybackTimers then self.PlaybackTimers[entIndex] = nil end
                    ent.IsBeingPlayedBack = false
                    ent.PlaybackBox = nil
                    local allDone = true
                    if self.PlaybackTimers then
                        for _, v in pairs(self.PlaybackTimers) do
                            if v then allDone = false break end
                        end
                    end
                    if allDone then self.IsPlayingBack = false end
                    return
                end
            end

            if not frame then
                timer.Remove(timerName)
                if self.PlaybackTimers then self.PlaybackTimers[entIndex] = nil end
                ent.IsBeingPlayedBack = false
                ent.PlaybackBox = nil
                local allDone = true
                if self.PlaybackTimers then
                    for _, v in pairs(self.PlaybackTimers) do
                        if v then allDone = false break end
                    end
                end
                if allDone then self.IsPlayingBack = false end
                return
            end

            if frame.pos and frame.ang then
                ent.TargetPos = frame.pos + basePos
                ent.TargetAng = frame.ang
            else
                ent.TargetPos = ent:GetPos()
                ent.TargetAng = ent:GetAngles()
            end

            if frame.material then ent:SetMaterial(frame.material) end
            if frame.color then ent:SetColor(frame.color) end
            if frame.renderfx then ent:SetRenderFX(frame.renderfx) end
            if frame.rendermode then ent:SetRenderMode(frame.rendermode) end
            if frame.skin then ent:SetSkin(frame.skin) end
            if frame.bodygroups then
                for id, val in pairs(frame.bodygroups) do
                    ent:SetBodygroup(id, val)
                end
            end

            ent.LastFrameTime = CurTime()
            ent.NextFrameTime = CurTime() + math.abs(0.02 / (self.PlaybackSpeed or 1))

            i = i + (self.PlaybackDirection * (self.PlaybackSpeed < 0 and -1 or 1))
            self.i = i
        end)
    end
end









if CLIENT then
    function ENT:Draw()
        self:DrawModel()
        local id = self:GetNWString("BoxID", self.BoxID or "")
        local ownerName = self:GetNWString("OwnerName", "Unknown")
        if id ~= "" and LocalPlayer():GetPos():DistToSqr(self:GetPos()) < 300*300 then
            local pos = self:GetPos() + Vector(0,0,40)
            local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)
            cam.Start3D2D(pos, ang, 0.2)
                draw.RoundedBox(8, -100, -45, 200, 70, Color(255, 255, 150, 230))
                draw.SimpleText(id, "DermaLarge", 0, -10, Color(0,0,0,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleTextOutlined("(" .. ownerName .. ")", "DermaDefault", 0, 10, Color(0,255,0,200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0,0,0,180))
            cam.End3D2D()
        end
    end
end

hook.Add("Think", "ActionRecorder_PlaybackThink", function()
    for _, ent in pairs(ents.GetAll()) do
        if IsValid(ent) and ent.IsBeingPlayedBack and IsValid(ent.PlaybackBox) then
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then
                local alpha = (CurTime() - ent.LastFrameTime) / (ent.NextFrameTime - ent.LastFrameTime)
                alpha = math.Clamp(alpha, 0, 1)
                local original_alpha = alpha

                local easing_func = ActionRecorder.EasingFunctions[ent.PlaybackBox.Easing or "Linear"]
                if easing_func then
                    local t = alpha
                    t = t + ent.PlaybackBox.EasingOffset
                    t = t * ent.PlaybackBox.EasingFrequency

                    local eased_alpha = easing_func(t)

                    if eased_alpha ~= eased_alpha or math.abs(eased_alpha) == math.huge then
                        eased_alpha = original_alpha
                    end

                    if ent.PlaybackBox.EasingInvert then
                        eased_alpha = 1 - eased_alpha
                    end

                    alpha = Lerp(ent.PlaybackBox.EasingAmplitude, original_alpha, eased_alpha)

                    if alpha ~= alpha or math.abs(alpha) == math.huge then
                        alpha = eased_alpha
                    end
                end

                local interpolatedPos = LerpVector(alpha, ent:GetPos(), ent.TargetPos)
                local interpolatedAng = LerpAngle(alpha, ent:GetAngles(), ent.TargetAng)

                local params = {
                    pos = interpolatedPos,
                    angle = interpolatedAng,
                    maxspeed = 10000,
                    maxangular = 10000,
                    maxspeeddamp = 10000,
                    maxangulardamp = 10000,
                    dampfactor = 1,
                    teleportdistance = ent.PlaybackBox and ent.PlaybackBox.PhysicslessTeleport and 0.1 or 0,
                    deltaTime = FrameTime()
                }
                phys:Wake()
                phys:ComputeShadowControl(params)
            end
        end

        -- Smooth return for No Loop (Smooth) when playback is finished
        if IsValid(ent) and ent.PlaybackBox and ent.PlaybackBox.IsOneTimeSmoothReturn and not ent.PlaybackBox.IsPlayingBack then
            local playbackBox = ent.PlaybackBox
            local initialPos = playbackBox.InitialPositions[ent:EntIndex()]
            local initialAng = playbackBox.InitialAngles[ent:EntIndex()]

            if initialPos and initialAng then
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    local alpha = (CurTime() - ent.LastFrameTime) / (ent.NextFrameTime - ent.LastFrameTime)
                    alpha = math.Clamp(alpha, 0, 1)
                    local original_alpha = alpha

                    local easing_func = ActionRecorder.EasingFunctions[playbackBox.Easing or "Linear"]
                    if easing_func then
                        local t = alpha
                        t = t + playbackBox.EasingOffset
                        t = t * playbackBox.EasingFrequency

                        local eased_alpha = easing_func(t)

                        if eased_alpha ~= eased_alpha or math.abs(eased_alpha) == math.huge then
                            eased_alpha = original_alpha
                        end

                        if playbackBox.EasingInvert then
                            eased_alpha = 1 - eased_alpha
                        end

                        alpha = Lerp(playbackBox.EasingAmplitude, original_alpha, eased_alpha)

                        if alpha ~= alpha or math.abs(alpha) == math.huge then
                            alpha = eased_alpha
                        end
                    end

                    local interpolatedPos = LerpVector(alpha, ent:GetPos(), initialPos)
                    local interpolatedAng = LerpAngle(alpha, ent:GetAngles(), initialAng)

                    local params = {
                        pos = interpolatedPos,
                        angle = interpolatedAng,
                        maxspeed = 10000,
                        maxangular = 10000,
                        maxspeeddamp = 10000,
                        maxangulardamp = 10000,
                        dampfactor = 1,
                        teleportdistance = playbackBox and playbackBox.PhysicslessTeleport and 0.1 or 0,
                        deltaTime = FrameTime()
                    }
                    phys:Wake()
                    phys:ComputeShadowControl(params)

                    if alpha >= 1 then
                        playbackBox.IsOneTimeSmoothReturn = false
                    end
                end
            end
        end
    end
end)




if SERVER then
    numpad.Register("ActionRecorder_Playback", function(ply, ent)
        if not IsValid(ent) then return end
        if ent:GetNWString("OwnerName", "") ~= ply:Nick() then return end
        ent:EmitSound(ent.SoundPath or "buttons/button3.wav")
        ent:StartPlayback(false)
    end)
    numpad.Register("ActionRecorder_Playback_Release", function(ply, ent)
        if not IsValid(ent) then return end
        if ent:GetNWString("OwnerName", "") ~= ply:Nick() then return end
        
    end)
    if WireLib then
        duplicator.RegisterEntityClass("action_playback_box", WireLib.MakeWireEnt, "Data")
    end
end

function ENT:TriggerInput(iname, value)
    if iname == "Play" then
        if value ~= 0 then
            self:StartPlayback(true)
        else
            
        end
    elseif iname == "Stop" and value ~= 0 then
        self:StopPlayback(true)
    elseif iname == "PlaybackSpeed" then
        self.PlaybackSpeed = value
    elseif iname == "LoopMode" then
        self.LoopMode = value
    end
end

function ENT:Think()
    if not WireLib then return end

    if self.IsPlayingBack ~= self.LastIsPlayingBack then
        WireLib.TriggerOutput(self, "IsPlaying", self.IsPlayingBack and 1 or 0)
        self.LastIsPlayingBack = self.IsPlayingBack
    end

    if self.IsPlayingBack then
        WireLib.TriggerOutput(self, "PlaybackSpeed", self.PlaybackSpeed)
        WireLib.TriggerOutput(self, "Frame", self.i or 0)
    end

    self:NextThink(CurTime())
    return true
end

