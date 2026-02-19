local repoBase = "https://raw.githubusercontent.com/devBELUGA/centcmds/main/"
local installDir = "/compios"
local launcherPath = "/centcmds.lua"

local files = {
    { remote = repoBase .. "main.lua", localPath = fs.combine(installDir, "main.lua") },
    { remote = repoBase .. "centcmds.lua", localPath = fs.combine(installDir, "centcmds.lua") }
}

local function downloadFile(remotePath, localPath)
    if fs.exists(localPath) then
        fs.delete(localPath)
    end

    local ok = shell.run("wget", remotePath, localPath)
    return ok and fs.exists(localPath)
end

if not http then
    printError("HTTP API is disabled. Enable it in ComputerCraft config.")
    return
end

print("Installing CompiOS...")
fs.makeDir(installDir)

for i = 1, #files do
    local file = files[i]
    print(("Downloading %d/%d: %s"):format(i, #files, fs.getName(file.localPath)))
    local ok = downloadFile(file.remote, file.localPath)
    if not ok then
        printError("Failed to download: " .. file.remote)
        return
    end
end

local launcherContent = table.concat({
    "local osMain = \"/compios/main.lua\"",
    "if fs.exists(osMain) then",
    "    shell.run(osMain)",
    "else",
    "    printError(\"CompiOS is not installed. Run download.lua again.\")",
    "end",
    ""
}, "\n")

local launcherFile = fs.open(launcherPath, "w")
if not launcherFile then
    printError("Cannot create launcher at " .. launcherPath)
    return
end
launcherFile.write(launcherContent)
launcherFile.close()

print("CompiOS installed.")
print("Launcher command: centcmds")
print("Starting CompiOS...")
shell.run(fs.combine(installDir, "main.lua"))
