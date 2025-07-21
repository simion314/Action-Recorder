TOOL.Category = "Construction"
TOOL.Name = "#Action Recorder"
TOOL.Mode = "actionrecorder"

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
    CreateConVar("actionrecorder_easing", "Linear", { FCVAR_ARCHIVE, FCVAR_REPLICATED })
    CreateConVar("actionrecorder_easing_amplitude", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED })
    CreateConVar("actionrecorder_easing_frequency", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED })
    CreateConVar("actionrecorder_easing_invert", "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED })
    CreateConVar("actionrecorder_easing_offset", "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED })
else
    CreateClientConVar("actionrecorder_playbackspeed", "1", true, true)
    CreateClientConVar("actionrecorder_loop", "0", true, true)
    CreateClientConVar("actionrecorder_playbacktype", "absolute", true, true)
    CreateClientConVar("actionrecorder_model", "models/dav0r/camera.mdl", true, true)
    CreateClientConVar("actionrecorder_boxid", "Box", true, true)
    CreateClientConVar("actionrecorder_globalmode", "0", true, true)
    CreateClientConVar("actionrecorder_key", "", true, true)
    CreateClientConVar("actionrecorder_soundpath", "buttons/button1.wav", true, true)
    CreateClientConVar("actionrecorder_easing", "Linear", true, true)
    CreateClientConVar("actionrecorder_easing_amplitude", "1", true, true)
    CreateClientConVar("actionrecorder_easing_frequency", "1", true, true)
    CreateClientConVar("actionrecorder_easing_invert", "0", true, true)
    CreateClientConVar("actionrecorder_easing_offset", "0", true, true)
end

if SERVER then
    util.AddNetworkString("ActionRecorder_PlayStartSound")
	util.AddNetworkString("ActionRecorder_PlayLoopSound")
    util.AddNetworkString("ActionRecorder_PlayStopSound")
	util.AddNetworkString("ActionRecorder_StopLoopSound")
	util.AddNetworkString("ActionRecorderNotify")
    util.AddNetworkString("ActionRecorder_FlashEffect")
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
    return ActionRecorder.ActivePlaybacks and ActionRecorder.ActivePlaybacks[prop:EntIndex()] ~= nil
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
    if SERVER then
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

            net.Start("ActionRecorder_PlayStartSound")
            net.Send(ply)

            net.Start("ActionRecorder_PlayLoopSound")
            net.Send(ply)

            net.Start("ActionRecorderNotify")
            net.WriteString("Recording enabled!")
            net.WriteInt(3, 3)
            net.Send(ply)

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

            umsg.Start("ActionRecorder_ToggleRecording", ply)
            umsg.Bool(true)
            umsg.End()

            if GetConVar("ar_enable_filmgrain"):GetBool() then
                net.Start("ActionRecorder_FlashEffect")
                net.Send(ply)
            end

        else
            net.Start("ActionRecorder_PlayStopSound")
            net.Send(ply)

            net.Start("ActionRecorder_StopLoopSound")  
            net.Send(ply)

            if GetConVar("ar_enable_filmgrain"):GetBool() then
                net.Start("ActionRecorder_FlashEffect")
                net.Send(ply)
            end

            net.Start("ActionRecorderNotify")
            net.WriteString("Recording disabled! Right click to place playback box / update settings.")
            net.WriteInt(3, 3)
            net.Send(ply)

            umsg.Start("ActionRecorder_ToggleRecording", ply)
            umsg.Bool(false)
            umsg.End()
        end
    end

    return true
end








function TOOL:RightClick(trace)
    if CLIENT then return true end

    local ply = self:GetOwner()
    local globalMode = GetConVar("actionrecorder_globalmode"):GetBool()
    local speed, loop, playbackType, model, boxid, key, soundpath, easing, easing_amplitude, easing_frequency, easing_invert, easing_offset

    if globalMode and ply:IsAdmin() then
        speed = tonumber(GetConVar("actionrecorder_playbackspeed"):GetString()) or 1
        loop = GetConVar("actionrecorder_loop"):GetInt()
        playbackType = GetConVar("actionrecorder_playbacktype"):GetString() or "absolute"
        model = GetConVar("actionrecorder_model"):GetString() or "models/dav0r/camera.mdl"
        boxid = GetConVar("actionrecorder_boxid"):GetString() or "Box"
        key = GetConVar("actionrecorder_key"):GetInt()
        soundpath = GetConVar("actionrecorder_soundpath"):GetString()
        easing = GetConVar("actionrecorder_easing"):GetString() or "Linear"
        easing_amplitude = GetConVar("actionrecorder_easing_amplitude"):GetFloat()
        easing_frequency = GetConVar("actionrecorder_easing_frequency"):GetFloat()
        easing_invert = GetConVar("actionrecorder_easing_invert"):GetBool()
        easing_offset = GetConVar("actionrecorder_easing_offset"):GetFloat()
    else
        speed = ply:GetInfoNum("actionrecorder_playbackspeed", 1)
        loop = ply:GetInfoNum("actionrecorder_loop", 0)
        playbackType = ply:GetInfo("actionrecorder_playbacktype") or "absolute"
        model = ply:GetInfo("actionrecorder_model") or "models/dav0r/camera.mdl"
        boxid = ply:GetInfo("actionrecorder_boxid") or "Box"
        key = ply:GetInfoNum("actionrecorder_key", 5)
        soundpath = ply:GetInfo("actionrecorder_soundpath")
        easing = ply:GetInfo("actionrecorder_easing") or "Linear"
        easing_amplitude = ply:GetInfoNum("actionrecorder_easing_amplitude", 1)
        easing_frequency = ply:GetInfoNum("actionrecorder_easing_frequency", 1)
        easing_invert = ply:GetInfoNum("actionrecorder_easing_invert", 0) == 1
        easing_offset = ply:GetInfoNum("actionrecorder_easing_offset", 0)
    end

    local found_box_owned = nil
    for _, ent in pairs(ents.FindByClass("action_playback_box")) do
        local entBoxID = ent.GetNWString and ent:GetNWString("BoxID", "") or (ent.BoxID or "")
        local entOwner = ent.GetOwner and ent:GetOwner() or nil
        if IsValid(ent) and entBoxID == boxid then
            if entOwner ~= ply then
                net.Start("ActionRecorderNotify")
                net.WriteString("BoxID is already in use by another player!")
                net.WriteInt(3, 3)
                net.Send(ply)
                return false
            else
                found_box_owned = ent
            end
        end
    end

    if found_box_owned then
        found_box_owned:UpdateSettings(speed, loop, playbackType, model, boxid, soundpath, easing, easing_amplitude, easing_frequency, easing_invert, easing_offset)
        found_box_owned.NumpadKey = key
        if SERVER then found_box_owned:SetupNumpad() end
        net.Start("ActionRecorderNotify")
        net.WriteString("Playback box with BoxID '" .. boxid .. "' updated with new settings!")
        net.WriteInt(3, 3) 
        net.Send(ply)
        return true
    end

    if not ply.ActionRecordData or table.Count(ply.ActionRecordData) == 0 then
        net.Start("ActionRecorderNotify")
        net.WriteString("No recording found!")
        net.WriteInt(3, 3)
        net.Send(ply)
        return false
    end

    local ent = ents.Create("action_playback_box")
    if not IsValid(ent) then return false end

    ent:SetPos(trace.HitPos + Vector(0, 0, 10))
    ent:Spawn()
    ent:SetPlaybackData(ply.ActionRecordData)
    ent:SetPlaybackSettings(speed, loop, playbackType, easing, easing_amplitude, easing_frequency, easing_invert, easing_offset)
    ent:SetModelPath(model)
    ent:SetBoxID(boxid)
    ent:SetOwner(ply)
    ent:SetOwnerName(ply:Nick() or "Unknown")
    ent.NumpadKey = key
    ent:SetSoundPath(soundpath)
    if SERVER then ent:SetupNumpad() end

    undo.Create("Action Playback Box")
        undo.AddEntity(ent)
        undo.SetPlayer(ply)
    undo.Finish()

    net.Start("ActionRecorderNotify")
    net.WriteString("Playback box placed! Press E on it to start playback.")
    net.WriteInt(3, 3)
    net.Send(ply)

    ply.ActionRecordData = nil

    return true
end






if CLIENT then
    include("vgui/action_recorder_graph_editor.lua")

    local isRecording = false

    usermessage.Hook("ActionRecorder_ToggleRecording", function(um)
        isRecording = um:ReadBool()
    end)

    hook.Add("HUDPaint", "ActionRecorder_HUDPaint", function()
        local ply = LocalPlayer()
        if ply:GetTool("actionrecorder") and isRecording then
            if GetConVar("ar_enable_filmgrain"):GetBool() then
                -- Apply film-like effect
                -- Subtle sepia tone
                DrawColorModify({
                    ["$pp_colour_addr"] = 0,
                    ["$pp_colour_addg"] = 0,
                    ["$pp_colour_addb"] = 0,
                    ["$pp_colour_contrast"] = 1.0,
                    ["$pp_colour_brightness"] = 0.0,
                    ["$pp_colour_desaturation"] = 0.05, -- Even more subtle desaturation
                    ["$pp_colour_mulr"] = 1.0,
                    ["$pp_colour_mulg"] = 0.95, -- Less green tint
                    ["$pp_colour_mulb"] = 0.9,  -- Less blue tint
                })

                -- Film grain overlay using noise.vmt
                local noiseMaterial = Material("overlays/noise.vmt")
                if noiseMaterial and not noiseMaterial:IsError() then
                    render.SetMaterial(noiseMaterial)
                    render.DrawScreenQuad()
                end

                -- Additive noise overlay using noiseadd.vmt for enhanced effect
                local noiseAddMaterial = Material("overlays/noiseadd.vmt")
                if noiseAddMaterial and not noiseAddMaterial:IsError() then
                    render.SetMaterial(noiseAddMaterial)
                    render.DrawScreenQuad()
                end
            end

            

            if GetConVar("ar_enable_hud"):GetBool() then
                -- Draw the recording HUD element (on top)
                local material = Material("vgui/action_recorder_hud_rec.png")
                if not material or material:IsError() then return end

                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(material)
                surface.DrawTexturedRect(ScrW() - 450, 0, 500, 300)
            end
        end
    end)
end

function TOOL.BuildCPanel(panel)
    local color_red    = Color(222, 33, 16)
    local color_yellow = Color(252, 209, 22)
    local color_blue   = Color(0, 61, 165)

    local function colorHeader(form, col)
        timer.Simple(0, function()
            if not IsValid(form) or not IsValid(form.Header) then return end
            form.Header.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, col)
                
            end
        end)
    end

    local signature = vgui.Create("DImage", panel)
    signature:SetImage("vgui/action_recorder_signature.png")
    signature:SetSize(340, 179)
    signature:Dock(TOP)
    signature:DockMargin(0, -30, 0, -5)
    signature:SetKeepAspect(true)
    panel:AddItem(signature)

    local sectionDividerGeneral = vgui.Create("DPanel", panel)
    sectionDividerGeneral:SetTall(2)
    sectionDividerGeneral:SetBackgroundColor(Color(50, 50, 50, 200))
    sectionDividerGeneral:Dock(TOP)
    sectionDividerGeneral:DockMargin(0, 2, 0, 2)
    panel:AddItem(sectionDividerGeneral)

    
    local generalSettingsForm = vgui.Create("DForm", panel)
    generalSettingsForm:SetName("General Settings")
    generalSettingsForm:Dock(TOP)
    generalSettingsForm:DockMargin(0, 2, 0, 2)
    panel:AddItem(generalSettingsForm)
    colorHeader(generalSettingsForm, color_red)
    generalSettingsForm:NumSlider("Playback Speed", "actionrecorder_playbackspeed", -500, 500, 2):SetDecimals(2)
    local loop_combo = generalSettingsForm:ComboBox("Loop Mode", "actionrecorder_loop")
    loop_combo:AddChoice("No Loop", 0, true)
    loop_combo:AddChoice("Loop", 1)
    loop_combo:AddChoice("Ping-Pong", 2)
    loop_combo:AddChoice("No Loop (Smooth)", 3)
    local combo = generalSettingsForm:ComboBox("Playback Type", "actionrecorder_playbacktype")
    combo:AddChoice("absolute", "absolute", true)
    combo:AddChoice("relative", "relative")
    generalSettingsForm:TextEntry("Model", "actionrecorder_model")
    generalSettingsForm:TextEntry("Playback Box ID", "actionrecorder_boxid")
    generalSettingsForm:TextEntry("Activation Sound", "actionrecorder_soundpath")
    generalSettingsForm:CheckBox("Physicsless Teleport", "ar_physicsless_teleport")
    local keyBinder = vgui.Create("DBinder")
    keyBinder:SetConVar("actionrecorder_key")
    generalSettingsForm:AddItem(keyBinder)

    local sectionDivider = vgui.Create("DPanel", panel)
    sectionDivider:SetTall(2)
    sectionDivider:SetBackgroundColor(Color(50, 50, 50, 200))
    sectionDivider:Dock(TOP)
    sectionDivider:DockMargin(0, 2, 0, 2)
    panel:AddItem(sectionDivider)

    
    local easingSettingsForm = vgui.Create("DForm", panel)
    easingSettingsForm:SetName("Easing Settings")
    easingSettingsForm:Dock(TOP)
    easingSettingsForm:DockMargin(0, 2, 0, 2)
    panel:AddItem(easingSettingsForm)
    colorHeader(easingSettingsForm, color_yellow)
    local easingHelpLabel = vgui.Create("DLabel", easingSettingsForm)
    easingHelpLabel:SetText("Easing is an experimental feature and may not always work as intended.")
    easingHelpLabel:SetTextColor(Color(0, 0, 128))
    easingHelpLabel:SetWrap(true)
    easingSettingsForm:AddItem(easingHelpLabel)
    local easing_combo = easingSettingsForm:ComboBox("Easing", "actionrecorder_easing")
    for name, _ in pairs(ActionRecorder.EasingFunctions) do
        easing_combo:AddChoice(name)
    end
    local easingComboHelpLabel = vgui.Create("DLabel", easingSettingsForm)
    easingComboHelpLabel:SetText("To use a custom easing graph, set the Easing type to \"Custom\".")
    easingComboHelpLabel:SetTextColor(Color(0, 0, 128))
    easingComboHelpLabel:SetWrap(true)
    easingSettingsForm:AddItem(easingComboHelpLabel)
    local custom_easing_button = easingSettingsForm:Button("Edit Custom Easing", "actionrecorder_edit_custom_easing")
    custom_easing_button:SetSize(150, 20)
    custom_easing_button:SetImage("icon16/page_white_edit.png")
    custom_easing_button:SetTooltip("To use an easing type that utilizes the graph you made in the editor, set the easing type to the \"Custom\" option")
    custom_easing_button.DoClick = function()
        vgui.Create("ActionRecorderGraphEditor")
    end
    easingSettingsForm:NumSlider("Easing Amplitude", "actionrecorder_easing_amplitude", 0, 10, 2)
    easingSettingsForm:NumSlider("Easing Frequency", "actionrecorder_easing_frequency", 0, 10, 2)
    easingSettingsForm:CheckBox("Invert Easing", "actionrecorder_easing_invert")
    easingSettingsForm:NumSlider("Easing Offset", "actionrecorder_easing_offset", -1, 1, 2)

    local sectionDivider2 = vgui.Create("DPanel", panel)
    sectionDivider2:SetTall(2)
    sectionDivider2:SetBackgroundColor(Color(50, 50, 50, 200))
    sectionDivider2:Dock(TOP)
    sectionDivider2:DockMargin(0, 5, 0, 5)
    panel:AddItem(sectionDivider2)

    
    local clientSettingsForm = vgui.Create("DForm", panel)
    clientSettingsForm:SetName("Client Settings")
    clientSettingsForm:Dock(TOP)
    clientSettingsForm:DockMargin(0, 5, 0, 5)
    panel:AddItem(clientSettingsForm)
    colorHeader(clientSettingsForm, color_blue)
    clientSettingsForm:CheckBox("Enable HUD", "ar_enable_hud")
    clientSettingsForm:CheckBox("Enable Custom Placement Sounds", "ar_enable_sounds")
    clientSettingsForm:CheckBox("Enable Film Grain Effect", "ar_enable_filmgrain")
end




function TOOL:GetSetConVars(ply)
    local globalMode = GetConVar("actionrecorder_globalmode"):GetBool()
    local cvars = {
        "actionrecorder_playbackspeed",
        "actionrecorder_loop",
        "actionrecorder_playbacktype",
        "actionrecorder_model",
        "actionrecorder_boxid",
        "actionrecorder_key",
        "actionrecorder_soundpath",
        "actionrecorder_startsound",
        "actionrecorder_stopsound",
        "actionrecorder_hudmaterial",
        "actionrecorder_easing",
        "actionrecorder_easing_amplitude",
        "actionrecorder_easing_frequency",
        "actionrecorder_easing_invert",
        "actionrecorder_easing_offset"
    }

    local settings = {}
    for _, cvar in ipairs(cvars) do
        if globalMode and ply:IsAdmin() then
            settings[cvar] = GetConVar(cvar):GetString()
        else
            settings[cvar] = ply:GetInfo(cvar)
        end
    end
    return settings
end

function TOOL:ApplyConVars(ply, settings)
    local globalMode = GetConVar("actionrecorder_globalmode"):GetBool()
    for cvar, val in pairs(settings) do
        if globalMode and ply:IsAdmin() then
            RunConsoleCommand(cvar, val)
        else
            ply:SetInfo(cvar, val)
        end
    end
end

function TOOL:Holster()
    if CLIENT then
        if IsValid(self.CustomEasingEditor) then
            self.CustomEasingEditor:Close()
        end
    end
end

local function GetEasingFunction(name)
    return ActionRecorder.EasingFunctions[name]
end

if CLIENT then
    ActionRecorder = ActionRecorder or {}
    ActionRecorder.EasingFunctions = ActionRecorder.EasingFunctions or {}
    ActionRecorder.EasingFunctions["Linear"] = function(t, amp, freq, inv, offset) return t end
    ActionRecorder.EasingFunctions["Sine"] = function(t, amp, freq, inv, offset) return math.sin(t * math.pi * freq + offset) * amp end
    ActionRecorder.EasingFunctions["Quadratic"] = function(t, amp, freq, inv, offset) return t*t * amp end
    ActionRecorder.EasingFunctions["Cubic"] = function(t, amp, freq, inv, offset) return t*t*t * amp end
    ActionRecorder.EasingFunctions["Quartic"] = function(t, amp, freq, inv, offset) return t*t*t*t * amp end
    ActionRecorder.EasingFunctions["Quintic"] = function(t, amp, freq, inv, offset) return t*t*t*t*t * amp end
    ActionRecorder.EasingFunctions["Exponential"] = function(t, amp, freq, inv, offset) return math.pow(2, 10 * (t - 1)) * amp end
    ActionRecorder.EasingFunctions["Circular"] = function(t, amp, freq, inv, offset) return math.sqrt(1 - (t-1)*(t-1)) * amp end
    ActionRecorder.EasingFunctions["Elastic"] = function(t, amp, freq, inv, offset)
        if t == 0 or t == 1 then return t end
        local p = .3
        local s = p / 4
        return amp * math.pow(2, -10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
    end
    ActionRecorder.EasingFunctions["Back"] = function(t, amp, freq, inv, offset)
        local s = 1.70158
        return amp * (t*t*((s+1)*t - s))
    end
    ActionRecorder.EasingFunctions["Bounce"] = function(t, amp, freq, inv, offset)
        if t < (1/2.75) then
            return amp * (7.5625*t*t)
        elseif t < (2/2.75) then
            t = t - (1.5/2.75)
            return amp * (7.5625*t*t + .75)
        elseif t < (2.5/2.75) then
            t = t - (2.25/2.75)
            return amp * (7.5625*t*t + .9375)
        else
            t = t - (2.625/2.75)
            return amp * (7.5625*t*t + .984375)
        end
    end
    ActionRecorder.EasingFunctions["Custom"] = function(t, amp, freq, inv, offset)
        local points = ActionRecorder.CustomEasingPoints or {{x = 0, y = 0}, {x = 1, y = 1}}

        -- Ensure points are sorted by x (should already be from VGUI, but good to be safe)
        table.sort(points, function(a, b) return a.x < b.x end)

        -- Handle edge cases for t outside the defined range of points
        if t <= points[1].x then
            return points[1].y * amp
        end
        if t >= points[#points].x then
            return points[#points].y * amp
        end

        local y_val = 0
        for i = 1, #points - 1 do
            local p1 = points[i]
            local p2 = points[i+1]

            if t >= p1.x and t <= p2.x then
                local range_x = p2.x - p1.x
                local range_y = p2.y - p1.y
                local normalized_x = (t - p1.x) / range_x
                y_val = p1.y + normalized_x * range_y
                break
            end
        end
        return y_val * amp
    end

    net.Receive("ActionRecorder_PlayStartSound", function()
        if not GetConVar("ar_enable_sounds"):GetBool() then return end
        surface.PlaySound("action_recorder/start_recording.wav")
    end)

    net.Receive("ActionRecorder_PlayStopSound", function()
        if not GetConVar("ar_enable_sounds"):GetBool() then return end
        surface.PlaySound("action_recorder/stop_recording.wav")
    end)

    net.Receive("ActionRecorderNotify", function()
        local msg = net.ReadString()
        local typ = net.ReadInt(3)
        notification.AddLegacy(msg, typ, 5)
    end)

    
    local loopActive = false
    local LOOP_FILE = "action_recorder/recording_loop.wav"
    local LOOP_DURATION = 1.2

    local function PlayLoopSound()
        if not loopActive then return end
        surface.PlaySound(LOOP_FILE)
        timer.Simple(LOOP_DURATION, PlayLoopSound)
    end

    net.Receive("ActionRecorder_PlayLoopSound", function()
        if not GetConVar("ar_enable_sounds"):GetBool() then return end
        loopActive = true
        PlayLoopSound()
    end)

    net.Receive("ActionRecorder_StopLoopSound", function()
        loopActive = false
    end)

    local flashAlpha = 0
    local flashStartTime = 0
    local flashDuration = 0.2 -- seconds

    net.Receive("ActionRecorder_FlashEffect", function()
        flashAlpha = 255
        flashStartTime = CurTime()
    end)

    hook.Add("HUDPaint", "ActionRecorder_FlashEffectHUD", function()
        if flashAlpha > 0 then
            local elapsed = CurTime() - flashStartTime
            local progress = math.min(elapsed / flashDuration, 1)
            local currentAlpha = math.max(0, 255 * (1 - progress))

            surface.SetDrawColor(255, 255, 255, currentAlpha)
            surface.DrawRect(0, 0, ScrW(), ScrH())

            if progress >= 1 then
                flashAlpha = 0
            end
        end
    end)
end