AddCSLuaFile()

if not ActionRecorder then ActionRecorder = {} end
ActionRecorder.Wire = {}

function ActionRecorder.Wire.SetupEntity(ent)
    if not WireLib then return false end
    
    ent.Inputs = WireLib.CreateInputs(ent, { 
        "Play", "Stop", "PlaybackSpeed", "LoopMode", "Reset", "SetFrame" 
    })
    ent.Outputs = WireLib.CreateOutputs(ent, { 
        "IsPlaying", "PlaybackSpeed", "Frame", "MaxFrames", "LoopMode", "Status" 
    })
    
    -- Initialize wire state tracking
    ent.WireState = {
        lastStatus = nil,
        lastFrame = -1,
        lastSpeed = nil,
        lastLoopMode = nil,
        outputThrottle = 0
    }
    
    ARLog("Wire integration setup completed for entity")
    return true
end

function ActionRecorder.Wire.UpdateOutputs(ent)
    if not WireLib or not ent.WireState then return end
    
    local ws = ent.WireState
    local currentFrame = ent:GetCurrentFrameIndex()
    local maxFrames = ent:GetMaxFrames()
    
    -- Status output (only when changed)
    if ent.status ~= ws.lastStatus then
        WireLib.TriggerOutput(ent, "IsPlaying", ent.status == AR_ANIMATION_STATUS.PLAYING and 1 or 0)
        WireLib.TriggerOutput(ent, "Status", ent.status)
        ws.lastStatus = ent.status
    end
    
    -- Frame output (only when changed)
    if currentFrame ~= ws.lastFrame then
        WireLib.TriggerOutput(ent, "Frame", currentFrame)
        WireLib.TriggerOutput(ent, "MaxFrames", maxFrames)
        ws.lastFrame = currentFrame
    end
    
    -- Speed and loop mode output (only when changed)
    if ent.PlaybackSpeed ~= ws.lastSpeed then
        WireLib.TriggerOutput(ent, "PlaybackSpeed", ent.PlaybackSpeed)
        ws.lastSpeed = ent.PlaybackSpeed
    end
    
    if ent.LoopMode ~= ws.lastLoopMode then
        WireLib.TriggerOutput(ent, "LoopMode", ent.LoopMode)
        ws.lastLoopMode = ent.LoopMode
    end
end

function ActionRecorder.Wire.ValidateLoopMode(value)
    local validModes = {
        [AR_LOOP_MODE.NO_LOOP] = true,
        [AR_LOOP_MODE.LOOP] = true,
        [AR_LOOP_MODE.PING_PONG] = true,
        [AR_LOOP_MODE.NO_LOOP_SMOOTH] = true
    }
    return validModes[value] and value or nil
end

function ActionRecorder.Wire.Error(ent, message)
    ARLog("Wire Error: " .. tostring(message))
    if WireLib and ent.WireState then
        WireLib.TriggerOutput(ent, "Status", -1) -- Error status
    end
end
