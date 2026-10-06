--[[
    ThugSense V2 - screenshot-matched Roblox UI shell
    -------------------------------------------------
    A reusable UI library based on the supplied 500x550 reference.
    Designed to load from a raw GitHub URL in common Roblox executor environments.

    This module recreates the visual/layout system only. The callbacks are
    intentionally generic; attach your own legitimate game/settings logic.

    Can be loaded directly with: loadstring(game:HttpGet(RAW_URL))()
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Library = {}
Library.__index = Library

local C = {
    Window      = Color3.fromRGB(13, 15, 16),
    Top         = Color3.fromRGB(14, 16, 17),
    Tab         = Color3.fromRGB(16, 18, 19),
    TabHover    = Color3.fromRGB(19, 22, 23),
    Panel       = Color3.fromRGB(19, 22, 23),
    PanelHead   = Color3.fromRGB(20, 23, 24),
    Control     = Color3.fromRGB(24, 27, 28),
    Track       = Color3.fromRGB(10, 13, 14),
    Border      = Color3.fromRGB(4, 6, 7),
    Border2     = Color3.fromRGB(40, 44, 45),
    Text        = Color3.fromRGB(185, 188, 188),
    Dim         = Color3.fromRGB(115, 119, 119),
    Accent      = Color3.fromRGB(40, 203, 168),
    AccentDark  = Color3.fromRGB(26, 150, 126),
    Knob        = Color3.fromRGB(182, 188, 187),
}

local FONT = Enum.Font.Code

local function New(class, props, parent)
    local x = Instance.new(class)
    for k, v in pairs(props or {}) do x[k] = v end
    x.Parent = parent
    return x
end

local function Border(parent, color, thickness)
    return New("UIStroke", {
        Color = color or C.Border,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function Label(parent, value, size, color)
    return New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = value or "",
        Font = FONT,
        TextSize = size or 12,
        TextColor3 = color or C.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)
end

local function Pad(parent, l, r, t, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
    }, parent)
end

function Library.new(title)
    -- Executor-friendly GUI parent. No LocalScript/PlayerGui dependency.
    local guiParent
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then guiParent = result end
    end
    if not guiParent then
        guiParent = game:GetService("CoreGui")
    end

    local old = guiParent:FindFirstChild("ThugSenseV2")
    if old then old:Destroy() end

    local gui = New("ScreenGui", {
        Name = "ThugSenseV2",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, guiParent)

    -- Optional executor GUI protection.
    pcall(function()
        if type(protectgui) == "function" then
            protectgui(gui)
        elseif syn and type(syn.protect_gui) == "function" then
            syn.protect_gui(gui)
        end
    end)

    -- Exact reference size: 500 x 550.
    local window = New("Frame", {
        Name = "Window",
        Size = UDim2.fromOffset(500, 550),
        Position = UDim2.new(0.5, -250, 0.5, -275),
        BackgroundColor3 = C.Window,
        BorderSizePixel = 1,
        BorderColor3 = Color3.fromRGB(2, 3, 4),
        Active = true,
    }, gui)
    Border(window, Color3.fromRGB(50, 53, 54), 1)

    local inner = New("Frame", {
        Name = "Inner",
        Position = UDim2.fromOffset(3, 3),
        Size = UDim2.new(1, -6, 1, -6),
        BackgroundColor3 = C.Window,
        BorderSizePixel = 1,
        BorderColor3 = C.Border,
    }, window)

    -- 36px title bar
    local titleBar = New("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = C.Top,
        BorderSizePixel = 1,
        BorderColor3 = C.Border,
        Active = true,
    }, inner)

    local titleText = Label(titleBar, title or "thug sense!", 12, C.Text)
    titleText.Size = UDim2.fromScale(1, 1)
    titleText.TextXAlignment = Enum.TextXAlignment.Center

    -- 32px tab strip
    local tabBar = New("Frame", {
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = C.Tab,
        BorderSizePixel = 1,
        BorderColor3 = C.Border,
    }, inner)

    local content = New("Frame", {
        Position = UDim2.fromOffset(0, 68),
        Size = UDim2.new(1, 0, 1, -68),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, inner)

    -- Dragging, matching the reference's simple top-bar behavior.
    local dragging = false
    local dragStart
    local startPos

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = window.Position
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            window.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)

    local Window = {
        Gui = gui,
        Frame = window,
        Tabs = {},
    }

    function Window:SetTitle(value)
        titleText.Text = value
    end

    function Window:Toggle()
        window.Visible = not window.Visible
    end

    function Window:Destroy()
        gui:Destroy()
    end

    local tabWidths = {
        Rage = 49,
        Legit = 67,
        Players = 74,
        Movement = 88,
        Exploits = 83,
        Settings = 88,
        Search = 88,
    }

    local currentTab

    function Window:AddTab(name)
        local width = tabWidths[name] or math.max(60, (#name * 8) + 20)

        local button = New("TextButton", {
            Name = name,
            Size = UDim2.fromOffset(width, 32),
            BackgroundColor3 = C.Tab,
            BorderSizePixel = 1,
            BorderColor3 = C.Border,
            AutoButtonColor = false,
            Text = name,
            Font = FONT,
            TextSize = 12,
            TextColor3 = C.Dim,
        }, tabBar)

        local underline = New("Frame", {
            Position = UDim2.new(0, 2, 1, -3),
            Size = UDim2.new(1, -4, 0, 2),
            BackgroundColor3 = C.Accent,
            BorderSizePixel = 0,
            Visible = false,
        }, button)

        local page = New("Frame", {
            Name = name .. "Page",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Visible = false,
            BorderSizePixel = 0,
        }, content)

        -- Reference has 8px outer margins and a 14px center gap.
        local left = New("Frame", {
            Position = UDim2.fromOffset(8, 8),
            Size = UDim2.new(0.5, -13, 1, -16),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, page)

        local right = New("Frame", {
            Position = UDim2.new(0.5, 5, 0, 8),
            Size = UDim2.new(0.5, -13, 1, -16),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, page)

        local leftLayout = New("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
        }, left)

        local rightLayout = New("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
        }, right)

        local Tab = {
            Window = Window,
            Button = button,
            Page = page,
            Left = left,
            Right = right,
            Sections = {},
        }

        function Tab:Select()
            for _, t in pairs(Window.Tabs) do
                t.Page.Visible = false
                t.Button.TextColor3 = C.Dim
                t.Button.BackgroundColor3 = C.Tab
                t.Underline.Visible = false
            end
            page.Visible = true
            button.TextColor3 = C.Accent
            button.BackgroundColor3 = C.TabHover
            underline.Visible = true
            currentTab = Tab
        end

        button.MouseEnter:Connect(function()
            if currentTab ~= Tab then
                button.BackgroundColor3 = C.TabHover
            end
        end)

        button.MouseLeave:Connect(function()
            if currentTab ~= Tab then
                button.BackgroundColor3 = C.Tab
            end
        end)

        button.MouseButton1Click:Connect(function()
            Tab:Select()
        end)

        Tab.Underline = underline
        Window.Tabs[name] = Tab

        if not currentTab then Tab:Select() end
        return Tab
    end

    -- Section factory -------------------------------------------------------
    local function AddSection(tab, name, side, height)
        local parent = side == "Right" and tab.Right or tab.Left

        local section = New("Frame", {
            Name = name,
            Size = UDim2.new(1, 0, 0, height or 100),
            BackgroundColor3 = C.Panel,
            BorderSizePixel = 1,
            BorderColor3 = C.Border,
        }, parent)
        Border(section, C.Border2, 1)

        local header = New("Frame", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = C.PanelHead,
            BorderSizePixel = 0,
        }, section)

        local headerText = Label(header, name, 12, C.Text)
        headerText.Position = UDim2.fromOffset(8, 0)
        headerText.Size = UDim2.new(1, -16, 1, 0)

        local body = New("Frame", {
            Position = UDim2.fromOffset(0, 28),
            Size = UDim2.new(1, 0, 1, -28),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, section)

        Pad(body, 8, 8, 5, 6)

        local list = New("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 5),
        }, body)

        local Section = {
            Frame = section,
            Body = body,
        }
        table.insert(tab.Sections, Section)

        function Section:AddToggle(name2, default, callback, hotkey)
            local row = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 19),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
            }, body)

            local box = New("Frame", {
                Position = UDim2.fromOffset(1, 2),
                Size = UDim2.fromOffset(13, 13),
                BackgroundColor3 = C.Control,
                BorderSizePixel = 1,
                BorderColor3 = C.Border,
            }, row)

            local fill = New("Frame", {
                Position = UDim2.fromOffset(1, 1),
                Size = UDim2.new(1, -2, 1, -2),
                BackgroundColor3 = C.Accent,
                BorderSizePixel = 0,
                Visible = default == true,
            }, box)

            local label = Label(row, name2, 12, C.Text)
            label.Position = UDim2.fromOffset(19, 0)
            label.Size = UDim2.new(1, hotkey and -42 or -19, 1, 0)

            if hotkey then
                local hk = Label(row, "[" .. hotkey .. "]", 11, C.Text)
                hk.Position = UDim2.new(1, -39, 0, 0)
                hk.Size = UDim2.fromOffset(39, 19)
                hk.TextXAlignment = Enum.TextXAlignment.Right
            end

            local state = default == true
            local control = {}

            function control:Set(value, silent)
                state = value == true
                fill.Visible = state
                if not silent and callback then callback(state) end
            end
            function control:Get() return state end

            row.MouseButton1Click:Connect(function()
                control:Set(not state)
            end)

            return control
        end

        function Section:AddSlider(name2, min, max, default, suffix, callback)
            min = min or 0
            max = max or 100
            default = default or min

            local row = New("Frame", {
                Size = UDim2.new(1, 0, 0, 42),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
            }, body)

            local label = Label(row, name2, 12, C.Text)
            label.Position = UDim2.fromOffset(0, 0)
            label.Size = UDim2.new(0.62, 0, 0, 19)

            local valueText = Label(row, tostring(default) .. (suffix or ""), 12, C.Text)
            valueText.Position = UDim2.new(0.38, 0, 0, 0)
            valueText.Size = UDim2.new(0.62, 0, 0, 19)
            valueText.TextXAlignment = Enum.TextXAlignment.Right

            local track = New("Frame", {
                Position = UDim2.fromOffset(0, 24),
                Size = UDim2.new(1, 0, 0, 9),
                BackgroundColor3 = C.Track,
                BorderSizePixel = 1,
                BorderColor3 = C.Border,
                Active = true,
            }, row)

            local fill = New("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = C.Accent,
                BorderSizePixel = 0,
            }, track)

            local knob = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.fromOffset(7, 24),
                BackgroundColor3 = C.Knob,
                BorderSizePixel = 0,
            }, track)
            Border(knob, C.Border, 1)

            local value = default
            local draggingSlider = false

            local function render(v, fire)
                value = math.clamp(v, min, max)
                local p = (value - min) / math.max(max - min, 0.00001)
                fill.Size = UDim2.new(p, 0, 1, 0)
                knob.Position = UDim2.new(p, 0, 0.5, 0)

                local shown
                if math.floor(value) == value then
                    shown = tostring(value)
                else
                    shown = string.format("%.1f", value)
                end
                valueText.Text = shown .. (suffix or "")

                if fire and callback then callback(value) end
            end

            local function fromX(x)
                local p = math.clamp(
                    (x - track.AbsolutePosition.X) / track.AbsoluteSize.X,
                    0, 1
                )
                render(min + (max - min) * p, true)
            end

            render(default, false)

            track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingSlider = true
                    fromX(input.Position.X)
                end
            end)

            UserInputService.InputChanged:Connect(function(input)
                if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
                    fromX(input.Position.X)
                end
            end)

            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    draggingSlider = false
                end
            end)

            local control = {}
            function control:Set(v, silent)
                local old = callback
                if silent then callback = nil end
                render(v, not silent)
                callback = old
            end
            function control:Get() return value end
            return control
        end

        function Section:AddDropdown(name2, options, default, callback)
            options = options or {}
            local current = default or options[1]

            local row = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                ZIndex = 5,
            }, body)

            local label = Label(row, name2, 12, C.Text)
            label.Size = UDim2.new(1, 0, 0, 18)

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
