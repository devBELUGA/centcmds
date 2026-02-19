local installerUrl = "https://raw.githubusercontent.com/devBELUGA/centcmds/main/download.lua"
local tempInstaller = "/.centcmds_installer.lua"
local removeTargets = {
    "/compios",
    "/centcmds.lua"
}

if not http then
    printError("HTTP API is disabled. Enable it in ComputerCraft config.")
    return
end

print("Reinstalling centcmds and CompiOS...")

for i = 1, #removeTargets do
    local path = removeTargets[i]
    if fs.exists(path) then
        fs.delete(path)
    end
end

if fs.exists(tempInstaller) then
    fs.delete(tempInstaller)
end

local downloaded = shell.run("wget", installerUrl, tempInstaller)
if not downloaded or not fs.exists(tempInstaller) then
    printError("Failed to download installer: " .. installerUrl)
    return
end

local ok = shell.run(tempInstaller)

if fs.exists(tempInstaller) then
    fs.delete(tempInstaller)
end

if not ok then
    printError("Reinstall failed.")
end
