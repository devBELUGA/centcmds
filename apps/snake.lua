local snake = {}

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

local function keyForCell(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function spawnFood(state)
    local used = {}
    for i = 1, #state.snake do
        used[keyForCell(state.snake[i].x, state.snake[i].y)] = true
    end

    local cells = {}
    for y = state.board.y1, state.board.y2 do
        for x = state.board.x1, state.board.x2 do
            if not used[keyForCell(x, y)] then
                cells[#cells + 1] = { x = x, y = y }
            end
        end
    end

    if #cells == 0 then
        return nil
    end

    return cells[math.random(1, #cells)]
end

local function resetGame(state, width, height)
    if width < 16 or height < 10 then
        state.tooSmall = true
        state.timerId = nil
        return
    end

    state.tooSmall = false
    state.board = {
        x1 = 2,
        y1 = 3,
        x2 = width - 1,
        y2 = height - 1
    }

    local centerX = math.floor((state.board.x1 + state.board.x2) / 2)
    local centerY = math.floor((state.board.y1 + state.board.y2) / 2)

    state.snake = {
        { x = centerX, y = centerY },
        { x = centerX - 1, y = centerY },
        { x = centerX - 2, y = centerY }
    }

    state.direction = "right"
    state.nextDirection = "right"
    state.score = 0
    state.speed = 0.16
    state.gameOver = false
    state.food = spawnFood(state)
    state.timerId = os.startTimer(state.speed)
end

local function setDirection(state, direction)
    if not direction then
        return
    end
    if opposite[state.direction] == direction then
        return
    end
    state.nextDirection = direction
end

local function stepGame(state)
    if state.tooSmall or state.gameOver then
        return
    end

    state.direction = state.nextDirection
    local vector = vectors[state.direction]
    local head = state.snake[1]

    local nextHead = {
        x = head.x + vector[1],
        y = head.y + vector[2]
    }

    if nextHead.x < state.board.x1 or nextHead.x > state.board.x2 or nextHead.y < state.board.y1 or nextHead.y > state.board.y2 then
        state.gameOver = true
        state.timerId = nil
        return
    end

    local grow = state.food and nextHead.x == state.food.x and nextHead.y == state.food.y
    local collisionLimit = grow and #state.snake or (#state.snake - 1)

    for i = 1, collisionLimit do
        if state.snake[i].x == nextHead.x and state.snake[i].y == nextHead.y then
            state.gameOver = true
            state.timerId = nil
            return
        end
    end

    table.insert(state.snake, 1, nextHead)

    if grow then
        state.score = state.score + 1
        state.speed = math.max(0.06, state.speed - 0.004)
        state.food = spawnFood(state)
    else
        table.remove(state.snake)
    end

    state.timerId = os.startTimer(state.speed)
end

function snake.new(ui)
    local app = {
        title = "Snake",
        iconLabel = "Snake",
        iconGlyph = "S",
        iconColor = colors.green,
        minW = 18,
        minH = 10
    }

    function app.defaultSize(layout)
        local contentW = math.min(40, math.max(18, layout.width - 16))
        local contentH = math.min(20, math.max(10, layout.height - 8))
        return contentW, contentH
    end

    function app.createState()
        return {
            tooSmall = false,
            board = { x1 = 2, y1 = 3, x2 = 2, y2 = 3 },
            snake = {},
            food = nil,
            direction = "right",
            nextDirection = "right",
            score = 0,
            speed = 0.16,
            timerId = nil,
            gameOver = false
        }
    end

    function app.resize(state, width, height)
        resetGame(state, width, height)
    end

    function app.draw(state, target, width, height)
        ui.fillBox(target, 1, 1, width, height, colors.black)

        if state.tooSmall then
            ui.writeAt(target, 1, 1, "Snake needs at least 16x10", colors.red, colors.black)
            ui.writeAt(target, 1, 2, "Resize this window", colors.lightGray, colors.black)
            return
        end

        local info = "Snake | Score: " .. tostring(state.score)
        ui.writeAt(target, 1, 1, ui.ellipsize(info, width), colors.white, colors.black)

        ui.fillBox(target, 1, 2, width, height, colors.gray)
        ui.fillBox(target, 2, 3, width - 1, height - 1, colors.black)

        if state.food then
            ui.writeAt(target, state.food.x, state.food.y, " ", colors.black, colors.red)
        end

        for i = 1, #state.snake do
            local segment = state.snake[i]
            local color = (i == 1) and colors.lime or colors.green
            ui.writeAt(target, segment.x, segment.y, " ", colors.black, color)
        end

        if state.gameOver then
            local line1 = "Game Over"
            local line2 = "Enter restart"
            ui.writeAt(target, ui.centeredX(line1, width), math.floor(height / 2), line1, colors.red, colors.black)
            ui.writeAt(target, ui.centeredX(line2, width), math.floor(height / 2) + 1, line2, colors.white, colors.black)
        end
    end

    function app.handle(state, event, p1, p2, p3, ctx)
        if event == "timer" and p1 == state.timerId then
            stepGame(state)
            return { redraw = true }
        end

        if event == "window_resized" then
            resetGame(state, ctx.width, ctx.height)
            return { redraw = true }
        end

        if event == "key" then
            if p1 == keys.up or p1 == keys.w then
                setDirection(state, "up")
                return { redraw = true }
            end
            if p1 == keys.down or p1 == keys.s then
                setDirection(state, "down")
                return { redraw = true }
            end
            if p1 == keys.left or p1 == keys.a then
                setDirection(state, "left")
                return { redraw = true }
            end
            if p1 == keys.right or p1 == keys.d then
                setDirection(state, "right")
                return { redraw = true }
            end
            if p1 == keys.enter and state.gameOver then
                resetGame(state, ctx.width, ctx.height)
                return { redraw = true }
            end
        end

        return nil
    end

    return app
end

return snake
