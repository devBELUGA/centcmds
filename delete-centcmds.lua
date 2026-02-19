local removeTargets = {
    "/compios",
    "/centcmds.lua",
    "/reinstall-centcmds.lua",
    "/update-centcmds.lua",
    "/.centcmds_installer.lua"
}

print("Deleting centcmds and CompiOS...")

for i = 1, #removeTargets do
    local path = removeTargets[i]
    if fs.exists(path) then
        fs.delete(path)
        print("Deleted: " .. path)
    end
end

if fs.exists("/delete-centcmds.lua") then
    fs.delete("/delete-centcmds.lua")
end

print("Delete completed.")
