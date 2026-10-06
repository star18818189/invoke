--[[
    Animated dark/teal tabbed UI library (Luau)

    local Window  = Library:CreateWindow({Title = "...", Size = Vector2.new(540, 580)})
    local Tab     = Window:AddTab("Name")
    local Section = Tab:AddSection("Title", "Left" | "Right")

    Section:AddToggle(flag, {Text, Default, Keybind = "C", Color = Color3, Callback, ColorCallback})
    Section:AddSlider(flag, {Text, Min, Max, Default, Suffix, Rounding, Callback})
    Section:AddDropdown(flag, {Text, Values, Default, Multi, Callback})
    Section:AddButton({Text, Callback, Confirm})
    Section:AddTextbox(flag, {Text, Default, Placeholder, Callback})
    Section:AddKeybind(flag, {Text, Default = "X", Callback, OnChange})
    Section:AddColorPicker(flag, {Text, Default, Callback})
    Section:AddLabel(text)

    Library:Notify(text, seconds)
    Library:SetAccent(Color3)
    Library:SaveConfig(name) / Library:LoadConfig(name)   (needs writefile/readfile)
    Library:GetConfig() / Library:SetConfig(table)
    Library:Unload()

    Values live in Library.Flags[flag]; every element also has :Set(value).
    Menu key: Library.ToggleKey (default RightShift).
]]

local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Library = {
    Flags = {},
    Objects = {},
    Windows = {},
    ToggleKey = Enum.KeyCode.RightShift,
    _conns = {},
    Theme = {
        Background = Color3.fromRGB(21, 25, 25),
        Panel = Color3.fromRGB(24, 29, 29),
        Border = Color3.fromRGB(48, 56, 56),
        Accent = Color3.fromRGB(32, 190, 150),
        Text = Color3.fromRGB(222, 230, 230),
        Dim = Color3.fromRGB(105, 116, 116),
        Hover = Color3.fromRGB(170, 182, 182),
        Inactive = Color3.fromRGB(35, 41, 41),
        Raised = Color3.fromRGB(46, 54, 54),
        Corner = 2, -- set to 0 for fully sharp edges (set before CreateWindow)
        Font = Enum.Font.Code,
    },
}

local QUINT = Enum.EasingStyle.Quint
local accentObjects = {}

------------------------------------------------------------------ helpers
local function Tween(obj, props, t, style, dir)
    local tw = TweenService:Create(obj, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad,
        dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function New(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function Corner(inst, r)
    local radius = r or Library.Theme.Corner
    if radius > 0 then New("UICorner", {CornerRadius = UDim.new(0, radius)}, inst) end
end

local function Stroke(inst, color, thickness)
    return New("UIStroke", {Color = color or Library.Theme.Border, Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, inst)
end

local function Accent(inst, prop)
    inst[prop] = Library.Theme.Accent
    table.insert(accentObjects, {inst, prop})
end

local function Conn(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Library._conns, c)
    return c
end

local function Label(parent, text, props)
    local l = New("TextLabel", {
        BackgroundTransparency = 1, Text = text, Font = Library.Theme.Font, TextSize = 13,
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

local function Inside(frame, p)
    local ap, as = frame.AbsolutePosition, frame.AbsoluteSize
    return p.X >= ap.X and p.X <= ap.X + as.X and p.Y >= ap.Y and p.Y <= ap.Y + as.Y
end

local function GuiParent()
    local ok, ui = pcall(function() return gethui and gethui() end)
    if ok and ui then return ui end
    ok, ui = pcall(function() return game:GetService("CoreGui") end)
    if ok and ui then return ui end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function ResolveKey(name)
    if not name then return nil end
    local ok, k = pcall(function() return Enum.KeyCode[name] end)
    return ok and k or nil
end

local function Draggable(handle, target)
    local dragging, startPos, startInput
    Conn(handle.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startInput = true, target.Position, i.Position
        end
    end)
    Conn(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    Conn(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- click/drag inside a frame -> fn(alphaX, alphaY)
local function DragArea(frame, fn, onStart, onEnd)
    local active = false
    local function update(pos)
        local ax = math.clamp((pos.X - frame.AbsolutePosition.X) / frame.AbsoluteSize.X, 0, 1)
        local ay = math.clamp((pos.Y - frame.AbsolutePosition.Y) / frame.AbsoluteSize.Y, 0, 1)
        fn(ax, ay)
    end
    Conn(frame.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            active = true
            if onStart then onStart() end
            update(i.Position)
        end
    end)
    Conn(UIS.InputChanged, function(i)
        if active and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position)
        end
    end)
    Conn(UIS.InputEnded, function(i)
        if active and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            active = false
            if onEnd then onEnd() end
        end
    end)
end

-- keybind button helper. onTrigger fires when key pressed, onChanged when rebound.
local function BindKey(button, default, onTrigger, onChanged)
    local key = ResolveKey(default)
    local binding = false
    local api = {}
    local function show()
        button.Text = binding and "[...]" or (key and ("[" .. key.Name .. "]") or "[-]")
        Tween(button, {TextColor3 = binding and Library.Theme.Accent or Library.Theme.Dim}, 0.12)
    end
    function api.Set(name)
        key = ResolveKey(name)
        show()
        if onChanged then onChanged(key) end
    end
    function api.Get() return key end
    button.MouseButton1Click:Connect(function() binding = true show() end)
    Conn(UIS.InputBegan, function(i, gpe)
        if binding then
            if i.UserInputType == Enum.UserInputType.Keyboard then
                binding = false
                if i.KeyCode == Enum.KeyCode.Backspace or i.KeyCode == Enum.KeyCode.Escape then
                    key = nil
                else
                    key = i.KeyCode
                end
                show()
                if onChanged then onChanged(key) end
            end
        elseif not gpe and key and i.KeyCode == key and onTrigger then
            onTrigger()
        end
    end)
    show()
    return api
end

-- color picker popup anchored to a swatch button
local function MakePicker(window, swatch, default, onChange)
    local T = Library.Theme
    local h, s, v = default:ToHSV()
    local open = false
    local api = {Value = default}

    local pop = New("CanvasGroup", {BackgroundColor3 = T.Background, Size = UDim2.fromOffset(170, 150),
        Visible = false, GroupTransparency = 1, ZIndex = 50, BorderSizePixel = 0}, window.Gui)
    Corner(pop)
    Stroke(pop)

    local sv = New("Frame", {BackgroundColor3 = Color3.fromHSV(h, 1, 1), Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(158, 108), ZIndex = 51, BorderSizePixel = 0}, pop)
    Corner(sv, 2)
    local white = New("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 52, BorderSizePixel = 0}, sv)
    New("UIGradient", {Transparency = NumberSequence.new(0, 1)}, white)
    Corner(white, 2)
    local black = New("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 53, BorderSizePixel = 0}, sv)
    New("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0)}, black)
    Corner(black, 2)
    local cursor = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7),
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 55, BorderSizePixel = 0}, sv)
    Corner(cursor, 4)
    Stroke(cursor, Color3.new(0, 0, 0))

    local hue = New("Frame", {Position = UDim2.fromOffset(6, 124), Size = UDim2.fromOffset(158, 12),
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 51, BorderSizePixel = 0}, pop)
    Corner(hue, 2)
    local seq = {}
    for k = 0, 6 do table.insert(seq, ColorSequenceKeypoint.new(k / 6, Color3.fromHSV(math.min(k / 6, 0.999), 1, 1))) end
    New("UIGradient", {Color = ColorSequence.new(seq)}, hue)
    local hueCursor = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(3, 16),
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 55, BorderSizePixel = 0}, hue)
    Stroke(hueCursor, Color3.new(0, 0, 0))

    local function apply(silent)
        local c = Color3.fromHSV(h, s, v)
        swatch.BackgroundColor3 = c
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        cursor.Position = UDim2.fromScale(s, 1 - v)
        hueCursor.Position = UDim2.fromScale(h, 0.5)
        api.Value = c
        if not silent and onChange then task.spawn(onChange, c) end
    end

    local function setOpen(state)
        open = state
        if state then
            local ap = swatch.AbsolutePosition
            pop.Position = UDim2.fromOffset(math.max(4, ap.X + swatch.AbsoluteSize.X - 170), ap.Y + 18)
            pop.Visible = true
            Tween(pop, {GroupTransparency = 0}, 0.15)
        else
            Tween(pop, {GroupTransparency = 1}, 0.12)
            task.delay(0.12, function() if not open then pop.Visible = false end end)
        end
    end

    DragArea(sv, function(ax, ay) s, v = ax, 1 - ay apply() end)
    DragArea(hue, function(ax) h = math.min(ax, 0.999) apply() end)
    swatch.MouseButton1Click:Connect(function() setOpen(not open) end)
    Conn(UIS.InputBegan, function(i)
        if open and i.UserInputType == Enum.UserInputType.MouseButton1 then
            local m = UIS:GetMouseLocation()
            if not Inside(pop, m) and not Inside(swatch, m) then setOpen(false) end
        end
    end)
    table.insert(window.Closers, function() if open then setOpen(false) end end)

    function api.Set(c, silent)
        h, s, v = c:ToHSV()
        apply(silent)
    end
    apply(true)
    return api
end

------------------------------------------------------------------ section elements
local Section = {}
Section.__index = Section

function Section:_add(frame, name)
    table.insert(self.Items, {frame = frame, name = name or ""})
    return frame
end

function Section:AddLabel(text)
    local l = Label(self.Body, text, {TextColor3 = Library.Theme.Dim})
    self:_add(l, text)
    return l
end

function Section:AddToggle(flag, opts)
    opts = opts or {}
    local T = Library.Theme
    local obj = {Value = false}

    local row = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18)}, self.Body)
    self:_add(row, opts.Text or flag)

    local box = New("Frame", {BackgroundColor3 = T.Inactive, Size = UDim2.fromOffset(11, 11),
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), BorderSizePixel = 0}, row)
    Corner(box)
    local boxStroke = Stroke(box)
    local inner = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0), BorderSizePixel = 0}, box)
    Accent(inner, "BackgroundColor3")
    Corner(inner, 1)

    local reserved = 0
    if opts.Color then reserved += 36 end
    if opts.Keybind then reserved += 42 end

    local text = New("TextButton", {BackgroundTransparency = 1, Text = opts.Text or flag, Font = T.Font, TextSize = 13,
        TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(19, 0),
        Size = UDim2.new(1, -19 - reserved, 1, 0), AutoButtonColor = false}, row)

    local hovering = false
    local function textColor()
        if obj.Value then return Library.Theme.Text end
        return hovering and Library.Theme.Hover or Library.Theme.Dim
    end
    text.MouseEnter:Connect(function() hovering = true Tween(text, {TextColor3 = textColor()}, 0.12) end)
    text.MouseLeave:Connect(function() hovering = false Tween(text, {TextColor3 = textColor()}, 0.12) end)

    local right = 0
    if opts.Color then
        local swatch = New("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = opts.Color,
            Size = UDim2.fromOffset(28, 10), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
            BorderSizePixel = 0}, row)
        Corner(swatch)
        Stroke(swatch)
        local picker = MakePicker(self.Window, swatch, opts.Color, function(c)
            Library.Flags[flag .. "_color"] = c
            if opts.ColorCallback then opts.ColorCallback(c) end
        end)
        Library.Flags[flag .. "_color"] = opts.Color
        Library.Objects[flag .. "_color"] = {Set = function(_, c) picker.Set(c) end}
        right = 36
    end
    if opts.Keybind then
        local keyBtn = New("TextButton", {BackgroundTransparency = 1, Font = T.Font, TextSize = 13, TextColor3 = T.Dim,
            Text = "", TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
            Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(1, -right, 0, 0)}, row)
        local kb
        kb = BindKey(keyBtn, opts.Keybind, function() obj:Set(not obj.Value) end, function(k)
            Library.Flags[flag .. "_key"] = k and k.Name or nil
        end)
        Library.Flags[flag .. "_key"] = opts.Keybind
        Library.Objects[flag .. "_key"] = {Set = function(_, name) kb.Set(name) end}
    end

    function obj:Set(v, silent)
        self.Value = v and true or false
        Library.Flags[flag] = self.Value
        if self.Value then
            Tween(inner, {Size = UDim2.fromOffset(7, 7)}, 0.22, Enum.EasingStyle.Back)
        else
            Tween(inner, {Size = UDim2.fromOffset(0, 0)}, 0.12)
        end
        Tween(boxStroke, {Color = self.Value and Library.Theme.Accent or Library.Theme.Border}, 0.15)
        Tween(text, {TextColor3 = textColor()}, 0.15)
        if not silent and opts.Callback then task.spawn(opts.Callback, self.Value) end
    end
    text.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
    box.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then obj:Set(not obj.Value) end
    end)

    Library.Objects[flag] = obj
    obj:Set(opts.Default or false, true)
    return obj
end

function Section:AddSlider(flag, opts)
    opts = opts or {}
    local T = Library.Theme
    local min, max = opts.Min or 0, opts.Max or 100
    local obj = {Value = min}

    local row = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30)}, self.Body)
    self:_add(row, opts.Text or flag)
    Label(row, opts.Text or flag, {Size = UDim2.new(0.6, 0, 0, 14)})
    local val = Label(row, "", {TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.4, 0, 0, 14),
        Position = UDim2.fromScale(0.6, 0), TextColor3 = T.Hover})

    local bar = New("Frame", {BackgroundColor3 = T.Inactive, Position = UDim2.fromOffset(0, 19),
        Size = UDim2.new(1, 0, 0, 8), BorderSizePixel = 0}, row)
    Corner(bar)
    Stroke(bar)
    local fill = New("Frame", {Size = UDim2.fromScale(0, 1), BorderSizePixel = 0}, bar)
    Accent(fill, "BackgroundColor3")
    Corner(fill)
    New("UIGradient", {Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(165, 165, 165))}, fill)

    function obj:Set(v, silent)
        v = math.clamp(Round(v, opts.Rounding or 0), min, max)
        self.Value = v
        Library.Flags[flag] = v
        Tween(fill, {Size = UDim2.fromScale((v - min) / (max - min), 1)}, 0.09)
        val.Text = tostring(v) .. (opts.Suffix or "")
        if not silent and opts.Callback then task.spawn(opts.Callback, v) end
    end
    DragArea(bar, function(ax) obj:Set(min + (max - min) * ax) end)

    Library.Objects[flag] = obj
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
    self:_add(holder, opts.Text or flag)
    New("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, holder)
    Label(holder, opts.Text or flag, {LayoutOrder = 1})

    local box = New("TextButton", {BackgroundColor3 = T.Inactive, Size = UDim2.new(1, 0, 0, 22), Text = "",
        AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = 2}, holder)
    Corner(box)
    local boxStroke = Stroke(box)
    local shown = Label(box, "", {Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -30, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd})
    local icon = New("TextLabel", {BackgroundTransparency = 1, Text = "≡", Font = T.Font, TextSize = 15, TextColor3 = T.Dim,
        Size = UDim2.fromOffset(20, 22), Position = UDim2.new(1, -22, 0, 0)}, box)

    local fullH = math.min(#values, 8) * 20
    local list = New("ScrollingFrame", {BackgroundColor3 = T.Background, Size = UDim2.new(1, 0, 0, 0), Visible = false,
        BorderSizePixel = 0, ClipsDescendants = true, ScrollBarThickness = 2, ScrollBarImageColor3 = T.Border,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), LayoutOrder = 3}, holder)
    Corner(list)
    Stroke(list)
    New("UIListLayout", {}, list)

    local buttons = {}
    local open = false
    local function setOpen(state)
        if state == open then return end
        open = state
        if state then
            if Library._openDD and Library._openDD ~= setOpen then Library._openDD(false) end
            Library._openDD = setOpen
            list.Visible = true
            Tween(list, {Size = UDim2.new(1, 0, 0, fullH)}, 0.22, QUINT)
        else
            Tween(list, {Size = UDim2.new(1, 0, 0, 0)}, 0.16, QUINT)
            task.delay(0.16, function() if not open then list.Visible = false end end)
        end
        Tween(icon, {TextColor3 = state and Library.Theme.Accent or Library.Theme.Dim}, 0.15)
        Tween(boxStroke, {Color = state and Library.Theme.Accent or Library.Theme.Border}, 0.15)
    end
    table.insert(self.Window.Closers, function() setOpen(false) end)

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
            Tween(b, {TextColor3 = on and Library.Theme.Accent or Library.Theme.Dim}, 0.15)
        end
        Library.Flags[flag] = obj.Value
    end

    function obj:Set(v, silent)
        if opts.Multi then
            self.Value = {}
            if type(v) == "table" then
                for k, val in pairs(v) do
                    if type(k) == "number" then self.Value[val] = true elseif val then self.Value[k] = true end
                end
            elseif v then
                self.Value[v] = true
            end
        else
            self.Value = v
        end
        refresh()
        if not silent and opts.Callback then task.spawn(opts.Callback, self.Value) end
    end

    for _, val in ipairs(values) do
        local b = New("TextButton", {BackgroundColor3 = T.Inactive, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20), Text = "  " .. val, Font = T.Font, TextSize = 13, TextColor3 = T.Dim,
            TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, BorderSizePixel = 0}, list)
        buttons[val] = b
        b.MouseEnter:Connect(function() Tween(b, {BackgroundTransparency = 0}, 0.1) end)
        b.MouseLeave:Connect(function() Tween(b, {BackgroundTransparency = 1}, 0.1) end)
        b.MouseButton1Click:Connect(function()
            if opts.Multi then
                obj.Value[val] = not obj.Value[val] or nil
                refresh()
                if opts.Callback then task.spawn(opts.Callback, obj.Value) end
            else
                obj:Set(val)
                setOpen(false)
            end
        end)
    end
    box.MouseEnter:Connect(function() if not open then Tween(boxStroke, {Color = Library.Theme.Dim}, 0.12) end end)
    box.MouseLeave:Connect(function() if not open then Tween(boxStroke, {Color = Library.Theme.Border}, 0.12) end end)
    box.MouseButton1Click:Connect(function() setOpen(not open) end)

    Library.Objects[flag] = obj
    obj:Set(opts.Default or (not opts.Multi and values[1]) or nil, true)
    return obj
end

function Section:AddButton(opts)
    opts = opts or {}
    local T = Library.Theme
    local base = opts.Text or "Button"
    local btn = New("TextButton", {BackgroundColor3 = T.Inactive, Size = UDim2.new(1, 0, 0, 22), Text = base,
        Font = T.Font, TextSize = 13, TextColor3 = T.Text, AutoButtonColor = false, BorderSizePixel = 0}, self.Body)
    Corner(btn)
    local st = Stroke(btn)
    self:_add(btn, base)

    local armed = false
    btn.MouseEnter:Connect(function()
        Tween(btn, {BackgroundColor3 = Library.Theme.Raised}, 0.12)
        Tween(st, {Color = Library.Theme.Dim}, 0.12)
    end)
    btn.MouseLeave:Connect(function()
        Tween(btn, {BackgroundColor3 = Library.Theme.Inactive}, 0.15)
        Tween(st, {Color = Library.Theme.Border}, 0.15)
    end)
    btn.MouseButton1Down:Connect(function()
        Tween(btn, {BackgroundColor3 = Library.Theme.Accent:Lerp(Library.Theme.Inactive, 0.65)}, 0.06)
    end)
    btn.MouseButton1Up:Connect(function() Tween(btn, {BackgroundColor3 = Library.Theme.Raised}, 0.2) end)
    btn.MouseButton1Click:Connect(function()
        if opts.Confirm and not armed then
            armed = true
            btn.Text = "Click again to confirm"
            Tween(btn, {TextColor3 = Library.Theme.Accent}, 0.12)
            task.delay(2, function()
                if armed then
                    armed = false
                    btn.Text = base
                    Tween(btn, {TextColor3 = Library.Theme.Text}, 0.12)
                end
            end)
            return
        end
        armed = false
        btn.Text = base
        btn.TextColor3 = Library.Theme.Text
        if opts.Callback then task.spawn(opts.Callback) end
    end)
    return btn
end

function Section:AddTextbox(flag, opts)
    opts = opts or {}
    local T = Library.Theme
    local obj = {Value = ""}

    local holder = New("Frame", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0)}, self.Body)
    self:_add(holder, opts.Text or flag)
    New("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, holder)
    if opts.Text then Label(holder, opts.Text, {LayoutOrder = 1}) end
    local box = New("TextBox", {BackgroundColor3 = T.Inactive, Size = UDim2.new(1, 0, 0, 22), Text = "",
        PlaceholderText = opts.Placeholder or "", PlaceholderColor3 = T.Dim, ClearTextOnFocus = false,
        Font = T.Font, TextSize = 13, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0, LayoutOrder = 2}, holder)
    Corner(box)
    local st = Stroke(box)
    New("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, box)
    box.Focused:Connect(function() Tween(st, {Color = Library.Theme.Accent}, 0.15) end)
    box.FocusLost:Connect(function()
        Tween(st, {Color = Library.Theme.Border}, 0.15)
        obj:Set(box.Text)
    end)

    function obj:Set(text, silent)
        self.Value = tostring(text or "")
        box.Text = self.Value
        Library.Flags[flag] = self.Value
        if not silent and opts.Callback then task.spawn(opts.Callback, self.Value) end
    end
    Library.Objects[flag] = obj
    obj:Set(opts.Default or "", true)
    return obj
end

function Section:AddKeybind(flag, opts)
    opts = opts or {}
    local T = Library.Theme
    local obj = {}
    local row = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18)}, self.Body)
    self:_add(row, opts.Text or flag)
    Label(row, opts.Text or flag, {Size = UDim2.new(1, -60, 1, 0), TextColor3 = T.Hover})
    local btn = New("TextButton", {BackgroundTransparency = 1, Font = T.Font, TextSize = 13, TextColor3 = T.Dim, Text = "",
        TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 80, 1, 0)}, row)
    local kb = BindKey(btn, opts.Default, function()
        if opts.Callback then task.spawn(opts.Callback) end
    end, function(k)
        Library.Flags[flag] = k and k.Name or nil
        if opts.OnChange then task.spawn(opts.OnChange, k) end
    end)
    function obj:Set(name) kb.Set(name) end
    Library.Flags[flag] = opts.Default
    Library.Objects[flag] = obj
    return obj
end

function Section:AddColorPicker(flag, opts)
    opts = opts or {}
    local T = Library.Theme
    local default = opts.Default or Color3.new(1, 1, 1)
    local row = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18)}, self.Body)
    self:_add(row, opts.Text or flag)
    Label(row, opts.Text or flag, {Size = UDim2.new(1, -40, 1, 0), TextColor3 = T.Hover})
    local swatch = New("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = default,
        Size = UDim2.fromOffset(28, 10), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5),
        BorderSizePixel = 0}, row)
    Corner(swatch)
    Stroke(swatch)
    local picker = MakePicker(self.Window, swatch, default, function(c)
        Library.Flags[flag] = c
        if opts.Callback then opts.Callback(c) end
    end)
    local obj = {}
    function obj:Set(c, silent) picker.Set(c, silent) end
    Library.Flags[flag] = default
    Library.Objects[flag] = obj
    return obj
end

------------------------------------------------------------------ tabs / window
local Tab = {}
Tab.__index = Tab

function Tab:AddSection(title, side)
    local T = Library.Theme
    local window = self.Window
    local column = (side == "Right") and self.Right or self.Left

    local frame = New("Frame", {BackgroundColor3 = T.Panel, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0), BorderSizePixel = 0}, column)
    Corner(frame)
    Stroke(frame)
    New("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215))}, frame)
    New("TextLabel", {BackgroundColor3 = T.Background, Text = " " .. title .. " ", Font = T.Font, TextSize = 13,
        TextColor3 = T.Text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 12),
        Position = UDim2.fromOffset(8, -6), ZIndex = 3, BorderSizePixel = 0}, frame)
    local body = New("Frame", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0)}, frame)
    New("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, body)
    New("UIPadding", {PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 9),
        PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9)}, body)

    local sec = setmetatable({Body = body, Window = window, Frame = frame, Title = title, Items = {}}, Section)
    table.insert(window.Sections, sec)
    return sec
end

local Window = {}
Window.__index = Window

function Window:_select(tab)
    if self.Active == tab then return end
    local old = self.Active
    self.Active = tab
    local T = Library.Theme

    for _, t in ipairs(self.Tabs) do
        Tween(t.Button, {TextColor3 = t == tab and T.Text or T.Dim}, 0.2)
        if t ~= tab and t ~= old then t.Page.Visible = false end
    end

    local target = {Position = UDim2.fromOffset(tab.X, 22), Size = UDim2.fromOffset(tab.W, 2)}
    if old then
        Tween(self.Indicator, target, 0.32, QUINT)
        Tween(old.Page, {GroupTransparency = 1}, 0.12)
        task.delay(0.12, function() if self.Active ~= old then old.Page.Visible = false end end)
    else
        self.Indicator.Position, self.Indicator.Size = target.Position, target.Size
    end

    tab.Page.Visible = true
    tab.Page.GroupTransparency = 1
    tab.Page.Position = UDim2.fromOffset(0, 10)
    task.delay(old and 0.07 or 0, function()
        if self.Active == tab then
            Tween(tab.Page, {GroupTransparency = 0, Position = UDim2.fromOffset(0, 0)}, 0.3, QUINT)
        end
    end)
    for _, close in ipairs(self.Closers) do close() end
end

function Window:AddTab(name)
    local T = Library.Theme
    local w = TextService:GetTextSize(name, 13, T.Font, Vector2.new(1000, 100)).X + 24
    local x = self.NextX
    self.NextX = x + w + 4

    local btn = New("TextButton", {BackgroundTransparency = 1, Text = name, Font = T.Font, TextSize = 13,
        TextColor3 = T.Dim, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w, 22),
        AutoButtonColor = false}, self.TabBar)

    local page = New("CanvasGroup", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false,
        GroupTransparency = 1}, self.Content)
    local function column(xs)
        local c = New("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
            Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(xs, xs == 0 and 0 or 4, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarImageColor3 = T.Border}, page)
        New("UIListLayout", {Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder}, c)
        New("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 6)}, c)
        return c
    end
    local tab = setmetatable({Left = column(0), Right = column(0.5), Window = self,
        Page = page, Button = btn, X = x, W = w}, Tab)

    btn.MouseEnter:Connect(function()
        if self.Active ~= tab then Tween(btn, {TextColor3 = Library.Theme.Hover}, 0.12) end
    end)
    btn.MouseLeave:Connect(function()
        if self.Active ~= tab then Tween(btn, {TextColor3 = Library.Theme.Dim}, 0.12) end
    end)
    btn.MouseButton1Click:Connect(function() self:_select(tab) end)

    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then self:_select(tab) end
    return tab
end

function Window:SetVisible(v)
    self.Visible = v
    if v then
        self.Main.Visible = true
        Tween(self.Main, {GroupTransparency = 0}, 0.22)
        Tween(self.Scale, {Scale = 1}, 0.3, Enum.EasingStyle.Back)
    else
        for _, close in ipairs(self.Closers) do close() end
        Tween(self.Main, {GroupTransparency = 1}, 0.15)
        Tween(self.Scale, {Scale = 0.95}, 0.15)
        task.delay(0.15, function() if not self.Visible then self.Main.Visible = false end end)
    end
end

function Window:Destroy() self.Gui:Destroy() end

function Library:CreateWindow(opts)
    opts = opts or {}
    local T = self.Theme
    local size = opts.Size or Vector2.new(540, 580)

    local gui = New("ScreenGui", {Name = "UILib", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = 999, IgnoreGuiInset = true})
    gui.Parent = GuiParent()

    local main = New("CanvasGroup", {BackgroundColor3 = T.Background, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size.X, size.Y), BorderSizePixel = 0,
        GroupTransparency = 1, Visible = false}, gui)
    Corner(main, math.max(T.Corner, 0))
    Stroke(main)
    local scale = New("UIScale", {Scale = 0.92}, main)

    local title = New("TextLabel", {BackgroundTransparency = 1, Text = opts.Title or "Window", Font = T.Font, TextSize = 14,
        TextColor3 = T.Text, Size = UDim2.new(1, 0, 0, 28)}, main)
    Draggable(title, main)

    local tabBar = New("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 33),
        Size = UDim2.new(1, -16, 0, 24)}, main)
    local indicator = New("Frame", {Position = UDim2.fromOffset(0, 22), Size = UDim2.fromOffset(0, 2), BorderSizePixel = 0}, tabBar)
    Accent(indicator, "BackgroundColor3")
    New("Frame", {BackgroundColor3 = T.Border, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0}, main)

    local content = New("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 64),
        Size = UDim2.new(1, -16, 1, -72)}, main)

    local win = setmetatable({Gui = gui, Main = main, Scale = scale, TabBar = tabBar, Content = content,
        Indicator = indicator, Tabs = {}, Sections = {}, Closers = {}, NextX = 0, Visible = false}, Window)

    -- notification holder
    if not self._notifyHolder then
        local holder = New("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(260, 400)}, gui)
        New("UIListLayout", {Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom,
            SortOrder = Enum.SortOrder.LayoutOrder}, holder)
        self._notifyHolder = holder
    end

    Conn(UIS.InputBegan, function(i, gpe)
        if not gpe and i.KeyCode == Library.ToggleKey then win:SetVisible(not win.Visible) end
    end)

    table.insert(self.Windows, win)
    task.defer(function() win:SetVisible(true) end)
    return win
end

------------------------------------------------------------------ notifications
function Library:Notify(text, duration)
    local holder = self._notifyHolder
    if not holder then return end
    duration = duration or 3
    local T = self.Theme

    local wrap = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0)}, holder)
    local card = New("CanvasGroup", {BackgroundColor3 = T.Background, Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.new(1, 40, 0, 0), GroupTransparency = 1, BorderSizePixel = 0}, wrap)
    Corner(card)
    Stroke(card)
    local edge = New("Frame", {Size = UDim2.new(0, 2, 1, 0), BorderSizePixel = 0}, card)
    Accent(edge, "BackgroundColor3")
    Label(card, text, {Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -18, 1, -2),
        TextTruncate = Enum.TextTruncate.AtEnd})
    local prog = New("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0}, card)
    Accent(prog, "BackgroundColor3")

    Tween(wrap, {Size = UDim2.new(1, 0, 0, 36)}, 0.2, QUINT)
    Tween(card, {Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0}, 0.35, QUINT)
    Tween(prog, {Size = UDim2.new(0, 0, 0, 2)}, duration, Enum.EasingStyle.Linear)
    task.delay(duration, function()
        Tween(card, {Position = UDim2.new(1, 40, 0, 0), GroupTransparency = 1}, 0.28, QUINT)
        task.wait(0.28)
        Tween(wrap, {Size = UDim2.new(1, 0, 0, 0)}, 0.2, QUINT)
        task.wait(0.2)
        wrap:Destroy()
    end)
end

------------------------------------------------------------------ theme / config / unload
function Library:SetAccent(color)
    self.Theme.Accent = color
    for _, p in ipairs(accentObjects) do
        if p[1].Parent then Tween(p[1], {[p[2]] = color}, 0.2) end
    end
end

function Library:GetConfig()
    local out = {}
    for flag, v in pairs(self.Flags) do
        if typeof(v) == "Color3" then
            out[flag] = {__color = {v.R, v.G, v.B}}
        elseif type(v) == "table" then
            local list = {}
            for k, on in pairs(v) do if on then table.insert(list, k) end end
            out[flag] = {__list = list}
        else
            out[flag] = v
        end
    end
    return out
end

function Library:SetConfig(cfg)
    for flag, v in pairs(cfg) do
        local obj = self.Objects[flag]
        if obj then
            if type(v) == "table" and v.__color then
                obj:Set(Color3.new(v.__color[1], v.__color[2], v.__color[3]))
            elseif type(v) == "table" and v.__list then
                obj:Set(v.__list)
            else
                obj:Set(v)
            end
        end
    end
end

function Library:SaveConfig(name)
    local ok = pcall(function()
        writefile(name .. ".json", HttpService:JSONEncode(self:GetConfig()))
    end)
    return ok
end

function Library:LoadConfig(name)
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(name .. ".json")) end)
    if ok and type(data) == "table" then
        self:SetConfig(data)
        return true
    end
    return false
end

function Library:Unload()
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    for _, w in ipairs(self.Windows) do pcall(function() w.Gui:Destroy() end) end
    self._conns, self.Windows, self._notifyHolder = {}, {}, nil
end

return Library
