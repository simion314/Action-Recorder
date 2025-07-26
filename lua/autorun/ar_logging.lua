-- lua/autorun/ar_logging.lua
if (SERVER) then
    CreateConVar("ar_debug", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enable Action Recorder debug logging.")
else
    CreateClientConVar("ar_debug", "0", true, true)
end

function AR_Log(...)
    if not GetConVar("ar_debug"):GetBool() then return end

    local processedArgs = {}
    table.insert(processedArgs, string.format("[%.3f] ", CurTime()))

    for i = 1, select('#', ...) do
        local arg = select(i, ...)
        if type(arg) == "table" and arg.x and arg.y and arg.z then -- Likely a Vector
            table.insert(processedArgs, tostring(arg))
        elseif type(arg) == "table" and arg.p and arg.y and arg.r then -- Likely an Angle
            table.insert(processedArgs, tostring(arg))
        elseif type(arg) == "boolean" then
            table.insert(processedArgs, tostring(arg))
        elseif type(arg) == "number" then
            table.insert(processedArgs, tostring(arg))
        elseif type(arg) == "nil" then
            table.insert(processedArgs, "[nil]")
        else
            table.insert(processedArgs, arg)
        end
    end

    local logMessage = table.concat(processedArgs, "\t")

    if (SERVER) then
        MsgC(Color(255, 100, 100), "[AR DEBUG SERVER] ", Color(255, 255, 255), logMessage, "\n")
    else
        MsgC(Color(100, 100, 255), "[AR DEBUG CLIENT] ", Color(255, 255, 255), logMessage, "\n")
    end
end
