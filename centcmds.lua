local currentProgram = shell.getRunningProgram()
local programDir = fs.getDir(currentProgram)
local mainPath = fs.combine(programDir, "main.lua")

shell.run(mainPath)
