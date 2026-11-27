--[[
	ArdLua UI Library  v3.1.0  "Flat"
	Pemilik : ArdLua
	UI library Roblox: tema gelap datar, simpel dan modern, mouse + touch.

	API:
		local Ard = loadstring(game:HttpGet("URL_RAW_KAMU"))()

		local panel = Ard:Forge("Judul")
		panel:Note{Name}
		panel:Switch{Name, Default, Id, Run}
		panel:Action{Name, Run}
		panel:Keybind{Name, Key, Hold, Id, Run}
		panel:Range{Name, Min, Max, Default, Step, Suffix, Id, Run}
		panel:Picker{Name, Items, Default, Id, Run}
		panel:Field{Name, Default, Hint, Id, Run}
		panel:Palette{Name, Default, Id, Run}
		local group = panel:Group("Judul", terbuka)     -- punya semua method di atas

		Semua elemen : :Get()  :Set(nilai, diam)  :Rename(teks)
		Picker       : :Insert(item)  :Drop(item)  :Refill(daftar)
		Panel/Group  : :Rename(teks)

		Ard:Skin("Crimson" | "Ocean" | "Violet" | "Emerald" | "Gold" | {Accent = ...})  -- SEBELUM Launch
		Ard:Launch()
		Ard:Reveal(true/false)            -- tanpa argumen = bolak-balik
		Ard:Hotkey(Enum.KeyCode.RightShift)
		Ard:Ping{Title, Body, Time, Kind} -- Kind: "info" | "good" | "warn" | "bad"
		Ard:Store("nama") / Ard:Restore("nama")  -- simpan/muat config (butuh writefile)
		Ard:Shutdown()
		Ard.State[Id]                     -- nilai terkini
]]

local ArdLua = {
	State = {},
	Version = "3.1.0",
	Owner = "ArdLua",
	Watermark = "by ArdLua",
	ShowAvatar = true,
}

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

--// Theme (font sengaja tidak diubah)
local Theme = {
	Background   = Color3.fromRGB(18, 18, 22),
	Header       = Color3.fromRGB(24, 24, 29),
	Element      = Color3.fromRGB(29, 29, 35),
	ElementHover = Color3.fromRGB(37, 37, 44),
	Track        = Color3.fromRGB(52, 52, 61),
	Stroke       = Color3.fromRGB(48, 48, 57),
	Popup        = Color3.fromRGB(24, 24, 29),
	Text         = Color3.fromRGB(240, 240, 250),
	SubText      = Color3.fromRGB(150, 150, 162),
	Accent       = Color3.fromRGB(240, 60, 70),
	Font         = Enum.Font.GothamBlack,
	FontBold     = Enum.Font.GothamBlack,
	FontTitle    = Enum.Font.LuckiestGuy,
	FontCode     = Enum.Font.Code,
}

local Skins = {
	Crimson = {Accent = Color3.fromRGB(255, 52, 86)},
	Ocean   = {Accent = Color3.fromRGB(30, 144, 255)},
	Violet  = {Accent = Color3.fromRGB(138, 84, 255)},
	Emerald = {Accent = Color3.fromRGB(16, 185, 110)},
	Gold    = {Accent = Color3.fromRGB(235, 160, 20)},
}

local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local MED  = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SLOW = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local WHITE = Color3.new(1, 1, 1)
local PANEL_W = 230

--// State internal
local links = {}       -- koneksi event
local loops = {}       -- loop Heartbeat aktif (bind hold, rainbow)
local panels = {}
local registry = {}    -- Id -> elemen (untuk Store/Restore)
local drag, activePopup, screen, toastStack, hotkey
local visible = true
local zTop = 1

--// Helpers
local function link(signal, fn)
	local c = signal:Connect(fn)
	table.insert(links, c)
	return c
end

local function new(class, props)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	inst.Parent = parent
	return inst
end

local function tween(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

local function safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then warn("[ArdLua] callback error: " .. tostring(err)) end
end

local function startLoop(fn)
	local c = RunService.Heartbeat:Connect(fn)
	loops[c] = true
	return c
end

local function stopLoop(c)
	if c then
		c:Disconnect()
		loops[c] = nil
	end
end

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1
		or i.UserInputType == Enum.UserInputType.Touch
end

local function inside(gui, pos)
	local p, s = gui.AbsolutePosition, gui.AbsoluteSize
	return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
end

local function snap(n, step)
	local v = math.floor(n / step + 0.5) * step
	return tonumber(string.format("%.8g", v)) or v
end

local function corner(parent, r)
	return new("UICorner", {CornerRadius = UDim.new(0, r), Parent = parent})
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color, Thickness = thickness or 1, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
	})
end

local function pad(parent, t, b, l, r)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b),
		PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r), Parent = parent,
	})
end

local function text(props)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.Font = props.Font or Theme.Font
	props.TextColor3 = props.TextColor3 or Theme.Text
	props.TextSize = props.TextSize or 17
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return new("TextLabel", props)
end

local function hover(btn, normal, over)
	link(btn.MouseEnter, function()
		tween(btn, FAST, {BackgroundColor3 = over or Theme.ElementHover})
	end)
	link(btn.MouseLeave, function()
		tween(btn, FAST, {BackgroundColor3 = normal or Theme.Element})
	end)
end

-- Drag generik: hanya mengikuti jari/mouse yang memulai drag.
local function beginDrag(input, onMove, onEnd)
	drag = {input = input, onMove = onMove, onEnd = onEnd}
end

local function draggable(handle, target, onTap)
	local moved = false
	link(handle.InputBegan, function(input)
		if not isPress(input) then return end
		if activePopup then activePopup:Dismiss() end
		moved = false
		zTop = zTop + 1
		target.ZIndex = zTop
		local from, at = input.Position, target.Position
		beginDrag(input, function(move)
			local dx, dy = move.Position.X - from.X, move.Position.Y - from.Y
			if math.abs(dx) > 5 or math.abs(dy) > 5 then moved = true end
			if moved then
				tween(target, TweenInfo.new(0.07), {
					Position = UDim2.new(at.X.Scale, at.X.Offset + dx, at.Y.Scale, at.Y.Offset + dy),
				})
			end
		end)
	end)
	link(handle.Activated, function()
		if not moved and onTap then onTap() end
	end)
end

--// Popup
local function newPopup(width, height)
	local holder = new("CanvasGroup", {
		Name = "Popup", ZIndex = 5000,
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Theme.Popup, BorderSizePixel = 0,
		GroupTransparency = 1, Visible = false, Parent = screen,
	})
	corner(holder, 10)
	stroke(holder, Theme.Accent, 1, 0.4)
	return holder
end

local function showPopup(el, anchor)
	if activePopup and activePopup ~= el then activePopup:Dismiss() end
	local holder = el.popup
	local pos, size, view = anchor.AbsolutePosition, anchor.AbsoluteSize, screen.AbsoluteSize
	local w, h = holder.Size.X.Offset, holder.Size.Y.Offset
	local x = math.clamp(pos.X, 0, math.max(view.X - w, 0))
	local y = pos.Y + size.Y + 5
	if y + h > view.Y then y = math.max(pos.Y - h - 5, 0) end
	holder.Position = UDim2.fromOffset(x, y - 8)
	holder.Visible = true
	el.opened, el.anchor, activePopup = true, anchor, el
	tween(holder, SLOW, {GroupTransparency = 0, Position = UDim2.fromOffset(x, y)})
end

local function hidePopup(el)
	if not el.opened then return end
	el.opened = false
	if activePopup == el then activePopup = nil end
	tween(el.popup, FAST, {GroupTransparency = 1})
	task.delay(0.15, function()
		if not el.opened then el.popup.Visible = false end
	end)
end

--// Dasar elemen
local Element = {}
Element.__index = Element

function Element:Get()
	return self.value
end

function Element:Rename(newName)
	self.name = tostring(newName)
	if self.title then self.title.Text = self.name end
end

function Element:Set() end

local function commit(el, value, silent)
	el.value = value
	if el.id then ArdLua.State[el.id] = value end
	if not silent then safe(el.run, value) end
end

local function row(owner, el, height, class)
	local props = {
		Name = el.kind, LayoutOrder = el.order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Theme.Element, BorderSizePixel = 0,
		Parent = owner.body,
	}
	if class == "TextButton" then
		props.Text = ""
		props.AutoButtonColor = false
	end
	local r = new(class or "Frame", props)
	corner(r, 8)
	el.outline = stroke(r, Theme.Stroke, 1, 0.6)
	return r
end

--// Builder tiap elemen
local Build = {}

function Build.Note(el, owner)
	el.title = text({
		Name = "Note", LayoutOrder = el.order,
		Size = UDim2.new(1, 0, 0, 26), Text = el.name, Parent = owner.body,
	})
	pad(el.title, 0, 0, 4, 0)
	function el:Set(v)
		self.value = tostring(v)
		self:Rename(v)
	end
end

function Build.Switch(el, owner)
	local r = row(owner, el, 34, "TextButton")
	hover(r)
	el.title = text({Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -66, 1, 0), Text = el.name, Parent = r})

	local track = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(38, 20), BackgroundColor3 = Theme.Track,
		BorderSizePixel = 0, Parent = r,
	})
	corner(track, 10)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = track,
	})
	corner(knob, 8)

	local function paint(on, animate)
		local pos = on and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
		if animate then
			tween(knob, MED, {Position = pos})
			tween(track, MED, {BackgroundColor3 = on and Theme.Accent or Theme.Track})
		else
			knob.Position = pos
			track.BackgroundColor3 = on and Theme.Accent or Theme.Track
		end
	end
	paint(el.value, false)

	function el:Set(v, silent)
		v = v and true or false
		paint(v, true)
		commit(self, v, silent)
	end
	link(r.Activated, function() el:Set(not el.value) end)

	if el.value then
		task.defer(function() safe(el.run, true) end)
	end
end

function Build.Action(el, owner)
	local r = row(owner, el, 34, "TextButton")
	hover(r)
	el.title = text({
		Size = UDim2.fromScale(1, 1), Text = el.name, ZIndex = 2,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = r,
	})
	link(r.Activated, function()
		el.outline.Color = Theme.Accent
		el.outline.Transparency = 0
		tween(el.outline, SLOW, {Color = Theme.Stroke, Transparency = 0.6})
		safe(el.run)
	end)
end

local function keyText(key)
	if string.find(key, "MouseButton") then return "MB" .. string.sub(key, -1) end
	return key
end

function Build.Keybind(el, owner)
	local listening, held = false, nil
	local r = row(owner, el, 34, "TextButton")
	hover(r)
	el.title = text({Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -90, 1, 0), Text = el.name, Parent = r})

	local cap = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22),
		BackgroundColor3 = Theme.Track, BorderSizePixel = 0,
		Text = keyText(el.value), Font = Theme.FontBold, TextSize = 16,
		TextColor3 = Theme.SubText, Parent = r,
	})
	corner(cap, 6)
	pad(cap, 0, 0, 8, 8)

	function el:Set(key, silent)
		listening = false
		stopLoop(held)
		held = nil
		if typeof(key) == "EnumItem" then key = key.Name end
		self.value = key or self.value
		if self.id then ArdLua.State[self.id] = self.value end
		cap.Text = keyText(self.value)
		tween(cap, FAST, {BackgroundColor3 = Theme.Track, TextColor3 = Theme.SubText})
	end

	link(r.Activated, function()
		if listening then return end
		listening = true
		cap.Text = "..."
		tween(cap, FAST, {BackgroundColor3 = Theme.Accent, TextColor3 = WHITE})
	end)

	local function matches(i)
		return i.KeyCode.Name == el.value or i.UserInputType.Name == el.value
	end

	link(UserInputService.InputBegan, function(i)
		if UserInputService:GetFocusedTextBox() then return end
		if listening then
			if i.UserInputType == Enum.UserInputType.Keyboard then
				if i.KeyCode == Enum.KeyCode.Escape then el:Set() else el:Set(i.KeyCode.Name) end
			elseif i.UserInputType == Enum.UserInputType.MouseButton2
				or i.UserInputType == Enum.UserInputType.MouseButton3 then
				el:Set(i.UserInputType.Name)
			end
			return
		end
		if matches(i) then
			if el.hold then
				if not held then held = startLoop(function() safe(el.run, false) end) end
			else
				safe(el.run)
			end
		end
	end)

	link(UserInputService.InputEnded, function(i)
		if held and matches(i) then
			stopLoop(held)
			held = nil
			safe(el.run, true) -- true = tombol dilepas
		end
	end)
end

function Build.Range(el, owner)
	local r = row(owner, el, 50)
	el.title = text({Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -84, 0, 22), Text = el.name, Parent = r})

	local input = new("TextBox", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 7),
		Size = UDim2.fromOffset(60, 22), BackgroundColor3 = Theme.Track, BorderSizePixel = 0,
		Text = "", TextColor3 = Theme.Text, Font = Theme.FontBold, TextSize = 15,
		ClearTextOnFocus = false, Parent = r,
	})
	corner(input, 6)

	local track = new("Frame", {
		Position = UDim2.new(0, 12, 0, 36), Size = UDim2.new(1, -24, 0, 6),
		BackgroundColor3 = Theme.Track, BorderSizePixel = 0, Parent = r,
	})
	corner(track, 3)
	local fill = new("Frame", {BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = track})
	corner(fill, 3)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = track,
	})
	corner(knob, 8)

	local function paint(v, animate)
		local range = el.max - el.min
		if range == 0 then range = 1 end
		local p = (v - el.min) / range
		local zero = math.clamp((0 - el.min) / range, 0, 1)
		local fp = UDim2.fromScale(math.min(p, zero), 0)
		local fs = UDim2.fromScale(math.abs(p - zero), 1)
		local kp = UDim2.fromScale(p, 0.5)
		if animate then
			tween(knob, FAST, {Position = kp})
			tween(fill, FAST, {Position = fp, Size = fs})
		else
			knob.Position, fill.Position, fill.Size = kp, fp, fs
		end
		input.Text = tostring(v) .. el.suffix
	end
	paint(el.value, false)

	function el:Set(v, silent)
		v = math.clamp(snap(tonumber(v) or self.value, self.step), self.min, self.max)
		paint(v, true)
		if v ~= self.value then commit(self, v, silent) end
	end

	local function follow(i)
		local rel = (i.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		el:Set(el.min + math.clamp(rel, 0, 1) * (el.max - el.min))
	end

	link(r.InputBegan, function(i)
		if not isPress(i) or inside(input, i.Position) then return end
		local scroller = owner.scroller
		scroller.ScrollingEnabled = false
		tween(knob, FAST, {Size = UDim2.fromOffset(16, 16)})
		follow(i)
		beginDrag(i, follow, function()
			scroller.ScrollingEnabled = true
			tween(knob, FAST, {Size = UDim2.fromOffset(12, 12)})
		end)
	end)

	link(input.FocusLost, function()
		el:Set(tonumber((string.match(input.Text, "%-?%d*%.?%d+"))))
	end)
end

function Build.Picker(el, owner)
	local r = row(owner, el, 52, "TextButton")
	hover(r)
	el.title = text({
		Position = UDim2.new(0, 12, 0, 7), Size = UDim2.new(1, -40, 0, 14),
		Text = el.name, TextSize = 14, TextColor3 = Theme.SubText, Parent = r,
	})
	local current = text({
		Position = UDim2.new(0, 12, 0, 24), Size = UDim2.new(1, -40, 0, 22),
		Text = el.value, TextSize = 18, Font = Theme.FontBold, Parent = r,
	})
	local arrow = text({
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(16, 16), Text = ">", Font = Theme.FontBold,
		TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = 90, Parent = r,
	})

	el.popup = newPopup(214, 38)
	local scroller = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = el.popup,
	})
	pad(scroller, 4, 4, 4, 4)
	new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = scroller})

	local buttons, conns, count, serial = {}, {}, 0, 0

	local function highlight()
		for v, b in pairs(buttons) do
			b.TextColor3 = (v == el.value) and Theme.Accent or Theme.Text
		end
	end
	local function resize()
		el.popup.Size = UDim2.fromOffset(math.max(r.AbsoluteSize.X, 120), math.max(math.min(count, 5), 1) * 32 + 8)
	end

	function el:Dismiss()
		if not self.opened then return end
		tween(arrow, MED, {Rotation = 90})
		hidePopup(self)
	end

	function el:Set(v, silent)
		v = tostring(v)
		current.Text = v
		self.value = v
		highlight()
		commit(self, v, silent)
	end

	function el:Insert(v)
		v = tostring(v)
		if buttons[v] then return end
		count, serial = count + 1, serial + 1
		local b = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Popup, BorderSizePixel = 0,
			AutoButtonColor = false, Text = v, Font = Theme.Font, TextSize = 14,
			TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = serial, Parent = scroller,
		})
		corner(b, 6)
		pad(b, 0, 0, 10, 0)
		hover(b, Theme.Popup, Theme.Element)
		buttons[v] = b
		conns[v] = b.Activated:Connect(function()
			el:Set(v)
			el:Dismiss()
		end)
		highlight()
	end

	function el:Drop(v)
		v = tostring(v)
		if not buttons[v] then return end
		conns[v]:Disconnect()
		buttons[v]:Destroy()
		buttons[v], conns[v] = nil, nil
		count = count - 1
		if self.value == v then self:Set("", true) end
	end

	function el:Refill(list)
		local old = {}
		for v in pairs(buttons) do table.insert(old, v) end
		for _, v in ipairs(old) do self:Drop(v) end
		for _, v in ipairs(list) do self:Insert(v) end
	end

	if el.value ~= "" then el:Insert(el.value) end
	for _, v in ipairs(el.items) do el:Insert(v) end

	link(r.Activated, function()
		if el.opened then
			el:Dismiss()
		else
			resize()
			tween(arrow, MED, {Rotation = -90})
			showPopup(el, r)
		end
	end)
end

function Build.Field(el, owner)
	local r = row(owner, el, 52)
	el.title = text({
		Position = UDim2.new(0, 12, 0, 7), Size = UDim2.new(1, -24, 0, 14),
		Text = el.name, TextSize = 14, TextColor3 = Theme.SubText, Parent = r,
	})
	local input = new("TextBox", {
		Position = UDim2.new(0, 12, 0, 24), Size = UDim2.new(1, -24, 0, 22),
		BackgroundTransparency = 1, Text = el.value, PlaceholderText = el.hint,
		PlaceholderColor3 = Theme.SubText, TextColor3 = Theme.Text, Font = Theme.FontBold,
		TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false, ClipsDescendants = true, Parent = r,
	})

	function el:Set(v, silent)
		input.Text = tostring(v)
		commit(self, input.Text, silent)
	end
	link(r.InputBegan, function(i)
		if isPress(i) and not input:IsFocused() then input:CaptureFocus() end
	end)
	link(input.Focused, function()
		tween(el.outline, MED, {Color = Theme.Accent, Transparency = 0})
	end)
	link(input.FocusLost, function(enter)
		tween(el.outline, MED, {Color = Theme.Stroke, Transparency = 0.6})
		el.value = input.Text
		if el.id then ArdLua.State[el.id] = el.value end
		safe(el.run, el.value, enter)
	end)
end

function Build.Palette(el, owner)
	local r = row(owner, el, 34, "TextButton")
	hover(r)
	el.title = text({Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -64, 1, 0), Text = el.name, Parent = r})
	local swatch = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(34, 18), BackgroundColor3 = el.value, BorderSizePixel = 0, Parent = r,
	})
	corner(swatch, 5)
	stroke(swatch, WHITE, 1, 0.6)

	local original = el.value
	local history = {el.value}
	local h, s, v = Color3.toHSV(el.value)
	local rainbow, rainbowBtn, svBox, svKnob, hueKnob, preview

	el.popup = newPopup(240, 170)

	local function paint()
		local c = Color3.fromHSV(h, s, v)
		preview.BackgroundColor3 = c
		svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svKnob.Position = UDim2.fromScale(s, 1 - v)
		hueKnob.Position = UDim2.fromScale(h, 0.5)
	end

	svBox = new("Frame", {
		Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(136, 126),
		BorderSizePixel = 0, ClipsDescendants = true, Active = true, Parent = el.popup,
	})
	corner(svBox, 6)
	local function shade(color, rotation, a, b)
		local f = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0, Parent = svBox})
		new("UIGradient", {
			Rotation = rotation,
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b)}),
			Parent = f,
		})
	end
	shade(WHITE, 0, 0, 1)
	shade(Color3.new(0, 0, 0), 90, 1, 0)
	svKnob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1, ZIndex = 3, Parent = svBox,
	})
	corner(svKnob, 5)
	stroke(svKnob, WHITE, 2, 0)

	local hueBar = new("Frame", {
		Position = UDim2.fromOffset(8, 142), Size = UDim2.fromOffset(136, 14),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, Active = true, Parent = el.popup,
	})
	corner(hueBar, 7)
	local keys = {}
	for n = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(n / 6, Color3.fromHSV((n % 6) / 6, 1, 1)))
	end
	new("UIGradient", {Color = ColorSequence.new(keys), Parent = hueBar})
	hueKnob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 6, 1, 4),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = hueBar,
	})
	corner(hueKnob, 3)

	preview = new("Frame", {
		Position = UDim2.fromOffset(152, 8), Size = UDim2.fromOffset(80, 40),
		BorderSizePixel = 0, Parent = el.popup,
	})
	corner(preview, 8)
	paint()

	function el:Set(c, silent)
		if typeof(c) ~= "Color3" then return end
		h, s, v = Color3.toHSV(c)
		swatch.BackgroundColor3 = c
		paint()
		commit(self, c, silent)
	end

	local function stopRainbow()
		if rainbow then
			stopLoop(rainbow)
			rainbow = nil
			rainbowBtn.TextColor3 = Theme.Text
		end
	end

	local function pick(box, apply)
		link(box.InputBegan, function(i)
			if not isPress(i) or rainbow then return end
			local function follow(m)
				local x = math.clamp((m.Position.X - box.AbsolutePosition.X) / math.max(box.AbsoluteSize.X, 1), 0, 1)
				local y = math.clamp((m.Position.Y - box.AbsolutePosition.Y) / math.max(box.AbsoluteSize.Y, 1), 0, 1)
				apply(x, y)
				paint()
			end
			follow(i)
			beginDrag(i, follow)
		end)
	end
	pick(svBox, function(x, y) s, v = x, 1 - y end)
	pick(hueBar, function(x) h = math.min(x, 0.999) end)

	local function popupButton(label, y, fn)
		local b = new("TextButton", {
			Position = UDim2.fromOffset(152, y), Size = UDim2.fromOffset(80, 20),
			BackgroundColor3 = Theme.Element, BorderSizePixel = 0, AutoButtonColor = false,
			Text = label, Font = Theme.FontCode, TextSize = 15, TextColor3 = Theme.Text, Parent = el.popup,
		})
		corner(b, 6)
		hover(b)
		link(b.Activated, fn)
		return b
	end
	popupButton("Reset", 54, function()
		stopRainbow()
		history = {original}
		el:Set(original)
	end)
	popupButton("Undo", 78, function()
		stopRainbow()
		if #history > 1 then table.remove(history) end
		el:Set(history[#history])
	end)
	popupButton("Set", 102, function()
		stopRainbow()
		local c = Color3.fromHSV(h, s, v)
		table.insert(history, c)
		el:Set(c)
	end)
	rainbowBtn = popupButton("Rainbow", 126, function()
		if rainbow then
			stopRainbow()
			el:Set(history[#history])
			return
		end
		rainbow = startLoop(function()
			local c = Color3.fromHSV(os.clock() % 5 / 5, 1, 1)
			rainbowBtn.TextColor3 = c
			el:Set(c)
		end)
	end)

	function el:Dismiss()
		hidePopup(self)
	end
	link(r.Activated, function()
		if el.opened then
			el:Dismiss()
		else
			h, s, v = Color3.toHSV(el.value)
			paint()
			showPopup(el, r)
		end
	end)
end

--// Container (Panel & Group)
local Container = {}
Container.__index = Container

local function render(owner, item)
	if item.kind == "Group" then
		item:_build()
	else
		Build[item.kind](item, owner)
	end
end

local function add(owner, el)
	el.order = #owner.items_ + 1
	table.insert(owner.items_, el)
	if owner.body then render(owner, el) end -- boleh menambah elemen setelah Launch
	return el
end

local function element(kind, o, value)
	o = type(o) == "table" and o or {Name = o}
	local el = setmetatable({
		kind = kind,
		name = tostring(o.Name or kind),
		run = type(o.Run) == "function" and o.Run or function() end,
		value = value,
	}, Element)
	if value ~= nil and kind ~= "Note" then
		el.id = o.Id or el.name
		ArdLua.State[el.id] = value
		registry[el.id] = el
	end
	return el, o
end

function Container:Note(o)
	local el = element("Note", o)
	el.value = el.name
	return add(self, el)
end

function Container:Switch(o)
	o = o or {}
	local el = element("Switch", o, o.Default == true)
	return add(self, el)
end

function Container:Action(o)
	local el = element("Action", o)
	return add(self, el)
end

function Container:Keybind(o)
	o = o or {}
	local key = o.Key or "F"
	if typeof(key) == "EnumItem" then key = key.Name end
	local el = element("Keybind", o, tostring(key))
	el.hold = o.Hold == true
	return add(self, el)
end

function Container:Range(o)
	o = o or {}
	local min = tonumber(o.Min) or 0
	local max = tonumber(o.Max) or 100
	local step = (tonumber(o.Step) or 1)
	if step <= 0 then step = 1 end
	local el = element("Range", o, math.clamp(tonumber(o.Default) or min, min, max))
	el.min, el.max, el.step = min, max, step
	el.suffix = tostring(o.Suffix or "")
	return add(self, el)
end

function Container:Picker(o)
	o = o or {}
	local items = type(o.Items) == "table" and o.Items or {}
	local el = element("Picker", o, tostring(o.Default or items[1] or ""))
	el.items = items
	return add(self, el)
end

function Container:Field(o)
	o = o or {}
	local el = element("Field", o, tostring(o.Default or ""))
	el.hint = tostring(o.Hint or "")
	return add(self, el)
end

function Container:Palette(o)
	o = o or {}
	local el = element("Palette", o, typeof(o.Default) == "Color3" and o.Default or WHITE)
	return add(self, el)
end

function Container:Rename(newName)
	self.name = tostring(newName)
	if self.title then self.title.Text = self.name end
end

-- Header + isi. Dipakai Panel (isi bisa di-scroll) dan Group.
local function buildShell(c, parent, isGroup)
	local mark = not isGroup and ArdLua.Watermark
	local avatarOn = not isGroup and ArdLua.ShowAvatar
	local headerH = isGroup and 32 or (mark and 50 or 40)

	local main = new("Frame", {
		Name = c.name, LayoutOrder = c.order or 0,
		Position = isGroup and UDim2.new() or UDim2.fromOffset(20 + (PANEL_W + 20) * (c.index - 1), 20),
		Size = isGroup and UDim2.new(1, 0, 0, headerH) or UDim2.fromOffset(PANEL_W, headerH),
		BackgroundColor3 = isGroup and Theme.Header or Theme.Background,
		BorderSizePixel = 0, ClipsDescendants = true, Parent = parent,
	})
	corner(main, isGroup and 8 or 12)
	c.main = main

	if not isGroup then
		stroke(main, Theme.Stroke, 1, 0)
	end

	local header = new("TextButton", {
		Name = "Header", Size = UDim2.new(1, 0, 0, headerH), Text = "", AutoButtonColor = false,
		BackgroundColor3 = Theme.Header, BackgroundTransparency = isGroup and 1 or 0,
		BorderSizePixel = 0, Parent = main,
	})
	if not isGroup then
		corner(header, 12)
	end

	if avatarOn then
		local avatar = new("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(28, 28), BackgroundColor3 = Theme.Element,
			BorderSizePixel = 0, Image = "", Parent = header,
		})
		corner(avatar, 14)
		stroke(avatar, Theme.Stroke, 1, 0)
		task.spawn(function()
			local ok, img = pcall(function()
				return Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId,
					Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			end)
			if ok and img then avatar.Image = img end
		end)
	end

	local left = isGroup and 12 or (avatarOn and 50 or 14)
	c.title = text({
		Position = UDim2.new(0, left, 0, mark and 3 or 0),
		Size = UDim2.new(1, -left - 30, mark and 0 or 1, mark and 28 or 0),
		Text = c.name, Font = Theme.FontTitle, TextSize = isGroup and 16 or 17,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
	})
	if mark then
		text({
			Position = UDim2.fromOffset(left, 30), Size = UDim2.new(1, -left - 30, 0, 14),
			Text = tostring(mark), Font = Theme.FontBold, TextSize = 12, TextColor3 = Theme.Accent, Parent = header,
		})
	end

	local arrow = text({
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(16, 16), Text = ">", Font = Theme.FontBold, TextSize = 14,
		TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = c.expanded and 90 or 0, Parent = header,
	})

	local body
	if isGroup then
		body = new("Frame", {
			Position = UDim2.fromOffset(0, headerH), Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1, Parent = main,
		})
	else
		body = new("ScrollingFrame", {
			Position = UDim2.fromOffset(0, headerH), Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
			ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.Accent,
			ScrollingDirection = Enum.ScrollingDirection.Y, Parent = main,
		})
		c.scroller = body
		link(body:GetPropertyChangedSignal("CanvasPosition"), function()
			if activePopup then activePopup:Dismiss() end
		end)
	end
	pad(body, 6, 8, 8, 8)
	local layout = new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = body})

	local function refresh(animate)
		local full = #c.items_ > 0 and layout.AbsoluteContentSize.Y + 14 or 0
		local shown = full
		if not isGroup then
			-- tinggi panel dibatasi layar, sisanya bisa di-scroll
			shown = math.min(full, math.max(screen.AbsoluteSize.Y - headerH - 60, 120))
			body.CanvasSize = UDim2.fromOffset(0, full)
		end
		body.Size = UDim2.new(1, 0, 0, shown)
		local height = headerH + (c.expanded and shown or 0)
		local size = isGroup and UDim2.new(1, 0, 0, height) or UDim2.fromOffset(PANEL_W, height)
		if animate then tween(main, MED, {Size = size}) else main.Size = size end
	end

	local function toggle()
		if activePopup then activePopup:Dismiss() end
		c.expanded = not c.expanded
		tween(arrow, MED, {Rotation = c.expanded and 90 or 0})
		refresh(true)
	end

	if isGroup then
		stroke(main, Theme.Stroke, 1, 0.6)
		link(header.Activated, toggle)
	else
		draggable(header, main, toggle)
		link(screen:GetPropertyChangedSignal("AbsoluteSize"), function() refresh(false) end)
	end
	link(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function() refresh(false) end)

	c.body = body
	for _, item in ipairs(c.items_) do render(c, item) end
	refresh(false)
end

function Container:Group(name, expanded)
	local owner = self
	local group = setmetatable({
		kind = "Group", name = tostring(name or "Group"),
		items_ = {}, expanded = expanded == true,
	}, Container)
	function group:_build()
		self.scroller = owner.scroller
		buildShell(self, owner.body, true)
	end
	return add(owner, group)
end

--// Global input
local globalsOn = false
local function wireGlobals()
	if globalsOn then return end
	globalsOn = true
	link(UserInputService.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.Keyboard then
			if hotkey and i.KeyCode == hotkey and not UserInputService:GetFocusedTextBox() then
				ArdLua:Reveal()
			end
			return
		end
		local p = activePopup
		if p and isPress(i) and not inside(p.popup, i.Position) and not inside(p.anchor, i.Position) then
			p:Dismiss()
		end
	end)
	link(UserInputService.InputChanged, function(i)
		if not drag then return end
		local t = drag.input.UserInputType
		local mouse = t == Enum.UserInputType.MouseButton1 and i.UserInputType == Enum.UserInputType.MouseMovement
		if mouse or i == drag.input then drag.onMove(i) end
	end)
	link(UserInputService.InputEnded, function(i)
		if drag and (i == drag.input or (i.UserInputType == Enum.UserInputType.MouseButton1
			and drag.input.UserInputType == Enum.UserInputType.MouseButton1)) then
			local done = drag
			drag = nil
			if done.onEnd then done.onEnd() end
		end
	end)
end

--// Public API
function ArdLua:Forge(name)
	local panel = setmetatable({
		name = tostring(name or "ArdLua"), items_ = {}, expanded = true, index = #panels + 1,
	}, Container)
	table.insert(panels, panel)
	if screen then buildShell(panel, screen, false) end
	return panel
end

function ArdLua:Skin(skin)
	local chosen = type(skin) == "string" and Skins[skin] or skin
	if type(chosen) ~= "table" then return end
	for k, v in pairs(chosen) do
		if not string.find(k, "^Font") then Theme[k] = v end -- font dikunci
	end
end

function ArdLua:Hotkey(keyCode)
	hotkey = keyCode
end

function ArdLua:Launch(parent)
	if screen and screen.Parent then return screen end
	screen = new("ScreenGui", {
		Name = "ArdLua", ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000,
	})
	if not parent and type(gethui) == "function" then parent = gethui() end
	screen.Parent = parent or Players.LocalPlayer:WaitForChild("PlayerGui")
	wireGlobals()

	for _, panel in ipairs(panels) do
		buildShell(panel, screen, false)
	end
	return screen
end

function ArdLua:Reveal(state)
	if state == nil then state = not visible end
	visible = state and true or false
	if activePopup then activePopup:Dismiss() end
	for _, panel in ipairs(panels) do
		if panel.main then panel.main.Visible = visible end
	end
end

local KindColor = {
	good = Color3.fromRGB(60, 215, 130),
	warn = Color3.fromRGB(255, 196, 60),
	bad = Color3.fromRGB(255, 70, 80),
}

function ArdLua:Ping(o)
	if not screen then return end
	o = type(o) == "table" and o or {Body = tostring(o)}
	local duration = tonumber(o.Time) or 4
	local color = KindColor[o.Kind] or Theme.Accent

	if not (toastStack and toastStack.Parent) then
		toastStack = new("Frame", {
			Name = "Pings", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16),
			Size = UDim2.new(0, 260, 1, -32), BackgroundTransparency = 1, ZIndex = 6000, Parent = screen,
		})
		new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), Parent = toastStack,
		})
	end

	local toast = new("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Background, BorderSizePixel = 0, GroupTransparency = 1, Parent = toastStack,
	})
	corner(toast, 10)
	stroke(toast, color, 1, 0.4)

	local body = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Parent = toast,
	})
	pad(body, 10, 14, 16, 12)
	new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = body})

	if o.Title then
		text({Size = UDim2.new(1, 0, 0, 16), Text = tostring(o.Title), Font = Theme.FontBold,
			TextSize = 14, TextColor3 = color, LayoutOrder = 1, Parent = body})
	end
	if o.Body then
		text({Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(o.Body),
			TextSize = 13, TextColor3 = Theme.SubText, TextWrapped = true, LayoutOrder = 2, Parent = body})
	end

	local timer = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = color, BorderSizePixel = 0, Parent = toast,
	})

	tween(toast, MED, {GroupTransparency = 0})
	tween(timer, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 3)})
	task.delay(duration, function()
		tween(toast, MED, {GroupTransparency = 1})
		task.wait(0.25)
		toast:Destroy()
	end)
end

--// Config
local function path(name)
	return "ArdLua_" .. string.gsub(tostring(name or "default"), "[^%w_%-]", "") .. ".json"
end

function ArdLua:Store(name)
	if type(writefile) ~= "function" then return false, "writefile tidak tersedia" end
	local data = {}
	for id, el in pairs(registry) do
		local v = el.value
		if typeof(v) == "Color3" then v = {rgb = {v.R, v.G, v.B}} end
		data[id] = v
	end
	return pcall(function() writefile(path(name), HttpService:JSONEncode(data)) end)
end

function ArdLua:Restore(name)
	if type(readfile) ~= "function" or type(isfile) ~= "function" then
		return false, "readfile tidak tersedia"
	end
	local ok, data = pcall(function()
		assert(isfile(path(name)), "config belum ada")
		return HttpService:JSONDecode(readfile(path(name)))
	end)
	if not ok then return false, data end
	for id, v in pairs(data) do
		local el = registry[id]
		if el then
			if type(v) == "table" and v.rgb then v = Color3.new(v.rgb[1], v.rgb[2], v.rgb[3]) end
			el:Set(v)
		end
	end
	return true
end

function ArdLua:Shutdown()
	for _, c in ipairs(links) do pcall(function() c:Disconnect() end) end
	for c in pairs(loops) do pcall(function() c:Disconnect() end) end
	if screen then screen:Destroy() end
	links, loops, panels, registry = {}, {}, {}, {}
	drag, activePopup, screen, toastStack, hotkey = nil, nil, nil, nil, nil
	visible, globalsOn = true, false
	self.State = {}
end

return ArdLua
