local oldTextColor = term.getTextColor()
local oldBackgroundColor = term.getBackgroundColor()
local oldCursorBlink = term.getCursorBlink()

term.setCursorBlink(false)

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function centeredX(text, width)
    return math.floor((width - #text) / 2) + 1
end

local function writeAt(x, y, text, textColor, backgroundColor)
    local width, height = term.getSize()
    if y < 1 or y > height then
        return
    end
    if x > width then
        return
    end

    local drawText = text
    if x < 1 then
        drawText = drawText:sub(2 - x)
        x = 1
    end
    if x + #drawText - 1 > width then
        drawText = drawText:sub(1, width - x + 1)
    end
    if #drawText == 0 then
        return
    end

    if textColor then
        term.setTextColor(textColor)
    end
    if backgroundColor then
        term.setBackgroundColor(backgroundColor)
    end

    term.setCursorPos(x, y)
    term.write(drawText)
end

local function clearWith(color)
    term.setBackgroundColor(color)
    term.clear()
    term.setCursorPos(1, 1)
end

local function fillRect(x1, y1, x2, y2, color)
    local width, height = term.getSize()
    x1 = clamp(x1, 1, width)
    x2 = clamp(x2, 1, width)
    y1 = clamp(y1, 1, height)
    y2 = clamp(y2, 1, height)

    if x2 < x1 or y2 < y1 then
        return
    end

    local segment = string.rep(" ", x2 - x1 + 1)
    term.setBackgroundColor(color)
    for y = y1, y2 do
        term.setCursorPos(x1, y)
        term.write(segment)
    end
end

local function inRect(x, y, x1, y1, x2, y2)
    return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

local function pullEvent(filter)
    return os.pullEventRaw(filter)
end

local function runTerminalApp()
    clearWith(colors.black)
    writeAt(1, 1, "CompiOS Terminal", colors.green, colors.black)
    writeAt(1, 2, "Type 'exit' to return.", colors.lightGray, colors.black)
    term.setCursorPos(1, 3)

    local history = {}

    while true do
        term.setTextColor(colors.lime)
        term.setBackgroundColor(colors.black)
        term.write("> ")

        term.setTextColor(colors.white)
        local command = read(nil, history, shell.complete)

        if command == "exit" then
            break
        end

        if command and command ~= "" then
            history[#history + 1] = command
            local ok = shell.run(command)
            if not ok then
                term.setTextColor(colors.red)
                print("Command failed.")
            end
        end
    end
end

local function runSnakeApp()
    local width, height = term.getSize()
    if width < 24 or height < 14 then
        clearWith(colors.black)
        writeAt(1, 1, "Snake needs at least 24x14 terminal size.", colors.red, colors.black)
        writeAt(1, 2, "Resize terminal and try again.", colors.lightGray, colors.black)
        writeAt(1, 4, "Press any key to return.", colors.gray, colors.black)
        pullEvent("key")
        return
    end

    local left = 3
    local top = 3
    local right = width - 2
    local bottom = height - 2

    local vectors = {
        up = { 0, -1 },
        down = { 0, 1 },
        left = { -1, 0 },
        right = { 1, 0 }
    }

    local opposite = {
        up = "down",
        down = "up",
        left = "right",
        right = "left"
    }

    local snake
    local food
    local direction
    local nextDirection
    local score
    local speed
    local gameOver

    local function snakeCellKey(x, y)
        return tostring(x) .. ":" .. tostring(y)
    end

    local function findFoodPosition()
        local occupied = {}
        for i = 1, #snake do
            occupied[snakeCellKey(snake[i].x, snake[i].y)] = true
        end

        for _ = 1, 300 do
            local fx = math.random(left + 1, right - 1)
            local fy = math.random(top + 1, bottom - 1)
            if not occupied[snakeCellKey(fx, fy)] then
                return { x = fx, y = fy }
            end
        end

        for y = top + 1, bottom - 1 do
            for x = left + 1, right - 1 do
                if not occupied[snakeCellKey(x, y)] then
                    return { x = x, y = y }
                end
            end
        end

        return nil
    end

    local function resetGame()
        local centerX = math.floor((left + right) / 2)
        local centerY = math.floor((top + bottom) / 2)

        snake = {
            { x = centerX, y = centerY },
            { x = centerX - 1, y = centerY },
            { x = centerX - 2, y = centerY }
        }

        direction = "right"
        nextDirection = "right"
        score = 0
        speed = 0.14
        gameOver = false
        food = findFoodPosition()
    end

    local function drawBoard()
        clearWith(colors.black)

        local title = "CompiOS Snake"
        writeAt(centeredX(title, width), 1, title, colors.green, colors.black)

        local info = "Score: " .. tostring(score) .. " | Arrows/WASD move | Q exit"
        writeAt(centeredX(info, width), 2, info, colors.lightGray, colors.black)

        fillRect(left, top, right, bottom, colors.gray)
        fillRect(left + 1, top + 1, right - 1, bottom - 1, colors.black)

        if food then
            writeAt(food.x, food.y, " ", colors.black, colors.red)
        end

        for i = 1, #snake do
            local part = snake[i]
            local partColor = (i == 1) and colors.lime or colors.green
            writeAt(part.x, part.y, " ", colors.black, partColor)
        end

        if gameOver then
            local line1 = "Game Over"
            local line2 = "Enter restart | Q exit"
            writeAt(centeredX(line1, width), math.floor(height / 2), line1, colors.red, colors.black)
            writeAt(centeredX(line2, width), math.floor(height / 2) + 1, line2, colors.white, colors.black)
        end
    end

    local function setDirection(newDirection)
        if not newDirection then
            return
        end
        if opposite[direction] == newDirection then
            return
        end
        nextDirection = newDirection
    end

    local function stepGame()
        direction = nextDirection

        local head = snake[1]
        local vector = vectors[direction]
        local nextHead = {
            x = head.x + vector[1],
            y = head.y + vector[2]
        }

        if nextHead.x <= left or nextHead.x >= right or nextHead.y <= top or nextHead.y >= bottom then
            gameOver = true
            return
        end

        local willGrow = food and nextHead.x == food.x and nextHead.y == food.y
        local collisionCheckTo = willGrow and #snake or (#snake - 1)

        for i = 1, collisionCheckTo do
            if snake[i].x == nextHead.x and snake[i].y == nextHead.y then
                gameOver = true
                return
            end
        end

        table.insert(snake, 1, nextHead)

        if willGrow then
            score = score + 1
            speed = math.max(0.06, speed - 0.004)
            food = findFoodPosition()
        else
            table.remove(snake)
        end
    end

    resetGame()
    drawBoard()
    local timerId = os.startTimer(speed)

    while true do
        local event, p1 = pullEvent()

        if event == "timer" and p1 == timerId then
            if not gameOver then
                stepGame()
                drawBoard()
                timerId = os.startTimer(speed)
            end
        elseif event == "key" then
            if p1 == keys.q then
                return
            end

            if gameOver then
                if p1 == keys.enter then
                    resetGame()
                    drawBoard()
                    timerId = os.startTimer(speed)
                end
            else
                if p1 == keys.up or p1 == keys.w then
                    setDirection("up")
                elseif p1 == keys.down or p1 == keys.s then
                    setDirection("down")
                elseif p1 == keys.left or p1 == keys.a then
                    setDirection("left")
                elseif p1 == keys.right or p1 == keys.d then
                    setDirection("right")
                end
            end
        elseif event == "term_resize" then
            width, height = term.getSize()
            if width < 24 or height < 14 then
                return
            end
            left = 3
            top = 3
            right = width - 2
            bottom = height - 2
            resetGame()
            drawBoard()
            timerId = os.startTimer(speed)
        elseif event == "terminate" then
            return
        end
    end
end

local appRegistry = {
    {
        id = "terminal",
        name = "CC Terminal",
        run = runTerminalApp
    },
    {
        id = "snake",
        name = "Snake",
        run = runSnakeApp
    }
}

local function renderBootMenu(selected)
    local width, height = term.getSize()
    clearWith(colors.black)

    local title = "CompiOS"
    local subtitle = "Boot Menu"
    local optionY = math.floor(height / 2) - 1

    writeAt(centeredX(title, width), math.max(2, optionY - 3), title, colors.green, colors.black)
    writeAt(centeredX(subtitle, width), math.max(3, optionY - 2), subtitle, colors.lightGray, colors.black)

    local options = { "1. Load OS", "2. Exit" }
    for i = 1, #options do
        local text
        local textColor
        if i == selected then
            text = ">< " .. options[i] .. " <"
            textColor = colors.white
        else
            text = "   " .. options[i] .. "  "
            textColor = colors.gray
        end
        writeAt(centeredX(text, width), optionY + i - 1, text, textColor, colors.black)
    end

    local hint = "Up/Down select | Enter confirm"
    writeAt(centeredX(hint, width), height - 1, hint, colors.gray, colors.black)
end

local function runBootMenu()
    local selected = 1
    while true do
        renderBootMenu(selected)

        local event, p1, p2, p3 = pullEvent()
        if event == "key" then
            if p1 == keys.up or p1 == keys.w then
                selected = math.max(1, selected - 1)
            elseif p1 == keys.down or p1 == keys.s then
                selected = math.min(2, selected + 1)
            elseif p1 == keys.enter then
                return selected
            end
        elseif event == "mouse_click" then
            local _, _, y = p1, p2, p3
            local _, height = term.getSize()
            local optionY = math.floor(height / 2) - 1
            if y == optionY then
                return 1
            elseif y == optionY + 1 then
                return 2
            end
        elseif event == "terminate" then
            return 2
        end
    end
end

local function renderLoading(progress, total, label)
    local width, height = term.getSize()
    clearWith(colors.black)

    local title = "Loading"
    writeAt(centeredX(title, width), 2, title, colors.green, colors.black)

    local barWidth = math.max(20, math.min(50, width - 8))
    local barX = math.floor((width - barWidth) / 2) + 1
    local barY = math.floor(height / 2)

    writeAt(barX, barY, "[" .. string.rep(" ", barWidth - 2) .. "]", colors.lightGray, colors.black)

    local innerWidth = barWidth - 2
    local ratio = (total > 0) and (progress / total) or 1
    local filled = math.floor(innerWidth * ratio + 0.5)
    if filled > 0 then
        writeAt(barX + 1, barY, string.rep(" ", filled), colors.black, colors.green)
    end

    local percent = math.floor(ratio * 100)
    writeAt(centeredX(tostring(percent) .. "%", width), barY + 2, tostring(percent) .. "%", colors.white, colors.black)

    if label then
        writeAt(centeredX(label, width), barY - 2, label, colors.gray, colors.black)
    end
end

local function runLoading()
    local tasks = {
        {
            label = "Checking terminal size",
            run = function()
                local _, _ = term.getSize()
            end
        },
        {
            label = "Preparing CompiOS desktop",
            run = function()
                local cache = {}
                for i = 1, 120 do
                    cache[i] = ("slot-%d"):format(i)
                end
            end
        },
        {
            label = "Loading CC Terminal app",
            run = function()
                if type(shell) ~= "table" or type(shell.run) ~= "function" then
                    error("Shell API is not available")
                end
            end
        },
        {
            label = "Loading Snake app",
            run = function()
                local _ = appRegistry[2].name
            end
        },
        {
            label = "Finalizing startup",
            run = function()
                local seed = os.epoch and os.epoch("utc") or os.time()
                math.randomseed(seed)
                for _ = 1, 12 do
                    math.random()
                end
            end
        }
    }

    local total = #tasks
    renderLoading(0, total, tasks[1].label)

    for i = 1, total do
        local task = tasks[i]
        renderLoading(i - 1, total, task.label)
        local ok, err = pcall(task.run)
        if not ok then
            clearWith(colors.black)
            writeAt(1, 1, "Loading failed:", colors.red, colors.black)
            writeAt(1, 2, tostring(err), colors.lightGray, colors.black)
            writeAt(1, 4, "Press any key to exit.", colors.gray, colors.black)
            pullEvent("key")
            return false
        end
        renderLoading(i, total, task.label)
    end

    return true
end

local function getStartMenuLayout(width, height)
    local menuWidth = math.min(28, width)
    local menuHeight = 8
    local x1 = 1
    local x2 = x1 + menuWidth - 1
    local y2 = height - 1
    local y1 = math.max(2, y2 - menuHeight + 1)

    return {
        x1 = x1,
        y1 = y1,
        x2 = x2,
        y2 = y2,
        firstAppY = y1 + 2,
        secondAppY = y1 + 3,
        shutdownY = y1 + 5
    }
end

local function backgroundAtPoint(state, x, y)
    local width, height = term.getSize()
    local startButtonWidth = 9

    if y == 1 then
        return colors.gray
    end

    if y == height then
        if x <= startButtonWidth then
            return state.startOpen and colors.green or colors.gray
        end
        return colors.lightGray
    end

    if state.startOpen then
        local menu = getStartMenuLayout(width, height)
        if inRect(x, y, menu.x1, menu.y1, menu.x2, menu.y2) then
            if y == menu.firstAppY or y == menu.secondAppY then
                return colors.lightGray
            end
            if y == menu.shutdownY then
                return colors.red
            end
            return colors.gray
        end
    end

    return colors.blue
end

local function drawStartMenu(width, height)
    local menu = getStartMenuLayout(width, height)

    fillRect(menu.x1, menu.y1, menu.x2, menu.y2, colors.gray)
    writeAt(menu.x1 + 2, menu.y1, "CompiOS", colors.white, colors.gray)

    fillRect(menu.x1 + 1, menu.firstAppY, menu.x2 - 1, menu.firstAppY, colors.lightGray)
    writeAt(menu.x1 + 2, menu.firstAppY, "1. CC Terminal", colors.black, colors.lightGray)

    fillRect(menu.x1 + 1, menu.secondAppY, menu.x2 - 1, menu.secondAppY, colors.lightGray)
    writeAt(menu.x1 + 2, menu.secondAppY, "2. Snake", colors.black, colors.lightGray)

    fillRect(menu.x1 + 1, menu.shutdownY, menu.x2 - 1, menu.shutdownY, colors.red)
    writeAt(menu.x1 + 2, menu.shutdownY, "Shutdown OS", colors.white, colors.red)
end

local function drawDesktop(state)
    local width, height = term.getSize()
    local startButtonWidth = 9

    fillRect(1, 1, width, height, colors.blue)

    fillRect(1, 1, width, 1, colors.gray)
    writeAt(2, 1, "CompiOS", colors.white, colors.gray)

    fillRect(1, height, width, height, colors.lightGray)

    local startColor = state.startOpen and colors.green or colors.gray
    fillRect(1, height, startButtonWidth, height, startColor)
    writeAt(2, height, "Start", colors.white, startColor)

    local desktopLabel = "CompiOS Desktop"
    writeAt(centeredX(desktopLabel, width), math.floor(height / 2) - 1, desktopLabel, colors.white, colors.blue)

    local desktopHint = "Click Start for apps"
    writeAt(centeredX(desktopHint, width), math.floor(height / 2), desktopHint, colors.lightGray, colors.blue)

    local taskHint = "Arrow keys move cursor"
    if #taskHint <= width - startButtonWidth - 1 then
        writeAt(width - #taskHint, height, taskHint, colors.black, colors.lightGray)
    end

    if state.startOpen then
        drawStartMenu(width, height)
    end

    local cursorBg = backgroundAtPoint(state, state.cursorX, state.cursorY)
    writeAt(state.cursorX, state.cursorY, "o", colors.white, cursorBg)
end

local function actionFromStartMenuClick(width, height, x, y)
    local menu = getStartMenuLayout(width, height)
    if not inRect(x, y, menu.x1, menu.y1, menu.x2, menu.y2) then
        return nil
    end

    if y == menu.firstAppY then
        return "terminal"
    end
    if y == menu.secondAppY then
        return "snake"
    end
    if y == menu.shutdownY then
        return "shutdown"
    end

    return "menu"
end

local function runDesktop()
    local width, height = term.getSize()
    local state = {
        startOpen = false,
        cursorX = math.floor(width / 2),
        cursorY = math.floor(height / 2)
    }

    while true do
        width, height = term.getSize()
        state.cursorX = clamp(state.cursorX, 1, width)
        state.cursorY = clamp(state.cursorY, 1, height)

        drawDesktop(state)

        local event, p1, p2, p3 = pullEvent()

        if event == "mouse_move" then
            state.cursorX = clamp(p1, 1, width)
            state.cursorY = clamp(p2, 1, height)
        elseif event == "mouse_drag" then
            state.cursorX = clamp(p2, 1, width)
            state.cursorY = clamp(p3, 1, height)
        elseif event == "mouse_click" then
            local x = p2
            local y = p3
            state.cursorX = clamp(x, 1, width)
            state.cursorY = clamp(y, 1, height)

            if y == height and x <= 9 then
                state.startOpen = not state.startOpen
            elseif state.startOpen then
                local action = actionFromStartMenuClick(width, height, x, y)
                if action == "terminal" then
                    state.startOpen = false
                    appRegistry[1].run()
                elseif action == "snake" then
                    state.startOpen = false
                    appRegistry[2].run()
                elseif action == "shutdown" then
                    return
                else
                    state.startOpen = false
                end
            else
                state.startOpen = false
            end
        elseif event == "key" then
            if p1 == keys.left then
                state.cursorX = clamp(state.cursorX - 1, 1, width)
            elseif p1 == keys.right then
                state.cursorX = clamp(state.cursorX + 1, 1, width)
            elseif p1 == keys.up then
                state.cursorY = clamp(state.cursorY - 1, 1, height)
            elseif p1 == keys.down then
                state.cursorY = clamp(state.cursorY + 1, 1, height)
            elseif p1 == keys.space then
                state.startOpen = not state.startOpen
            end
        elseif event == "term_resize" then
            width, height = term.getSize()
        elseif event == "terminate" then
            return
        end
    end
end

local function main()
    local menuChoice = runBootMenu()
    if menuChoice == 2 then
        return
    end

    local ok = runLoading()
    if not ok then
        return
    end

    runDesktop()
end

local ok, err = pcall(main)

term.setTextColor(oldTextColor)
term.setBackgroundColor(oldBackgroundColor)
term.setCursorBlink(oldCursorBlink)
term.clear()
term.setCursorPos(1, 1)

if not ok and err ~= "Terminated" then
    printError(err)
end
