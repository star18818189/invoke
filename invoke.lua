
            local box = New("Frame", {
                Position = UDim2.fromOffset(0, 19),
                Size = UDim2.new(1, 0, 0, 21),
                BackgroundColor3 = C.Control,
                BorderSizePixel = 1,
                BorderColor3 = C.Border,
                ZIndex = 6,
            }, row)

            local valueText = Label(box, tostring(current), 12, C.Text)
            valueText.Position = UDim2.fromOffset(7, 0)
            valueText.Size = UDim2.new(1, -30, 1, 0)
            valueText.ZIndex = 7

            local arrow = Label(box, "≡", 12, C.Dim)
            arrow.Position = UDim2.new(1, -27, 0, 0)
            arrow.Size = UDim2.fromOffset(20, 21)
            arrow.TextXAlignment = Enum.TextXAlignment.Center
            arrow.ZIndex = 7

            local popup

            local function close()
                if popup then popup:Destroy(); popup = nil end
            end

            local function open()
                close()
                popup = New("Frame", {
                    Position = UDim2.new(0, 0, 1, 1),
                    Size = UDim2.new(1, 0, 0, math.min(#options * 21, 147)),
                    BackgroundColor3 = C.Control,
                    BorderSizePixel = 1,
                    BorderColor3 = C.Border,
                    ZIndex = 100,
                }, box)

                New("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }, popup)

                for _, option in ipairs(options) do
                    local b = New("TextButton", {
                        Size = UDim2.new(1, 0, 0, 21),
                        BackgroundColor3 = C.Control,
                        BorderSizePixel = 0,
                        AutoButtonColor = false,
                        Text = tostring(option),
                        Font = FONT,
                        TextSize = 12,
                        TextColor3 = C.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 101,
                    }, popup)
                    Pad(b, 7, 4, 0, 0)

                    b.MouseEnter:Connect(function()
                        b.BackgroundColor3 = C.TabHover
                    end)
                    b.MouseLeave:Connect(function()
                        b.BackgroundColor3 = C.Control
                    end)
                    b.MouseButton1Click:Connect(function()
                        current = option
                        valueText.Text = tostring(option)
                        close()
                        if callback then callback(option) end
                    end)
                end
            end

            row.MouseButton1Click:Connect(function()
                if popup then close() else open() end
            end)

            local control = {}
            function control:Set(v, silent)
                current = v
                valueText.Text = tostring(v)
                if not silent and callback then callback(v) end
            end
            function control:Get() return current end
            return control
        end

        function Section:AddButton(name2, callback)
            local b = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundColor3 = C.Control,
                BorderSizePixel = 1,
                BorderColor3 = C.Border,
                AutoButtonColor = false,
                Text = name2,
                Font = FONT,
                TextSize = 12,
                TextColor3 = C.Text,
            }, body)
            Border(b, C.Border2, 1)

            b.MouseEnter:Connect(function() b.BackgroundColor3 = C.TabHover end)
            b.MouseLeave:Connect(function() b.BackgroundColor3 = C.Control end)
            b.MouseButton1Click:Connect(function()
                if callback then callback() end
            end)
            return b
        end

        function Section:AddLabel(value)
            local l = Label(body, value, 12, C.Text)
            l.Size = UDim2.new(1, 0, 0, 18)
            return l
        end

        return Section
    end

    function Window:AddSection(tab, name, side, height)
        assert(tab and tab.Page, "Pass a tab returned by Window:AddTab()")
        return AddSection(tab, name, side, height)
    end

    return Window
end

return Library
