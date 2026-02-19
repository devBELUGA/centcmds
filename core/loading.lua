local loading = {}

local function drawLoading(ui, progress, total, label)
    local width, height = term.getSize()
    ui.clear(term.current(), colors.black)

    local title = "Loading"
    ui.writeAt(term.current(), ui.centeredX(title, width), 2, title, colors.green, colors.black)

    local barWidth = math.max(20, math.min(50, width - 8))
    local barX = math.floor((width - barWidth) / 2) + 1
    local barY = math.floor(height / 2)

    ui.writeAt(term.current(), barX, barY, "[" .. string.rep(" ", barWidth - 2) .. "]", colors.lightGray, colors.black)

    local innerWidth = barWidth - 2
    local ratio = total > 0 and (progress / total) or 1
    local filled = math.floor(innerWidth * ratio + 0.5)
    if filled > 0 then
        ui.writeAt(term.current(), barX + 1, barY, string.rep(" ", filled), colors.black, colors.green)
    end

    local percent = math.floor(ratio * 100)
    local percentText = tostring(percent) .. "%"
    ui.writeAt(term.current(), ui.centeredX(percentText, width), barY + 2, percentText, colors.white, colors.black)

    if label and label ~= "" then
        ui.writeAt(term.current(), ui.centeredX(label, width), barY - 2, label, colors.gray, colors.black)
    end
end

function loading.run(ui, tasks, pullEvent)
    local total = #tasks
    if total == 0 then
        return true
    end

    drawLoading(ui, 0, total, tasks[1].label or "")

    for i = 1, total do
        local task = tasks[i]
        drawLoading(ui, i - 1, total, task.label or "")

        local ok, err = pcall(task.run)
        if not ok then
            ui.clear(term.current(), colors.black)
            ui.writeAt(term.current(), 1, 1, "Loading failed:", colors.red, colors.black)
            ui.writeAt(term.current(), 1, 2, tostring(err), colors.lightGray, colors.black)
            ui.writeAt(term.current(), 1, 4, "Press any key to exit.", colors.gray, colors.black)
            pullEvent("key")
            return false
        end

        drawLoading(ui, i, total, task.label or "")
    end

    return true
end

return loading
