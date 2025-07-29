
if CLIENT then
    CreateClientConVar("ar_debug", "1", true, false, "Activare/dezactivare afișare mesaje de debug pentru Action Recorder")
end

function ARLog(...)
    if GetConVar("ar_debug"):GetInt() then
        local args = {...}
        for i, v in ipairs(args) do
            if type(v) == "table" then
                PrintTable(v)
            else
                print(tostring(v))
            end
        end
    end
end


ARLog("Log Enabled")
