if CLIENT then
    CreateClientConVar("ar_debug", "0", true, false, "Activare/dezactivare afișare mesaje de debug pentru Action Recorder")
else
    -- Server-side debug convar (off by default)
    CreateConVar("ar_debug", "0", { FCVAR_ARCHIVE }, "Enable/disable debug logging for Action Recorder")
end

function ARLog(...)
    local cvar = GetConVar("ar_debug")
    if not cvar or cvar:GetInt() == 0 then return end

    local args = {...}
    for i, v in ipairs(args) do
        if type(v) == "table" then
            PrintTable(v)
        else
            print(tostring(v))
        end
    end
end