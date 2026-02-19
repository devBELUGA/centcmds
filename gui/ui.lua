local ui = {}

function ui.clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function ui.inRect(x, y, x1, y1, x2, y2)
    return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

function ui.centeredX(text, width)
    return math.floor((width - #text) / 2) + 1
end

function ui.ellipsize(text, width)
    if width <= 0 then
        return ""
    end
    if #text <= width then
        return text
    end
    if width == 1 then
        return "~"
    end
    return text:sub(1, width - 1) .. "~"
end

function ui.trim(text)
    return (tostring(text):gsub("^%s+", ""):gsub("%s+$", ""))
end

function ui.trimRight(text)
    return (tostring(text):gsub("%s+$", ""))
end

function ui.splitLines(text)
    local lines = {}
    local value = tostring(text or "")
    local start = 1

    while true do
        local at = value:find("\n", start, true)
        if not at then
            lines[#lines + 1] = value:sub(start)
            break
        end
        lines[#lines + 1] = value:sub(start, at - 1)
        start = at + 1
    end

    return lines
end

function ui.writeAt(target, x, y, text, textColor, backgroundColor)
    local width, height = target.getSize()
    if y < 1 or y > height then
        return
    end
    if x > width then
        return
    end

    local output = tostring(text or "")
    if x < 1 then
        output = output:sub(2 - x)
        x = 1
    end
    if x + #output - 1 > width then
        output = output:sub(1, width - x + 1)
    end
    if #output == 0 then
        return
    end

    if textColor then
        target.setTextColor(textColor)
    end
    if backgroundColor then
        target.setBackgroundColor(backgroundColor)
    end

    target.setCursorPos(x, y)
    target.write(output)
end

local function manualFill(target, x1, y1, x2, y2, color)
    local segment = string.rep(" ", x2 - x1 + 1)
    target.setBackgroundColor(color)
    for y = y1, y2 do
        target.setCursorPos(x1, y)
        target.write(segment)
    end
end

function ui.fillBox(target, x1, y1, x2, y2, color)
    local width, height = target.getSize()

    x1 = ui.clamp(math.floor(x1), 1, width)
    x2 = ui.clamp(math.floor(x2), 1, width)
    y1 = ui.clamp(math.floor(y1), 1, height)
    y2 = ui.clamp(math.floor(y2), 1, height)

    if x2 < x1 or y2 < y1 then
        return
    end

    if paintutils and paintutils.drawFilledBox then
        local current = term.current()
        if current ~= target then
            term.redirect(target)
            paintutils.drawFilledBox(x1, y1, x2, y2, color)
            term.redirect(current)
        else
            paintutils.drawFilledBox(x1, y1, x2, y2, color)
        end
        return
    end

    manualFill(target, x1, y1, x2, y2, color)
end

function ui.clear(target, color)
    local width, height = target.getSize()
    ui.fillBox(target, 1, 1, width, height, color)
    target.setCursorPos(1, 1)
end

function ui.hitTest(hotspots, x, y)
    for i = 1, #hotspots do
        local item = hotspots[i]
        if ui.inRect(x, y, item.x1, item.y1, item.x2, item.y2) then
            return item
        end
    end
    return nil
end

return ui
