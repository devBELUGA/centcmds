local desktop = {}

local function removeFromOrder(order, id)
    for i = 1, #order do
        if order[i] == id then
            table.remove(order, i)
            return
        end
    end
end

local function getLayout()
    local width, height = term.getSize()
    return {
        width = width,
        height = height,
        topBarY = 1,
        taskBarY = height,
        workX1 = 1,
        workY1 = 2,
        workX2 = width,
        workY2 = height - 1
    }
end

local function workspaceColor(row)
    if row % 2 == 0 then
        return colors.cyan
    end
    return colors.lightBlue
end

local function buildState(appList)
    local appMap = {}
    for i = 1, #appList do
        appMap[appList[i].id] = appList[i].app
    end

    return {
        appList = appList,
        appMap = appMap,
        windows = {},
        order = {},
        focusId = nil,
        nextId = 1,
        running = true,
        dirty = true,
        startMenuOpen = false,
        dragging = nil,
        iconHotspots = {},
        taskbarHotspots = {},
        menuHotspots = {}
    }
end

local function ensureFocus(state)
    if state.focusId then
        local active = state.windows[state.focusId]
        if active and not active.minimized then
            return
        end
    end

    state.focusId = nil
    for i = #state.order, 1, -1 do
        local candidate = state.windows[state.order[i]]
        if candidate and not candidate.minimized then
            state.focusId = candidate.id
            return
        end
    end
end

local function focusWindow(state, id)
    local win = state.windows[id]
    if not win then
        return
    end

    win.minimized = false
    removeFromOrder(state.order, id)
    state.order[#state.order + 1] = id
    state.focusId = id
    state.dirty = true
end

local function closeWindow(state, id)
    local win = state.windows[id]
    if not win then
        return
    end

    if win.content then
        win.content.setCursorBlink(false)
        win.content.setVisible(false)
    end

    state.windows[id] = nil
    removeFromOrder(state.order, id)

    if state.focusId == id then
        state.focusId = nil
    end
    ensureFocus(state)
    state.dirty = true
end

local function toggleMinimize(state, id)
    local win = state.windows[id]
    if not win then
        return
    end

    if win.minimized then
        focusWindow(state, id)
        return
    end

    win.minimized = true
    win.content.setCursorBlink(false)
    win.content.setVisible(false)

    if state.focusId == id then
        state.focusId = nil
    end
    ensureFocus(state)
    state.dirty = true
end

local function invokeResizeHandler(win)
    if not win.app or not win.app.resize then
        return
    end

    pcall(win.app.resize, win.state, win.w - 2, win.h - 2, win)
end

local function fitWindowToLayout(ui, win, layout)
    local workWidth = layout.workX2 - layout.workX1 + 1
    local workHeight = layout.workY2 - layout.workY1 + 1

    local minContentW = win.app.minW or 16
    local minContentH = win.app.minH or 8

    local maxContentW = math.max(minContentW, workWidth - 2)
    local maxContentH = math.max(minContentH, workHeight - 2)

    local contentW = ui.clamp(win.w - 2, minContentW, maxContentW)
    local contentH = ui.clamp(win.h - 2, minContentH, maxContentH)

    win.w = contentW + 2
    win.h = contentH + 2

    win.x = ui.clamp(win.x, layout.workX1, layout.workX2 - win.w + 1)
    win.y = ui.clamp(win.y, layout.workY1, layout.workY2 - win.h + 1)

    win.content.reposition(win.x + 1, win.y + 1, contentW, contentH)
    invokeResizeHandler(win)
end

local function clampWindowsToScreen(ui, state)
    local layout = getLayout()
    for i = 1, #state.order do
        local win = state.windows[state.order[i]]
        if win then
            fitWindowToLayout(ui, win, layout)
        end
    end

    if state.dragging then
        state.dragging = nil
    end
    ensureFocus(state)
    state.dirty = true
end

local function openWindow(ui, state, appId)
    local app = state.appMap[appId]
    if not app then
        return
    end

    local layout = getLayout()
    local workWidth = layout.workX2 - layout.workX1 + 1
    local workHeight = layout.workY2 - layout.workY1 + 1

    local minContentW = app.minW or 16
    local minContentH = app.minH or 8

    local contentW = minContentW
    local contentH = minContentH
    if app.defaultSize then
        local defaultW, defaultH = app.defaultSize(layout)
        contentW = defaultW or contentW
        contentH = defaultH or contentH
    end

    contentW = ui.clamp(contentW, minContentW, math.max(minContentW, workWidth - 2))
    contentH = ui.clamp(contentH, minContentH, math.max(minContentH, workHeight - 2))

    local winW = contentW + 2
    local winH = contentH + 2
    local cascade = ((state.nextId - 1) % 5) * 2

    local winX = ui.clamp(layout.workX1 + 2 + cascade, layout.workX1, layout.workX2 - winW + 1)
    local winY = ui.clamp(layout.workY1 + 1 + cascade, layout.workY1, layout.workY2 - winH + 1)

    local id = state.nextId
    state.nextId = id + 1

    local content = window.create(term.current(), winX + 1, winY + 1, contentW, contentH, true)
    content.setBackgroundColor(colors.black)
    content.setTextColor(colors.white)
    content.clear()

    local newWindow = {
        id = id,
        appId = appId,
        app = app,
        title = app.title or appId,
        x = winX,
        y = winY,
        w = winW,
        h = winH,
        minimized = false,
        content = content,
        state = app.createState and app.createState() or {}
    }

    state.windows[id] = newWindow
    state.order[#state.order + 1] = id
    focusWindow(state, id)
    invokeResizeHandler(newWindow)
    state.startMenuOpen = false
    state.dirty = true
end

local function topWindowAt(ui, state, x, y)
    for i = #state.order, 1, -1 do
        local win = state.windows[state.order[i]]
        if win and not win.minimized then
            local x2 = win.x + win.w - 1
            local y2 = win.y + win.h - 1
            if ui.inRect(x, y, win.x, win.y, x2, y2) then
                return win
            end
        end
    end
    return nil
end

local function contentHit(ui, win, x, y)
    return ui.inRect(x, y, win.x + 1, win.y + 1, win.x + win.w - 2, win.y + win.h - 2)
end

local function zoneInWindow(ui, win, x, y)
    local x2 = win.x + win.w - 1
    if y == win.y then
        if x == x2 - 1 then
            return "close"
        end
        if x == x2 - 3 then
            return "minimize"
        end
        return "title"
    end

    if contentHit(ui, win, x, y) then
        return "content"
    end

    return "frame"
end

local function dispatchToApp(state, win, event, p1, p2, p3)
    if not win.app or not win.app.handle then
        return
    end

    local action = nil
    local ok, err = pcall(function()
        action = win.app.handle(win.state, event, p1, p2, p3, {
            width = win.w - 2,
            height = win.h - 2,
            window = win
        })
    end)

    if not ok then
        if win.content then
            win.content.setCursorBlink(false)
            win.content.setBackgroundColor(colors.black)
            win.content.clear()
            win.content.setCursorPos(1, 1)
            win.content.setTextColor(colors.red)
            win.content.write("App error")
            win.content.setCursorPos(1, 2)
            win.content.setTextColor(colors.lightGray)
            win.content.write(tostring(err))
        end
        state.dirty = true
        return
    end

    if type(action) ~= "table" then
        return
    end

    if action.close then
        closeWindow(state, win.id)
        return
    end

    if action.minimize then
        toggleMinimize(state, win.id)
        return
    end

    if action.redraw then
        state.dirty = true
    end
end

local function drawTopBar(ui)
    local root = term.current()
    local layout = getLayout()
    ui.fillBox(root, 1, layout.topBarY, layout.width, layout.topBarY, colors.gray)
    ui.writeAt(root, 2, layout.topBarY, "CompiOS", colors.white, colors.gray)

    if textutils and textutils.formatTime then
        local timeText = textutils.formatTime(os.time(), true)
        ui.writeAt(root, layout.width - #timeText, layout.topBarY, timeText, colors.white, colors.gray)
    end
end

local function drawDesktopIcons(ui, state, layout)
    state.iconHotspots = {}
    local root = term.current()

    for i = 1, #state.appList do
        local item = state.appList[i]
        local iconX = 3
        local iconY = layout.workY1 + 2 + (i - 1) * 6
        if iconY + 3 <= layout.workY2 then
            local app = item.app
            local iconColor = app.iconColor or colors.lightGray
            local iconGlyph = app.iconGlyph or "*"
            local iconLabel = ui.ellipsize(app.iconLabel or app.title or item.id, 12)

            ui.fillBox(root, iconX, iconY, iconX + 4, iconY + 2, iconColor)
            ui.writeAt(root, iconX + 2, iconY + 1, iconGlyph, colors.white, iconColor)

            local labelBg = workspaceColor(iconY + 3)
            ui.writeAt(root, iconX, iconY + 3, iconLabel, colors.white, labelBg)

            state.iconHotspots[#state.iconHotspots + 1] = {
                x1 = iconX,
                y1 = iconY,
                x2 = math.max(iconX + 4, iconX + #iconLabel - 1),
                y2 = iconY + 3,
                action = "open_app",
                appId = item.id
            }
        end
    end
end

local function drawWindowFrame(ui, win, focused)
    local root = term.current()
    local x1 = win.x
    local y1 = win.y
    local x2 = win.x + win.w - 1
    local y2 = win.y + win.h - 1

    ui.fillBox(root, x1, y1, x2, y2, colors.lightGray)
    ui.fillBox(root, x1 + 1, y1 + 1, x2 - 1, y2 - 1, colors.black)

    local titleColor = focused and colors.blue or colors.gray
    ui.fillBox(root, x1, y1, x2, y1, titleColor)

    local title = ui.ellipsize(win.title, math.max(1, win.w - 8))
    ui.writeAt(root, x1 + 1, y1, title, colors.white, titleColor)
    ui.writeAt(root, x2 - 3, y1, "_", colors.white, titleColor)
    ui.writeAt(root, x2 - 1, y1, "X", colors.red, titleColor)
end

local function drawWindows(ui, state)
    for i = 1, #state.order do
        local win = state.windows[state.order[i]]
        if win then
            if win.minimized then
                win.content.setCursorBlink(false)
                win.content.setVisible(false)
            else
                local focused = (state.focusId == win.id)
                drawWindowFrame(ui, win, focused)

                win.content.reposition(win.x + 1, win.y + 1, win.w - 2, win.h - 2)
                win.content.setVisible(true)

                if win.app and win.app.draw then
                    local ok, err = pcall(win.app.draw, win.state, win.content, win.w - 2, win.h - 2, focused)
                    if not ok then
                        ui.clear(win.content, colors.black)
                        ui.writeAt(win.content, 1, 1, "Draw error", colors.red, colors.black)
                        ui.writeAt(win.content, 1, 2, tostring(err), colors.lightGray, colors.black)
                    end
                end

                win.content.redraw()
            end
        end
    end
end

local function drawTaskbar(ui, state, layout)
    local root = term.current()
    state.taskbarHotspots = {}

    ui.fillBox(root, 1, layout.taskBarY, layout.width, layout.taskBarY, colors.gray)

    local startWidth = 8
    local startColor = state.startMenuOpen and colors.green or colors.lightGray
    ui.fillBox(root, 1, layout.taskBarY, startWidth, layout.taskBarY, startColor)
    ui.writeAt(root, 2, layout.taskBarY, "Start", colors.black, startColor)

    state.taskbarHotspots[#state.taskbarHotspots + 1] = {
        x1 = 1,
        y1 = layout.taskBarY,
        x2 = startWidth,
        y2 = layout.taskBarY,
        action = "start_toggle"
    }

    local cursorX = startWidth + 2
    for i = 1, #state.order do
        local win = state.windows[state.order[i]]
        if win then
            local label = ui.ellipsize(win.title, 9)
            local body = " " .. label .. " "
            local bodyWidth = #body
            local totalWidth = bodyWidth + 2

            if cursorX + totalWidth - 1 > layout.width then
                break
            end

            local bodyColor = colors.lightGray
            local bodyTextColor = colors.black
            if win.minimized then
                bodyColor = colors.gray
                bodyTextColor = colors.white
            elseif state.focusId == win.id then
                bodyColor = colors.blue
                bodyTextColor = colors.white
            end

            ui.fillBox(root, cursorX, layout.taskBarY, cursorX + bodyWidth - 1, layout.taskBarY, bodyColor)
            ui.writeAt(root, cursorX, layout.taskBarY, body, bodyTextColor, bodyColor)

            local minX = cursorX + bodyWidth
            local closeX = cursorX + bodyWidth + 1

            local minChar = win.minimized and "+" or "_"
            ui.fillBox(root, minX, layout.taskBarY, minX, layout.taskBarY, colors.gray)
            ui.writeAt(root, minX, layout.taskBarY, minChar, colors.white, colors.gray)

            ui.fillBox(root, closeX, layout.taskBarY, closeX, layout.taskBarY, colors.red)
            ui.writeAt(root, closeX, layout.taskBarY, "x", colors.white, colors.red)

            state.taskbarHotspots[#state.taskbarHotspots + 1] = {
                x1 = cursorX,
                y1 = layout.taskBarY,
                x2 = cursorX + bodyWidth - 1,
                y2 = layout.taskBarY,
                action = "task_main",
                winId = win.id
            }
            state.taskbarHotspots[#state.taskbarHotspots + 1] = {
                x1 = minX,
                y1 = layout.taskBarY,
                x2 = minX,
                y2 = layout.taskBarY,
                action = "task_min",
                winId = win.id
            }
            state.taskbarHotspots[#state.taskbarHotspots + 1] = {
                x1 = closeX,
                y1 = layout.taskBarY,
                x2 = closeX,
                y2 = layout.taskBarY,
                action = "task_close",
                winId = win.id
            }

            cursorX = cursorX + totalWidth + 1
        end
    end
end

local function drawStartMenu(ui, state, layout)
    state.menuHotspots = {}
    if not state.startMenuOpen then
        return
    end

    local root = term.current()
    local menuWidth = math.min(26, layout.width)
    local menuHeight = 8
    local x1 = 1
    local y2 = layout.taskBarY - 1
    local y1 = math.max(layout.workY1, y2 - menuHeight + 1)
    local x2 = x1 + menuWidth - 1

    ui.fillBox(root, x1, y1, x2, y2, colors.gray)
    ui.writeAt(root, x1 + 2, y1, "CompiOS", colors.white, colors.gray)

    local row = y1 + 2
    for i = 1, #state.appList do
        if row >= y2 - 1 then
            break
        end

        local item = state.appList[i]
        local label = tostring(i) .. ". " .. (item.app.iconLabel or item.app.title or item.id)
        local clipped = ui.ellipsize(label, menuWidth - 4)

        ui.fillBox(root, x1 + 1, row, x2 - 1, row, colors.lightGray)
        ui.writeAt(root, x1 + 2, row, clipped, colors.black, colors.lightGray)

        state.menuHotspots[#state.menuHotspots + 1] = {
            x1 = x1 + 1,
            y1 = row,
            x2 = x2 - 1,
            y2 = row,
            action = "open_app",
            appId = item.id
        }

        row = row + 1
    end

    ui.fillBox(root, x1 + 1, y2 - 1, x2 - 1, y2 - 1, colors.red)
    ui.writeAt(root, x1 + 2, y2 - 1, "Shutdown OS", colors.white, colors.red)

    state.menuHotspots[#state.menuHotspots + 1] = {
        x1 = x1 + 1,
        y1 = y2 - 1,
        x2 = x2 - 1,
        y2 = y2 - 1,
        action = "shutdown"
    }
end

local function render(ui, state)
    local layout = getLayout()
    local root = term.current()

    for y = layout.workY1, layout.workY2 do
        ui.fillBox(root, 1, y, layout.width, y, workspaceColor(y))
    end

    drawDesktopIcons(ui, state, layout)
    drawWindows(ui, state)
    drawTopBar(ui)
    drawTaskbar(ui, state, layout)
    drawStartMenu(ui, state, layout)
    term.setCursorBlink(false)
end

local function runAction(ui, state, action)
    if action.action == "start_toggle" then
        state.startMenuOpen = not state.startMenuOpen
        state.dirty = true
        return
    end

    if action.action == "open_app" then
        openWindow(ui, state, action.appId)
        return
    end

    if action.action == "shutdown" then
        state.running = false
        return
    end

    if action.action == "task_main" then
        local win = state.windows[action.winId]
        if not win then
            return
        end

        if win.minimized then
            focusWindow(state, win.id)
            return
        end

        if state.focusId == win.id then
            toggleMinimize(state, win.id)
            return
        end

        focusWindow(state, win.id)
        return
    end

    if action.action == "task_min" then
        toggleMinimize(state, action.winId)
        return
    end

    if action.action == "task_close" then
        closeWindow(state, action.winId)
        return
    end
end

local function handleMouseClick(ui, state, button, x, y)
    local taskHit = ui.hitTest(state.taskbarHotspots, x, y)

    if state.startMenuOpen then
        local menuHit = ui.hitTest(state.menuHotspots, x, y)
        if menuHit then
            runAction(ui, state, menuHit)
            return
        end

        if taskHit then
            runAction(ui, state, taskHit)
            return
        end

        state.startMenuOpen = false
        state.dirty = true
    end

    if taskHit then
        runAction(ui, state, taskHit)
        return
    end

    local win = topWindowAt(ui, state, x, y)
    if win then
        focusWindow(state, win.id)
        local zone = zoneInWindow(ui, win, x, y)

        if zone == "close" then
            closeWindow(state, win.id)
            return
        end

        if zone == "minimize" then
            toggleMinimize(state, win.id)
            return
        end

        if zone == "title" and button == 1 then
            state.dragging = {
                winId = win.id,
                offsetX = x - win.x,
                offsetY = y - win.y
            }
            return
        end

        if zone == "content" then
            dispatchToApp(state, win, "mouse_click", button, x - win.x, y - win.y)
            return
        end

        return
    end

    local iconHit = ui.hitTest(state.iconHotspots, x, y)
    if iconHit then
        runAction(ui, state, iconHit)
    end
end

local function handleMouseDrag(ui, state, button, x, y)
    if state.dragging then
        local win = state.windows[state.dragging.winId]
        if not win then
            state.dragging = nil
            return
        end

        local layout = getLayout()
        win.x = ui.clamp(x - state.dragging.offsetX, layout.workX1, layout.workX2 - win.w + 1)
        win.y = ui.clamp(y - state.dragging.offsetY, layout.workY1, layout.workY2 - win.h + 1)
        win.content.reposition(win.x + 1, win.y + 1, win.w - 2, win.h - 2)
        state.dirty = true
        return
    end

    local win = topWindowAt(ui, state, x, y)
    if win and contentHit(ui, win, x, y) then
        dispatchToApp(state, win, "mouse_drag", button, x - win.x, y - win.y)
    end
end

local function handleMouseUp(ui, state, button, x, y)
    if state.dragging then
        state.dragging = nil
        state.dirty = true
        return
    end

    local win = topWindowAt(ui, state, x, y)
    if win and contentHit(ui, win, x, y) then
        dispatchToApp(state, win, "mouse_up", button, x - win.x, y - win.y)
    end
end

local function handleMouseScroll(ui, state, direction, x, y)
    local win = topWindowAt(ui, state, x, y)
    if win and contentHit(ui, win, x, y) then
        dispatchToApp(state, win, "mouse_scroll", direction, x - win.x, y - win.y)
    end
end

local function dispatchToFocusedWindow(state, event, p1, p2, p3)
    if not state.focusId then
        return
    end

    local focused = state.windows[state.focusId]
    if not focused or focused.minimized then
        return
    end

    dispatchToApp(state, focused, event, p1, p2, p3)
end

local function dispatchTimer(state, timerId)
    local ids = {}
    for i = 1, #state.order do
        ids[i] = state.order[i]
    end

    for i = 1, #ids do
        local win = state.windows[ids[i]]
        if win then
            dispatchToApp(state, win, "timer", timerId)
        end
    end
end

function desktop.run(ui, appList, pullEvent)
    local state = buildState(appList)

    while state.running do
        if state.dirty then
            render(ui, state)
            state.dirty = false
        end

        local event, p1, p2, p3 = pullEvent()

        if event == "mouse_click" then
            handleMouseClick(ui, state, p1, p2, p3)
        elseif event == "mouse_drag" then
            handleMouseDrag(ui, state, p1, p2, p3)
        elseif event == "mouse_up" then
            handleMouseUp(ui, state, p1, p2, p3)
        elseif event == "mouse_scroll" then
            handleMouseScroll(ui, state, p1, p2, p3)
        elseif event == "char" then
            dispatchToFocusedWindow(state, "char", p1, p2, p3)
        elseif event == "paste" then
            dispatchToFocusedWindow(state, "paste", p1, p2, p3)
        elseif event == "key" then
            dispatchToFocusedWindow(state, "key", p1, p2, p3)
        elseif event == "timer" then
            dispatchTimer(state, p1)
        elseif event == "term_resize" then
            clampWindowsToScreen(ui, state)
        elseif event == "terminate" then
            state.running = false
        end
    end
end

return desktop
