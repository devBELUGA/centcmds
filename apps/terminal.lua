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

local function captureCommandOutput(ui, command, width, height)
    local lines = {}
    local captureWidth = math.max(10, width)
    local captureHeight = math.max(40, math.min(220, height * 12))
    local captureWindow = window.create(term.current(), 1, 1, captureWidth, captureHeight, false)

    captureWindow.setBackgroundColor(colors.black)
    captureWindow.setTextColor(colors.white)
    captureWindow.clear()
    captureWindow.setCursorPos(1, 1)

    local previous = term.redirect(captureWindow)
    local ok, result = pcall(shell.run, command)
    term.redirect(previous)

    for y = 1, captureHeight do
        local text = select(1, captureWindow.getLine(y))
        text = ui.trimRight(text or "")
        if text ~= "" then
            lines[#lines + 1] = text
        end
    end

    if not ok then
        lines[#lines + 1] = "Error: " .. tostring(result)
        return lines, false
    end

    if result == false and #lines == 0 then
        lines[#lines + 1] = "Command failed."
    end

    return lines, result ~= false
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
                "CompiOS Terminal",
                "Run CC:Tweaked commands here.",
                "Type 'exit' to close this window."
            },
            input = "",
            history = {},
            historyIndex = nil,
            maxLines = 420
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

        if event == "key" then
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

            if p1 == keys.enter then
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

                local output = captureCommandOutput(ui, command, ctx.width, ctx.height)
                for i = 1, #output do
                    addLine(ui, state, output[i])
                end
                return { redraw = true }
            end
        end

        return nil
    end

    return app
end

return terminal
