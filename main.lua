local rootTerm = term.current()
local oldTextColor = term.getTextColor()
local oldBackgroundColor = term.getBackgroundColor()
local oldCursorBlink = term.getCursorBlink()

term.setCursorBlink(false)

local runningProgram = shell.getRunningProgram() or "main.lua"
local baseDir = fs.getDir(runningProgram)

local function fromBase(relativePath)
    if baseDir == "" then
        return relativePath
    end
    return fs.combine(baseDir, relativePath)
end

local function loadModule(relativePath)
    local fullPath = fromBase(relativePath)
    local chunk, err = loadfile(fullPath)
    if not chunk then
        error("Cannot load module '" .. relativePath .. "': " .. tostring(err))
    end

    local module = chunk()
    if type(module) ~= "table" then
        error("Module '" .. relativePath .. "' must return a table")
    end

    return module
end

local function pullEvent(filter)
    return os.pullEventRaw(filter)
end

local function run()
    local ui = loadModule("gui/ui.lua")
    local boot = loadModule("core/boot.lua")
    local loading = loadModule("core/loading.lua")
    local desktop = loadModule("gui/desktop.lua")
    local browserAppFactory = loadModule("apps/browser.lua")
    local terminalAppFactory = loadModule("apps/terminal.lua")
    local snakeAppFactory = loadModule("apps/snake.lua")

    local appList = {
        { id = "browser", app = browserAppFactory.new(ui) },
        { id = "terminal", app = terminalAppFactory.new(ui) },
        { id = "snake", app = snakeAppFactory.new(ui) }
    }

    local menuChoice = boot.run(ui, pullEvent)
    if menuChoice ~= 1 then
        return
    end

    local loadingTasks = {
        {
            label = "Checking CC:Tweaked APIs",
            run = function()
                assert(type(window) == "table", "window API missing")
                assert(type(paintutils) == "table", "paintutils API missing")
                assert(type(shell) == "table", "shell API missing")
                assert(type(fs) == "table", "filesystem API missing")
            end
        },
        {
            label = "Checking CompiOS files",
            run = function()
                local required = {
                    "main.lua",
                    "core/boot.lua",
                    "core/loading.lua",
                    "gui/ui.lua",
                    "gui/desktop.lua",
                    "apps/browser.lua",
                    "apps/terminal.lua",
                    "apps/snake.lua"
                }
                for i = 1, #required do
                    local path = fromBase(required[i])
                    assert(fs.exists(path), "Missing file: " .. required[i])
                end
            end
        },
        {
            label = "Registering desktop apps",
            run = function()
                for i = 1, #appList do
                    local item = appList[i]
                    assert(item.app and item.app.draw and item.app.handle, "Invalid app: " .. item.id)
                end
            end
        },
        {
            label = "Seeding random generator",
            run = function()
                local seed = os.epoch and os.epoch("utc") or (os.time() * 1000)
                math.randomseed(seed)
                for _ = 1, 12 do
                    math.random()
                end
            end
        },
        {
            label = "Preparing GUI session",
            run = function()
                local width, height = term.getSize()
                assert(width >= 20 and height >= 12, "Terminal too small for CompiOS")
            end
        }
    }

    local loadingOk = loading.run(ui, loadingTasks, pullEvent)
    if not loadingOk then
        return
    end

    desktop.run(ui, appList, pullEvent)
end

local ok, err = pcall(run)

term.redirect(rootTerm)
term.setTextColor(oldTextColor)
term.setBackgroundColor(oldBackgroundColor)
term.setCursorBlink(oldCursorBlink)
term.clear()
term.setCursorPos(1, 1)

if not ok and tostring(err) ~= "Terminated" then
    printError(err)
end
