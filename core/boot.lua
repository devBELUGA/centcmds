local boot = {}

function boot.run(ui, pullEvent)
    local selected = 1

    while true do
        local width, height = term.getSize()
        ui.clear(term.current(), colors.black)

        local title = "CompiOS"
        local subtitle = "Boot Menu"
        local optionY = math.floor(height / 2) - 1

        ui.writeAt(term.current(), ui.centeredX(title, width), math.max(2, optionY - 3), title, colors.green, colors.black)
        ui.writeAt(term.current(), ui.centeredX(subtitle, width), math.max(3, optionY - 2), subtitle, colors.lightGray, colors.black)

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

            ui.writeAt(term.current(), ui.centeredX(text, width), optionY + i - 1, text, textColor, colors.black)
        end

        local hint = "Up/Down select | Enter confirm"
        ui.writeAt(term.current(), ui.centeredX(hint, width), height - 1, hint, colors.gray, colors.black)

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
            if y == optionY then
                return 1
            end
            if y == optionY + 1 then
                return 2
            end
        elseif event == "terminate" then
            return 2
        end
    end
end

return boot
