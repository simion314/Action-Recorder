---@diagnostic disable: undefined-global
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Action Playback Box"
ENT.Category = "Utility"
ENT.Spawnable = false
ENT.SoundPath = "buttons/button1.wav"

-- Global playback timer
local GLOBAL_PLAYBACK_TIMER = "ActionRecorder_GlobalPlayback"
local GLOBAL_TIMER_INTERVAL = AR_FRAME_INTERVAL
local ActivePlaybackBoxes = {}

function ENT:Initialize()
    self:SetSolid(SOLID_VPHYSICS)
    if SERVER then
        self:SetUseType(SIMPLE_USE)
    end
    self.PlaybackData = {}
    self.PlaybackSpeed = 1
    self.LoopMode = AR_LOOP_MODE.NO_LOOP
    self.PlaybackDirection = AR_PLAYBACK_DIRECTION.FORWARD
    self.PlaybackType = AR_PLAYBACK_TYPE.ABSOLUTE
    self.Easing = "Linear"
    self.EasingAmplitude = 1
    self.EasingFrequency = 1
    self.EasingInvert = false
    self.EasingOffset = 0
    self.status = AR_ANIMATION_STATUS.NOT_STARTED
    self.lastStatus = AR_ANIMATION_STATUS.NOT_STARTED
    self.BoxID = "Box"
    self.NumpadKey = self.NumpadKey or 5
    self.IsOneTimeSmoothReturn = false
    self.IsActivated = false
    self.ShouldSmoothReturn = false
    self.PhysicslessTeleport = false

    if SERVER and not self:GetNWString("OwnerName", nil) then
        self:SetNWString("OwnerName", "Unknown")
    end

    if SERVER then
        self:SetupNumpad()
        ActionRecorder.Wire.SetupEntity(self)
    end
    --ARLog("Done initializing" )
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
    self:StopPlayback(true)
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
     if not data or type(data) ~= "table" or next(data) == nil then
        ARLog("SetPlaybackData Attempt to set Empty data ", data)
        return
     end
    --ARLog("SetPlaybackData length ", #data)
    self.PlaybackData = {}
    self.AnimationInfo = {}
    for id,frames in pairs(data) do
        if not frames or 0 == #frames then
            ARLog("attempt to setplayback entity with zero frames skipping")
            continue end--just ignore zero frames recordings
        self.PlaybackData[id] = frames
        self.AnimationInfo[id] = {
            frameCount = #frames,
            direction = AR_PLAYBACK_DIRECTION.FORWARD,
            status = AR_ANIMATION_STATUS.NOT_STARTED,
            currentFrameIndex = 1,
            initialPos = nil,
            initialAng = nil
        }
   end
   self.status = AR_ANIMATION_STATUS.NOT_STARTED
end
function ENT:SetPlaybackSettings(speed, loopMode, playbackType, easing, easing_amplitude, easing_frequency, easing_invert, easing_offset)
    self.PlaybackSpeed = speed or 1
    self.LoopMode = loopMode or AR_LOOP_MODE.NO_LOOP
    self.PlaybackType = playbackType or AR_PLAYBACK_TYPE.ABSOLUTE
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
        if IsValid(box) and box ~= myBox and box.status == AR_ANIMATION_STATUS.PLAYING and istable(box.PlaybackData) and box.BoxID ~= myBox.BoxID then
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
    if self.status  ~= AR_ANIMATION_STATUS.PLAYING and not forceReturn then return end

    self.status = AR_ANIMATION_STATUS.FINISHED
    self.IsActivated = false
    -- Remove this box from the active playback boxes
    ActivePlaybackBoxes[self] = nil

    -- If no boxes are playing, remove the global timer
    if table.IsEmpty(ActivePlaybackBoxes) then
        timer.Remove(GLOBAL_PLAYBACK_TIMER)
    end

    local freezeOnEnd = self:GetNWBool("FreezeOnEnd", false)

    if freezeOnEnd and (self.LoopMode == AR_LOOP_MODE.NO_LOOP or self.LoopMode == AR_LOOP_MODE.NO_LOOP_SMOOTH) then
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

function ENT:Cleanup()

end


function ENT:StartPlayback()
    --ARLog("StartPlayback")
    -- Capture initial positions/angles when playback starts
    if self.status ~= AR_ANIMATION_STATUS.PLAYING then -- Only capture if not already playing
        for entIndex, frames in pairs(self.PlaybackData or {}) do
            local ent = Entity(entIndex)
            if IsValid(ent) then
                local info = self.AnimationInfo[entIndex]
                if info then
                    info.initialPos = ent:GetPos()
                    ARLog("initial pos ", info.initialPos)
                    info.initialAng = ent:GetAngles()
                end
            end
        end
    end
    self.LastFrameTime = CurTime()
    self.status = AR_ANIMATION_STATUS.PLAYING
    self.PlaybackDirection = AR_PLAYBACK_DIRECTION.FORWARD
    self.IsActivated = true

    -- Add this box to the active playback boxes
    ActivePlaybackBoxes[self] = true

    for _, info in pairs(self.AnimationInfo) do
        info.status = AR_ANIMATION_STATUS.PLAYING
        info.currentFrameIndex = 1
     end
    -- Create the global timer if it doesn't exist
    if not timer.Exists(GLOBAL_PLAYBACK_TIMER) then
        --ARLog("Creating global timer")
        timer.Create(GLOBAL_PLAYBACK_TIMER, GLOBAL_TIMER_INTERVAL, 0, function()
            for box, _ in pairs(ActivePlaybackBoxes) do
                if IsValid(box) then
                    box:ProcessPlayback()
                else
                    ARLog("We have an invalid box")
                end
            end
        end)
    end

    -- Initialize playback for all entities
    for entIndex, _ in pairs(self.PlaybackData or {}) do
        self:SetupEntityPlayback(entIndex)
    end
    --ARLog("Finished StarPlayback")
end

--- This function assumes all entities have same number of frames
--TODO this could be optimized by storing the frames count in the box object when recording is done
function ENT:getFramesCount()
    -- Legacy function - use GetMaxFrames() instead
    return self:GetMaxFrames()
end

function ENT:GetCurrentFrameIndex()
    -- Return the minimum frame across all animated entities
    local minFrame = math.huge
    for _, info in pairs(self.AnimationInfo or {}) do
        if info and info.currentFrameIndex then
            minFrame = math.min(minFrame, info.currentFrameIndex)
            --ARLog("min frame is ", minFrame)f
        end
    end
    return minFrame == math.huge and 1 or minFrame
end

function ENT:GetMaxFrames()
    -- Return the maximum frame count across all entities
    local maxFrames = 0
    for _, info in pairs(self.AnimationInfo or {}) do
        if info and info.frameCount then
            maxFrames = math.max(maxFrames, info.frameCount)
        end
    end
    return maxFrames
end
function ENT:StopPlaybackIfNeeded()
    local allEntitiesFinished = true
    
    for _, info in pairs(self.AnimationInfo or {}) do
        if info.status ~= AR_ANIMATION_STATUS.FINISHED then
            allEntitiesFinished = false
            break
        end
    end
    if allEntitiesFinished then
        self:StopPlayback()
    end
end
function ENT:advanceFrames(amount, frameCount, currentFrameIndex)

    if frameCount <= 1 then
        ARLog("Only one frame available, marking entity as finished.")
        return -1  -- Mark as finished to stop processing
    end
    local atStart = currentFrameIndex == 1
    local atEnd = currentFrameIndex == frameCount
    local nextFrameIndex = currentFrameIndex
    local direction = self:calculateDirection()

    -- Log basic information
    -- ARLog("direction:", direction, "atStart:", atStart, "atEnd:", atEnd, "frameCount:", frameCount)

    if direction > 0 then
         -- ARLog("Positive direction detected")
        if not atEnd then
            --ARLog("Not at end, incrementing index")
            nextFrameIndex = math.min(nextFrameIndex + amount, frameCount)
        else
            --ARLog("At end, handling loop modes")
            if self.LoopMode == AR_LOOP_MODE.NO_LOOP then
                ARLog("No loop mode, entity finished")
                return -1
            elseif self.LoopMode == AR_LOOP_MODE.PING_PONG then
                --ARLog("Ping pong mode, reversing direction")
                self.PlaybackDirection = self.PlaybackDirection * (-1)
                nextFrameIndex = frameCount
            elseif self.LoopMode == AR_LOOP_MODE.LOOP then
                ARLog("Loop mode, resetting to start")
                nextFrameIndex = 1
            else
                ARLog("Unsupported Loop mode in advanceFrames")
            end
        end
    else -- direction < 0 case
         -- ARLog("Negative direction detected")
        if not atStart then
            --ARLog("Not at start, decrementing index")
            nextFrameIndex = math.max(1, nextFrameIndex - amount)
        else
            --ARLog("At start, handling loop modes")
            if self.LoopMode == AR_LOOP_MODE.NO_LOOP then
                ARLog("No loop mode, entity finished")
                return -1
            elseif self.LoopMode == AR_LOOP_MODE.PING_PONG then
                --ARLog("Ping pong mode, reversing direction")
                self.PlaybackDirection = self.PlaybackDirection * (-1)
                nextFrameIndex = 1
            elseif self.LoopMode == AR_LOOP_MODE.LOOP then
                --ARLog("Loop mode, resetting to end")
                nextFrameIndex = frameCount
            else
                ARLog("Unsupported Loop mode in advanceFrames")
            end
        end
    end

    --ARLog("advanceFrames calculated nextFrameIndex:", nextFrameIndex)
    return nextFrameIndex
end

function ENT:calculateNextFrame(currentFrameIndex, framesCount)
    local speed = self.PlaybackSpeed or 1
    --ARLog("calculateNextFrame: speed=", speed, " currentFrame=", currentFrameIndex, " totalFrames=", framesCount)
    if (speed == 0) then
        ARLog("Speed is zero for ") -- TODO add the box id in the message
        return 1 -- move object at first frame if he set speed to 0
    end
    local moveTimeInterval = GLOBAL_TIMER_INTERVAL / math.abs(speed) --dividing with a num less then 1 will increase the numerator
    local lastMoveTime = self.LastFrameTime
    local now = CurTime()
    local timeSinceLastMove = now - lastMoveTime
    -- if speed is small we might not need to move to next frame
    if (math.abs(speed) < 1) then
        ARLog("speed < 1  ")
        if timeSinceLastMove < moveTimeInterval then
             ARLog(" returning sae frame index   ", timeSinceLastMove, moveTimeInterval)
            return currentFrameIndex
        else -- we need to advance 1 frame
           return self:advanceFrames(1, framesCount, currentFrameIndex)
        end
    else --case speed is greate then 1 in abs value
        local framesToMove = math.floor(timeSinceLastMove / moveTimeInterval)
        return self:advanceFrames(framesToMove, framesCount, currentFrameIndex)
    end
end

function ENT:SetupEntityPlayback(entIndex)
    --ARLog("SetupEntityPlayback")
    local ent = Entity(entIndex)
    if not IsValid(ent) then return end
    --if IsPropControlledByOtherBox(ent, self) then return end -- This is only for replaying one box at a time.
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return end
    local frames = self.PlaybackData[entIndex]
    local info = self.AnimationInfo[entIndex]
    local frameCount = info.frameCount
    if frameCount == 0 then return end

    local freezeOnEnd = self:GetNWBool("FreezeOnEnd", false)
    if not (freezeOnEnd and (self.LoopMode == AR_LOOP_MODE.NO_LOOP or self.LoopMode == AR_LOOP_MODE.NO_LOOP_SMOOTH)) then
        phys:EnableMotion(true)
    end

    ent:SetCollisionGroup(COLLISION_GROUP_NONE)

    local i = info.currentFrameIndex

    local basePos = Vector(0,0,0)
    if self.PlaybackType == AR_PLAYBACK_TYPE.RELATIVE and frames[1] and frames[1].pos then
        if info.initialPos then
            basePos = info.initialPos - frames[1].pos
        end
    end

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
    ent.IsBeingPlayedBack = true
    ent.PlaybackBox = self
end

function ENT:calculateDirection()
    return (self.PlaybackDirection * (self.PlaybackSpeed < 0 and -1 or 1))
end
function ENT:ProcessPlayback()
    if self.status ~= AR_ANIMATION_STATUS.PLAYING then
        ARLog("Wrong status in process playback: ", self.status)
    return end

    local freezeOnEnd = self:GetNWBool("FreezeOnEnd", false)
    local now = CurTime()

    --ARLog("ProcessPlayback: Processing ", table.Count(self.PlaybackData or {}), " entities")

    for entIndex, frames in pairs(self.PlaybackData or {}) do
         local ent = Entity(entIndex)
         if not IsValid(ent) then continue end
         local phys = ent:GetPhysicsObject()
         if not IsValid(phys) then continue end


         local info = self.AnimationInfo[entIndex]
         
         -- Skip entities that are already finished
         if info.status == AR_ANIMATION_STATUS.FINISHED then
             --ARLog("Skipping finished entity: ", entIndex)
             continue
         end
         
         local frameCount = info.frameCount
         --ARLog("Entity ", entIndex, " frameCount: ", frameCount, " currentFrame: ", info.currentFrameIndex)
         if frameCount == 0 then
            ARLog("This entity has zero frames, should not have been added ", entIndex)
            continue
         end
         local frameIndex = self:calculateNextFrame(info.currentFrameIndex, frameCount)
         --ARLog("Entity ", entIndex, " calculated frameIndex: ", frameIndex, " (was ", info.currentFrameIndex, ")")
         if (frameIndex == info.currentFrameIndex) then
                --ARLog("no move, probably speed is low")
                -- Calculate interpolation alpha for slow speeds
                --[[
                if self.PlaybackSpeed < 1 and self.PlaybackSpeed ~= 0 then
                    local moveTimeInterval = GLOBAL_TIMER_INTERVAL / math.abs(self.PlaybackSpeed)
                    local timeSinceLastMove = now - self.LastFrameTime
                    local alpha = math.min(1, timeSinceLastMove / moveTimeInterval)
                    self:InterpolateActivePlayback(ent, alpha)
                end
                --]]
                continue
            end
         
         -- Check if entity finished
         if frameIndex == -1 then
             info.status = AR_ANIMATION_STATUS.FINISHED
             --ARLog("Entity " .. entIndex .. " marked as finished")
             -- Check if all entities are finished and stop playback if needed
             self:StopPlaybackIfNeeded()
             continue
         end

        -- Calculate the base position
        local frame = frames[frameIndex]
        if frame then
            local basePos = Vector(0,0,0)
            if self.PlaybackType == AR_PLAYBACK_TYPE.RELATIVE and frame.pos then
                if info.initialPos and frames[1] and frames[1].pos then
                    basePos = info.initialPos - frames[1].pos
                end
            end

            self:ApplyFrameData(ent, frame, basePos)
        end
        info.currentFrameIndex = frameIndex
    end

    self.LastFrameTime = now
end

--[[
function ENT:InterpolateActivePlayback(ent, alpha)
    if not IsValid(ent) or not ent.IsBeingPlayedBack or not IsValid(ent.PlaybackBox) then
        return
    end
    
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return end
    
    alpha = alpha or 1
    local easing_func = ActionRecorder.EasingFunctions[ent.PlaybackBox.Easing or "Linear"]
    if easing_func then
        alpha = math.Clamp(alpha, 0, 1)
        local original_alpha = alpha
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

function ENT:InterpolateSmoothReturn(ent)
    if not IsValid(ent) or not ent.PlaybackBox or not ent.PlaybackBox.IsOneTimeSmoothReturn then
        return
    end
    
    if ent.PlaybackBox.status == AR_ANIMATION_STATUS.PLAYING then
        return
    end
    
    local playbackBox = ent.PlaybackBox
    local initialPos = playbackBox.InitialPositions[ent:EntIndex()]
    local initialAng = playbackBox.InitialAngles[ent:EntIndex()]

    if not initialPos or not initialAng then return end
    
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return end

    local alpha = 1 -- TODO implement this properly
    local easing_func = ActionRecorder.EasingFunctions[playbackBox.Easing or "Linear"]
    if easing_func then
        alpha = math.Clamp(alpha, 0, 1)
        local original_alpha = alpha

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
--]]

function ENT:ApplyFrameData(ent, frame, basePos)
    --ARLog("ApplyFrameData called for entity ", ent:EntIndex())
    
    -- Apply position and angle changes
    if frame.pos and frame.ang then
        local targetPos = frame.pos + basePos
        local targetAng = frame.ang
        --ARLog("Moving entity to pos: ", targetPos, " ang: ", targetAng)
        
        -- Move the entity directly
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            local params = {
                pos = targetPos,
                angle = targetAng,
                maxspeed = 10000,
                maxangular = 10000,
                maxspeeddamp = 10000,
                maxangulardamp = 10000,
                dampfactor = 1,
                teleportdistance = self.PhysicslessTeleport and 0.1 or 0,
                deltaTime = GLOBAL_TIMER_INTERVAL
            }
            phys:Wake()
            phys:ComputeShadowControl(params)
        else
            -- Fallback for entities without physics
            ent:SetPos(targetPos)
            ent:SetAngles(targetAng)
        end
    else
        ARLog("ApplyFrameData NO pos OR angle", frame.pos, frame.ang)
    end

    -- Apply visual changes
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

function ENT:OnDuplicated()
    -- Re-setup wire integration when entity is duplicated
    if WireLib then
        timer.Simple(0.1, function()
            if IsValid(self) then
                --ARLog("Re-initializing wire integration after duplication")
                ActionRecorder.Wire.SetupEntity(self)
            end
        end)
    end
end

function ENT:TriggerInput(iname, value)
    if not WireLib then return end
    
    local handlers = {
        ["Play"] = function(val) 
            if val ~= 0 then 
                self:StartPlayback(true) 
            else 
                self:StopPlayback(true) 
            end 
        end,
        
        ["Stop"] = function(val) 
            if val ~= 0 then self:StopPlayback(true) end 
        end,
        
        ["PlaybackSpeed"] = function(val) 
            self.PlaybackSpeed = math.Clamp(val, -10, 10) 
        end,
        
        ["LoopMode"] = function(val) 
            local validMode = ActionRecorder.Wire.ValidateLoopMode(val)
            if validMode then
                self.LoopMode = validMode
            else
                ActionRecorder.Wire.Error(self, "Invalid loop mode: " .. tostring(val))
            end
        end,
        
        ["Reset"] = function(val) 
            if val ~= 0 then self:ResetPlayback() end 
        end,
        
        ["SetFrame"] = function(val)
            if 0 == val then
                return
            end
            --ARLog("SetFrame input val is ", val)
            self:SetCurrentFrame(math.max(1, val))
        end
    }
    
    local handler = handlers[iname]
    if handler then 
        handler(value) 
    else
        ActionRecorder.Wire.Error(self, "Unknown input: " .. tostring(iname))
    end
end

function ENT:Think()
    if not WireLib or not self.WireState then return end
    
    local now = CurTime()
    
    -- Throttle wire outputs to 10Hz instead of 50Hz for better performance
    if now - self.WireState.outputThrottle < 0.1 then
        self:NextThink(now + 0.02)
        return true
    end
    self.WireState.outputThrottle = now
    
    -- Update wire outputs using the centralized system
    ActionRecorder.Wire.UpdateOutputs(self)
    
    self:NextThink(now + 0.02)
    return true
end

function ENT:ResetPlayback()
    --ARLog("ResetPlayback called via wire input")
    self:StopPlayback(true)
    
    -- Reset all animation info to frame 1
    for _, info in pairs(self.AnimationInfo or {}) do
        if info then
            info.currentFrameIndex = 1
            info.status = AR_ANIMATION_STATUS.FINISHED
        end
    end
    
    -- Update wire outputs immediately to reflect the reset
    if self.WireState then
        ActionRecorder.Wire.UpdateOutputs(self)
    end
end

function ENT:SetCurrentFrame(frame)
    --ARLog("SetCurrentFrame called with frame: " .. tostring(frame))
    
    -- Set all entities to the specified frame
    for _, info in pairs(self.AnimationInfo or {}) do
        if info and info.frameCount then
            info.currentFrameIndex = math.Clamp(frame, 1, info.frameCount)
        end
    end
    
    -- Apply the frame data immediately by processing a single frame
    self:ProcessPlayback()
    
    -- Update wire outputs immediately
    if self.WireState then
        ActionRecorder.Wire.UpdateOutputs(self)
    end
end
