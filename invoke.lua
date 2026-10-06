--[[
    Dark/teal tabbed UI library (Luau)
    API:
      local Window  = Library:CreateWindow({Title = "...", Size = Vector2.new(520, 560)})
      local Tab     = Window:AddTab("Name")
      local Section = Tab:AddSection("Title", "Left" | "Right")
      Section:AddToggle(flag, {Text, Default, Keybind, Color, Callback})
      Section:AddSlider(flag, {Text, Min, Max, Default, Suffix, Rounding, Callback})
      Section:AddDropdown(flag, {Text, Values, Default, Multi, Callback})
      Section:AddButton({Text, Callback, Confirm})
      Section:AddLabel(text)
    Values live in Library.Flags[flag]. Each element returns an object with :Set(value).
    Menu toggle key: RightShift (Library.ToggleKey).
]]

local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Library = {
    Flags = {},
    ToggleKey = Enum.KeyCode.RightShift,
    Theme = {
        Background = Color3.fromRGB(22, 26, 26),
        Panel = Color3.fromRGB(26, 31, 31),
        Border = Color3.fromRGB(50, 58, 58),
        Accent = Color3.fromRGB(32, 190, 150),
        Text = Color3.fromRGB(220, 228, 228),
        Dim = Color3.fromRGB(105, 115, 115),
        Inactive = Color3.fromRGB(38, 44, 44),
    },
}

local FONT = Enum.Font.Code
local accentObjects = {} -- {instance, property}

local function New(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function Stroke(inst, color)
    return New("UIStroke", {Color = color or Library.Theme.Border, Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, inst)
end

local function Accent(inst, prop)
    inst[prop] = Library.Theme.Accent
    table.insert(accentObjects, {inst, prop})
end

function Library:SetAccent(color)
    self.Theme.Accent = color
    for _, p in ipairs(accentObjects) do
        if p[1].Parent then p[1][p[2]] = color end
    end
end

local function Label(parent, text, props)
    local l = New("TextLabel", {
        BackgroundTransparency = 1, Text = text, Font = FONT, TextSize = 13,
        TextColor3 = Library.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 16),
    }, parent)
    for k, v in pairs(props or {}) do l[k] = v end
    return l
end

local function Round(n, places)
    local m = 10 ^ (places or 0)
    return math.floor(n * m + 0.5) / m
end

local function Parent()
    local ok, ui = pcall(function() return gethui and gethui() end)
    if ok and ui then return ui end
    ok, ui = pcall(function() return game:GetService("CoreGui") end)
    if ok and ui then return ui end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function Draggable(handle, target)
    local dragging, startPos, startInput
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startInput = true, target.Position, i.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- generic "drag inside a frame" helper, calls fn(alphaX, alphaY)
local function DragArea(frame, fn)
    local active = false
    local function update(pos)
        local ax = math.clamp((pos.X - frame.AbsolutePosition.X) / frame.AbsoluteSize.X, 0, 1)
        local ay = math.clamp((pos.Y - frame.AbsolutePosition.Y) / frame.AbsoluteSize.Y, 0, 1)
        fn(ax, ay)
    end
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            active = true
            update(i.Position)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if active and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            active = false
        end
    end)
end

------------------------------------------------------------------ Elements
local Section = {}
Section.__index = Section

function Section:AddLabel(text)
    return Label(self.Body, text, {TextColor3 = Library.Theme.Dim})
end

function Section:AddToggle(flag, opts)
    opts = opts or {}
    local T = Library.Theme
    local obj = {Value = false}

    local row = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18)}, self.Body)
    local box = New("Frame", {BackgroundColor3 = T.Inactive, Size = UDim2.fromOffset(10, 10),
        Position = UDim2.new(0, 0, 0.5, -5), BorderSizePixel = 0}, row)
    Stroke(box)
    local text = New("TextButton", {BackgroundTransparency = 1, Text = opts.Text or flag, Font = FONT, TextSize = 13,
        TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(18, 0),
        Size = UDim2.new(1, -18, 1, 0), AutoButtonColor = false}, row)

    local right = 0
    local swatch, keyBtn

    if opts.Color then
        swatch = New("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = opts.Color,
            Size = UDim2.fromOffset(28, 10), Position = UDim2.new(1, -28, 0.5, -5), BorderSizePixel = 0}, row)
        Stroke(swatch)
        right = 34
    end
    if opts.Keybind then
        keyBtn = New("TextButton", {BackgroundTransparency = 1, Font = FONT, TextSize = 13, TextColor3 = T.Dim,
            Text = "[" .. tostring(opts.Keybind) .. "]", TextXAlignment = Enum.TextXAlignment.Right,
            Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(1, -40 - right, 0, 0)}, row)
    end

    function obj:Set(v, silent)
        self.Value = v and true or false
        Library.Flags[flag] = self.Value
        box.BackgroundColor3 = self.Value and Library.Theme.Accent or Library.Theme.Inactive
        text.TextColor3 = self.Value and Library.Theme.Text or Library.Theme.Dim
        if not silent and opts.Callback then task.spawn(opts.Callback, self.Value) end
    end
    text.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
    box.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then obj:Set(not obj.Value) end
    end)

    -- keybind (click to rebind, Backspace clears)
    local bound = opts.Keybind and Enum.KeyCode[opts.Keybind] or nil
    if keyBtn then
        local binding = false
        keyBtn.MouseButton1Click:Connect(function()
            binding = true
            keyBtn.Text = "[...]"
        end)
        UIS.InputBegan:Connect(function(i, gpe)
            if binding and i.UserInputType == Enum.UserInputType.Keyboard then
                binding = false
                if i.KeyCode == Enum.KeyCode.Backspace then
                    bound = nil
                    keyBtn.Text = "[-]"
                else
                    bound = i.KeyCode
                    keyBtn.Text = "[" .. i.KeyCode.Name .. "]"
                end
            elseif not gpe and bound and i.KeyCode == bound then
                obj:Set(not obj.Value)
            end
        end)
    end

    -- color picker
    if swatch then
        local h, s, v = opts.Color:ToHSV()
        Library.Flags[flag .. "_color"] = opts.Color
        local pop = New("Frame", {BackgroundColor3 = T.Background, Size = UDim2.fromOffset(160, 140),
            Visible = false, ZIndex = 50, BorderSizePixel = 0}, self.Window.Gui)
        Stroke(pop)
        local sv = New("Frame", {BackgroundColor3 = Color3.fromHSV(h, 1, 1), Position = UDim2.fromOffset(5, 5),
            Size = UDim2.fromOffset(150, 106), ZIndex = 51, BorderSizePixel = 0}, pop)
        local white = New("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 52, BorderSizePixel = 0}, sv)
        New("UIGradient", {Transparency = NumberSequence.new(0, 1)}, white)
        local black = New("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 53, BorderSizePixel = 0}, sv)
        New("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0)}, black)
        local cursor = New("Frame", {Size = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 55, BorderSizePixel = 0}, sv)
        local hue = New("Frame", {Position = UDim2.fromOffset(5, 120), Size = UDim2.fromOffset(150, 12),
            BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 51, BorderSizePixel = 0}, pop)
        local seq = {}
        for k = 0, 6 do table.insert(seq, ColorSequenceKeypoint.new(k / 6, Color3.fromHSV(k / 6, 1, 1))) end
        New("UIGradient", {Color = ColorSequence.new(seq)}, hue)

        local function apply()
            local c = Color3.fromHSV(h, s, v)
            swatch.BackgroundColor3 = c
            sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            cursor.Position = UDim2.new(s, -2, 1 - v, -2)
            Library.Flags[flag .. "_color"] = c
            if opts.ColorCallback then task.spawn(opts.ColorCallback, c) end
        end
        DragArea(sv, function(ax, ay) s, v = ax, 1 - ay apply() end)
        DragArea(hue, function(ax) h = math.min(ax, 0.999) apply() end)
        swatch.MouseButton1Click:Connect(function()
            pop.Visible = not pop.Visible
            local ap = swatch.AbsolutePosition
            local inset = pop.Parent.AbsolutePosition
            pop.Position = UDim2.fromOffset(ap.X - inset.X - 130, ap.Y - inset.Y + 14)
        end)
        apply()
    end

    obj:Set(opts.Default or false, true)
    return obj
end

function Section:AddSlider(flag, opts)
    opts = opts or {}
    local T = Library.Theme
    local min, max = opts.Min or 0, opts.Max or 100
    local obj = {Value = min}

    local row = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28)}, self.Body)
    Label(row, opts.Text or flag, {TextColor3 = T.Text, Size = UDim2.new(0.6, 0, 0, 14)})
    local val = Label(row, "", {TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.4, 0, 0, 14),
        Position = UDim2.fromScale(0.6, 0), TextColor3 = T.Text})
    local bar = New("Frame", {BackgroundColor3 = T.Inactive, Position = UDim2.fromOffset(0, 18),
        Size = UDim2.new(1, 0, 0, 7), BorderSizePixel = 0}, row)
    Stroke(bar)
    local fill = New("Frame", {Size = UDim2.fromScale(0, 1), BorderSizePixel = 0}, bar)
    Accent(fill, "BackgroundColor3")
    local grip = New("Frame", {Size = UDim2.new(0, 4, 1, 4), Position = UDim2.new(1, -2, 0, -2), BorderSizePixel = 0}, fill)
    Accent(grip, "BackgroundColor3")

    function obj:Set(v, silent)
        v = math.clamp(Round(v, opts.Rounding or 0), min, max)
        self.Value = v
        Library.Flags[flag] = v
        fill.Size = UDim2.fromScale((v - min) / (max - min), 1)
        val.Text = tostring(v) .. (opts.Suffix or "")
        if not silent and opts.Callback then task.spawn(opts.Callback, v) end
    end
    DragArea(bar, function(ax) obj:Set(min + (max - min) * ax) end)
    obj:Set(opts.Default or min, true)
    return obj
end

function Section:AddDropdown(flag, opts)
    opts = opts or {}
    local T = Library.Theme
    local values = opts.Values or {}
    local obj = {Value = opts.Multi and {} or nil}

    local holder = New("Frame", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0)}, self.Body)
    New("UIListLayout", {Padding = UDim.new(0, 2)}, holder)
    Label(holder, opts.Text or flag, {TextColor3 = T.Text})
    local box = New("TextButton", {BackgroundColor3 = T.Inactive, Size = UDim2.new(1, 0, 0, 22), Text = "",
        AutoButtonColor = false, BorderSizePixel = 0}, holder)
    Stroke(box)
    local shown = Label(box, "", {Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -30, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd})
    New("TextLabel", {BackgroundTransparency = 1, Text = "≡", Font = FONT, TextSize = 14, TextColor3 = T.Dim,
        Size = UDim2.fromOffset(20, 22), Position = UDim2.new(1, -22, 0, 0)}, box)

    local list = New("Frame", {BackgroundColor3 = T.Background, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0), Visible = false, BorderSizePixel = 0}, holder)
    Stroke(list)
    New("UIListLayout", {}, list)
    local buttons = {}

    local function refresh()
        if opts.Multi then
            local t = {}
            for _, val in ipairs(values) do if obj.Value[val] then table.insert(t, val) end end
            shown.Text = #t > 0 and table.concat(t, ", ") or "None"
        else
            shown.Text = tostring(obj.Value or "None")
        end
        for val, b in pairs(buttons) do
            local on = opts.Multi and obj.Value[val] or obj.Value == val
            b.TextColor3 = on and Library.Theme.Accent or Library.Theme.Dim
        end
        Library.Flags[flag] = obj.Value
    end

    function obj:Set(v, silent)
        if opts.Multi then
            self.Value = {}
            for _, k in ipairs(type(v) == "table" and v or {v}) do self.Value[k] = true end
        else
            self.Value = v
        end
        refresh()
        if not silent and opts.Callback then task.spawn(opts.Callback, self.Value) end
    end

    for _, val in ipairs(values) do
        local b = New("TextButton", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Text = "  " .. val,
            Font = FONT, TextSize = 13, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false}, list)
        buttons[val] = b
        b.MouseButton1Click:Connect(function()
            if opts.Multi then
                obj.Value[val] = not obj.Value[val] or nil
                refresh()
                if opts.Callback then task.spawn(opts.Callback, obj.Value) end
            else
                obj:Set(val)
                list.Visible = false
            end
        end)
    end
    box.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)

    obj:Set(opts.Default or (not opts.Multi and values[1]) or nil, true)
    return obj
end

function Section:AddButton(opts)
    opts = opts or {}
    local T = Library.Theme
    local btn = New("TextButton", {BackgroundColor3 = T.Inactive, Size = UDim2.new(1, 0, 0, 22), Text = opts.Text or "Button",
        Font = FONT, TextSize = 13, TextColor3 = T.Text, AutoButtonColor = false, BorderSizePixel = 0}, self.Body)
    Stroke(btn)
    local armed = false
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(48, 56, 56) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = T.Inactive end)
    btn.MouseButton1Click:Connect(function()
        if opts.Confirm and not armed then
            armed = true
            local old = btn.Text
            btn.Text = "Click again to confirm"
            task.delay(2, function() armed = false btn.Text = old end)
            return
        end
        armed = false
        btn.Text = opts.Text or "Button"
        if opts.Callback then task.spawn(opts.Callback) end
    end)
    return btn
end

------------------------------------------------------------------ Tabs / Window
local Tab = {}
Tab.__index = Tab

function Tab:AddSection(title, side)
    local column = (side == "Right") and self.Right or self.Left
    local frame = New("Frame", {BackgroundColor3 = Library.Theme.Panel, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, -2, 0, 0), BorderSizePixel = 0}, column)
    Stroke(frame)
    New("TextLabel", {BackgroundColor3 = Library.Theme.Background, Text = " " .. title .. " ", Font = FONT, TextSize = 13,
        TextColor3 = Library.Theme.Text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 14),
        Position = UDim2.fromOffset(8, -7), ZIndex = 3, BorderSizePixel = 0}, frame)
    local body = New("Frame", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0)}, frame)
    New("UIListLayout", {Padding = UDim.new(0, 5)}, body)
    New("UIPadding", {PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, body)
    return setmetatable({Body = body, Window = self.Window}, Section)
end

local Window = {}
Window.__index = Window

function Window:AddTab(name)
    local T = Library.Theme
    local btn = New("TextButton", {BackgroundTransparency = 1, Text = name, Font = FONT, TextSize = 13,
        TextColor3 = T.Dim, Size = UDim2.new(0, 66, 1, 0), AutoButtonColor = false}, self.TabBar)
    local line = New("Frame", {Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
        BorderSizePixel = 0, Visible = false}, btn)
    Accent(line, "BackgroundColor3")

    local page = New("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false}, self.Content)
    local function column(x)
        local c = New("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
            Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(x, x == 0 and 0 or 4, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarImageColor3 = T.Border}, page)
        New("UIListLayout", {Padding = UDim.new(0, 14)}, c)
        New("UIPadding", {PaddingTop = UDim.new(0, 8)}, c)
        return c
    end
    local tab = setmetatable({Left = column(0), Right = column(0.5), Window = self}, Tab)

    local function select()
        for _, t in ipairs(self.Tabs) do
            t.Page.Visible = false
            t.Button.TextColor3 = T.Dim
            t.Line.Visible = false
        end
        page.Visible = true
        btn.TextColor3 = T.Text
        line.Visible = true
    end
    btn.MouseButton1Click:Connect(select)
    tab.Page, tab.Button, tab.Line = page, btn, line
    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then select() end
    return tab
end

function Window:SetVisible(v) self.Main.Visible = v end
function Window:Destroy() self.Gui:Destroy() end

function Library:CreateWindow(opts)
    opts = opts or {}
    local T = self.Theme
    local size = opts.Size or Vector2.new(520, 560)

    local gui = New("ScreenGui", {Name = "UILib", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = 999, IgnoreGuiInset = true})
    gui.Parent = Parent()

    local main = New("Frame", {BackgroundColor3 = T.Background, Size = UDim2.fromOffset(size.X, size.Y),
        Position = UDim2.new(0.5, -size.X / 2, 0.5, -size.Y / 2), BorderSizePixel = 0}, gui)
    Stroke(main)

    local title = New("TextLabel", {BackgroundTransparency = 1, Text = opts.Title or "Window", Font = FONT, TextSize = 14,
        TextColor3 = T.Text, Size = UDim2.new(1, 0, 0, 28)}, main)
    Draggable(title, main)
    New("Frame", {BackgroundColor3 = T.Border, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0}, main)

    local tabBar = New("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 32), Size = UDim2.new(1, -12, 0, 24)}, main)
    New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}, tabBar)
    New("Frame", {BackgroundColor3 = T.Border, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0}, main)

    local content = New("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 62),
        Size = UDim2.new(1, -16, 1, -70)}, main)

    local win = setmetatable({Gui = gui, Main = main, TabBar = tabBar, Content = content, Tabs = {}}, Window)

    UIS.InputBegan:Connect(function(i, gpe)
        if not gpe and i.KeyCode == Library.ToggleKey then main.Visible = not main.Visible end
    end)
    return win
end

return Library
