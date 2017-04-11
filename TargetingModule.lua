-- Libraries
RbxUtility = LoadLibrary 'RbxUtility';
Create = RbxUtility.Create;
Support = require(script.Parent.SupportLibrary);
Selection = require(script.Parent.SelectionModule);

TargetingModule = {};
TargetingModule.TargetChanged = RbxUtility.CreateSignal();

function TargetingModule.EnableTargeting()
	-- 	Begin targeting parts from the mouse

	-- Get core API
	local Core = GetCore();

	-- Get current mouse
	Mouse = GetCore().Mouse;

	-- Listen for target changes
	Core.Connections.Targeting = Mouse.Move:connect(TargetingModule.UpdateTarget);

	-- Listen for target clicks
	Core.Connections.Selecting = Mouse.Button1Up:connect(TargetingModule.SelectTarget);

	-- Listen for 2D selection
	Core.Connections.RectSelectionStarted = Mouse.Button1Down:connect(TargetingModule.StartRectangleSelecting);
	Core.Connections.RectSelectionFinished = Support.AddUserInputListener('Ended', 'MouseButton1', true, TargetingModule.FinishRectangleSelecting);

	-- Hide target box when tool is unequipped
	Core.Connections.HideTargetBoxOnDisable = Core.Disabling:connect(TargetingModule.HighlightTarget);

	-- Cancel any ongoing selection when tool is unequipped
	Core.Connections.CancelSelectionOnDisable = Core.Disabling:connect(TargetingModule.CancelRectangleSelecting);

end;

function TargetingModule.UpdateTarget()

	-- Ensure target has changed
	if Target == Mouse.Target then
		return;
	end;

	-- Update target
	Target = Mouse.Target;

	-- Fire events
	TargetingModule.TargetChanged:fire(Mouse.Target);

end;

function TargetingModule.HighlightTarget(Target)

	-- Create target box
	if not TargetBox then
		TargetBox = Create 'SelectionBox' {
			Name = 'BTTargetOutline',
			Parent = GetCore().UIContainer,
			LineThickness = 0.025,
			Transparency = 0.5,
			Color = BrickColor.new 'Institutional white'
		};
	end;

	-- Focus on target
	TargetBox.Parent = Target and GetCore().UIContainer or nil;
	TargetBox.Adornee = Target;

end;

function TargetingModule.SelectTarget()

	-- Ensure target selection isn't cancelled
	if SelectionCancelled then
		SelectionCancelled = false;
		return;
	end;

	-- Focus on clicked, selected item
	if not Selection.Multiselecting and Selection.IsSelected(Target) then
		Selection.SetFocus(Target);
		return;
	end;

	-- Clear selection if invalid target selected
	if not GetCore().IsSelectable(Target) then
		Selection.Clear(true);
		return;
	end;

	-- Unselect clicked, selected item if multiselection is enabled
	if Selection.Multiselecting and Selection.IsSelected(Target) then
		Selection.Remove({ Target }, true);
		return;
	end;

	-- Add to selection if multiselecting
	if Selection.Multiselecting then
		Selection.Add({ Target }, true);

	-- Replace selection if not multiselecting
	else
		Selection.Replace({ Target }, true);
	end;

end;

function TargetingModule.StartRectangleSelecting()

	-- Ensure selection isn't cancelled
	if SelectionCancelled then
		return;
	end;

	-- Mark where rectangle selection started
	RectangleSelectStart = Vector2.new(Mouse.X, Mouse.Y);

	GetCore().Connections.WatchRectangleSelection = Mouse.Move:connect(function ()

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

	-- Create selection rectangle
	if not SelectionRectangle then
		SelectionRectangle = Create 'Frame' {
			Name = 'SelectionRectangle',
			Parent = GetCore().UI,
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
	SelectionRectangle.Parent = GetCore().UI;
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
		Connections.WatchRectangleSelection:disconnect();
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

	local RectangleSelecting = RectangleSelecting;
	local RectangleSelectStart = RectangleSelectStart;

	-- Clear rectangle selection
	TargetingModule.CancelRectangleSelecting();

	-- Ensure rectangle selection is ongoing
	if not RectangleSelecting then
		return;
	end;

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
	for _, Part in pairs(Support.GetAllDescendants(Workspace)) do
		if Part:IsA 'BasePart' then
			local ScreenPoint, OnScreen = Workspace.CurrentCamera:WorldToScreenPoint(Part.Position);
			if OnScreen then
				local LeftCheck = ScreenPoint.X >= StartPoint.X;
				local RightCheck = ScreenPoint.X <= EndPoint.X;
				local TopCheck = ScreenPoint.Y >= StartPoint.Y;
				local BottomCheck = ScreenPoint.Y <= EndPoint.Y;
				table.insert(SelectableItems, (LeftCheck and RightCheck and TopCheck and BottomCheck) and Part or nil);
			end;
		end;
	end;

	-- Add to selection if multiselecting
	if Selection.Multiselecting then
		Selection.Add(SelectableItems, true);

	-- Replace selection if not multiselecting
	else
		Selection.Replace(SelectableItems, true);
	end;

end;

TargetingModule.TargetChanged:connect(function (Target)

	-- Hide target box if no/unselectable target
	if not Target or not GetCore().IsSelectable(Target) or GetCore().Selection.IsSelected(Target) then
		TargetingModule.HighlightTarget(nil);

	-- Show target outline if target is selectable
	else
		TargetingModule.HighlightTarget(Target);
	end;

end);

function GetCore()
	return require(script.Parent.Core);
end;

return TargetingModule;