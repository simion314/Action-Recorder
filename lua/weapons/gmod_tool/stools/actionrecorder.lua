TOOL.Category = "Utility"
TOOL.Name = "#Action Recorder"

if CLIENT then
    language.Add("tool.actionrecorder.name", "Action Recorder")
    language.Add("tool.actionrecorder.desc", "Record and playback any movements")
    language.Add("tool.actionrecorder.0", "Left click: Enable/Disable recording | Right click: Place playback box / update settings")
end

if SERVER then
    CreateConVar("actionrecorder_playbackspeed", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED })
    CreateConVar("actionrecorder_loop", "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED })
    CreateConVar("actionrecorder_playbacktype", "absolute", { FCVAR_ARCHIVE, FCVAR_REPLICATED })
    CreateConVar("actionrecorder_model", "models/dav0r/camera.mdl", { FCVAR_ARCHIVE, FCVAR_REPLICATED })
    CreateConVar("actionrecorder_boxid", "Box", { FCVAR_ARCHIVE, FCVAR_REPLICATED })
    CreateConVar("actionrecorder_globalmode", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED })
    CreateConVar("actionrecorder_soundpath", "buttons/button1.wav", { FCVAR_ARCHIVE, FCVAR_REPLICATED })
else
    CreateClientConVar("actionrecorder_playbackspeed", "1", true, true)
    CreateClientConVar("actionrecorder_loop", "0", true, true)
    CreateClientConVar("actionrecorder_playbacktype", "absolute", true, true)
    CreateClientConVar("actionrecorder_model", "models/dav0r/camera.mdl", true, true)
    CreateClientConVar("actionrecorder_boxid", "Box", true, true)
    CreateClientConVar("actionrecorder_globalmode", "0", true, true)
    CreateClientConVar("actionrecorder_key", "", true, true)
    CreateClientConVar("actionrecorder_soundpath", "buttons/button1.wav", true, true)
end

local function vectorsDifferent(a, b)
    return not a or not b or a.x ~= b.x or a.y ~= b.y or a.z ~= b.z
end
local function anglesDifferent(a, b)
    return not a or not b or a.p ~= b.p or a.y ~= b.y or a.r ~= b.r
end

local function StopPropRecording(ply, prop)
    if not IsValid(prop) then return end
    prop.ActionRecorder_Recording = false
    timer.Remove("ActionRecorder_Prop_"..(IsValid(ply) and ply:EntIndex() or 0).."_"..prop:EntIndex())
end

local function IsPropControlledByOtherBox(prop, myBoxID)
    for _, box in pairs(ents.FindByClass("action_playback_box")) do
        if IsValid(box) and box.BoxID ~= myBoxID and box.IsPlayingBack and istable(box.PlaybackData) then
            for k, _ in pairs(box.PlaybackData) do
                if k == prop:EntIndex() then
                    return true
                end
            end
        end
    end
    return false
end

local function StartPropRecording(ply, prop, boxid)
    if prop.ActionRecorder_Recording then return end

    ply.ActionRecordData = ply.ActionRecordData or {}
    local id = prop:EntIndex()
    ply.ActionRecordData[id] = {}
    prop.ActionRecorder_Recording = true
    local timerName = "ActionRecorder_Prop_"..ply:EntIndex().."_"..id

    timer.Create(timerName, 0.02, 0, function()
        if not IsValid(prop) or not IsValid(ply) or not ply.ActionRecorderEnabled or not ply.ActionRecordData then
            StopPropRecording(ply, prop)
            return
        end

        if not ply.ActionRecordData[id] then return end

        local last = ply.ActionRecordData[id][#ply.ActionRecordData[id]]
        local cur = {
            pos = prop:GetPos(),
            ang = prop:GetAngles(),
            time = CurTime(),
            material = prop:GetMaterial(),
            color = prop:GetColor(),
            renderfx = prop:GetRenderFX(),
            rendermode = prop:GetRenderMode(),
            skin = prop:GetSkin(),
            bodygroups = (function()
                local t = {}
                for k,v in pairs(prop:GetBodyGroups() or {}) do
                    t[v.id] = prop:GetBodygroup(v.id)
                end
                return t
            end)()
        }

        local changed = false
        if not last or vectorsDifferent(last.pos, cur.pos) or anglesDifferent(last.ang, cur.ang)
            or last.material ~= cur.material
            or last.skin ~= cur.skin
            or last.rendermode ~= cur.rendermode
            or last.renderfx ~= cur.renderfx then
            changed = true
        elseif last.color and cur.color and (last.color.r ~= cur.color.r or last.color.g ~= cur.color.g or last.color.b ~= cur.color.b or last.color.a ~= cur.color.a) then
            changed = true
        else
            for id, val in pairs(cur.bodygroups) do
                if not last.bodygroups or last.bodygroups[id] ~= val then
                    changed = true
                    break
                end
            end
        end

        if changed then
            table.insert(ply.ActionRecordData[id], cur)
        end
    end)
end

hook.Add("EntityRemoved", "ActionRecorder_EntityRemoved", function(ent)
    if ent.ActionRecorder_Recording then
        StopPropRecording(nil, ent)
    end
end)

hook.Add("Think", "ActionRecorder_Think", function()
    for _, ply in pairs(player.GetAll()) do
        if ply.ActionRecorderEnabled then
            local globalMode = GetConVar("actionrecorder_globalmode"):GetBool()
            local boxid
            if globalMode and ply:IsAdmin() then
                boxid = GetConVar("actionrecorder_boxid"):GetString() or "Box"
            else
                boxid = ply:GetInfo("actionrecorder_boxid") or "Box"
            end
            for _, ent in pairs(ents.GetAll()) do
                if IsValid(ent) and not ent:IsPlayer() and not ent.ActionRecorder_Recording then
                    if ent.GetCreator and ent:GetCreator() == ply and not IsPropControlledByOtherBox(ent, boxid) then
                        local phys = ent:GetPhysicsObject()
                        if IsValid(phys) then
                            StartPropRecording(ply, ent, boxid)
                        end
                    end
                end
            end
        end
    end
end)

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    ply.ActionRecorderEnabled = not ply.ActionRecorderEnabled

    local globalMode = GetConVar("actionrecorder_globalmode"):GetBool()
    local boxid
    if globalMode and ply:IsAdmin() then
        boxid = GetConVar("actionrecorder_boxid"):GetString() or "Box"
    else
        boxid = ply:GetInfo("actionrecorder_boxid") or "Box"
    end

    if ply.ActionRecorderEnabled then
        ply.ActionRecordData = {}

        for _, ent in pairs(ents.GetAll()) do
            if IsValid(ent) and not ent:IsPlayer() then
                if ent.GetCreator and ent:GetCreator() == ply and not IsPropControlledByOtherBox(ent, boxid) then
                    local phys = ent:GetPhysicsObject()
                    if IsValid(phys) then
                        StartPropRecording(ply, ent, boxid)
                    end
                end
            end
        end

        ply:ChatPrint("Recording enabled! Only your props will record (and not props already controlled by other boxes).")
    else
        ply:ChatPrint("Recording disabled! Right click to place playback box / update settings.")
    end
    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    local globalMode = GetConVar("actionrecorder_globalmode"):GetBool()
    local speed, loop, playbackType, model, boxid, key, soundpath

    if globalMode and ply:IsAdmin() then
        speed = tonumber(GetConVar("actionrecorder_playbackspeed"):GetString()) or 1
        loop = GetConVar("actionrecorder_loop"):GetInt()
        playbackType = GetConVar("actionrecorder_playbacktype"):GetString() or "absolute"
        model = GetConVar("actionrecorder_model"):GetString() or "models/dav0r/camera.mdl"
        boxid = GetConVar("actionrecorder_boxid"):GetString() or "Box"
        key = GetConVar("actionrecorder_key"):GetInt()
        soundpath = GetConVar("actionrecorder_soundpath"):GetString()
    else
        speed = ply:GetInfoNum("actionrecorder_playbackspeed", 1)
        loop = ply:GetInfoNum("actionrecorder_loop", 0)
        playbackType = ply:GetInfo("actionrecorder_playbacktype") or "absolute"
        model = ply:GetInfo("actionrecorder_model") or "models/dav0r/camera.mdl"
        boxid = ply:GetInfo("actionrecorder_boxid") or "Box"
        key = ply:GetInfoNum("actionrecorder_key", 5)
        soundpath = ply:GetInfo("actionrecorder_soundpath")
    end

    local updated = false
    for _, ent in pairs(ents.FindByClass("action_playback_box")) do
        local entBoxID = ent.BoxID or (ent.GetNWString and ent:GetNWString("BoxID", ""))
        if IsValid(ent) and entBoxID == boxid then
            ent:UpdateSettings(speed, loop, playbackType, model, boxid, soundpath)
            ent.NumpadKey = key
            if SERVER then ent:SetupNumpad() end
            updated = true
        end
    end

    if updated then
        ply:ChatPrint("Playback box(es) with BoxID '"..boxid.."' updated with new settings!")
        return true
    end

    if not ply.ActionRecordData or table.Count(ply.ActionRecordData) == 0 then
        ply:ChatPrint("No recording found!")
        return false
    end

    local ent = ents.Create("action_playback_box")
    if not IsValid(ent) then return false end
    ent:SetPos(trace.HitPos + Vector(0,0,10))
    ent:Spawn()

    ent:SetPlaybackData(ply.ActionRecordData)
    ent:SetPlaybackSettings(speed, loop, playbackType)
    ent:SetModelPath(model)
    ent:SetBoxID(boxid)
    ent:SetOwnerName(ply:Nick() or "Unknown")
    ent.NumpadKey = key
    ent:SetSoundPath(soundpath)
    if SERVER then ent:SetupNumpad() end

    undo.Create("Action Playback Box")
        undo.AddEntity(ent)
        undo.SetPlayer(ply)
    undo.Finish()

    ply:ChatPrint("Playback box placed! Press E on it to start playback.")
    ply.ActionRecordData = nil
    return true
end

function TOOL.BuildCPanel(panel)
    panel:Help("Playback Speed (negative = reverse)")
    panel:NumSlider("Playback Speed", "actionrecorder_playbackspeed", -500, 500, 2):SetDecimals(2)
    panel:Help("Loop Mode")
    local loop_combo = panel:ComboBox("Loop Mode", "actionrecorder_loop")
    loop_combo:AddChoice("No Loop", 0, true)
    loop_combo:AddChoice("Loop", 1)
    loop_combo:AddChoice("Ping-Pong", 2)
    panel:Help("Playback Type")
    local combo = panel:ComboBox("Playback Type", "actionrecorder_playbacktype")
    combo:AddChoice("absolute", "absolute", true)
    combo:AddChoice("relative", "relative")
    panel:Help("Model Path")
    panel:TextEntry("Model", "actionrecorder_model")
    panel:Help("Playback Box ID / Name")
    panel:TextEntry("Box ID", "actionrecorder_boxid")
    panel:Help("Activation Sound")
    panel:TextEntry("Sound Path", "actionrecorder_soundpath")
    panel:Help("Keybind")
    panel:KeyBinder("Playback Key", "actionrecorder_key")
end