--!strict
-- Invoke UI Library
-- A compact, red-accented Roblox interface library.
-- Place this file in a ModuleScript and require it from a LocalScript.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Invoke = {}
Invoke.__index = Invoke
Invoke.Version = "1.1.0"

Invoke.Theme = {
	Accent = Color3.fromRGB(225, 42, 57),
	AccentDark = Color3.fromRGB(132, 24, 34),
	Background = Color3.fromRGB(10, 11, 14),
	Surface = Color3.fromRGB(16, 17, 21),
	SurfaceRaised = Color3.fromRGB(22, 23, 29),
	SurfaceHover = Color3.fromRGB(29, 30, 37),
	Stroke = Color3.fromRGB(48, 50, 60),
	StrokeSoft = Color3.fromRGB(34, 35, 43),
	Text = Color3.fromRGB(238, 239, 244),
	TextMuted = Color3.fromRGB(142, 145, 157),
	Success = Color3.fromRGB(69, 201, 126),
	Warning = Color3.fromRGB(245, 180, 66),
	Error = Color3.fromRGB(235, 72, 72),
}

local DEFAULT_FONT = Enum.Font.Code
local TWEEN_FAST = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SMOOTH = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function create(className: string, properties: {[string]: any}?): Instance
	local object = Instance.new(className)
	local parent: Instance? = nil

	if properties then
		for property, value in pairs(properties) do
			if property == "Parent" then
				parent = value
			else
				(object :: any)[property] = value
			end
		end
	end

	if parent then
		object.Parent = parent
	end

	return object
end

local function addCorner(parent: Instance, radius: number): UICorner
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius),
		Parent = parent,
	}) :: UICorner
end

local function addStroke(parent: Instance, color: Color3, transparency: number?, thickness: number?): UIStroke
	return create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		Parent = parent,
	}) :: UIStroke
end

local function addPadding(parent: Instance, left: number, right: number, top: number, bottom: number): UIPadding
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingRight = UDim.new(0, right),
		PaddingTop = UDim.new(0, top),
		PaddingBottom = UDim.new(0, bottom),
		Parent = parent,
	}) :: UIPadding
end

local function tween(object: Instance, properties: {[string]: any}, info: TweenInfo?): Tween
	local animation = TweenService:Create(object, info or TWEEN_FAST, properties)
	animation:Play()
	return animation
end

local function safeCall(callback: ((...any) -> ())?, ...: any)
	if not callback then
		return
	end

	local ok, message = pcall(callback, ...)
	if not ok then
		warn("[Invoke] Callback error: " .. tostring(message))
	end
end

local function roundToStep(value: number, step: number): number
	return math.floor((value / step) + 0.5) * step
end

local function clampWindowPosition(root: Frame, position: UDim2): UDim2
	local camera = workspace.CurrentCamera
	if not camera then
		return position
	end

	local viewport = camera.ViewportSize
	local halfSize = root.AbsoluteSize / 2
	local absoluteX = (viewport.X * position.X.Scale) + position.X.Offset
	local absoluteY = (viewport.Y * position.Y.Scale) + position.Y.Offset
	local padding = 10

	local minimumX = math.min(halfSize.X + padding, viewport.X / 2)
	local maximumX = math.max(viewport.X - halfSize.X - padding, viewport.X / 2)
	local minimumY = math.min(halfSize.Y + padding, viewport.Y / 2)
	local maximumY = math.max(viewport.Y - halfSize.Y - padding, viewport.Y / 2)

	local clampedX = math.clamp(absoluteX, minimumX, maximumX)
	local clampedY = math.clamp(absoluteY, minimumY, maximumY)

	return UDim2.new(
		position.X.Scale,
		clampedX - (viewport.X * position.X.Scale),
		position.Y.Scale,
		clampedY - (viewport.Y * position.Y.Scale)
	)
end

local function formatNumber(value: number): string
	if math.abs(value - math.floor(value)) < 0.0001 then
		return tostring(math.floor(value))
	end
	return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

local function getGuiParent(): Instance
	local player = Players.LocalPlayer
	if player then
		return player:WaitForChild("PlayerGui")
	end
	return game:GetService("CoreGui")
end

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

function Invoke:CreateWindow(config: {[string]: any}?)
	config = config or {}
	if not RunService:IsClient() then
		error("[Invoke] CreateWindow must be called from a LocalScript on the client", 2)
	end

	local theme = table.clone(self.Theme)
	if config.Theme then
		for key, value in pairs(config.Theme) do
			theme[key] = value
		end
	end
	if config.Accent then
		theme.Accent = config.Accent
	end

	local window = setmetatable({
		Theme = theme,
		Tabs = {},
		Connections = {},
		CurrentTab = nil,
		Visible = true,
		Destroyed = false,
		ToggleKey = config.ToggleKey or Enum.KeyCode.RightShift,
	}, Window)

	local gui = create("ScreenGui", {
		Name = config.Name or "InvokeUI",
		DisplayOrder = config.DisplayOrder or 100,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = config.Parent or getGuiParent(),
	}) :: ScreenGui
	window.Gui = gui

	local root = create("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = config.Position or UDim2.fromScale(0.5, 0.5),
		Size = config.Size or UDim2.fromOffset(720, 480),
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 1,
		Parent = gui,
	}) :: Frame
	window.Root = root
	window._fullSize = root.Size
	addCorner(root, 8)
	addStroke(root, theme.Stroke, 0, 1)

	local shadow = create("ImageLabel", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = root.Position,
		Size = UDim2.new(1, 44, 1, 44),
		BackgroundTransparency = 1,
		Image = "rbxassetid://6015897843",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.38,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		ZIndex = 0,
		Parent = gui,
	}) :: ImageLabel
	window.Shadow = shadow

	local function syncShadow()
		shadow.Position = root.Position
		shadow.Size = UDim2.new(
			root.Size.X.Scale,
			root.Size.X.Offset + 44,
			root.Size.Y.Scale,
			root.Size.Y.Offset + 44
		)
	end
	window:_connect(root:GetPropertyChangedSignal("Position"), syncShadow)
	window:_connect(root:GetPropertyChangedSignal("Size"), syncShadow)
	syncShadow()

	local topbar = create("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		Parent = root,
	}) :: Frame

	create("Frame", {
		Name = "AccentLine",
		Position = UDim2.new(0, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Parent = topbar,
	})

	local brand = create("TextLabel", {
		Name = "Brand",
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "I",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 18,
		Parent = topbar,
	}) :: TextLabel
	addCorner(brand, 6)

	create("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(64, 7),
		Size = UDim2.new(1, -190, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = config.Title or "Invoke",
		TextColor3 = theme.Text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topbar,
	})

	create("TextLabel", {
		Name = "Subtitle",
		Position = UDim2.fromOffset(64, 27),
		Size = UDim2.new(1, -190, 0, 16),
		BackgroundTransparency = 1,
		Font = DEFAULT_FONT,
		Text = config.Subtitle or "INTERFACE SYSTEM",
		TextColor3 = theme.TextMuted,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topbar,
	})

	local keyBadge = create("TextLabel", {
		Name = "KeyBadge",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -52, 0.5, 0),
		Size = UDim2.fromOffset(88, 26),
		BackgroundColor3 = theme.SurfaceRaised,
		BorderSizePixel = 0,
		Font = DEFAULT_FONT,
		Text = window.ToggleKey.Name:upper(),
		TextColor3 = theme.TextMuted,
		TextSize = 10,
		Parent = topbar,
	}) :: TextLabel
	addCorner(keyBadge, 4)
	addStroke(keyBadge, theme.StrokeSoft, 0)

	local close = create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -13, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = theme.SurfaceRaised,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "X",
		TextColor3 = theme.TextMuted,
		TextSize = 11,
		Parent = topbar,
	}) :: TextButton
	addCorner(close, 4)

	local sidebar = create("Frame", {
		Name = "Sidebar",
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(0, 164, 1, -54),
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		Parent = root,
	}) :: Frame
	window.Sidebar = sidebar

	create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = theme.StrokeSoft,
		BorderSizePixel = 0,
		Parent = sidebar,
	})

	create("TextLabel", {
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "WORKSPACE",
		TextColor3 = theme.TextMuted,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sidebar,
	})

	local nav = create("ScrollingFrame", {
		Name = "Navigation",
		Position = UDim2.fromOffset(8, 42),
		Size = UDim2.new(1, -16, 1, -84),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = sidebar,
	}) :: ScrollingFrame
	window.Navigation = nav
	create("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = nav,
	})

	local footer = create("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -14),
		Size = UDim2.new(1, -32, 0, 20),
		BackgroundTransparency = 1,
		Font = DEFAULT_FONT,
		Text = "INVOKE  /  " .. Invoke.Version,
		TextColor3 = theme.TextMuted,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sidebar,
	}) :: TextLabel
	window.Footer = footer

	local content = create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(164, 54),
		Size = UDim2.new(1, -164, 1, -54),
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = root,
	}) :: Frame
	window.Content = content

	local notificationLayer = create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 64),
		Size = UDim2.fromOffset(290, 360),
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: Frame
	window.NotificationLayer = notificationLayer
	create("UIListLayout", {
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = notificationLayer,
	})

	-- Window dragging, constrained to the viewport.
	do
		local dragging = false
		local dragStart = Vector2.zero
		local startPosition = root.Position
		local dragInput: InputObject? = nil

		window:_connect(topbar.InputBegan, function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPosition = root.Position
				dragInput = input
			end
		end)

		window:_connect(UserInputService.InputChanged, function(input: InputObject)
			if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
				local delta = input.Position - dragStart
				local proposed = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
				root.Position = clampWindowPosition(root, proposed)
			end
		end)

		window:_connect(UserInputService.InputEnded, function(input: InputObject)
			if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
				dragInput = nil
			end
		end)
	end

	local camera = workspace.CurrentCamera
	if camera then
		window:_connect(camera:GetPropertyChangedSignal("ViewportSize"), function()
			root.Position = clampWindowPosition(root, root.Position)
		end)
	end

	window:_connect(close.MouseEnter, function()
		tween(close, {BackgroundColor3 = theme.Accent, TextColor3 = Color3.new(1, 1, 1)})
	end)
	window:_connect(close.MouseLeave, function()
		tween(close, {BackgroundColor3 = theme.SurfaceRaised, TextColor3 = theme.TextMuted})
	end)
	window:_connect(close.Activated, function()
		window:SetVisible(false)
	end)

	window:_connect(UserInputService.InputBegan, function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == window.ToggleKey then
			window:SetVisible(not window.Visible)
		end
	end)

	return window
end

function Window:_connect(signal: RBXScriptSignal, callback: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(callback)
	table.insert(self.Connections, connection)
	return connection
end

function Window:SetVisible(visible: boolean)
	if self.Destroyed or self.Visible == visible then
		return
	end

	self.Visible = visible
	if visible then
		self.Gui.Enabled = true
		self.Shadow.Visible = true
		self.Root.Size = UDim2.new(self.Root.Size.X.Scale, math.max(1, self.Root.Size.X.Offset - 16), self.Root.Size.Y.Scale, math.max(1, self.Root.Size.Y.Offset - 16))
		self.Root.BackgroundTransparency = 0.14
		tween(self.Root, {
			Size = self._fullSize or UDim2.fromOffset(720, 480),
			BackgroundTransparency = 0,
		}, TWEEN_SMOOTH)
	else
		self._fullSize = self.Root.Size
		local hideTween = tween(self.Root, {
			Size = UDim2.new(self.Root.Size.X.Scale, self.Root.Size.X.Offset - 16, self.Root.Size.Y.Scale, self.Root.Size.Y.Offset - 16),
			BackgroundTransparency = 0.14,
		}, TWEEN_FAST)
		hideTween.Completed:Once(function()
			if not self.Visible and not self.Destroyed then
				self.Gui.Enabled = false
				self.Shadow.Visible = false
				self.Root.Size = self._fullSize
				self.Root.BackgroundTransparency = 0
			end
		end)
	end
end

function Window:Toggle()
	self:SetVisible(not self.Visible)
end

function Window:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	self.Gui:Destroy()
end

function Window:Notify(config: {[string]: any} | string)
	if self.Destroyed then
		return
	end
	if type(config) == "string" then
		config = {Text = config}
	end

	local theme = self.Theme
	local requestedKind = tostring(config.Type or "Info"):lower()
	local kind = requestedKind:sub(1, 1):upper() .. requestedKind:sub(2)
	local kindColors = {
		Info = theme.Accent,
		Success = theme.Success,
		Warning = theme.Warning,
		Error = theme.Error,
	}
	local color = kindColors[kind] or theme.Accent
	local toast = create("Frame", {
		Name = "Toast",
		Size = UDim2.fromOffset(0, 72),
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self.NotificationLayer,
	}) :: Frame
	addCorner(toast, 6)
	addStroke(toast, theme.Stroke, 0)

	create("Frame", {
		Size = UDim2.fromOffset(3, 72),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = toast,
	})

	create("TextLabel", {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = config.Title or kind:upper(),
		TextColor3 = theme.Text,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = toast,
	})

	create("TextLabel", {
		Position = UDim2.fromOffset(14, 29),
		Size = UDim2.new(1, -28, 0, 31),
		BackgroundTransparency = 1,
		Font = DEFAULT_FONT,
		Text = config.Text or "Notification",
		TextColor3 = theme.TextMuted,
		TextSize = 10,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = toast,
	})

	tween(toast, {Size = UDim2.fromOffset(280, 72)}, TWEEN_SMOOTH)
	task.delay(config.Duration or 3.5, function()
		if toast.Parent then
			local out = tween(toast, {Size = UDim2.fromOffset(0, 72), BackgroundTransparency = 1}, TWEEN_SMOOTH)
			out.Completed:Once(function()
				toast:Destroy()
			end)
		end
	end)
end

function Window:AddTab(name: string, icon: string?)
	local theme = self.Theme
	local index = #self.Tabs + 1
	local tab = setmetatable({
		Window = self,
		Name = name,
		Sections = {},
		LeftHeight = 0,
		RightHeight = 0,
	}, Tab)

	local button = create("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = theme.Surface,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		Text = "",
		LayoutOrder = index,
		Parent = self.Navigation,
	}) :: TextButton
	addCorner(button, 5)

	local marker = create("Frame", {
		Name = "Marker",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromOffset(3, 20),
		BackgroundColor3 = theme.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = button,
	}) :: Frame
	addCorner(marker, 2)

	local iconLabel = create("TextLabel", {
		Name = "Icon",
		Position = UDim2.fromOffset(13, 0),
		Size = UDim2.fromOffset(24, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = icon or string.sub(name, 1, 1):upper(),
		TextColor3 = theme.TextMuted,
		TextSize = 12,
		Parent = button,
	}) :: TextLabel

	local nameLabel = create("TextLabel", {
		Name = "Name",
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -48, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = name,
		TextColor3 = theme.TextMuted,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = button,
	}) :: TextLabel

	local page = create("Frame", {
		Name = name,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 1, -28),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self.Content,
	}) :: Frame
	tab.Page = page
	tab.Button = button
	tab.Marker = marker
	tab.IconLabel = iconLabel
	tab.NameLabel = nameLabel

	local left = create("ScrollingFrame", {
		Name = "Left",
		Size = UDim2.new(0.5, -6, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = theme.Accent,
		Parent = page,
	}) :: ScrollingFrame
	local right = left:Clone()
	right.Name = "Right"
	right.Position = UDim2.new(0.5, 6, 0, 0)
	right.Parent = page
	tab.Left = left
	tab.Right = right

	for _, column in ipairs({left, right}) do
		create("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = column,
		})
		addPadding(column, 0, 4, 0, 8)
	end

	self:_connect(button.MouseEnter, function()
		if self.CurrentTab ~= tab then
			tween(button, {BackgroundTransparency = 0.45, BackgroundColor3 = theme.SurfaceRaised})
		end
	end)
	self:_connect(button.MouseLeave, function()
		if self.CurrentTab ~= tab then
			tween(button, {BackgroundTransparency = 1})
		end
	end)
	self:_connect(button.Activated, function()
		self:SelectTab(tab)
	end)

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(tabOrName: any)
	local target = tabOrName
	if type(tabOrName) == "string" then
		for _, tab in ipairs(self.Tabs) do
			if tab.Name == tabOrName then
				target = tab
				break
			end
		end
	end
	if type(target) ~= "table" or target.Window ~= self then
		return
	end

	local theme = self.Theme
	for _, tab in ipairs(self.Tabs) do
		local selected = tab == target
		tab.Page.Visible = selected
		tween(tab.Button, {
			BackgroundTransparency = selected and 0 or 1,
			BackgroundColor3 = theme.SurfaceRaised,
		})
		tween(tab.Marker, {BackgroundTransparency = selected and 0 or 1})
		tween(tab.IconLabel, {TextColor3 = selected and theme.Accent or theme.TextMuted})
		tween(tab.NameLabel, {TextColor3 = selected and theme.Text or theme.TextMuted})
	end
	self.CurrentTab = target
end

function Tab:AddSection(title: string, side: string?)
	local theme = self.Window.Theme
	local chosenSide = side and side:lower() or nil
	local column
	if chosenSide == "left" then
		column = self.Left
	elseif chosenSide == "right" then
		column = self.Right
	else
		column = self.LeftHeight <= self.RightHeight and self.Left or self.Right
	end

	local section = setmetatable({
		Tab = self,
		Window = self.Window,
		Controls = {},
		EstimatedHeight = 45,
	}, Section)

	local frame = create("Frame", {
		Name = title,
		Size = UDim2.new(1, -2, 0, 42),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
		Parent = column,
	}) :: Frame
	addCorner(frame, 6)
	addStroke(frame, theme.StrokeSoft, 0)
	section.Frame = frame
	section.Column = column

	local header = create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = frame,
	}) :: Frame

	create("Frame", {
		Position = UDim2.fromOffset(13, 13),
		Size = UDim2.fromOffset(3, 12),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Parent = header,
	})

	create("TextLabel", {
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -36, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = title:upper(),
		TextColor3 = theme.Text,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})

	create("Frame", {
		Position = UDim2.new(0, 12, 1, -1),
		Size = UDim2.new(1, -24, 0, 1),
		BackgroundColor3 = theme.StrokeSoft,
		BorderSizePixel = 0,
		Parent = header,
	})

	local body = create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = frame,
	}) :: Frame
	section.Body = body
	create("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})
	addPadding(body, 10, 10, 4, 10)
	create("UIListLayout", {
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})

	table.insert(self.Sections, section)
	return section
end

function Section:_row(name: string, height: number): Frame
	local row = create("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = self.Window.Theme.SurfaceRaised,
		BorderSizePixel = 0,
		Parent = self.Body,
	}) :: Frame
	addCorner(row, 4)
	addStroke(row, self.Window.Theme.StrokeSoft, 0.35)
	self.EstimatedHeight += height + 5
	if self.Column == self.Tab.Left then
		self.Tab.LeftHeight += height + 5
	else
		self.Tab.RightHeight += height + 5
	end
	return row
end

function Section:AddLabel(text: string)
	local theme = self.Window.Theme
	local row = self:_row("Label", 30)
	row.BackgroundTransparency = 1
	local label = create("TextLabel", {
		Size = UDim2.new(1, -8, 1, 0),
		Position = UDim2.fromOffset(4, 0),
		BackgroundTransparency = 1,
		Font = DEFAULT_FONT,
		Text = text,
		TextColor3 = theme.TextMuted,
		TextSize = 10,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	}) :: TextLabel
	local control = {}
	function control:Set(value: string)
		label.Text = value
	end
	table.insert(self.Controls, control)
	return control
end

function Section:AddDivider(text: string?)
	local theme = self.Window.Theme
	local row = self:_row("Divider", text and 24 or 12)
	row.BackgroundTransparency = 1
	create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = theme.StrokeSoft,
		BorderSizePixel = 0,
		Parent = row,
	})
	if text then
		local label = create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 0, 0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = theme.Surface,
			Font = DEFAULT_FONT,
			Text = "  " .. text:upper() .. "  ",
			TextColor3 = theme.TextMuted,
			TextSize = 9,
			Parent = row,
		}) :: TextLabel
		label.ZIndex = 2
	end
end

function Section:AddButton(config: {[string]: any} | string)
	if type(config) == "string" then
		config = {Text = config}
	end
	local theme = self.Window.Theme
	local row = self:_row("Button", 36)
	local button = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		Text = "  " .. (config.Text or "Button"),
		TextColor3 = theme.Text,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	}) :: TextButton
	local arrow = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		Font = DEFAULT_FONT,
		Text = ">",
		TextColor3 = theme.Accent,
		TextSize = 13,
		Parent = row,
	}) :: TextLabel

	self.Window:_connect(button.MouseEnter, function()
		tween(row, {BackgroundColor3 = theme.SurfaceHover})
		tween(arrow, {Position = UDim2.new(1, -8, 0.5, 0)})
	end)
	self.Window:_connect(button.MouseLeave, function()
		tween(row, {BackgroundColor3 = theme.SurfaceRaised})
		tween(arrow, {Position = UDim2.new(1, -12, 0.5, 0)})
	end)
	self.Window:_connect(button.Activated, function()
		tween(row, {BackgroundColor3 = theme.AccentDark}, TweenInfo.new(0.06))
		task.delay(0.08, function()
			if row.Parent then
				tween(row, {BackgroundColor3 = theme.SurfaceHover})
			end
		end)
		safeCall(config.Callback)
	end)

	local control = {}
	function control:SetText(text: string)
		button.Text = "  " .. text
	end
	table.insert(self.Controls, control)
	return control
end

function Section:AddToggle(config: {[string]: any})
	local theme = self.Window.Theme
	local value = config.Default == true
	local row = self:_row("Toggle", 36)
	local button = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		Text = "  " .. (config.Text or "Toggle"),
		TextColor3 = theme.Text,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	}) :: TextButton

	local track = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(34, 18),
		BackgroundColor3 = value and theme.Accent or theme.Stroke,
		BorderSizePixel = 0,
		Parent = row,
	}) :: Frame
	addCorner(track, 9)
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = value and UDim2.new(1, -9, 0.5, 0) or UDim2.new(0, 9, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	}) :: Frame
	addCorner(knob, 6)

	local control = {}
	function control:Set(newValue: boolean, silent: boolean?)
		value = newValue == true
		tween(track, {BackgroundColor3 = value and theme.Accent or theme.Stroke})
		tween(knob, {Position = value and UDim2.new(1, -9, 0.5, 0) or UDim2.new(0, 9, 0.5, 0)}, TWEEN_SMOOTH)
		if not silent then
			safeCall(config.Callback, value)
		end
	end
	function control:Get(): boolean
		return value
	end

	self.Window:_connect(button.MouseEnter, function()
		tween(row, {BackgroundColor3 = theme.SurfaceHover})
	end)
	self.Window:_connect(button.MouseLeave, function()
		tween(row, {BackgroundColor3 = theme.SurfaceRaised})
	end)
	self.Window:_connect(button.Activated, function()
		control:Set(not value)
	end)
	table.insert(self.Controls, control)
	return control
end

function Section:AddSlider(config: {[string]: any})
	local theme = self.Window.Theme
	local minimum = config.Min or 0
	local maximum = config.Max or 100
	if maximum < minimum then
		minimum, maximum = maximum, minimum
	end
	local step = math.abs(config.Step or 1)
	if step == 0 then
		step = 1
	end
	local value = math.clamp(config.Default or minimum, minimum, maximum)
	local dragging = false
	local row = self:_row("Slider", 54)

	create("TextLabel", {
		Position = UDim2.fromOffset(10, 5),
		Size = UDim2.new(1, -80, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = config.Text or "Slider",
		TextColor3 = theme.Text,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local valueLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 5),
		Size = UDim2.fromOffset(62, 20),
		BackgroundTransparency = 1,
		Font = DEFAULT_FONT,
		Text = formatNumber(value) .. (config.Suffix or ""),
		TextColor3 = theme.Accent,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	}) :: TextLabel

	local track = create("TextButton", {
		Position = UDim2.new(0, 10, 1, -17),
		Size = UDim2.new(1, -20, 0, 6),
		BackgroundColor3 = theme.Stroke,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = row,
	}) :: TextButton
	addCorner(track, 3)
	local fill = create("Frame", {
		Size = UDim2.fromScale((value - minimum) / math.max(maximum - minimum, 0.0001), 1),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Parent = track,
	}) :: Frame
	addCorner(fill, 3)
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = fill,
	}) :: Frame
	addCorner(knob, 5)

	local control = {}
	function control:Set(newValue: number, silent: boolean?)
		newValue = math.clamp(roundToStep(newValue, step), minimum, maximum)
		value = newValue
		local alpha = (value - minimum) / math.max(maximum - minimum, 0.0001)
		fill.Size = UDim2.fromScale(alpha, 1)
		valueLabel.Text = formatNumber(value) .. (config.Suffix or "")
		if not silent then
			safeCall(config.Callback, value)
		end
	end
	function control:Get(): number
		return value
	end
	local function setFromInput(input: InputObject)
		local width = math.max(track.AbsoluteSize.X, 1)
		local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / width, 0, 1)
		control:Set(minimum + ((maximum - minimum) * alpha))
	end

	self.Window:_connect(track.InputBegan, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromInput(input)
		end
	end)
	self.Window:_connect(UserInputService.InputChanged, function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromInput(input)
		end
	end)
	self.Window:_connect(UserInputService.InputEnded, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	table.insert(self.Controls, control)
	return control
end

function Section:AddDropdown(config: {[string]: any})
	local theme = self.Window.Theme
	local options = config.Options or {}
	local value = config.Default
	local open = false
	local row = self:_row("Dropdown", 36)
	row.ClipsDescendants = true

	local button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		Text = "  " .. (config.Text or "Dropdown"),
		TextColor3 = theme.Text,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	}) :: TextButton
	local selected = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -30, 0, 0),
		Size = UDim2.new(0.5, 0, 0, 36),
		BackgroundTransparency = 1,
		Font = DEFAULT_FONT,
		Text = value and tostring(value) or "SELECT",
		TextColor3 = value and theme.Text or theme.TextMuted,
		TextSize = 10,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	}) :: TextLabel
	local caret = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(12, 36),
		BackgroundTransparency = 1,
		Font = DEFAULT_FONT,
		Text = "+",
		TextColor3 = theme.Accent,
		TextSize = 14,
		Parent = row,
	}) :: TextLabel
	local list = create("Frame", {
		Position = UDim2.fromOffset(8, 38),
		Size = UDim2.new(1, -16, 0, 0),
		BackgroundTransparency = 1,
		Parent = row,
	}) :: Frame
	create("UIListLayout", {
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})

	local control = {}
	local optionButtons = {}
	local function renderOptions()
		for _, optionButton in ipairs(optionButtons) do
			optionButton:Destroy()
		end
		table.clear(optionButtons)
		for order, option in ipairs(options) do
			local optionButton = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = theme.Background,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = DEFAULT_FONT,
				Text = "  " .. tostring(option),
				TextColor3 = option == value and theme.Accent or theme.TextMuted,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = order,
				Parent = list,
			}) :: TextButton
			addCorner(optionButton, 3)
			table.insert(optionButtons, optionButton)
			self.Window:_connect(optionButton.MouseEnter, function()
				tween(optionButton, {BackgroundColor3 = theme.SurfaceHover, TextColor3 = theme.Text})
			end)
			self.Window:_connect(optionButton.MouseLeave, function()
				tween(optionButton, {BackgroundColor3 = theme.Background, TextColor3 = option == value and theme.Accent or theme.TextMuted})
			end)
			self.Window:_connect(optionButton.Activated, function()
				control:Set(option)
				control:SetOpen(false)
			end)
		end
	end
	function control:SetOpen(state: boolean)
		open = state
		local listHeight = #options * 29
		list.Size = UDim2.new(1, -16, 0, listHeight)
		tween(row, {Size = UDim2.new(1, 0, 0, open and (44 + listHeight) or 36)}, TWEEN_SMOOTH)
		caret.Text = open and "-" or "+"
	end
	function control:Set(newValue: any, silent: boolean?)
		value = newValue
		selected.Text = value ~= nil and tostring(value) or "SELECT"
		selected.TextColor3 = value ~= nil and theme.Text or theme.TextMuted
		renderOptions()
		if not silent then
			safeCall(config.Callback, value)
		end
	end
	function control:Get(): any
		return value
	end
	function control:Refresh(newOptions: {any}, keepValue: boolean?)
		options = newOptions or {}
		if not keepValue then
			value = nil
			selected.Text = "SELECT"
			selected.TextColor3 = theme.TextMuted
		end
		renderOptions()
		if open then
			control:SetOpen(true)
		end
	end

	renderOptions()
	self.Window:_connect(button.Activated, function()
		control:SetOpen(not open)
	end)
	table.insert(self.Controls, control)
	return control
end

function Section:AddTextbox(config: {[string]: any})
	local theme = self.Window.Theme
	local row = self:_row("Textbox", 58)
	create("TextLabel", {
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = config.Text or "Input",
		TextColor3 = theme.Text,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local box = create("TextBox", {
		Position = UDim2.fromOffset(8, 25),
		Size = UDim2.new(1, -16, 0, 25),
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
		ClearTextOnFocus = config.ClearOnFocus == true,
		Font = DEFAULT_FONT,
		PlaceholderText = config.Placeholder or "Enter value...",
		PlaceholderColor3 = theme.TextMuted,
		Text = config.Default or "",
		TextColor3 = theme.Text,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	}) :: TextBox
	addCorner(box, 3)
	addStroke(box, theme.StrokeSoft, 0)
	addPadding(box, 8, 8, 0, 0)

	local control = {}
	function control:Set(value: string, silent: boolean?)
		box.Text = tostring(value)
		if not silent then
			safeCall(config.Callback, box.Text)
		end
	end
	function control:Get(): string
		return box.Text
	end
	self.Window:_connect(box.Focused, function()
		tween(row, {BackgroundColor3 = theme.SurfaceHover})
	end)
	self.Window:_connect(box.FocusLost, function(enterPressed: boolean)
		tween(row, {BackgroundColor3 = theme.SurfaceRaised})
		if config.SubmitOnEnter == false or enterPressed then
			safeCall(config.Callback, box.Text, enterPressed)
		end
	end)
	table.insert(self.Controls, control)
	return control
end

function Section:AddKeybind(config: {[string]: any})
	local theme = self.Window.Theme
	local value = config.Default or Enum.KeyCode.Unknown
	local listening = false
	local row = self:_row("Keybind", 36)
	create("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -100, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = config.Text or "Keybind",
		TextColor3 = theme.Text,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local bindButton = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(80, 24),
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = DEFAULT_FONT,
		Text = value.Name:upper(),
		TextColor3 = theme.TextMuted,
		TextSize = 9,
		Parent = row,
	}) :: TextButton
	addCorner(bindButton, 3)
	addStroke(bindButton, theme.StrokeSoft, 0)

	local control = {}
	function control:Set(newValue: Enum.KeyCode)
		value = newValue
		bindButton.Text = value.Name:upper()
		bindButton.TextColor3 = theme.TextMuted
		listening = false
	end
	function control:Get(): Enum.KeyCode
		return value
	end
	self.Window:_connect(bindButton.Activated, function()
		listening = true
		bindButton.Text = "PRESS KEY"
		bindButton.TextColor3 = theme.Accent
	end)
	self.Window:_connect(UserInputService.InputBegan, function(input: InputObject, processed: boolean)
		if listening and input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				listening = false
				bindButton.Text = value.Name:upper()
				bindButton.TextColor3 = theme.TextMuted
			else
				control:Set(input.KeyCode)
				safeCall(config.Changed, value)
			end
		elseif not processed and not listening and input.KeyCode == value and value ~= Enum.KeyCode.Unknown then
			safeCall(config.Callback, value)
		end
	end)
	table.insert(self.Controls, control)
	return control
end

function Section:AddColorPicker(config: {[string]: any})
	local theme = self.Window.Theme
	local value = config.Default or theme.Accent
	local open = false
	local row = self:_row("ColorPicker", 36)
	row.ClipsDescendants = true

	local button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		Text = "  " .. (config.Text or "Color"),
		TextColor3 = theme.Text,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	}) :: TextButton
	local swatch = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0, 18),
		Size = UDim2.fromOffset(28, 18),
		BackgroundColor3 = value,
		BorderSizePixel = 0,
		Parent = row,
	}) :: Frame
	addCorner(swatch, 3)
	addStroke(swatch, theme.Stroke, 0)

	local panel = create("Frame", {
		Position = UDim2.fromOffset(8, 40),
		Size = UDim2.new(1, -16, 0, 92),
		BackgroundTransparency = 1,
		Parent = row,
	}) :: Frame
	local channels = {
		{Name = "R", Color = Color3.fromRGB(235, 65, 75)},
		{Name = "G", Color = Color3.fromRGB(65, 210, 125)},
		{Name = "B", Color = Color3.fromRGB(75, 135, 235)},
	}
	local fills = {}
	local channelLabels = {}
	local draggingChannel: number? = nil
	local control = {}

	local function getChannels(): (number, number, number)
		return math.round(value.R * 255), math.round(value.G * 255), math.round(value.B * 255)
	end
	local function render()
		local r, g, b = getChannels()
		local values = {r, g, b}
		for index = 1, 3 do
			fills[index].Size = UDim2.fromScale(values[index] / 255, 1)
			channelLabels[index].Text = channels[index].Name .. "  " .. tostring(values[index])
		end
		swatch.BackgroundColor3 = value
	end
	function control:Set(newValue: Color3, silent: boolean?)
		value = newValue
		render()
		if not silent then
			safeCall(config.Callback, value)
		end
	end
	function control:Get(): Color3
		return value
	end
	function control:SetOpen(state: boolean)
		open = state
		tween(row, {Size = UDim2.new(1, 0, 0, open and 140 or 36)}, TWEEN_SMOOTH)
	end

	for index, channel in ipairs(channels) do
		local y = (index - 1) * 30
		local label = create("TextLabel", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(48, 22),
			BackgroundTransparency = 1,
			Font = DEFAULT_FONT,
			Text = channel.Name,
			TextColor3 = theme.TextMuted,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = panel,
		}) :: TextLabel
		channelLabels[index] = label
		local channelTrack = create("TextButton", {
			Position = UDim2.new(0, 54, 0, y + 8),
			Size = UDim2.new(1, -54, 0, 6),
			BackgroundColor3 = theme.Stroke,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Parent = panel,
		}) :: TextButton
		addCorner(channelTrack, 3)
		local channelFill = create("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = channel.Color,
			BorderSizePixel = 0,
			Parent = channelTrack,
		}) :: Frame
		addCorner(channelFill, 3)
		fills[index] = channelFill
		local function setChannel(input: InputObject)
			local width = math.max(channelTrack.AbsoluteSize.X, 1)
			local alpha = math.clamp((input.Position.X - channelTrack.AbsolutePosition.X) / width, 0, 1)
			local r, g, b = getChannels()
			if index == 1 then r = math.round(alpha * 255) end
			if index == 2 then g = math.round(alpha * 255) end
			if index == 3 then b = math.round(alpha * 255) end
			control:Set(Color3.fromRGB(r, g, b))
		end
		self.Window:_connect(channelTrack.InputBegan, function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingChannel = index
				setChannel(input)
			end
		end)
		self.Window:_connect(UserInputService.InputChanged, function(input: InputObject)
			if draggingChannel == index and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setChannel(input)
			end
		end)
	end
	self.Window:_connect(UserInputService.InputEnded, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingChannel = nil
		end
	end)
	self.Window:_connect(button.Activated, function()
		control:SetOpen(not open)
	end)
	render()
	table.insert(self.Controls, control)
	return control
end

-- Short aliases for users who prefer a smaller API.
Window.Tab = Window.AddTab
Tab.Section = Tab.AddSection
Section.Label = Section.AddLabel
Section.Divider = Section.AddDivider
Section.Button = Section.AddButton
Section.Toggle = Section.AddToggle
Section.Slider = Section.AddSlider
Section.Dropdown = Section.AddDropdown
Section.Textbox = Section.AddTextbox
Section.Keybind = Section.AddKeybind
Section.ColorPicker = Section.AddColorPicker

return Invoke
