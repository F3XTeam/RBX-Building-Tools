local Tool = script.Parent.Parent
local Workspace = game:GetService 'Workspace'
local UserInputService = game:GetService 'UserInputService'
local ContextActionService = game:GetService 'ContextActionService'
local Selection = require(script.Parent.Selection);

-- Libraries
local Libraries = Tool:WaitForChild 'Libraries'
local Support = require(Libraries:WaitForChild 'SupportLibrary')
local Signal = require(Libraries:WaitForChild 'Signal')
local Make = require(Libraries:WaitForChild 'Make')
local InstancePool = require(Libraries:WaitForChild 'InstancePool')

TargetingModule = {};
TargetingModule.TargetingMode = 'Scoped'
TargetingModule.TargetingModeChanged = Signal.new()
TargetingModule.Scope = Workspace
TargetingModule.IsScopeLocked = true
TargetingModule.TargetChanged = Signal.new()
TargetingModule.ScopeChanged = Signal.new()
TargetingModule.ScopeTargetChanged = Signal.new()
TargetingModule.ScopeLockChanged = Signal.new()

function TargetingModule:EnableTargeting()
	-- 	Begin targeting parts from the mouse

	-- Get core API
	local Core = GetCore();
	local Connections = Core.Connections;

	-- Create reference to mouse
	Mouse = Core.Mouse;

	-- Listen for target changes
	Connections.Targeting = Mouse.Move:Connect(function ()
		self:UpdateTarget(self.Scope)
	end)

	-- Listen for target clicks
	Connections.Selecting = Mouse.Button1Up:Connect(self.SelectTarget)

	-- Listen for sibling selection middle clicks
	Connections.SiblingSelecting = Support.AddUserInputListener('Began', 'MouseButton3', true, function ()
		self.SelectSiblings(Mouse.Target, not Selection.Multiselecting)
	end);

	-- Listen for 2D selection
	Connections.RectSelectionStarted = Mouse.Button1Down:Connect(self.StartRectangleSelecting);
	Connections.RectSelectionFinished = Support.AddUserInputListener('Ended', 'MouseButton1', true, self.FinishRectangleSelecting);

	-- Hide target box when tool is unequipped
	Connections.HideTargetBoxOnDisable = Core.Disabling:Connect(self.HighlightTarget);

	-- Cancel any ongoing selection when tool is unequipped
	Connections.CancelSelectionOnDisable = Core.Disabling:Connect(self.CancelRectangleSelecting);

	-- Enable scope selection
	self:EnableScopeSelection()

	-- Enable automatic scope resetting
	self:EnableScopeAutoReset()

	-- Enable targeting mode hotkeys
	self:BindTargetingModeHotkeys()

end;

function TargetingModule:SetScope(Scope)
	if self.Scope ~= Scope then
		self.Scope = Scope
		self.ScopeChanged:Fire(Scope)
	end
end

local function IsVisible(Item)
	return Item:IsA 'Model' or Item:IsA 'BasePart'
end

local function IsTargetable(Item)
	return Item:IsA 'Model' or
		Item:IsA 'BasePart' or
		Item:IsA 'Tool' or
		Item:IsA 'Accessory' or
		Item:IsA 'Accoutrement'
end

--- Returns the target within the current scope based on the current targeting mode.
-- @param Target Which part is being targeted directly
-- @param Scope The current scope to search for the target in
-- @returns Instance | nil
function TargetingModule:FindTargetInScope(Target, Scope)

	-- Return `nil` if no target, or if scope is unset
	if not (Target and Scope) then
		return nil
	end

	-- If in direct targeting mode, return target
	if self.TargetingMode == 'Direct' and (Target:IsDescendantOf(Scope)) then
		return Target
	end

	-- Search for ancestor of target directly within scope
	local TargetChain = { Target }
	while Target and (Target.Parent ~= Scope) do
		table.insert(TargetChain, 1, Target.Parent)
		Target = Target.Parent
	end

	-- Return targetable ancestor closest to scope
	for Index, Target in ipairs(TargetChain) do
		if IsTargetable(Target) then
			return Target
		end
	end

end

function TargetingModule:UpdateTarget(Scope, Force)
	local Scope = Scope or self.Scope

	-- Get target
	local NewTarget = Mouse.Target
	local NewScopeTarget = self:FindTargetInScope(NewTarget, Scope)

	-- Register whether target has changed
	if (self.LastTarget == NewTarget) and (not Force) then
		return NewTarget, NewScopeTarget
	else
		self.LastTarget = NewTarget
		self.TargetChanged:Fire(NewTarget)
	end

	-- Make sure target is selectable
	local Core = GetCore()
	if not Core.IsSelectable({ NewTarget }) then
		self.HighlightTarget(nil)
		self.LastTarget = nil
		self.LastScopeTarget = nil
		self.TargetChanged:Fire(nil)
		self.ScopeTargetChanged:Fire(nil)
		return
	end

	-- Register whether scope target has changed
	if (self.LastScopeTarget == NewScopeTarget) and (not Force) then
		return NewTarget, NewScopeTarget
	else
		self.LastScopeTarget = NewScopeTarget
		self.ScopeTargetChanged:Fire(NewScopeTarget)
	end

	-- Update scope target highlight
	if not Core.Selection.IsSelected(NewScopeTarget) then
		self.HighlightTarget(NewScopeTarget)
	end

	-- Return new targets
	return NewTarget, NewScopeTarget
end

local function GetVisibleChildren(Item, Table)
	local Table = Table or {}

	-- Search for visible items recursively
	for _, Item in pairs(Item:GetChildren()) do
		if IsVisible(Item) then
			Table[#Table + 1] = Item
		else
			GetVisibleChildren(Item, Table)
		end
	end

	-- Return visible items
	return Table
end

-- Create target box pool
local TargetBoxPool = InstancePool.new(60, function ()
	return Make 'SelectionBox' {
		Name = 'BTTargetBox',
		Parent = GetCore().UI,
		LineThickness = 0.025,
		Transparency = 0.5,
		Color = BrickColor.new 'Institutional white'
	}
end)

-- Define target box cleanup routine
function TargetBoxPool.Cleanup(TargetBox)
	TargetBox.Adornee = nil
	TargetBox.Visible = nil
end

function TargetingModule.HighlightTarget(Target)

	-- Clear previous target boxes
	TargetBoxPool:ReleaseAll()

	-- Make sure target exists
	if not Target then
		return
	end

	-- Get targetable items
	local Items = Support.FlipTable { Target }
	if not IsVisible(Target) then
		Items = Support.FlipTable(GetVisibleChildren(Target))
	end

	-- Focus target boxes on target
	for Target in pairs(Items) do
		local TargetBox = TargetBoxPool:Get()
		TargetBox.Adornee = Target
		TargetBox.Visible = true
	end

end;

local function IsAncestorSelected(Item)
	while Item and (Item ~= TargetingModule.Scope) do
		if Selection.IsSelected(Item) then
			return true
		else
			Item = Item.Parent
		end
	end
end

function TargetingModule.SelectTarget(Force)
	local Scope = TargetingModule.Scope

	-- Update target
	local Target, ScopeTarget = TargetingModule:UpdateTarget(Scope, true)

	-- Ensure target selection isn't cancelled
	if not Force and SelectionCancelled then
		SelectionCancelled = false;
		return;
	end;

	-- Focus on clicked, selected item
	if not Selection.Multiselecting and (Selection.IsSelected(ScopeTarget) or IsAncestorSelected(ScopeTarget)) then
		Selection.SetFocus(ScopeTarget)
		return;
	end;

	-- Clear selection if invalid target selected
	if not GetCore().IsSelectable({ Target }) then
		Selection.Clear(true);
		return;
	end;

	-- Unselect clicked, selected item if multiselection is enabled
	if Selection.Multiselecting and Selection.IsSelected(ScopeTarget) then
		Selection.Remove({ ScopeTarget }, true)
		return
	end

	-- Add to selection if multiselecting
	if Selection.Multiselecting then
		Selection.Add({ ScopeTarget }, true)
		Selection.SetFocus(ScopeTarget)

	-- Replace selection if not multiselecting
	else
		Selection.Replace({ ScopeTarget }, true)
		Selection.SetFocus(ScopeTarget)
	end

end;

function TargetingModule.SelectSiblings(Part, ReplaceSelection)
	-- Selects all parts under the same parent as `Part`

	-- If a part is not specified, assume the currently focused part
	local Part = Part or Selection.Focus;

	-- Ensure the part exists and its parent is not Workspace
	if not Part or Part.Parent == TargetingModule.Scope then
		return;
	end;

	-- Get the focused item's siblings
	local Siblings = Support.GetDescendantsWhichAreA(Part.Parent, 'BasePart')

	-- Ensure items are selectable
	if not GetCore().IsSelectable(Siblings) then
		return
	end

	-- Add to or replace selection
	if ReplaceSelection then
		Selection.Replace(Siblings, true);
	else
		Selection.Add(Siblings, true);
	end;

end;

function TargetingModule.StartRectangleSelecting()

	-- Ensure selection isn't cancelled
	if SelectionCancelled then
		return;
	end;

	-- Mark where rectangle selection started
	RectangleSelectStart = Vector2.new(Mouse.X, Mouse.Y);

	-- Track mouse while rectangle selecting
	GetCore().Connections.WatchRectangleSelection = Mouse.Move:Connect(function ()

		-- If rectangle selecting, update rectangle
		if RectangleSelecting then
			TargetingModule.UpdateSelectionRectangle();

		-- Watch for potential rectangle selections
		elseif RectangleSelectStart and (Vector2.new(Mouse.X, Mouse.Y) - RectangleSelectStart).magnitude >= 10 then
			RectangleSelecting = true;
			SelectionCancelled = true;
		end;

	end);

end;

function TargetingModule.UpdateSelectionRectangle()

	-- Ensure rectangle selection is ongoing
	if not RectangleSelecting then
		return;
	end;

	-- Get core API
	local Core = GetCore();

	-- Create selection rectangle
	if not SelectionRectangle then
		SelectionRectangle = Make 'Frame' {
			Name = 'SelectionRectangle',
			Parent = Core.UI,
			BackgroundColor3 = Color3.fromRGB(100, 100, 100),
			BorderColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 1
		};
	end;

	local StartPoint = Vector2.new(
		math.min(RectangleSelectStart.X, Mouse.X),
		math.min(RectangleSelectStart.Y, Mouse.Y)
	);
	local EndPoint = Vector2.new(
		math.max(RectangleSelectStart.X, Mouse.X),
		math.max(RectangleSelectStart.Y, Mouse.Y)
	);

	-- Update size and position
	SelectionRectangle.Parent = Core.UI;
	SelectionRectangle.Position = UDim2.new(0, StartPoint.X, 0, StartPoint.Y);
	SelectionRectangle.Size = UDim2.new(0, EndPoint.X - StartPoint.X, 0, EndPoint.Y - StartPoint.Y);

end;

function TargetingModule.CancelRectangleSelecting()

	-- Prevent potential rectangle selections
	RectangleSelectStart = nil;

	-- Clear ongoing rectangle selection
	RectangleSelecting = false;

	-- Clear rectangle selection watcher
	local Connections = GetCore().Connections;
	if Connections.WatchRectangleSelection then
		Connections.WatchRectangleSelection:Disconnect();
		Connections.WatchRectangleSelection = nil;
	end;

	-- Clear rectangle UI
	if SelectionRectangle then
		SelectionRectangle.Parent = nil;
	end;

end;

function TargetingModule.CancelSelecting()
	SelectionCancelled = true;
	TargetingModule.CancelRectangleSelecting();
end;

function TargetingModule.FinishRectangleSelecting()
	local Core = GetCore()

	local RectangleSelecting = RectangleSelecting;
	local RectangleSelectStart = RectangleSelectStart;

	-- Clear rectangle selection
	TargetingModule.CancelRectangleSelecting();

	-- Ensure rectangle selection is ongoing
	if not RectangleSelecting then
		return;
	end;

	-- Ensure a targeting scope is set
	if not TargetingModule.Scope then
		return
	end

	-- Get rectangle dimensions
	local StartPoint = Vector2.new(
		math.min(RectangleSelectStart.X, Mouse.X),
		math.min(RectangleSelectStart.Y, Mouse.Y)
	);
	local EndPoint = Vector2.new(
		math.max(RectangleSelectStart.X, Mouse.X),
		math.max(RectangleSelectStart.Y, Mouse.Y)
	);

	local SelectableItems = {};

	-- Find items that lie within the rectangle
	local ScopeParts = Support.GetDescendantsWhichAreA(TargetingModule.Scope, 'BasePart')
	for _, Part in pairs(ScopeParts) do
		local ScreenPoint, OnScreen = Workspace.CurrentCamera:WorldToScreenPoint(Part.Position)
		if OnScreen then
			local LeftCheck = ScreenPoint.X >= StartPoint.X
			local RightCheck = ScreenPoint.X <= EndPoint.X
			local TopCheck = ScreenPoint.Y >= StartPoint.Y
			local BottomCheck = ScreenPoint.Y <= EndPoint.Y
			if (LeftCheck and RightCheck and TopCheck and BottomCheck) and Core.IsSelectable({ Part }) then
				local ScopeTarget = TargetingModule:FindTargetInScope(Part, TargetingModule.Scope)
				SelectableItems[ScopeTarget] = true
			end
		end
	end

	-- Add to selection if multiselecting
	if Selection.Multiselecting then
		Selection.Add(Support.Keys(SelectableItems), true)

	-- Replace selection if not multiselecting
	else
		Selection.Replace(Support.Keys(SelectableItems), true)
	end;

end;

function TargetingModule.PrismSelect()
	-- Selects parts in the currently selected parts

	-- Ensure parts are selected
	if #Selection.Items == 0 then
		return;
	end;

	-- Get core API
	local Core = GetCore();

	-- Get region for selection items and find potential parts
	local Extents = require(Core.Tool.Core.BoundingBox).CalculateExtents(Selection.Items, nil, true);
	local Region = Region3.new(Extents.Min, Extents.Max);
	local PotentialParts = Workspace:FindPartsInRegion3WithIgnoreList(Region, Selection.Items, math.huge);

	-- Enable collision on all potential parts
	local OriginalState = {};
	for _, PotentialPart in pairs(PotentialParts) do
		OriginalState[PotentialPart] = { Anchored = PotentialPart.Anchored, CanCollide = PotentialPart.CanCollide };
		PotentialPart.Anchored = true;
		PotentialPart.CanCollide = true;
	end;

	local Parts = {};

	-- Find all parts intersecting with selection
	for _, Part in pairs(Selection.Items) do
		local TouchingParts = Part:GetTouchingParts();
		for _, TouchingPart in pairs(TouchingParts) do
			if not Selection.IsSelected(TouchingPart) then
				Parts[TouchingPart] = true;
			end;
		end;
	end;

	-- Restore all potential parts' original states
	for PotentialPart, State in pairs(OriginalState) do
		PotentialPart.CanCollide = State.CanCollide;
		PotentialPart.Anchored = State.Anchored;
	end;

	-- Delete the selection parts
	Core.DeleteSelection();

	-- Select all found parts
	Selection.Replace(Support.Keys(Parts), true);

end;

function TargetingModule:EnableScopeSelection()
	-- Enables the scope selection interface

	-- Set up state
	local Scoping = false
	local InitialScope = nil

	local function HandleScopeInput(Action, State, Input)
		if State.Name == 'Begin' then
			local IsAltPressed = UserInputService:IsKeyDown 'LeftAlt' or
				UserInputService:IsKeyDown 'RightAlt'
			local IsShiftPressed = UserInputService:IsKeyDown 'LeftShift' or
				UserInputService:IsKeyDown 'RightShift'

			-- If Alt is pressed, begin scoping
			if (not Scoping) and (Input.KeyCode.Name:match 'Alt') then
				Scoping = self.Scope
				InitialScope = self.Scope

				-- Set new scope to current scope target
				local Target, ScopeTarget = self:UpdateTarget(self.Scope, true)
				if Target ~= ScopeTarget then
					self:SetScope(ScopeTarget or self.Scope)
					self:UpdateTarget(self.Scope, true)
					self.IsScopeLocked = false
					self.ScopeLockChanged:Fire(false)
					Scoping = self.Scope
				end

			-- If Alt-Shift-Z is pressed, exit current scope
			elseif Scoping and IsAltPressed and IsShiftPressed and (Input.KeyCode.Name == 'Z') then
				local NewScope = self.Scope.Parent or InitialScope
				if GetCore().Security.IsLocationAllowed(NewScope, GetCore().Player) then
					self:SetScope(NewScope)
					self:UpdateTarget(self.Scope, true)
					self.IsScopeLocked = false
					self.ScopeLockChanged:Fire(false)
					Scoping = self.Scope
				end
				return Enum.ContextActionResult.Sink

			-- If Alt-Z is pressed, enter scope of current target
			elseif Scoping and IsAltPressed and (Input.KeyCode.Name == 'Z') then
				local Target, ScopeTarget = self:UpdateTarget(self.Scope, true)
				if Target ~= ScopeTarget then
					self:SetScope(ScopeTarget or self.Scope)
					self:UpdateTarget(self.Scope, true)
					self.IsScopeLocked = false
					self.ScopeLockChanged:Fire(false)
					Scoping = self.Scope
				end
				return Enum.ContextActionResult.Sink

			-- If Alt-F is pressed, stay in current scope
			elseif Scoping and IsAltPressed and (Input.KeyCode.Name == 'F') then
				Scoping = true
				self.IsScopeLocked = true
				self.ScopeLockChanged:Fire(true)
				return Enum.ContextActionResult.Sink
			end

		-- Disable scoping on Alt release
		elseif State.Name == 'End' then
			if Scoping and (Input.KeyCode.Name:match 'Alt') then
				if self.Scope == Scoping then
					self:SetScope(InitialScope)
					self.IsScopeLocked = true
					self.ScopeLockChanged:Fire(true)
				end
				self:UpdateTarget(self.Scope, true)
				Scoping = nil
				InitialScope = nil
			end
		end

		-- If window focus changes, reset and disable scoping
		if Scoping and Input.UserInputType.Name == 'Focus' then
			if self.Scope == Scoping then
				self:SetScope(InitialScope)
				self.IsScopeLocked = true
				self.ScopeLockChanged:Fire(true)
			end
			self:UpdateTarget(self.Scope, true)
			Scoping = nil
			InitialScope = nil
		end

		-- Pass all non-sunken input to next handler
		return Enum.ContextActionResult.Pass
	end

	-- Enable scoping interface
	ContextActionService:BindAction('BT: Scope', HandleScopeInput, false,
		Enum.KeyCode.LeftAlt,
		Enum.KeyCode.RightAlt,
		Enum.KeyCode.Z,
		Enum.KeyCode.F,
		Enum.UserInputType.Focus
	)

	-- Disable scoping interface when tool disables
	GetCore().Disabling:Connect(function ()
		ContextActionService:UnbindAction('BT: Scope')
	end)

end

function TargetingModule:EnableScopeAutoReset()
	-- Enables automatic scope resetting (when scope becomes invalid)

	local LastScopeListener, LastScopeAncestry

	-- Listen to changes in scope
	GetCore().UIMaid.ScopeReset = self.ScopeChanged:Connect(function (Scope)

		-- Clear last scope listener
		LastScopeListener = LastScopeListener and LastScopeListener:Disconnect()

		-- Only listen to new scope if defined
		if not Scope then
			return
		end

		-- Capture new scope's ancestry
		LastScopeAncestry = {}
		local Ancestor = Scope.Parent
		while Ancestor:IsDescendantOf(Workspace) do
			table.insert(LastScopeAncestry, Ancestor)
			Ancestor = Ancestor.Parent
		end

		-- Reset scope when scope is gone
		LastScopeListener = Scope.AncestryChanged:Connect(function (_, Parent)
			if Parent == nil then

				-- Get next parent in ancestry
				local NextScopeInAncestry
				if LastScopeAncestry then
					for _, Parent in ipairs(LastScopeAncestry) do
						if Parent:IsDescendantOf(Workspace) then
							NextScopeInAncestry = Parent
							break
						end
					end
				end

				-- Set next scope
				if NextScopeInAncestry then
					self:SetScope(NextScopeInAncestry)
				else
					self:SetScope(Workspace, true)
				end

			-- Capture scope ancestry when it changes
			else
				LastScopeAncestry = {}
				local Ancestor = Scope.Parent
				while Ancestor:IsDescendantOf(Workspace) do
					table.insert(LastScopeAncestry, Ancestor)
					Ancestor = Ancestor.Parent
				end
			end
		end)

	end)
end

--- Switches to the specified targeting mode.
-- @returns void
function TargetingModule:SetTargetingMode(NewTargetingMode)
	if (NewTargetingMode == 'Scoped') or (NewTargetingMode == 'Direct') then
		self.TargetingMode = NewTargetingMode
		self.TargetingModeChanged:Fire(NewTargetingMode)
	else
		error('Invalid targeting mode', 2)
	end
end

--- Toggles between targeting modes.
-- @returns void
function TargetingModule:ToggleTargetingMode()
	if self.TargetingMode == 'Scoped' then
		self:SetTargetingMode('Direct')
	elseif self.TargetingMode == 'Direct' then
		self:SetTargetingMode('Scoped')
	end
end

--- Installs listener for targeting mode toggling hotkeys.
-- @returns void
function TargetingModule:BindTargetingModeHotkeys()
	local function Callback(Action, State, Input)
		if (State.Name == 'End') then
			return Enum.ContextActionResult.Pass
		end

		-- Ensure shift is held
		local KeysPressed = UserInputService:GetKeysPressed()
		local IsShiftHeld = Input:IsModifierKeyDown(Enum.ModifierKey.Shift)
		if (#KeysPressed ~= 2) or (not IsShiftHeld) then
			return Enum.ContextActionResult.Pass
		end

		-- Toggle between targeting modes
		self:ToggleTargetingMode()
		self:UpdateTarget(nil, true)

		-- Sink input
		return Enum.ContextActionResult.Sink
	end

	-- Install listener for T key
	ContextActionService:BindAction('BT: Toggle Targeting Mode', Callback, false, Enum.KeyCode.T)

	-- Unbind hotkey when tool is disabled
	local Core = GetCore()
	Core.Connections.UnbindTargetingModeHotkeys = Core.Disabling:Connect(function ()
		ContextActionService:UnbindAction('BT: Toggle Targeting Mode')
	end)
end

function GetCore()
	return require(script.Parent);
end;

return TargetingModule;