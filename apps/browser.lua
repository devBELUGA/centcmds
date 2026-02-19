local browser = {}

local namedColors = {
    white = colors.white, black = colors.black, gray = colors.gray, grey = colors.gray,
    lightgray = colors.lightGray, lightgrey = colors.lightGray, silver = colors.lightGray,
    red = colors.red, maroon = colors.red, orange = colors.orange, yellow = colors.yellow,
    olive = colors.brown, lime = colors.lime, green = colors.green, teal = colors.cyan,
    aqua = colors.cyan, cyan = colors.cyan, blue = colors.blue, navy = colors.blue,
    purple = colors.purple, magenta = colors.magenta, fuchsia = colors.magenta,
    pink = colors.pink, brown = colors.brown
}

local palette = {
    { c = colors.white, r = 240, g = 240, b = 240 },
    { c = colors.orange, r = 242, g = 178, b = 51 },
    { c = colors.magenta, r = 229, g = 127, b = 216 },
    { c = colors.lightBlue, r = 153, g = 178, b = 242 },
    { c = colors.yellow, r = 222, g = 222, b = 108 },
    { c = colors.lime, r = 127, g = 204, b = 25 },
    { c = colors.pink, r = 242, g = 178, b = 204 },
    { c = colors.gray, r = 76, g = 76, b = 76 },
    { c = colors.lightGray, r = 153, g = 153, b = 153 },
    { c = colors.cyan, r = 76, g = 153, b = 178 },
    { c = colors.purple, r = 178, g = 102, b = 229 },
    { c = colors.blue, r = 51, g = 102, b = 204 },
    { c = colors.brown, r = 127, g = 102, b = 76 },
    { c = colors.green, r = 87, g = 166, b = 78 },
    { c = colors.red, r = 204, g = 76, b = 76 },
    { c = colors.black, r = 17, g = 17, b = 17 }
}

local blockTags = {
    body = true, div = true, p = true, section = true, article = true, main = true,
    header = true, footer = true, nav = true, ul = true, ol = true, li = true,
    h1 = true, h2 = true, h3 = true, h4 = true, h5 = true, h6 = true, pre = true,
    table = true, tr = true, center = true
}

local defaultTagStyle = {
    body = { display = "block", fg = colors.black, bg = colors.white, align = "left" },
    a = { fg = colors.blue },
    p = { display = "block" }, div = { display = "block" }, section = { display = "block" },
    article = { display = "block" }, main = { display = "block" }, header = { display = "block" },
    footer = { display = "block" }, nav = { display = "block" }, ul = { display = "block" },
    ol = { display = "block" }, li = { display = "block" }, pre = { display = "block", whiteSpace = "pre", bg = colors.lightGray },
    h1 = { display = "block", fg = colors.blue, align = "center" },
    h2 = { display = "block", fg = colors.purple }, h3 = { display = "block", fg = colors.green },
    h4 = { display = "block", fg = colors.green }, h5 = { display = "block", fg = colors.green },
    h6 = { display = "block", fg = colors.green }, center = { display = "block", align = "center" }
}

local function trim(v)
    return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function copy(t)
    local o = {}
    if t then for k, v in pairs(t) do o[k] = v end end
    return o
end

local function merge(to, from)
    if from then for k, v in pairs(from) do to[k] = v end end
end

local function nearestColor(r, g, b)
    local best = colors.white
    local dist = 10 ^ 9
    for i = 1, #palette do
        local p = palette[i]
        local d = (p.r - r) ^ 2 + (p.g - g) ^ 2 + (p.b - b) ^ 2
        if d < dist then
            dist = d
            best = p.c
        end
    end
    return best
end

local function cssToColor(raw)
    local value = trim(raw):lower()
    if value == "" or value == "transparent" then return nil end
    if namedColors[value] then return namedColors[value] end

    local h3 = value:match("^#([0-9a-f][0-9a-f][0-9a-f])$")
    if h3 then
        return nearestColor(
            tonumber(h3:sub(1, 1) .. h3:sub(1, 1), 16),
            tonumber(h3:sub(2, 2) .. h3:sub(2, 2), 16),
            tonumber(h3:sub(3, 3) .. h3:sub(3, 3), 16)
        )
    end

    local h6 = value:match("^#([0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])$")
    if h6 then
        return nearestColor(
            tonumber(h6:sub(1, 2), 16),
            tonumber(h6:sub(3, 4), 16),
            tonumber(h6:sub(5, 6), 16)
        )
    end

    local rr, gg, bb = value:match("^rgb%s*%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)$")
    if rr then return nearestColor(tonumber(rr), tonumber(gg), tonumber(bb)) end
    return nil
end

local function parseDecls(css)
    local out = {}
    for part in tostring(css or ""):gmatch("([^;]+)") do
        local k, v = part:match("^%s*([%w%-_]+)%s*:%s*(.-)%s*$")
        if k and v then
            local key = k:lower()
            local val = trim(v):lower()
            if key == "color" then
                local c = cssToColor(val)
                if c then out.fg = c end
            elseif key == "background" or key == "background-color" then
                local c = cssToColor(val)
                if c then out.bg = c end
            elseif key == "text-align" then
                if val == "left" or val == "center" or val == "right" then out.align = val end
            elseif key == "display" then
                if val == "block" or val == "inline" then out.display = val end
            elseif key == "white-space" then
                out.whiteSpace = (val:find("pre", 1, true) and "pre") or "normal"
            end
        end
    end
    return out
end

local function parseCssRules(css)
    local rules = { tag = {}, class = {}, id = {} }
    for selectorBlob, declBlob in tostring(css or ""):gmatch("([^{}]+){([^}]*)}") do
        local patch = parseDecls(declBlob)
        for selector in selectorBlob:gmatch("([^,]+)") do
            local s = trim(selector):lower()
            local cl = s:match("^%.([%w_%-:]+)$")
            local id = s:match("^#([%w_%-:]+)$")
            local tag = s:match("^([%a][%w%-]*)$")
            if cl then
                rules.class[cl] = rules.class[cl] or {}
                merge(rules.class[cl], patch)
            elseif id then
                rules.id[id] = rules.id[id] or {}
                merge(rules.id[id], patch)
            elseif tag then
                rules.tag[tag] = rules.tag[tag] or {}
                merge(rules.tag[tag], patch)
            end
        end
    end
    return rules
end

local function decodeEntities(text)
    local out = tostring(text or "")
    out = out:gsub("&nbsp;", " "):gsub("&amp;", "&"):gsub("&quot;", "\""):gsub("&#39;", "'"):gsub("&lt;", "<"):gsub("&gt;", ">")
    out = out:gsub("&#x([0-9a-fA-F]+);", function(h)
        local n = tonumber(h, 16)
        if n and n >= 32 and n <= 126 then return string.char(n) end
        return " "
    end)
    out = out:gsub("&#([0-9]+);", function(d)
        local n = tonumber(d, 10)
        if n and n >= 32 and n <= 126 then return string.char(n) end
        return " "
    end)
    return out
end

local function sanitizeHtml(raw)
    local html = tostring(raw or ""):gsub("\r", "")
    local css = {}
    html = html:gsub("<!--.-%-%->", " ")
    html = html:gsub("<[sS][tT][yY][lL][eE][^>]*>(.-)</[sS][tT][yY][lL][eE]>", function(block) css[#css + 1] = block return " " end)
    html = html:gsub("<[sS][cC][rR][iI][pP][tT][^>]*>.-</[sS][cC][rR][iI][pP][tT]>", " ")
    html = html:gsub("<[nN][oO][sS][cC][rR][iI][pP][tT][^>]*>.-</[nN][oO][sS][cC][rR][iI][pP][tT]>", " ")
    return html, table.concat(css, "\n")
end

local function parseAttrs(token)
    local out = {}
    local body = token:match("^<%s*/?%s*[%w:_-]+(.-)/?%s*>$")
    if not body then return out end
    for k, v in body:gmatch("([%w:_%-]+)%s*=%s*\"(.-)\"") do out[k:lower()] = v end
    for k, v in body:gmatch("([%w:_%-]+)%s*=%s*'(.-)'") do out[k:lower()] = v end
    for k, v in body:gmatch("([%w:_%-]+)%s*=%s*([^%s\"'>/]+)") do
        local kk = k:lower()
        if out[kk] == nil then out[kk] = v end
    end
    return out
end

local function splitClasses(raw)
    local out = {}
    for token in tostring(raw or ""):gmatch("([^%s]+)") do out[#out + 1] = token:lower() end
    return out
end

local function resolveUrl(base, href)
    local raw = trim(href)
    if raw == "" then return nil end
    if raw:match("^%a[%w+%-%.]*://") then return raw end
    local scheme, host, path = tostring(base or ""):match("^(https?)://([^/%?#]+)([^?#]*)")
    if not scheme or not host then return raw end
    path = path ~= "" and path or "/"
    if raw:sub(1, 2) == "//" then return scheme .. ":" .. raw end
    if raw:sub(1, 1) == "/" then return scheme .. "://" .. host .. raw end
    local baseDir = path:gsub("[^/]+$", "")
    return scheme .. "://" .. host .. baseDir .. raw
end

local function computeStyle(parent, tag, attrs, rules)
    local style = copy(parent)
    merge(style, defaultTagStyle[tag])
    merge(style, rules.tag[tag])
    local classes = splitClasses(attrs.class)
    for i = 1, #classes do merge(style, rules.class[classes[i]]) end
    if attrs.id then merge(style, rules.id[attrs.id:lower()]) end
    if attrs.style then merge(style, parseDecls(attrs.style)) end
    if not style.display then style.display = blockTags[tag] and "block" or "inline" end
    if not style.fg then style.fg = parent.fg or colors.black end
    if not style.bg then style.bg = parent.bg or colors.white end
    if not style.align then style.align = parent.align or "left" end
    if not style.whiteSpace then style.whiteSpace = parent.whiteSpace or "normal" end
    return style
end

local function parseHtmlBlocks(html, baseUrl)
    local cleaned, cssText = sanitizeHtml(html)
    local rules = parseCssRules(cssText)
    local blocks = {}

    local stack = {{
        tag = "root",
        href = nil,
        style = { fg = colors.black, bg = colors.white, align = "left", display = "block", whiteSpace = "normal" }
    }}

    local current = nil

    local function top() return stack[#stack] end
    local function flush()
        if current and #current.segments > 0 then blocks[#blocks + 1] = current end
        current = nil
    end
    local function ensure(ctx)
        if not current then
            current = { align = ctx.style.align, bg = ctx.style.bg, segments = {} }
        end
    end
    local function addText(ctx, txt)
        local value = decodeEntities(txt)
        if ctx.style.whiteSpace ~= "pre" then
            value = value:gsub("%s+", " ")
            if trim(value) == "" then
                return
            end
        end
        if value == "" then return end
        ensure(ctx)
        current.segments[#current.segments + 1] = {
            text = value, fg = ctx.style.fg, bg = ctx.style.bg, href = ctx.href, whiteSpace = ctx.style.whiteSpace
        }
    end

    for token in cleaned:gmatch("(<[^>]+>|[^<]+)") do
        if token:sub(1, 1) == "<" then
            local tag = token:match("^<%s*/?%s*([%w:_%-]+)")
            tag = tag and tag:lower() or nil
            if tag then
                local isClose = token:match("^<%s*/") ~= nil
                if isClose then
                    for i = #stack, 2, -1 do
                        if stack[i].tag == tag then
                            if stack[i].style.display == "block" then flush() end
                            table.remove(stack, i)
                            break
                        end
                    end
                elseif tag == "br" then
                    addText(top(), "\n")
                else
                    local attrs = parseAttrs(token)
                    local style = computeStyle(top().style, tag, attrs, rules)
                    local href = top().href
                    if tag == "a" and attrs.href then href = resolveUrl(baseUrl, attrs.href) end
                    local ctx = { tag = tag, href = href, style = style }
                    if style.display == "block" then
                        flush()
                        if tag == "li" then
                            ensure(ctx)
                            current.segments[#current.segments + 1] = { text = "* ", fg = style.fg, bg = style.bg, whiteSpace = "normal" }
                        end
                    end
                    if tag == "img" then
                        ensure(ctx)
                        current.segments[#current.segments + 1] = {
                            text = attrs.alt and ("[Image: " .. attrs.alt .. "]") or "[Image]",
                            fg = colors.gray,
                            bg = style.bg,
                            href = attrs.src and resolveUrl(baseUrl, attrs.src) or nil,
                            whiteSpace = "normal"
                        }
                        flush()
                    elseif token:match("/%s*>$") == nil then
                        stack[#stack + 1] = ctx
                    end
                end
            end
        else
            addText(top(), token)
        end
    end

    flush()
    if #blocks == 0 then
        blocks[1] = { align = "left", bg = colors.white, segments = { { text = "(empty page)", fg = colors.gray, bg = colors.white } } }
    end
    return blocks
end

local function extractPlainText(html)
    local cleaned = tostring(html or "")
    cleaned = cleaned:gsub("\r", "")
    cleaned = cleaned:gsub("<!--.-%-%->", " ")
    cleaned = cleaned:gsub("<[sS][cC][rR][iI][pP][tT][^>]*>.-</[sS][cC][rR][iI][pP][tT]>", " ")
    cleaned = cleaned:gsub("<[sS][tT][yY][lL][eE][^>]*>.-</[sS][tT][yY][lL][eE]>", " ")
    cleaned = cleaned:gsub("<[nN][oO][sS][cC][rR][iI][pP][tT][^>]*>.-</[nN][oO][sS][cC][rR][iI][pP][tT]>", " ")
    cleaned = cleaned:gsub("<[bB][rR]%s*/?>", "\n")
    cleaned = cleaned:gsub("</[pP]>", "\n")
    cleaned = cleaned:gsub("</[dD][iI][vV]>", "\n")
    cleaned = cleaned:gsub("</[hH][1-6]>", "\n")
    cleaned = cleaned:gsub("</[lL][iI]>", "\n")
    cleaned = cleaned:gsub("<[^>]+>", " ")
    cleaned = decodeEntities(cleaned)
    cleaned = cleaned:gsub("[ \t]+", " ")
    cleaned = cleaned:gsub("\n%s+", "\n")
    cleaned = cleaned:gsub("\n\n+", "\n\n")
    return trim(cleaned)
end

local function extractTitle(html)
    local title = tostring(html or ""):match("<[tT][iI][tT][lL][eE][^>]*>(.-)</[tT][iI][tT][lL][eE]>")
    if not title then
        return nil
    end
    title = decodeEntities(title:gsub("<[^>]+>", " "))
    title = trim(title:gsub("%s+", " "))
    if title == "" then
        return nil
    end
    return title
end

local function extractDescription(html)
    local raw = tostring(html or "")
    local d1 = raw:match("<[mM][eE][tT][aA][^>]-name%s*=%s*[\"']description[\"'][^>]-content%s*=%s*[\"'](.-)[\"'][^>]->")
    local d2 = raw:match("<[mM][eE][tT][aA][^>]-content%s*=%s*[\"'](.-)[\"'][^>]-name%s*=%s*[\"']description[\"'][^>]->")
    local desc = d1 or d2
    if not desc then
        return nil
    end
    desc = decodeEntities(desc)
    desc = trim(desc:gsub("%s+", " "))
    if desc == "" then
        return nil
    end
    return desc
end

local function extractLinks(html, baseUrl, limit)
    local links = {}
    local maxLinks = limit or 24

    for href, text in tostring(html or ""):gmatch("<[aA][^>]-href%s*=%s*[\"'](.-)[\"'][^>]*>(.-)</[aA]>") do
        local label = decodeEntities(text:gsub("<[^>]+>", " "))
        label = trim(label:gsub("%s+", " "))
        if label ~= "" then
            local resolved = resolveUrl(baseUrl, href)
            if resolved then
                links[#links + 1] = {
                    href = resolved,
                    label = label
                }
                if #links >= maxLinks then
                    break
                end
            end
        end
    end

    return links
end

local function countVisibleChars(blocks)
    local total = 0
    for i = 1, #blocks do
        local block = blocks[i]
        for j = 1, #block.segments do
            local text = tostring(block.segments[j].text or "")
            text = text:gsub("%s+", "")
            total = total + #text
        end
    end
    return total
end

local function addSimpleBlock(blocks, text, fg, bg, href, align, pre)
    blocks[#blocks + 1] = {
        align = align or "left",
        bg = bg or colors.white,
        segments = {
            {
                text = text,
                fg = fg or colors.black,
                bg = bg or colors.white,
                href = href,
                whiteSpace = pre and "pre" or "normal"
            }
        }
    }
end

local function buildFallbackBlocks(html, baseUrl)
    local blocks = {}
    local title = extractTitle(html) or baseUrl or "Page"
    local desc = extractDescription(html)
    local links = extractLinks(html, baseUrl, 30)
    local text = extractPlainText(html)

    addSimpleBlock(blocks, title, colors.blue, colors.white, nil, "center")
    addSimpleBlock(blocks, "Simplified browser view", colors.gray, colors.white)
    if desc then
        addSimpleBlock(blocks, desc, colors.black, colors.white)
    end

    if #links > 0 then
        addSimpleBlock(blocks, "Links:", colors.purple, colors.white)
        for i = 1, #links do
            local link = links[i]
            local line = tostring(i) .. ". " .. link.label
            addSimpleBlock(blocks, line, colors.blue, colors.white, link.href)
        end
    end

    if text ~= "" then
        addSimpleBlock(blocks, "Text snapshot:", colors.green, colors.white)
        local clipped = text
        if #clipped > 7000 then
            clipped = clipped:sub(1, 7000) .. "\n...[truncated]"
        end
        addSimpleBlock(blocks, clipped, colors.black, colors.white, nil, "left", true)
    else
        addSimpleBlock(blocks, "No readable text found on this page.", colors.red, colors.white)
    end

    return blocks
end

local function buildRows(blocks, width)
    local rows = {}
    local function newRow(bg, align) return { runs = {}, len = 0, bg = bg or colors.white, align = align or "left" } end
    local function pushChar(row, ch, fg, bg, href)
        local last = row.runs[#row.runs]
        if last and last.fg == fg and last.bg == bg and last.href == href then last.text = last.text .. ch
        else row.runs[#row.runs + 1] = { text = ch, fg = fg, bg = bg, href = href } end
        row.len = row.len + 1
    end

    for i = 1, #blocks do
        local b = blocks[i]
        local row = newRow(b.bg, b.align)
        for j = 1, #b.segments do
            local s = b.segments[j]
            local text = tostring(s.text or "")
            if s.whiteSpace ~= "pre" then text = text:gsub("%s+", " ") end
            for k = 1, #text do
                local ch = text:sub(k, k)
                if ch == "\n" then
                    rows[#rows + 1] = row
                    row = newRow(b.bg, b.align)
                else
                    if row.len >= width then
                        rows[#rows + 1] = row
                        row = newRow(b.bg, b.align)
                    end
                    pushChar(row, ch, s.fg or colors.black, s.bg or b.bg or colors.white, s.href)
                end
            end
        end
        rows[#rows + 1] = row
        rows[#rows + 1] = newRow(b.bg, "left")
    end
    if #rows == 0 then rows[1] = newRow(colors.white, "left") end
    return rows
end

local function isHtmlResponse(headers, body)
    if type(headers) == "table" then
        for k, v in pairs(headers) do
            if tostring(k):lower() == "content-type" and tostring(v):lower():find("text/html", 1, true) then return true end
        end
    end
    local probe = tostring(body or ""):sub(1, 512):lower()
    return probe:find("<html", 1, true) or probe:find("<!doctype html", 1, true)
end

local function fetch(url)
    local req = { url = url, redirect = true, timeout = 15, headers = { ["User-Agent"] = "CompiBrowser/2.1" } }
    local ok, r1, r2, r3 = pcall(http.get, req)
    if ok then return r1, r2, r3 end
    local ok2, a, b, c = pcall(http.get, url, req.headers, false)
    if ok2 then return a, b, c end
    return nil, tostring(r1), nil
end

local function loadUrl(state, rawUrl, width)
    if not http then
        state.status = "HTTP API disabled in config."
        state.blocks = { { align = "left", bg = colors.white, segments = { { text = "Enable HTTP in CC config.", fg = colors.red, bg = colors.white } } } }
        state.rows = buildRows(state.blocks, width)
        state.scroll = 1
        return
    end

    local url = trim(rawUrl)
    if url == "" then state.status = "Enter URL."; return end
    if not url:match("^%a[%w+%-%.]*://") then url = "https://" .. url end

    if http.checkURL then
        local ok, reason = http.checkURL(url)
        if not ok then state.status = "Blocked URL: " .. tostring(reason); return end
    end

    state.currentUrl, state.addressInput, state.scroll = url, url, 1
    state.status = "Loading " .. url

    local response, err, fail = fetch(url)
    local handle = response or fail
    if not handle then
        state.status = "Request failed: " .. tostring(err)
        state.blocks = { { align = "left", bg = colors.white, segments = { { text = "Request failed:\n" .. tostring(err), fg = colors.red, bg = colors.white } } } }
        state.rows = buildRows(state.blocks, width)
        return
    end

    local code, message = handle.getResponseCode()
    local headers = handle.getResponseHeaders and handle.getResponseHeaders() or {}
    local body = handle.readAll() or ""
    handle.close()

    if #body > 220000 then body = body:sub(1, 220000) end

    local host = url:match("^https?://([^/%?#]+)") or "site"
    state.status = tostring(code) .. " " .. tostring(message or "") .. " | " .. host
    if host:find("youtube%.com") or host:find("youtu%.be") then
        state.status = state.status .. " | Video/JS limited in CC"
    end

    if isHtmlResponse(headers, body) then
        local parsed = parseHtmlBlocks(body, url)
        if countVisibleChars(parsed) < 80 then
            parsed = buildFallbackBlocks(body, url)
            state.status = state.status .. " | fallback"
        end
        state.blocks = parsed
    else
        state.blocks = { { align = "left", bg = colors.white, segments = { { text = body, fg = colors.black, bg = colors.white, whiteSpace = "pre" } } } }
    end

    state.rows = buildRows(state.blocks, width)
    state.scroll = 1
end

function browser.new(ui)
    local app = { title = "Browser", iconLabel = "Browser", iconGlyph = "B", iconColor = colors.orange, minW = 40, minH = 10 }

    function app.defaultSize(layout)
        return math.min(70, math.max(40, layout.width - 6)), math.min(18, math.max(10, layout.height - 7))
    end

    function app.createState()
        return {
            currentUrl = "https://www.google.com",
            addressInput = "https://www.google.com",
            editingAddress = true,
            status = "Ready",
            blocks = { { align = "left", bg = colors.white, segments = { { text = "Loading...", fg = colors.black, bg = colors.white } } } },
            rows = {},
            scroll = 1,
            links = {},
            firstLoadDone = false
        }
    end

    function app.resize(state, width)
        local w = math.max(10, width)
        if not state.firstLoadDone then
            loadUrl(state, state.currentUrl, w)
            state.firstLoadDone = true
        else
            state.rows = buildRows(state.blocks, w)
            state.scroll = clamp(state.scroll, 1, math.max(1, #state.rows))
        end
    end

    function app.draw(state, target, width, height, focused)
        ui.fillBox(target, 1, 1, width, height, colors.white)
        if width < 20 or height < 7 then
            ui.fillBox(target, 1, 1, width, height, colors.black)
            ui.writeAt(target, 1, 1, "Resize browser window", colors.red, colors.black)
            target.setCursorBlink(false)
            return
        end

        local go, reload = "[GO]", "[R]"
        local goX = width - #go + 1
        local rX = goX - #reload - 1
        local fieldX = 5
        local fieldW = math.max(6, rX - fieldX - 1)

        ui.fillBox(target, 1, 1, width, 1, colors.lightGray)
        ui.writeAt(target, 1, 1, "URL:", colors.black, colors.lightGray)
        local shown = state.addressInput
        if #shown > fieldW then shown = shown:sub(#shown - fieldW + 1) end
        ui.fillBox(target, fieldX, 1, fieldX + fieldW - 1, 1, colors.white)
        ui.writeAt(target, fieldX, 1, shown, colors.black, colors.white)
        ui.writeAt(target, rX, 1, reload, colors.white, colors.blue)
        ui.writeAt(target, goX, 1, go, colors.white, colors.blue)

        ui.fillBox(target, 1, 2, width, 2, colors.gray)
        ui.writeAt(target, 1, 2, ui.ellipsize(state.status, width), colors.white, colors.gray)

        local viewY, viewH = 3, height - 2
        local maxScroll = math.max(1, #state.rows - viewH + 1)
        state.scroll = clamp(state.scroll, 1, maxScroll)
        state.links = {}

        for row = 1, viewH do
            local src = state.rows[state.scroll + row - 1]
            local y = viewY + row - 1
            if src then
                local rowBg = src.bg or colors.white
                ui.fillBox(target, 1, y, width, y, rowBg)
                local x = 1
                if src.align == "center" then x = math.floor((width - src.len) / 2) + 1
                elseif src.align == "right" then x = width - src.len + 1 end
                x = clamp(x, 1, width)

                for i = 1, #src.runs do
                    local run = src.runs[i]
                    local txt = run.text
                    local draw = txt
                    local dx = x
                    if dx + #draw - 1 > width then draw = draw:sub(1, width - dx + 1) end
                    if #draw > 0 and dx <= width then
                        local fg = run.href and colors.blue or (run.fg or colors.black)
                        ui.writeAt(target, dx, y, draw, fg, run.bg or rowBg)
                        if run.href then state.links[#state.links + 1] = { x1 = dx, x2 = dx + #draw - 1, y = y, href = run.href } end
                    end
                    x = x + #txt
                end
            else
                ui.fillBox(target, 1, y, width, y, colors.white)
            end
        end

        if maxScroll > 1 then
            local mark = ("[%d/%d]"):format(state.scroll, maxScroll)
            ui.writeAt(target, math.max(1, width - #mark + 1), height, mark, colors.lightGray, colors.white)
        end

        if focused and state.editingAddress then
            local cx = clamp(fieldX + #shown + 1, fieldX, fieldX + fieldW)
            target.setCursorPos(cx, 1)
            target.setCursorBlink(true)
        else
            target.setCursorBlink(false)
        end
    end

    function app.handle(state, event, p1, p2, p3, ctx)
        local width = math.max(10, ctx.width)
        local viewH = math.max(1, ctx.height - 2)
        local maxScroll = math.max(1, #state.rows - viewH + 1)
        local goX = width - 3
        local rX = goX - 4

        if event == "mouse_click" then
            local x, y = p2, p3
            if y == 1 then
                if x >= goX then
                    state.editingAddress = false
                    loadUrl(state, state.addressInput, width)
                    return { redraw = true }
                elseif x >= rX and x < goX then
                    state.editingAddress = false
                    loadUrl(state, state.currentUrl, width)
                    return { redraw = true }
                else
                    state.editingAddress = true
                    return { redraw = true }
                end
            end

            if y >= 3 then
                for i = 1, #state.links do
                    local link = state.links[i]
                    if y == link.y and x >= link.x1 and x <= link.x2 then
                        loadUrl(state, link.href, width)
                        return { redraw = true }
                    end
                end
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
            if p1 == "r" then loadUrl(state, state.currentUrl, width); return { redraw = true } end
            if p1 == "l" then state.editingAddress = true; return { redraw = true } end
            return nil
        end

        if event ~= "key" then return nil end

        if state.editingAddress then
            if p1 == keys.backspace then
                state.addressInput = state.addressInput:sub(1, -2)
                return { redraw = true }
            elseif p1 == keys.enter then
                state.editingAddress = false
                loadUrl(state, state.addressInput, width)
                return { redraw = true }
            elseif p1 == keys.escape then
                state.editingAddress = false
                state.addressInput = state.currentUrl
                return { redraw = true }
            end
            return nil
        end

        if p1 == keys.up then state.scroll = clamp(state.scroll - 1, 1, maxScroll); return { redraw = true } end
        if p1 == keys.down then state.scroll = clamp(state.scroll + 1, 1, maxScroll); return { redraw = true } end
        if p1 == keys.pageUp then state.scroll = clamp(state.scroll - 8, 1, maxScroll); return { redraw = true } end
        if p1 == keys.pageDown then state.scroll = clamp(state.scroll + 8, 1, maxScroll); return { redraw = true } end
        if p1 == keys.home then state.scroll = 1; return { redraw = true } end
        if p1 == keys["end"] then state.scroll = maxScroll; return { redraw = true } end
        if p1 == keys.r then loadUrl(state, state.currentUrl, width); return { redraw = true } end
        if p1 == keys.l then state.editingAddress = true; return { redraw = true } end
        return nil
    end

    return app
end

return browser
