local terminal = {}

local function addLine(ui, state, text)
    local parts = ui.splitLines(text)
    for i = 1, #parts do
        state.lines[#state.lines + 1] = parts[i]
    end

    if #state.lines > state.maxLines then
        local overflow = #state.lines - state.maxLines
        for _ = 1, overflow do
            table.remove(state.lines, 1)
        end
    end
end

local function createRecorder(width, height)
    local blank = string.rep(" ", width)
    local lines = {}
    for i = 1, height do
        lines[i] = blank
    end

    local cursorX = 1
    local cursorY = 1
    local textColor = colors.white
    local backgroundColor = colors.black
    local cursorBlink = false

    local function putChar(char)
        if cursorY < 1 or cursorY > height then
            cursorX = cursorX + 1
            return
        end

        if cursorX >= 1 and cursorX <= width then
            local line = lines[cursorY]
            lines[cursorY] = line:sub(1, cursorX - 1) .. char .. line:sub(cursorX + 1)
        end

        cursorX = cursorX + 1
    end

    local function writeImpl(text)
        local value = tostring(text or "")
        for i = 1, #value do
            putChar(value:sub(i, i))
        end
    end

    local function scrollImpl(amount)
        if amount == 0 then
            return
        end

        if amount > 0 then
            for _ = 1, amount do
                table.remove(lines, 1)
                lines[#lines + 1] = blank
            end
            return
        end

        for _ = 1, math.abs(amount) do
            table.remove(lines)
            table.insert(lines, 1, blank)
        end
    end

    local recorder = {}

    function recorder.write(text)
        writeImpl(text)
    end

    function recorder.blit(text)
        writeImpl(text)
    end

    function recorder.clear()
        for i = 1, height do
            lines[i] = blank
        end
        cursorX = 1
        cursorY = 1
    end

    function recorder.clearLine()
        if cursorY >= 1 and cursorY <= height then
            lines[cursorY] = blank
        end
    end

    function recorder.scroll(amount)
        scrollImpl(tonumber(amount) or 0)
    end

    function recorder.setCursorPos(x, y)
        cursorX = math.floor(tonumber(x) or 1)
        cursorY = math.floor(tonumber(y) or 1)
    end

    function recorder.getCursorPos()
        return cursorX, cursorY
    end

    function recorder.getSize()
        return width, height
    end

    function recorder.setCursorBlink(value)
        cursorBlink = not not value
    end

    function recorder.getCursorBlink()
        return cursorBlink
    end

    function recorder.isColor()
        return true
    end

    function recorder.isColour()
        return true
    end

    function recorder.setTextColor(value)
        textColor = value
    end

    function recorder.setTextColour(value)
        textColor = value
    end

    function recorder.getTextColor()
        return textColor
    end

    function recorder.getTextColour()
        return textColor
    end

    function recorder.setBackgroundColor(value)
        backgroundColor = value
    end

    function recorder.setBackgroundColour(value)
        backgroundColor = value
    end

    function recorder.getBackgroundColor()
        return backgroundColor
    end

    function recorder.getBackgroundColour()
        return backgroundColor
    end

    function recorder.setPaletteColor()
    end

    function recorder.setPaletteColour()
    end

    function recorder.getPaletteColor()
        return nil
    end

    function recorder.getPaletteColour()
        return nil
    end

    function recorder.getCapturedLines()
        local output = {}
        for i = 1, #lines do
            local trimmed = lines[i]:gsub("%s+$", "")
            if trimmed ~= "" then
                output[#output + 1] = trimmed
            end
        end
        return output
    end

    return recorder
end

local blockedInteractive = {
    edit = true,
    lua = true,
    shell = true,
    monitor = true
}

local function captureCommandOutput(command, width)
    local commandName = command:match("^%s*([^%s]+)")
    if commandName then
        commandName = string.lower(commandName)
    end
    if commandName and blockedInteractive[commandName] then
        return {
            "Interactive command '" .. commandName .. "' is blocked in window terminal.",
            "Run it from native CraftOS shell after leaving CompiOS."
        }, false
    end

    local captureWidth = math.max(16, width)
    local captureHeight = 1000
    local recorder = createRecorder(captureWidth, captureHeight)

    local previous = term.redirect(recorder)
    local ok, result = pcall(shell.run, command)
    term.redirect(previous)

    local lines = recorder.getCapturedLines()

    if not ok then
        lines[#lines + 1] = "Error: " .. tostring(result)
        return lines, false
    end

    if result == false and #lines == 0 then
        lines[#lines + 1] = "Command failed."
        return lines, false
    end

    if #lines == 0 then
        return { "(no output)" }, true
    end

    return lines, true
end

function terminal.new(ui)
    local app = {
        title = "Terminal",
        iconLabel = "Terminal",
        iconGlyph = "T",
        iconColor = colors.lightBlue,
        minW = 28,
        minH = 8
    }

    function app.defaultSize(layout)
        local contentW = math.min(56, math.max(28, layout.width - 10))
        local contentH = math.min(16, math.max(8, layout.height - 9))
        return contentW, contentH
    end

    function app.createState()
        return {
            lines = {
                "CompiOS Terminal (CC:Tweaked shell commands)",
                "Type 'exit' to close this window."
            },
            input = "",
            history = {},
            historyIndex = nil,
            maxLines = 520
        }
    end

    function app.draw(state, target, width, height, focused)
        ui.fillBox(target, 1, 1, width, height, colors.black)

        if width < 12 or height < 4 then
            ui.writeAt(target, 1, 1, "Resize window", colors.red, colors.black)
            target.setCursorBlink(false)
            return
        end

        local viewHeight = height - 1
        local startLine = math.max(1, #state.lines - viewHeight + 1)
        local row = 1
        for i = startLine, #state.lines do
            local line = ui.ellipsize(state.lines[i], width)
            ui.writeAt(target, 1, row, line, colors.white, colors.black)
            row = row + 1
            if row > viewHeight then
                break
            end
        end

        ui.fillBox(target, 1, height, width, height, colors.gray)
        local prompt = "> " .. state.input
        if #prompt > width then
            prompt = prompt:sub(#prompt - width + 1)
        end
        ui.writeAt(target, 1, height, prompt, colors.black, colors.gray)

        if focused then
            local cursorX = math.min(width, #prompt + 1)
            target.setCursorPos(cursorX, height)
            target.setCursorBlink(true)
        else
            target.setCursorBlink(false)
        end
    end

    function app.handle(state, event, p1, p2, p3, ctx)
        if event == "char" then
            state.input = state.input .. p1
            return { redraw = true }
        end

        if event == "paste" then
            state.input = state.input .. p1
            return { redraw = true }
        end

        if event ~= "key" then
            return nil
        end

        if p1 == keys.backspace then
            state.input = state.input:sub(1, -2)
            return { redraw = true }
        end

        if p1 == keys.up then
            if #state.history > 0 then
                if not state.historyIndex then
                    state.historyIndex = #state.history
                else
                    state.historyIndex = math.max(1, state.historyIndex - 1)
                end
                state.input = state.history[state.historyIndex] or state.input
                return { redraw = true }
            end
            return nil
        end

        if p1 == keys.down then
            if state.historyIndex then
                state.historyIndex = state.historyIndex + 1
                if state.historyIndex > #state.history then
                    state.historyIndex = nil
                    state.input = ""
                else
                    state.input = state.history[state.historyIndex]
                end
                return { redraw = true }
            end
            return nil
        end

        if p1 ~= keys.enter then
            return nil
        end

        local rawInput = state.input
        state.input = ""
        state.historyIndex = nil

        local command = ui.trim(rawInput)
        if command == "" then
            addLine(ui, state, ">")
            return { redraw = true }
        end

        state.history[#state.history + 1] = command
        addLine(ui, state, "> " .. command)

        if command == "exit" then
            return { close = true, redraw = true }
        end

        if command == "clear" then
            state.lines = {}
            return { redraw = true }
        end

        local outputLines = captureCommandOutput(command, ctx.width)
        for i = 1, #outputLines do
            addLine(ui, state, outputLines[i])
        end

        return { redraw = true }
    end

    return app
end

return terminal
