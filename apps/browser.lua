local browser = {}

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function splitLines(value)
    local lines = {}
    local text = tostring(value or "")
    local start = 1

    while true do
        local at = text:find("\n", start, true)
        if not at then
            lines[#lines + 1] = text:sub(start)
            break
        end

        lines[#lines + 1] = text:sub(start, at - 1)
        start = at + 1
    end

    return lines
end

local function decodeEntities(html)
    local output = html
    local entities = {
        ["&nbsp;"] = " ",
        ["&amp;"] = "&",
        ["&quot;"] = "\"",
        ["&#39;"] = "'",
        ["&lt;"] = "<",
        ["&gt;"] = ">"
    }

    for from, to in pairs(entities) do
        output = output:gsub(from, to)
    end

    output = output:gsub("&#x([0-9a-fA-F]+);", function(hex)
        local code = tonumber(hex, 16)
        if not code then
            return "?"
        end
        if code >= 32 and code <= 126 then
            return string.char(code)
        end
        return " "
    end)

    output = output:gsub("&#([0-9]+);", function(dec)
        local code = tonumber(dec, 10)
        if not code then
            return "?"
        end
        if code >= 32 and code <= 126 then
            return string.char(code)
        end
        return " "
    end)

    return output
end

local function htmlToText(html)
    local text = tostring(html or "")

    text = text:gsub("\r", "")
    text = text:gsub("<!--.-%-%->", " ")
    text = text:gsub("<script.-</script>", " ")
    text = text:gsub("<style.-</style>", " ")
    text = text:gsub("<noscript.-</noscript>", " ")

    text = text:gsub("<[bB][rR]%s*/?>", "\n")
    text = text:gsub("</[pP][^>]*>", "\n")
    text = text:gsub("</[dD][iI][vV][^>]*>", "\n")
    text = text:gsub("</[hH][1-6][^>]*>", "\n")
    text = text:gsub("</[lL][iI][^>]*>", "\n")
    text = text:gsub("<[lL][iI][^>]*>", "\n* ")
    text = text:gsub("<[^>]->", "")
    text = decodeEntities(text)
    text = text:gsub("[\t ]+", " ")
    text = text:gsub("\n%s+", "\n")

    return text
end

local function wrapLine(line, width)
    local out = {}
    local value = line or ""
    if value == "" then
        out[1] = ""
        return out
    end

    local remaining = value
    while #remaining > width do
        local chunk = remaining:sub(1, width)
        local splitAt = chunk:match("^.*()%s+%S-$")

        if splitAt and splitAt >= math.floor(width * 0.5) then
            out[#out + 1] = chunk:sub(1, splitAt - 1)
            remaining = remaining:sub(splitAt + 1)
        else
            out[#out + 1] = chunk
            remaining = remaining:sub(width + 1)
        end
    end

    out[#out + 1] = remaining
    return out
end

local function normalizeUrl(raw)
    local url = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if url == "" then
        return nil
    end

    if not url:match("^%a[%w+%-%.]*://") then
        url = "https://" .. url
    end

    return url
end

local function isHtmlContentType(headers)
    if type(headers) ~= "table" then
        return false
    end

    for key, value in pairs(headers) do
        local k = tostring(key):lower()
        if k == "content-type" then
            return tostring(value):lower():find("text/html", 1, true) ~= nil
        end
    end

    return false
end

local function buildRenderedLines(state, width)
    local lines = {}
    local source = state.rawBody or ""
    local useHtml = state.isHtml == true
    local prepared

    if useHtml then
        prepared = htmlToText(source)
    else
        prepared = tostring(source)
    end

    local sourceLines = splitLines(prepared)
    for i = 1, #sourceLines do
        local wrapped = wrapLine(sourceLines[i], width)
        for j = 1, #wrapped do
            lines[#lines + 1] = wrapped[j]
        end
    end

    if #lines == 0 then
        lines[1] = "(empty page)"
    end

    state.renderedLines = lines
    state.scroll = clamp(state.scroll or 1, 1, math.max(1, #lines))
end

local function loadUrl(state, rawUrl, viewWidth)
    if not http then
        state.status = "HTTP API disabled in config."
        state.rawBody = ""
        state.isHtml = false
        buildRenderedLines(state, viewWidth)
        return
    end

    local url = normalizeUrl(rawUrl)
    if not url then
        state.status = "Enter URL first."
        return
    end

    state.status = "Loading " .. url
    state.currentUrl = url
    state.addressInput = url
    state.scroll = 1

    if http.checkURL then
        local allowed, reason = http.checkURL(url)
        if not allowed then
            state.status = "Blocked URL: " .. tostring(reason)
            state.rawBody = ""
            state.isHtml = false
            buildRenderedLines(state, viewWidth)
            return
        end
    end

    local request = {
        url = url,
        redirect = true,
        timeout = 12,
        headers = {
            ["User-Agent"] = "CompiOSBrowser/1.0"
        }
    }

    local response
    local err
    local failResponse

    local okRequest, r1, r2, r3 = pcall(http.get, request)
    if okRequest then
        response, err, failResponse = r1, r2, r3
    else
        local okLegacy, l1, l2, l3 = pcall(http.get, url, request.headers, false)
        if okLegacy then
            response, err, failResponse = l1, l2, l3
        else
            state.status = "Request error: " .. tostring(r1)
            state.rawBody = ""
            state.isHtml = false
            buildRenderedLines(state, viewWidth)
            return
        end
    end

    local handle = response or failResponse
    if not handle then
        state.status = "Request failed: " .. tostring(err)
        state.rawBody = ""
        state.isHtml = false
        buildRenderedLines(state, viewWidth)
        return
    end

    local code, message = handle.getResponseCode()
    local headers = handle.getResponseHeaders and handle.getResponseHeaders() or {}
    local body = handle.readAll() or ""
    handle.close()

    state.isHtml = isHtmlContentType(headers)
    state.rawBody = body

    local host = url:match("^https?://([^/%?#]+)") or "site"
    local baseStatus = tostring(code) .. " " .. tostring(message or "")
    state.status = baseStatus .. " | " .. host

    if host:find("youtube%.com") or host:find("youtu%.be") then
        state.status = state.status .. " | JS/video limited in CC"
    end

    buildRenderedLines(state, viewWidth)
end

function browser.new(ui)
    local app = {
        title = "Browser",
        iconLabel = "Browser",
        iconGlyph = "B",
        iconColor = colors.orange,
        minW = 36,
        minH = 10
    }

    function app.defaultSize(layout)
        local contentW = math.min(66, math.max(36, layout.width - 8))
        local contentH = math.min(18, math.max(10, layout.height - 8))
        return contentW, contentH
    end

    function app.createState()
        return {
            currentUrl = "https://www.google.com",
            addressInput = "https://www.google.com",
            editingAddress = true,
            rawBody = "",
            isHtml = true,
            renderedLines = { "Loading..." },
            scroll = 1,
            status = "Ready",
            firstLoadDone = false
        }
    end

    function app.resize(state, width)
        local viewWidth = math.max(12, width)
        if not state.firstLoadDone then
            loadUrl(state, state.currentUrl, viewWidth)
            state.firstLoadDone = true
            return
        end
        buildRenderedLines(state, viewWidth)
    end

    function app.draw(state, target, width, height, focused)
        ui.fillBox(target, 1, 1, width, height, colors.black)

        if width < 18 or height < 6 then
            ui.writeAt(target, 1, 1, "Resize browser window", colors.red, colors.black)
            target.setCursorBlink(false)
            return
        end

        local goLabel = "[GO]"
        local goX = math.max(10, width - #goLabel + 1)
        local fieldX = 5
        local fieldWidth = math.max(4, goX - fieldX - 1)

        ui.fillBox(target, 1, 1, width, 1, colors.lightGray)
        ui.writeAt(target, 1, 1, "URL:", colors.black, colors.lightGray)

        local shown = state.addressInput
        if #shown > fieldWidth then
            shown = shown:sub(#shown - fieldWidth + 1)
        end
        ui.writeAt(target, fieldX, 1, string.rep(" ", fieldWidth), colors.black, colors.white)
        ui.writeAt(target, fieldX, 1, shown, colors.black, colors.white)
        ui.writeAt(target, goX, 1, goLabel, colors.white, colors.blue)

        ui.fillBox(target, 1, 2, width, 2, colors.gray)
        ui.writeAt(target, 1, 2, ui.ellipsize(state.status, width), colors.white, colors.gray)

        local viewHeight = height - 2
        local maxScroll = math.max(1, #state.renderedLines - viewHeight + 1)
        state.scroll = clamp(state.scroll, 1, maxScroll)

        local row = 3
        for i = state.scroll, #state.renderedLines do
            if row > height then
                break
            end

            local line = ui.ellipsize(state.renderedLines[i], width)
            ui.writeAt(target, 1, row, line, colors.white, colors.black)
            row = row + 1
        end

        if maxScroll > 1 then
            local marker = ("[%d/%d]"):format(state.scroll, maxScroll)
            ui.writeAt(target, math.max(1, width - #marker + 1), height, marker, colors.lightGray, colors.black)
        end

        if focused and state.editingAddress then
            local cursorX = fieldX + #shown
            cursorX = clamp(cursorX + 1, fieldX, fieldX + fieldWidth)
            target.setCursorPos(cursorX, 1)
            target.setCursorBlink(true)
        else
            target.setCursorBlink(false)
        end
    end

    function app.handle(state, event, p1, p2, p3, ctx)
        local viewWidth = math.max(12, ctx.width)
        local viewHeight = math.max(1, ctx.height - 2)
        local maxScroll = math.max(1, #state.renderedLines - viewHeight + 1)

        if event == "mouse_click" then
            local x = p2
            local y = p3
            local goLabel = "[GO]"
            local goX = math.max(10, ctx.width - #goLabel + 1)

            if y == 1 then
                if x >= goX then
                    state.editingAddress = false
                    loadUrl(state, state.addressInput, viewWidth)
                    return { redraw = true }
                end
                state.editingAddress = true
                return { redraw = true }
            end

            state.editingAddress = false
            return { redraw = true }
        end

        if event == "mouse_scroll" then
            state.scroll = clamp(state.scroll + p1, 1, maxScroll)
            return { redraw = true }
        end

        if event == "paste" and state.editingAddress then
            state.addressInput = state.addressInput .. p1
            return { redraw = true }
        end

        if event == "char" then
            if state.editingAddress then
                state.addressInput = state.addressInput .. p1
                return { redraw = true }
            end

            if p1 == "r" then
                loadUrl(state, state.currentUrl, viewWidth)
                return { redraw = true }
            end

            if p1 == "l" then
                state.editingAddress = true
                return { redraw = true }
            end

            return nil
        end

        if event ~= "key" then
            return nil
        end

        if state.editingAddress then
            if p1 == keys.backspace then
                state.addressInput = state.addressInput:sub(1, -2)
                return { redraw = true }
            end

            if p1 == keys.enter then
                state.editingAddress = false
                loadUrl(state, state.addressInput, viewWidth)
                return { redraw = true }
            end

            if p1 == keys.escape then
                state.editingAddress = false
                state.addressInput = state.currentUrl
                return { redraw = true }
            end

            return nil
        end

        if p1 == keys.up then
            state.scroll = clamp(state.scroll - 1, 1, maxScroll)
            return { redraw = true }
        end

        if p1 == keys.down then
            state.scroll = clamp(state.scroll + 1, 1, maxScroll)
            return { redraw = true }
        end

        if p1 == keys.pageUp then
            state.scroll = clamp(state.scroll - 8, 1, maxScroll)
            return { redraw = true }
        end

        if p1 == keys.pageDown then
            state.scroll = clamp(state.scroll + 8, 1, maxScroll)
            return { redraw = true }
        end

        if p1 == keys.home then
            state.scroll = 1
            return { redraw = true }
        end

        if p1 == keys["end"] then
            state.scroll = maxScroll
            return { redraw = true }
        end

        if p1 == keys.r then
            loadUrl(state, state.currentUrl, viewWidth)
            return { redraw = true }
        end

        if p1 == keys.l then
            state.editingAddress = true
            return { redraw = true }
        end

        return nil
    end

    return app
end

return browser
