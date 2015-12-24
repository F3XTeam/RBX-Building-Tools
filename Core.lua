------------------------------------------
-- Create references to important objects
------------------------------------------

-- Reference services
Workspace				= Game:GetService 'Workspace';
Players					= Game:GetService 'Players';
MarketplaceService		= Game:GetService 'MarketplaceService';
ContentProvider			= Game:GetService 'ContentProvider';
SoundService			= Game:GetService 'SoundService';
UserInputService		= Game:GetService 'UserInputService';
SelectionService		= Game:GetService 'Selection';
CoreGui					= Game:GetService 'CoreGui';
HttpService				= Game:GetService 'HttpService';
ChangeHistoryService	= Game:GetService 'ChangeHistoryService';

-- Reference external assets
Assets = {
	DarkSlantedRectangle	= 'http://www.roblox.com/asset/?id=127774197';
	LightSlantedRectangle	= 'http://www.roblox.com/asset/?id=127772502';
	ActionCompletionSound	= 'http://www.roblox.com/asset/?id=99666917';
	ExpandArrow				= 'http://www.roblox.com/asset/?id=134367382';
	UndoActiveDecal			= 'http://www.roblox.com/asset/?id=141741408';
	UndoInactiveDecal		= 'http://www.roblox.com/asset/?id=142074557';
	RedoActiveDecal			= 'http://www.roblox.com/asset/?id=141741327';
	RedoInactiveDecal		= 'http://www.roblox.com/asset/?id=142074553';
	DeleteActiveDecal		= 'http://www.roblox.com/asset/?id=141896298';
	DeleteInactiveDecal		= 'http://www.roblox.com/asset/?id=142074644';
	ExportActiveDecal		= 'http://www.roblox.com/asset/?id=141741337';
	ExportInactiveDecal		= 'http://www.roblox.com/asset/?id=142074569';
	CloneActiveDecal		= 'http://www.roblox.com/asset/?id=142073926';
	CloneInactiveDecal		= 'http://www.roblox.com/asset/?id=142074563';
	PluginIcon				= 'http://www.roblox.com/asset/?id=142287521';
	GroupLockIcon			= 'http://www.roblox.com/asset/?id=175396862';
	GroupUnlockIcon			= 'http://www.roblox.com/asset/?id=160408836';
	GroupUpdateOKIcon		= 'http://www.roblox.com/asset/?id=164421681';
	GroupUpdateIcon			= 'http://www.roblox.com/asset/?id=160402908';
};

-- The ID of the tool model on ROBLOX
ToolAssetID = 142785488;

Tool = script.Parent;
Player = Players.LocalPlayer;
Mouse = nil;

-- Set tool or plugin-specific references
if plugin then
	ToolType		= 'plugin';
	GUIContainer	= CoreGui;

	-- Create the toolbar button
	ToolbarButton = plugin:CreateToolbar( 'Building Tools by F3X' ):CreateButton( '', 'Building Tools by F3X', Assets.PluginIcon );

elseif Tool:IsA 'Tool' then
	ToolType		= 'tool';
	GUIContainer	= Player:WaitForChild 'PlayerGui';
end;


------------------------------------------
-- Load external dependencies
------------------------------------------

RbxUtility = LoadLibrary 'RbxUtility';
Support = require(Tool:WaitForChild 'SupportLibrary');
ServerAPI = Tool:WaitForChild 'ServerAPI';
Security = require(Tool:WaitForChild 'SecurityModule');

-- Preload external assets
for ResourceName, ResourceUrl in pairs( Assets ) do
	ContentProvider:Preload( ResourceUrl );
end;

-- Wait for gloo to load
repeat wait( 0 ) until _G.gloo;
Gloo = _G.gloo;

-- Wait for other components to load
Tool:WaitForChild 'HttpInterface';
Tool:WaitForChild 'Interfaces';
Tool:WaitForChild 'FilterModeAllowed';

-- Determine whether filter mode is enabled
FilterMode = (Workspace.FilteringEnabled and Game:FindFirstChild 'NetworkClient' and Tool.FilterModeAllowed.Value) and true or false;

-- Keep track of possible future changes in filter mode
Tool.FilterModeAllowed.Changed:connect(function ()
	FilterMode = (Workspace.FilteringEnabled and Game:FindFirstChild 'NetworkClient' and Tool.FilterModeAllowed.Value) and true or false;
end);


------------------------------------------
-- Prepare the UI
------------------------------------------
-- Wait for all parts of the base UI to fully replicate
if ToolType == 'tool' then
	local UIComponentCount = (Tool:WaitForChild 'UIComponentCount').Value;
	repeat wait( 0.1 ) until #Support.GetAllDescendants(Tool.Interfaces) >= UIComponentCount;
end;


------------------------------------------
-- Create data containers
------------------------------------------

ActiveKeys = {};

CurrentTool = nil;

function equipTool( NewTool )

	-- If it's a different tool than the current one
	if CurrentTool ~= NewTool then

		-- Run (if existent) the old tool's `Unequipped` listener
		if CurrentTool and CurrentTool.Listeners.Unequipped then
			CurrentTool.Listeners.Unequipped();
		end;

		CurrentTool = NewTool;

		-- Recolor the handle
		if ToolType == 'tool' then
			if FilterMode then
				ServerAPI:InvokeServer('RecolorHandle', NewTool.Color);
			else
				Tool.Handle.BrickColor = NewTool.Color;
			end;
		end;

		-- Highlight the right button on the dock
		for _, Button in pairs( Dock.ToolButtons:GetChildren() ) do
			Button.BackgroundTransparency = 1;
		end;
		local Button = Dock.ToolButtons:FindFirstChild( getToolName( NewTool ) .. "Button" );
		if Button then
			Button.BackgroundTransparency = 0;
		end;

		-- Run (if existent) the new tool's `Equipped` listener
		if NewTool.Listeners.Equipped then
			NewTool.Listeners.Equipped();
		end;

	end;
end;

function cloneSelection()
	-- Clones the items in the selection

	-- Make sure that there are items in the selection
	if #Selection.Items > 0 then

		local item_copies = {};

		-- Send the request for cloning these parts if filter mode is on
		if FilterMode then
			item_copies = ServerAPI:InvokeServer('Clone', Selection.Items);

		-- Otherwise, make the copies directly locally
		else 
			for _, Item in pairs( Selection.Items ) do
				local ItemCopy = Item:Clone();
				ItemCopy.Parent = Workspace;
				table.insert( item_copies, ItemCopy );
			end;
		end;

		-- Replace the selection with the copied items
		Selection:clear();
		for _, Item in pairs( item_copies ) do
			Selection:add( Item );
		end;

		local HistoryRecord = {
			copies = item_copies;
			Unapply = function ( self )
				for _, Copy in pairs( self.copies ) do
					if Copy then
						SetParent(Copy, nil);
					end;
				end;
			end;
			Apply = function ( self )
				Selection:clear();
				for _, Copy in pairs( self.copies ) do
					if Copy then
						SetParent(Copy, Workspace);
						MakeJoints(Copy);
						Selection:add(Copy);
					end;
				end;
			end;
		};
		History:Add( HistoryRecord );

		-- Play a confirmation sound
		local Sound = RbxUtility.Create "Sound" {
			Name = "BTActionCompletionSound";
			Pitch = 1.5;
			SoundId = Assets.ActionCompletionSound;
			Volume = 1;
			Parent = Player or SoundService;
		};
		Sound:Play();
		Sound:Destroy();

		-- Highlight the outlines of the new parts
		coroutine.wrap( function ()
			for transparency = 1, 0.5, -0.1 do
				for Item, SelectionBox in pairs( SelectionBoxes ) do
					SelectionBox.Transparency = transparency;
				end;
				wait( 0.1 );
			end;
		end )();

	end;

end;

function deleteSelection()
	-- Deletes the items in the selection

	if #Selection.Items == 0 then
		return;
	end;

	local selection_items = Support.CloneTable(Selection.Items);

	-- Create a history record
	local HistoryRecord = {
		targets = selection_items;
		parents = {};
		Apply = function ( self )
			for _, Target in pairs( self.targets ) do
				if Target then
					SetParent(Target, nil);
				end;
			end;
		end;
		Unapply = function ( self )
			Selection:clear();
			for _, Target in pairs( self.targets ) do
				if Target then
					SetParent(Target, self.parents[Target]);
					MakeJoints(Target);
					Selection:add(Target);
				end;
			end;
		end;
	};

	for _, Item in pairs( selection_items ) do
		HistoryRecord.parents[Item] = Item.Parent;
		SetParent(Item, nil);
	end;

	History:Add( HistoryRecord );

end;

function prismSelect()
	-- Selects all the parts within the area of the selected parts

	-- Make sure parts to define the area are present
	if #Selection.Items == 0 then
		return;
	end;

	local parts = {};

	-- Get all the parts in workspace
	local workspace_parts = {};
	local workspace_children = Support.GetAllDescendants(Workspace);
	for _, Child in pairs( workspace_children ) do
		if Child:IsA( 'BasePart' ) and not Selection:find( Child ) then
			table.insert( workspace_parts, Child );
		end;
	end;

	-- Go through each part and perform area tests on each one
	local checks = {};
	for _, Item in pairs( workspace_parts ) do
		checks[Item] = 0;
		for _, SelectionItem in pairs( Selection.Items ) do

			-- Calculate the position of the item in question in relation to the area-defining parts
			local offset = SelectionItem.CFrame:toObjectSpace( Item.CFrame );
			local extents = SelectionItem.Size / 2;

			-- Check the item off if it passed this test (if it's within the range of the extents)
			if ( math.abs( offset.x ) <= extents.x ) and ( math.abs( offset.y ) <= extents.y ) and ( math.abs( offset.z ) <= extents.z ) then
				checks[Item] = checks[Item] + 1;
			end;

		end;
	end;

	-- Delete the parts that were used to select the area
	local selection_items = Support.CloneTable(Selection.Items);
	local selection_item_parents = {};
	for _, Item in pairs( selection_items ) do
		selection_item_parents[Item] = Item.Parent;
		Item.Parent = nil;
	end;

	-- Select the parts that passed any area checks
	for _, Item in pairs( workspace_parts ) do
		if checks[Item] > 0 then
			Selection:add( Item );
		end;
	end;

	-- Add a history record
	History:Add( {
		selection_parts = selection_items;
		selection_part_parents = selection_item_parents;
		new_selection = Support.CloneTable(Selection.Items);
		Apply = function ( self )
			Selection:clear();
			for _, Item in pairs( self.selection_parts ) do
				Item.Parent = nil;
			end;
			for _, Item in pairs( self.new_selection ) do
				Selection:add( Item );
			end;
		end;
		Unapply = function ( self )
			Selection:clear();
			for _, Item in pairs( self.selection_parts ) do
				Item.Parent = self.selection_part_parents[Item];
				Selection:add( Item );
			end;
		end;
	} );

end;

function toggleHelp()

	-- Make sure the dock is ready
	if not Dock then
		return;
	end;

	-- Toggle the visibility of the help tooltip
	Dock.HelpInfo.Visible = not Dock.HelpInfo.Visible;

end;

function getToolName( tool )
	-- Returns the name of `tool` as registered in `Tools`

	local name_search = Support.FindTableOccurrences(Tools, tool);
	if #name_search > 0 then
		return name_search[1];
	end;

end;

function isSelectable( Object )
	-- Returns whether `Object` is selectable

	if not Object or not Object.Parent or not Object:IsA( "BasePart" ) or Object.Locked or Selection:find( Object ) or Groups:IsPartIgnored( Object ) then
		return false;
	end;

	-- If areas are enabled, check if the player can manipulate this part
	if Security.AreAreasEnabled() then
		return Security.IsPartAuthorizedForPlayer(Object, Player);
	end;

	-- If it passes all checks, return true
	return true;
end;

function Change(Object, Changes)
	-- Performs a local and server-side change on `Object`

	local Part;
	if Object:IsA 'BasePart' then
		Part = Object;
	elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Sparkles' or Object:IsA 'DataModelMesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Weld' or Object:IsA 'Light' then
		Part = Object.Parent;
	end;

	-- Only perform changes to authorized parts
	if Part:IsA 'BasePart' and Security.IsPartAuthorizedForPlayer(Part, Player) then

		-- If in filter mode, only send changes to server
		if FilterMode then
			ServerAPI:InvokeServer('Change', Object, Changes);

		-- If filter mode is disabled, apply changes locally and instantly
		elseif not FilterMode then
			for Property, Value in pairs(Changes) do
				Object[Property] = Value;
			end;
		end;

	end;

end;

function SetParent(Object, Parent)
	-- Sets `Object`'s parent to `Parent`

	-- If in filter mode, request parenting from the server
	if FilterMode then
		ServerAPI:InvokeServer('SetParent', Object, Parent);

	-- Otherwise, set parent directly
	else

		-- If this is a part, make sure we have permission to modify it
		if Object:IsA 'BasePart' then
			if not Security.IsPartAuthorizedForPlayer(Object, Player) then
				return;
			end;

		-- If this is a decoration, make sure we have permission to modify it, and the new parent part
		elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Sparkles' or Object:IsA 'DataModelMesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Weld' or Object:IsA 'Light' then
			
			-- Make sure we can modify the current parent of the decoration (if any)
			if Object.Parent and Object.Parent:IsA 'BasePart' then
				if not Security.IsPartAuthorizedForPlayer(Object.Parent, Player) then
					return;
				end;
			end;

			-- Make sure we can modify the target parent part
			if Parent and Parent:IsA 'BasePart' then
				if not Security.IsPartAuthorizedForPlayer(Parent, Player) then
					return;
				end;
			end;

		end;

		-- If no authorization checks have failed, perform the setting
		Object.Parent = Parent;

	end;
end;

function MakeJoints(Part)
	-- Performs a server-side call to Part:MakeJoints()

	-- Only perform changes to authorized parts
	if Part:IsA 'BasePart' and Security.IsPartAuthorizedForPlayer(Part, Player) then

		-- If in filter mode, request changes from the server
		if FilterMode then
			ServerAPI:InvokeServer('MakeJoints', Part);

		-- If in local mode (filtering disabled), apply changes locally and directly
		elseif not FilterMode then
			Part:MakeJoints();
		end;

	end;

end;

function IsVersionOutdated()
	-- Returns whether this version of Building Tools is out of date

	-- Check the most recent version number
	local AssetInfo			= MarketplaceService:GetProductInfo( ToolAssetID, Enum.InfoType.Asset );
	local VersionID 		= AssetInfo.Description:match( '%[Version: (.+)%]' );
	local CurrentVersionID	= ( Tool:WaitForChild 'Version' ).Value;

	-- If the most recent version ID differs from the current tool's version ID,
	-- this version of the tool is outdated
	if VersionID ~= CurrentVersionID then
		return true;
	end;

	-- If it's up-to-date, return false
	return false;
end;

-- Provide initial HttpService availability info
HttpAvailable, HttpAvailabilityError = Tool.HttpInterface:WaitForChild('Test'):InvokeServer();

-- Keep track of the latest HttpService availability status
-- (which is only likely to change while in Studio, using the plugin)
if ToolType == 'plugin' then
	HttpService.Changed:connect( function ()
		HttpAvailable, HttpAvailabilityError = Tool.HttpInterface:WaitForChild('Test'):InvokeServer();
	end );
end;

local StartupNotificationsShown = false;
function ShowStartupNotifications()

	-- Make sure the startup notifications are only shown once
	if StartupNotificationsShown then
		return;
	end;
	StartupNotificationsShown = true;

	-- Create the main container for notifications
	local NotificationContainer = Tool.Interfaces.BTStartupNotificationContainer:Clone();

	-- Add the right notifications
	if not HttpAvailable and HttpAvailabilityError == 'Http requests are not enabled' then
		NotificationContainer.HttpDisabledWarning.Visible = true;
	end;
	if not HttpAvailable and HttpAvailabilityError == 'Http requests can only be executed by game server' then
		NotificationContainer.SoloWarning.Visible = true;
	end;
	if IsVersionOutdated() then
		if ToolType == 'tool' then
			NotificationContainer.ToolUpdateNotification.Visible = true;
		elseif ToolType == 'plugin' then
			NotificationContainer.PluginUpdateNotification.Visible = true;
		end;
	end;

	local function SetContainerSize()
		-- A function to position the notifications in the container and
		-- resize the container to fit all the notifications

		-- Keep track of the lowest extent of each item in the container
		local LowestPoint = 0;

		local Notifications = NotificationContainer:GetChildren();
		for NotificationIndex, Notification in pairs( Notifications ) do

			-- Position each notification under the last one
			Notification.Position = UDim2.new(
				Notification.Position.X.Scale,
				Notification.Position.X.Offset,
				Notification.Position.Y.Scale,
				( LowestPoint == 0 ) and 0 or ( LowestPoint + 10 )
			);

			-- Calculate the lowest point of this notification
			local VerticalEnd = Notification.Position.Y.Offset + Notification.Size.Y.Offset;
			if Notification.Visible and VerticalEnd > LowestPoint then
				LowestPoint = VerticalEnd;
			end;

		end;

		NotificationContainer.Size = UDim2.new(
			NotificationContainer.Size.X.Scale,
			NotificationContainer.Size.X.Offset,
			0,
			LowestPoint
		);
	end;

	SetContainerSize();

	-- Have the container start from the center/bottom of the screen
	local HCenterPos = ( UI.AbsoluteSize.x - NotificationContainer.Size.X.Offset ) / 2;
	local VBottomPos = UI.AbsoluteSize.y + NotificationContainer.Size.Y.Offset;
	NotificationContainer.Position = UDim2.new( 0, HCenterPos, 0, VBottomPos );

	NotificationContainer.Parent = UI;

	local function CenterNotificationContainer()
		-- A function to center the notification container

		-- Animate the container to slide up to the absolute center of the screen
		local VCenterPos = ( UI.AbsoluteSize.y - NotificationContainer.Size.Y.Offset ) / 2;
		NotificationContainer:TweenPosition(
			UDim2.new( 0, HCenterPos, 0, VCenterPos ),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Quad,
			0.2
		);
	end;

	CenterNotificationContainer();

	-- Add functionality to the notification UIs
	for _, Notification in pairs( NotificationContainer:GetChildren() ) do
		if Notification.Visible then
			Notification.OKButton.MouseButton1Click:connect( function ()
				Notification:Destroy();
				SetContainerSize();
				CenterNotificationContainer();
			end );
			Notification.HelpButton.MouseButton1Click:connect( function ()
				Notification.HelpButton:Destroy();
				Notification.ButtonSeparator:Destroy();
				Notification.OKButton:TweenSize(
					UDim2.new( 1, 0, 0, 22 ),
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.2
				);
				Notification.Notice:Destroy();
				Notification.Help.Visible = true;
				Notification:TweenSize(
					UDim2.new(
						Notification.Size.X.Scale, Notification.Size.X.Offset,
						Notification.Size.Y.Scale, Notification.Help.NotificationSize.Value
					),
					Enum.EasingDirection.Out,
					Enum.EasingStyle.Quad,
					0.2,
					true,
					function ()
						SetContainerSize();
						CenterNotificationContainer();
					end
				);
			end );
		end;
	end;

	-- Get rid of the notifications if the user unequips the tool
	if ToolType == 'tool' then
		Tool.Unequipped:connect( function ()
			if NotificationContainer.Visible then
				NotificationContainer.Visible = false;
				NotificationContainer:Destroy();
			end;
		end );
	end;
end;

-- Keep some state data
clicking = false;
selecting = false;
click_x, click_y = 0, 0;
override_selection = false;

SelectionBoxes = {};
SelectionExistenceListeners = {};
SelectionBoxColor = BrickColor.new( "Cyan" );
TargetBox = nil;

-- Keep a container for temporary connections
-- from the platform
Connections = {};

-- Make sure the UI container gets placed
UI = RbxUtility.Create "ScreenGui" {
	Name = "Building Tools by F3X (UI)"
};
if ToolType == 'tool' then
	UI.Parent = GUIContainer;
elseif ToolType == 'plugin' then
	UI.Parent = CoreGui;
end;

Dragger = nil;

function updateSelectionBoxColor()
	-- Updates the color of the selectionboxes
	for _, SelectionBox in pairs( SelectionBoxes ) do
		SelectionBox.Color = SelectionBoxColor;
	end;
end;

Selection = {

	["Items"] = {};

	-- Provide events to listen to changes in the selection
	["Changed"] = RbxUtility.CreateSignal();
	["ItemAdded"] = RbxUtility.CreateSignal();
	["ItemRemoved"] = RbxUtility.CreateSignal();
	["Cleared"] = RbxUtility.CreateSignal();

	-- Provide a method to get an item's index in the selection
	["find"] = function ( self, Needle )

		-- Look through all the selected items and return the matching item's index
		for item_index, Item in pairs( self.Items ) do
			if Item == Needle then
				return item_index;
			end;
		end;

		-- Otherwise, return `nil`

	end;

	-- Provide a method to add items to the selection
	["add"] = function ( self, NewPart )

		-- Make sure `NewPart` is selectable
		if not isSelectable( NewPart ) then
			return false;
		end;

		-- Make sure `NewPart` isn't already in the selection
		if #Support.FindTableOccurrences(self.Items, NewPart) > 0 then
			return false;
		end;

		-- Insert it into the selection
		table.insert( self.Items, NewPart );

		-- Add its SelectionBox if we're in tool mode
		if ToolType == 'tool' then
			SelectionBoxes[NewPart] = Instance.new( "SelectionBox", UI );
			SelectionBoxes[NewPart].Name = "BTSelectionBox";
			SelectionBoxes[NewPart].Color = SelectionBoxColor;
			SelectionBoxes[NewPart].Adornee = NewPart;
			SelectionBoxes[NewPart].LineThickness = 0.05;
			SelectionBoxes[NewPart].Transparency = 0.5;
		end;

		-- Remove any target selection box focus
		if NewPart == TargetBox.Adornee then
			TargetBox.Adornee = nil;
		end;

		-- Make sure to remove the item from the selection when it's deleted
		SelectionExistenceListeners[NewPart] = NewPart.AncestryChanged:connect( function ( Object, NewParent )
			if NewParent == nil then
				Selection:remove( NewPart );
			end;
		end );

		-- Provide a reference to the last item added to the selection (i.e. NewPart)
		self:focus( NewPart );

		-- Fire events
		self.ItemAdded:fire( NewPart );
		self.Changed:fire();

	end;

	-- Provide a method to remove items from the selection
	["remove"] = function ( self, Item, Clearing )

		-- Make sure selection item `Item` exists
		if not self:find( Item ) then
			return false;
		end;

		-- Remove `Item`'s SelectionBox
		local SelectionBox = SelectionBoxes[Item];
		if SelectionBox then
			SelectionBox:Destroy();
		end;
		SelectionBoxes[Item] = nil;

		-- Delete the item from the selection
		table.remove( self.Items, self:find( Item ) );

		-- If it was logged as the last item, change it
		if self.Last == Item then
			self:focus( ( #self.Items > 0 ) and self.Items[#self.Items] or nil );
		end;

		-- Delete the existence listeners of the item
		SelectionExistenceListeners[Item]:disconnect();
		SelectionExistenceListeners[Item] = nil;

		-- Fire events
		self.ItemRemoved:fire( Item, Clearing );
		self.Changed:fire();

	end;

	-- Provide a method to clear the selection
	["clear"] = function ( self )

		-- Go through all the items in the selection and call `self.remove` on them
		for _, Item in pairs(Support.CloneTable(self.Items)) do
			self:remove( Item, true );
		end;

		-- Fire events
		self.Cleared:fire();

	end;

	-- Provide a method to change the focus of the selection
	["focus"] = function ( self, NewFocus )

		-- Change the focus
		self.Last = NewFocus;

		-- Fire events
		self.Changed:fire();

	end;	

};

------------------------------------------
-- WARNING: MICROOPTIMIZED CODE
------------------------------------------

-- Create shortcuts to certain things that are expensive to call constantly
local cframe_new = CFrame.new;
local table_insert = table.insert;
local cframe_toWorldSpace = CFrame.new().toWorldSpace;
local math_min = math.min;
local math_max = math.max;

function calculateExtents(Items, StaticExtents, JustExtents)
	-- Returns the size and position of a boundary box that covers the extents
	-- of the parts in table `Items`

	-- Make sure there's actually any parts given
	local RandomItem;
	local ItemCount = 0;
	for _, Item in pairs(Items) do
		ItemCount = ItemCount + 1;
		RandomItem = Item;
	end;
	if ItemCount == 0 then
		return;
	end;

	local ComparisonBaseMin = StaticExtents and StaticExtents['Minimum'] or RandomItem['Position'];
	local ComparisonBaseMax = StaticExtents and StaticExtents['Maximum'] or RandomItem['Position'];
	local MinX, MinY, MinZ = ComparisonBaseMin['x'], ComparisonBaseMin['y'], ComparisonBaseMin['z'];
	local MaxX, MaxY, MaxZ = ComparisonBaseMax['x'], ComparisonBaseMax['y'], ComparisonBaseMax['z'];

	for _, Part in pairs(Items) do

		if not (Part.Anchored and StaticExtents) then
			local PartCFrame = Part['CFrame'];
			local PartSize = Part['Size'] / 2;
			local SizeX, SizeY, SizeZ = PartSize['x'], PartSize['y'], PartSize['z'];

			local Corner;
			local XPoints, YPoints, ZPoints = {}, {}, {};

			Corner = cframe_toWorldSpace( PartCFrame, cframe_new( SizeX, SizeY, SizeZ ) );
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);
			
			Corner = cframe_toWorldSpace( PartCFrame, cframe_new( -SizeX, SizeY, SizeZ ) );
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);

			Corner = cframe_toWorldSpace( PartCFrame, cframe_new( SizeX, -SizeY, SizeZ ) );
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);
			
			Corner = cframe_toWorldSpace( PartCFrame, cframe_new( SizeX, SizeY, -SizeZ ) );
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);
			
			Corner = cframe_toWorldSpace( PartCFrame, cframe_new( -SizeX, SizeY, -SizeZ ) );
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);
			
			Corner = cframe_toWorldSpace( PartCFrame, cframe_new( -SizeX, -SizeY, SizeZ ) );
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);
			
			Corner = cframe_toWorldSpace( PartCFrame, cframe_new( SizeX, -SizeY, -SizeZ ) );
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);
			
			Corner = cframe_toWorldSpace( PartCFrame, cframe_new( -SizeX, -SizeY, -SizeZ ) );
			table_insert(XPoints, Corner['x']);
			table_insert(YPoints, Corner['y']);
			table_insert(ZPoints, Corner['z']);

			MinX = math_min(MinX, unpack(XPoints));
			MinY = math_min(MinY, unpack(YPoints));
			MinZ = math_min(MinZ, unpack(ZPoints));
			MaxX = math_max(MaxX, unpack(XPoints));
			MaxY = math_max(MaxY, unpack(YPoints));
			MaxZ = math_max(MaxZ, unpack(ZPoints));

		end;

	end;

	if JustExtents then

		-- Return the extents information
		return {
			Minimum = { x = MinX, y = MinY, z = MinZ };
			Maximum = { x = MaxX, y = MaxY, z = MaxZ };
		};
	
	else

		-- Get the size between the extents
		local XSize, YSize, ZSize = 	MaxX - MinX,
										MaxY - MinY,
										MaxZ - MinZ;

		local Size = Vector3.new( XSize, YSize, ZSize );

		-- Get the centroid of the collection of points
		local Position = CFrame.new( 	MinX + ( MaxX - MinX ) / 2,
										MinY + ( MaxY - MinY ) / 2,
										MinZ + ( MaxZ - MinZ ) / 2 );

		-- Return the size of the collection of parts
		return Size, Position;

	end;

end;


-- Keep the Studio selection up-to-date (if applicable)
if ToolType == 'plugin' then
	Selection.Changed:connect( function ()
		SelectionService:Set( Selection.Items );
	end );
end;

Tools = {};


------------------------------------------
-- Define other utilities needed by tools
------------------------------------------

function createDropdown()

	local Frame = RbxUtility.Create "Frame" {
		Name = "Dropdown";
		Size = UDim2.new( 0, 20, 0, 20 );
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		ClipsDescendants = true;
	};

	RbxUtility.Create "ImageLabel" {
		Parent = Frame;
		Name = "Arrow";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Image = Assets.ExpandArrow;
		Position = UDim2.new( 1, -21, 0, 3 );
		Size = UDim2.new( 0, 20, 0, 20 );
		ZIndex = 3;
	};

	local DropdownObject = {
		-- Provide access to the actual frame
		Frame = Frame;

		-- Keep a list of all the options in the dropdown
		_options = {};

		-- Provide a function to add options to the dropdown
		addOption = function ( self, option )

			-- Add the option to the list
			table.insert( self._options, option );

			-- Create the GUI for the option
			local Button = RbxUtility.Create "TextButton" {
				Parent = self.Frame;
				BackgroundColor3 = Color3.new( 0, 0, 0 );
				BackgroundTransparency = 0.3;
				BorderColor3 = Color3.new( 27 / 255, 42 / 255, 53 / 255 );
				BorderSizePixel = 1;
				Name = option;
				Position = UDim2.new( math.ceil( #self._options / 9 ) - 1, 0, 0, 25 * ( ( #self._options % 9 == 0 ) and 9 or ( #self._options % 9 ) ) );
				Size = UDim2.new( 1, 0, 0, 25 );
				ZIndex = 3;
				Text = "";
			};
			local Label = RbxUtility.Create "TextLabel" {
				Parent = Button;
				BackgroundTransparency = 1;
				BorderSizePixel = 0;
				Position = UDim2.new( 0, 6, 0, 0 );
				Size = UDim2.new( 1, -30, 1, 0 );
				ZIndex = 3;
				Font = Enum.Font.ArialBold;
				FontSize = Enum.FontSize.Size12;
				Text = option;
				TextColor3 = Color3.new( 1, 1, 1 );
				TextXAlignment = Enum.TextXAlignment.Left;
				TextYAlignment = Enum.TextYAlignment.Center;
			};

			-- Return the button object
			return Button;

		end;

		selectOption = function ( self, option )
			self.Frame.MainButton.CurrentOption.Text = option;
		end;

		open = false;

		toggle = function ( self )

			-- If it's open, close it
			if self.open then
				self.Frame.MainButton.BackgroundTransparency = 0.3;
				self.Frame.ClipsDescendants = true;
				self.open = false;

			-- If it's not open, open it
			else
				self.Frame.MainButton.BackgroundTransparency = 0;
				self.Frame.ClipsDescendants = false;
				self.open = true;
			end;

		end;

	};

	-- Create the GUI for the option
	local MainButton = RbxUtility.Create "TextButton" {
		Parent = Frame;
		Name = "MainButton";
		BackgroundColor3 = Color3.new( 0, 0, 0 );
		BackgroundTransparency = 0.3;
		BorderColor3 = Color3.new( 27 / 255, 42 / 255, 53 / 255 );
		BorderSizePixel = 1;
		Position = UDim2.new( 0, 0, 0, 0 );
		Size = UDim2.new( 1, 0, 0, 25 );
		ZIndex = 2;
		Text = "";

		-- Toggle the dropdown when pressed
		[RbxUtility.Create.E "MouseButton1Up"] = function ()
			DropdownObject:toggle();
		end;
	};
	RbxUtility.Create "TextLabel" {
		Parent = MainButton;
		Name = "CurrentOption";
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Position = UDim2.new( 0, 6, 0, 0 );
		Size = UDim2.new( 1, -30, 1, 0 );
		ZIndex = 3;
		Font = Enum.Font.ArialBold;
		FontSize = Enum.FontSize.Size12;
		Text = "";
		TextColor3 = Color3.new( 1, 1, 1 );
		TextXAlignment = Enum.TextXAlignment.Left;
		TextYAlignment = Enum.TextYAlignment.Center;
	};

	return DropdownObject;

end;


------------------------------------------
-- Provide an interface to the 2D
-- selection system
------------------------------------------

Select2D = {

	-- Keep state data
	["enabled"] = false;

	-- Keep objects
	["GUI"] = nil;

	-- Keep temporary, disposable connections
	["Connections"] = {};

	-- Provide an interface to the functions
	["start"] = function ( self )

		if self.enabled then
			return;
		end;

		self.enabled = true;

		-- Create the GUI
		self.GUI = RbxUtility.Create "ScreenGui" {
			Name = "BTSelectionRectangle";
			Parent = UI;
		};

		local Rectangle = RbxUtility.Create "Frame" {
			Name = "Rectangle";
			Active = false;
			Parent = self.GUI;
			BackgroundColor3 = Color3.new( 0, 0, 0 );
			BackgroundTransparency = 0.5;
			BorderSizePixel = 0;
			Position = UDim2.new( 0, math.min( click_x, Mouse.X ), 0, math.min( click_y, Mouse.Y ) );
			Size = UDim2.new( 0, math.max( click_x, Mouse.X ) - math.min( click_x, Mouse.X ), 0, math.max( click_y, Mouse.Y ) - math.min( click_y, Mouse.Y ) );
		};

		-- Listen for when to resize the selection
		self.Connections.SelectionResize = Mouse.Move:connect( function ()
			Rectangle.Position = UDim2.new( 0, math.min( click_x, Mouse.X ), 0, math.min( click_y, Mouse.Y ) );
			Rectangle.Size = UDim2.new( 0, math.max( click_x, Mouse.X ) - math.min( click_x, Mouse.X ), 0, math.max( click_y, Mouse.Y ) - math.min( click_y, Mouse.Y ) );
		end );

		-- Listen for when the selection ends (when the left mouse button is released)
		self.Connections.SelectionEnd = UserInputService.InputEnded:connect( function ( InputData )
			if InputData.UserInputType == Enum.UserInputType.MouseButton1 then
				self:select();
				self:finish();
			end;
		end );

	end;

	["select"] = function ( self )

		if not self.enabled then
			return;
		end;

		for _, Object in pairs(Support.GetAllDescendants(Workspace)) do

			-- Make sure we can select this part
			if isSelectable( Object ) then

				-- Check if the part is rendered within the range of the selection area
				local PartPosition = Workspace.CurrentCamera:WorldToScreenPoint(Object.Position);
				if PartPosition then
					local left_check = PartPosition.x >= self.GUI.Rectangle.AbsolutePosition.x;
					local right_check = PartPosition.x <= ( self.GUI.Rectangle.AbsolutePosition.x + self.GUI.Rectangle.AbsoluteSize.x );
					local top_check = PartPosition.y >= self.GUI.Rectangle.AbsolutePosition.y;
					local bottom_check = PartPosition.y <= ( self.GUI.Rectangle.AbsolutePosition.y + self.GUI.Rectangle.AbsoluteSize.y );

					-- If the part is within the selection area, select it
					if left_check and right_check and top_check and bottom_check then
						Selection:add( Object );
					end;
				end;

			end;

		end;

	end;

	["finish"] = function ( self )

		if not self.enabled then
			return;
		end;

		-- Disconnect temporary connections
		for connection_index, Connection in pairs( self.Connections ) do
			Connection:disconnect();
			self.Connections[connection_index] = nil;
		end;

		-- Remove temporary objects
		self.GUI:Destroy();
		self.GUI = nil;

		self.enabled = false;

	end;

};

------------------------------------------
-- Provide an interface to the edge
-- selection system
------------------------------------------
SelectEdge = {

	-- Keep state data
	["enabled"] = false;
	["started"] = false;

	-- Keep objects
	["Marker"] = nil;
	["MarkerOutline"] = RbxUtility.Create "SelectionBox" {
		Color = BrickColor.new( "Institutional white" );
		Parent = UI;
		Name = "BTEdgeSelectionMarkerOutline";
	};

	-- Keep temporary, disposable connections
	["Connections"] = {};

	-- Provide an interface to the functions
	["start"] = function ( self, edgeSelectionCallback )

		if self.started then
			return;
		end;

		-- Listen for when to engage in selection
		self.Connections.KeyListener = Mouse.KeyDown:connect( function ( key )

			local key = key:lower();
			local key_code = key:byte();

			if key == "t" and #Selection.Items > 0 then
				self:enable( edgeSelectionCallback );
			end;

		end );

		self.started = true;

	end;

	["enable"] = function ( self, edgeSelectionCallback )

		if self.enabled then
			return;
		end;

		self.Connections.MoveListener = Mouse.Move:connect( function ()

			-- Make sure the target can be selected
			if not Selection:find( Mouse.Target ) then
				return;
			end;

			-- Calculate the proximity to each edge
			local Proximity = {};
			local edges = {};

			-- Create shortcuts to certain things that are expensive to call constantly
			local table_insert = table.insert;
			local newCFrame = CFrame.new;
			local PartCFrame = Mouse.Target.CFrame;
			local cframe_toWorldSpace = PartCFrame.toWorldSpace;
			local PartSize = Mouse.Target.Size / 2;
			local SizeX, SizeY, SizeZ = PartSize.x, PartSize.y, PartSize.z;

			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( SizeX, SizeY, SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( -SizeX, SizeY, SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( SizeX, -SizeY, SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( SizeX, SizeY, -SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( -SizeX, SizeY, -SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( -SizeX, -SizeY, SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( SizeX, -SizeY, -SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( -SizeX, -SizeY, -SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( SizeX, SizeY, 0 ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( SizeX, 0, SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( 0, SizeY, SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( SizeX, 0, 0 ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( 0, SizeY, 0 ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( 0, 0, SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( -SizeX, SizeY, 0 ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( -SizeX, 0, SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( 0, -SizeY, SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( -SizeX, 0, 0 ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( 0, -SizeY, 0 ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( 0, 0, -SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( SizeX, -SizeY, 0 ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( SizeX, 0, -SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( 0, SizeY, -SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( -SizeX, -SizeY, 0 ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( -SizeX, 0, -SizeZ ) ) );
			table_insert( edges, cframe_toWorldSpace( PartCFrame, newCFrame( 0, -SizeY, -SizeZ ) ) );

			-- Calculate the proximity of every edge to the mouse
			for edge_index, Edge in pairs( edges ) do
				Proximity[edge_index] = ( Mouse.Hit.p - Edge.p ).magnitude;
			end;

			-- Get the closest edge to the mouse
			local highest_proximity = 1;
			for proximity_index, proximity in pairs( Proximity ) do
				if proximity < Proximity[highest_proximity] then
					highest_proximity = proximity_index;
				end;
			end;

			-- Replace the current target edge (if any)
			local ClosestEdge = edges[highest_proximity];

			if self.Marker then
				self.Marker:Destroy();
			end;
			self.Marker = RbxUtility.Create "Part" {
				Name = "BTEdgeSelectionMarker";
				Anchored = true;
				Locked = true;
				CanCollide = false;
				Transparency = 1;
				FormFactor = Enum.FormFactor.Custom;
				Size = Vector3.new( 0.2, 0.2, 0.2 );
				CFrame = ClosestEdge;
			};

			self.MarkerOutline.Adornee = self.Marker;

		end );

		self.Connections.ClickListener = Mouse.Button1Up:connect( function ()
			override_selection = true;
			self:select( edgeSelectionCallback );
		end );

		self.enabled = true;

	end;

	["select"] = function ( self, callback )

		if not self.enabled or not self.Marker then
			return;
		end;

		self.MarkerOutline.Adornee = self.Marker;

		callback( self.Marker );

		-- Stop treating it like a marker
		self.Marker = nil;

		self:disable();

	end;

	["disable"] = function ( self )

		if not self.enabled then
			return;
		end;

		-- Disconnect unnecessary temporary connections
		if self.Connections.ClickListener then
			self.Connections.ClickListener:disconnect();
			self.Connections.ClickListener = nil;
		end;
		if self.Connections.MoveListener then
			self.Connections.MoveListener:disconnect();
			self.Connections.MoveListener = nil;
		end;

		-- Remove temporary objects
		if self.Marker then
			self.Marker:Destroy();
		end;
		self.Marker = nil;

		self.MarkerOutline.Adornee = nil;
		self.enabled = false;

	end;

	["stop"] = function ( self )

		if not self.started then
			return;
		end;

		-- Cancel any ongoing selection
		self:disable();

		-- Disconnect & remove all temporary connections
		for connection_index, Connection in pairs( self.Connections ) do
			Connection:disconnect();
			self.Connections[connection_index] = nil;
		end;

		-- Remove temporary objects
		if self.Marker then
			self.Marker:Destroy();
		end;

		self.started = false;

	end;

};

------------------------------------------
-- Provide an interface to the history
-- system
------------------------------------------
History = {
	
	Data = {};

	-- The current position in the history stack
	Index = 0;

	-- An event firing upon any change in the history
	Changed = RbxUtility.CreateSignal();

};

function History:Undo()

	-- Stay within boundaries
	if History.Index - 1 < 0 then
		return;
	end;

	-- Get the history record, unapply it
	local Record = History.Data[History.Index];
	Record:Unapply();

	-- Update the index
	History.Index = History.Index - 1;

	-- Fire the Changed event
	History.Changed:fire();

end;

function History:Redo()

	-- Stay within boundaries
	if History.Index + 1 > #History.Data then
		return;
	end;

	-- Update the index
	History.Index = History.Index + 1;

	-- Get the history record and apply it
	local Record = History.Data[History.Index];
	Record:Apply();

	-- Fire the Changed event
	History.Changed:fire();

end;

function History:Add(Record)

	-- Update the index
	History.Index = History.Index + 1;

	-- Register the new history record
	History.Data[History.Index] = Record;

	-- Clear history ahead
	for Index = History.Index + 1, #History.Data do
		History.Data[Index] = nil;
	end;

	-- Fire the Changed event
	History.Changed:fire();

end;

-- Link up to Studio's history system if this is the plugin
if ToolType == 'plugin' then
	History.Changed:connect(function ()
		ChangeHistoryService:SetWaypoint 'Building Tools by F3X';
	end);
end;


------------------------------------------
-- Provide an interface color picker
-- system
------------------------------------------
ColorPicker = {
	
	-- Keep some state data
	["enabled"] = false;
	["callback"] = nil;
	["track_mouse"] = nil;
	["hue"] = 0;
	["saturation"] = 1;
	["value"] = 1;

	-- Keep the current GUI here
	["GUI"] = nil;

	-- Keep temporary, disposable connections here
	["Connections"] = {};

	-- Provide an interface to the functions
	["start"] = function ( self, callback, start_color )

		-- Replace any existing color pickers
		if self.enabled then
			self:cancel();
		end;
		self.enabled = true;

		-- Create the GUI
		self.GUI = Tool.Interfaces.BTHSVColorPicker:Clone();
		self.GUI.Parent = UI;

		-- Register the callback function for when we're done here
		self.callback = callback;

		-- Update the GUI
		local start_color = start_color or Color3.new( 1, 0, 0 );
		self:_changeColor(Support.RGBToHSV(start_color.r, start_color.g, start_color.b));

		-- Add functionality to the GUI's interactive elements
		table.insert( self.Connections, self.GUI.HueSaturation.MouseButton1Down:connect( function ( x, y )
			self.track_mouse = 'hue-saturation';
			self:_onMouseMove( x, y );
		end ) );

		table.insert( self.Connections, self.GUI.HueSaturation.MouseButton1Up:connect( function ()
			self.track_mouse = nil;
		end ) );

		table.insert( self.Connections, self.GUI.MouseMoved:connect( function ( x, y )
			self:_onMouseMove( x, y );
		end ) );

		table.insert( self.Connections, self.GUI.Value.MouseButton1Down:connect( function ( x, y )
			self.track_mouse = 'value';
			self:_onMouseMove( x, y );
		end ) );

		table.insert( self.Connections, self.GUI.Value.MouseButton1Up:connect( function ()
			self.track_mouse = nil;
		end ) );

		table.insert( self.Connections, self.GUI.OkButton.MouseButton1Up:connect( function ()
			self:finish();
		end ) );

		table.insert( self.Connections, self.GUI.CancelButton.MouseButton1Up:connect( function ()
			self:cancel();
		end ) );

		table.insert( self.Connections, self.GUI.HueOption.Input.TextButton.MouseButton1Down:connect( function ()
			self.GUI.HueOption.Input.TextBox:CaptureFocus();
		end ) );
		table.insert( self.Connections, self.GUI.HueOption.Input.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( self.GUI.HueOption.Input.TextBox.Text );
			if potential_new then
				if potential_new > 360 then
					potential_new = 360;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:_changeColor( potential_new, self.saturation, self.value );
			else
				self:_updateGUI();
			end;
		end ) );

		table.insert( self.Connections, self.GUI.SaturationOption.Input.TextButton.MouseButton1Down:connect( function ()
			self.GUI.SaturationOption.Input.TextBox:CaptureFocus();
		end ) );
		table.insert( self.Connections, self.GUI.SaturationOption.Input.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( ( self.GUI.SaturationOption.Input.TextBox.Text:gsub( '%%', '' ) ) );
			if potential_new then
				if potential_new > 100 then
					potential_new = 100;
				elseif potential_new < 0 then
					potential_new = 0;
				end;
				self:_changeColor( self.hue, potential_new / 100, self.value );
			else
				self:_updateGUI();
			end;
		end ) );

		table.insert( self.Connections, self.GUI.ValueOption.Input.TextButton.MouseButton1Down:connect( function ()
			self.GUI.ValueOption.Input.TextBox:CaptureFocus();
		end ) );
		table.insert( self.Connections, self.GUI.ValueOption.Input.TextBox.FocusLost:connect( function ( enter_pressed )
			local potential_new = tonumber( ( self.GUI.ValueOption.Input.TextBox.Text:gsub( '%%', '' ) ) );
			if potential_new then
				if potential_new < 0 then
					potential_new = 0;
				elseif potential_new > 100 then
					potential_new = 100;
				end;
				self:_changeColor( self.hue, self.saturation, potential_new / 100 );
			else
				self:_updateGUI();
			end;
		end ) );

	end;

	["_onMouseMove"] = function ( self, x, y )
		if not self.track_mouse then
			return;
		end;

		if self.track_mouse == 'hue-saturation' then
			-- Calculate the mouse position relative to the graph
			local graph_x, graph_y = x - self.GUI.HueSaturation.AbsolutePosition.x, y - self.GUI.HueSaturation.AbsolutePosition.y;

			-- Make sure we're not going out of bounds
			if graph_x < 0 then
				graph_x = 0;
			elseif graph_x > self.GUI.HueSaturation.AbsoluteSize.x then
				graph_x = self.GUI.HueSaturation.AbsoluteSize.x;
			end;
			if graph_y < 0 then
				graph_y = 0;
			elseif graph_y > self.GUI.HueSaturation.AbsoluteSize.y then
				graph_y = self.GUI.HueSaturation.AbsoluteSize.y;
			end;

			-- Calculate the new color and change it
			self:_changeColor( 359 * graph_x / 209, 1 - graph_y / 200, self.value );

		elseif self.track_mouse == 'value' then
			-- Calculate the mouse position relative to the value bar
			local bar_y = y - self.GUI.Value.AbsolutePosition.y;

			-- Make sure we're not going out of bounds
			if bar_y < 0 then
				bar_y = 0;
			elseif bar_y > self.GUI.Value.AbsoluteSize.y then
				bar_y = self.GUI.Value.AbsoluteSize.y;
			end;

			-- Calculate the new color and change it
			self:_changeColor( self.hue, self.saturation, 1 - bar_y / 200 );
		end;
	end;

	["_changeColor"] = function ( self, hue, saturation, value )
		if hue ~= hue then
			hue = 359;
		end;
		self.hue = hue;
		self.saturation = saturation == 0 and 0.01 or saturation;
		self.value = value;
		self:_updateGUI();
	end;

	["_updateGUI"] = function ( self )

		self.GUI.HueSaturation.Cursor.Position = UDim2.new( 0, 209 * self.hue / 360 - 8, 0, ( 1 - self.saturation ) * 200 - 8 );
		self.GUI.Value.Cursor.Position = UDim2.new( 0, -2, 0, ( 1 - self.value ) * 200 - 8 );

		local color = Color3.new(Support.HSVToRGB(self.hue, self.saturation, self.value));
		self.GUI.ColorDisplay.BackgroundColor3 = color;
		self.GUI.Value.ColorBG.BackgroundColor3 = Color3.new(Support.HSVToRGB(self.hue, self.saturation, 1));

		self.GUI.HueOption.Bar.BackgroundColor3 = color;
		self.GUI.SaturationOption.Bar.BackgroundColor3 = color;
		self.GUI.ValueOption.Bar.BackgroundColor3 = color;

		self.GUI.HueOption.Input.TextBox.Text = math.floor( self.hue );
		self.GUI.SaturationOption.Input.TextBox.Text = math.floor( self.saturation * 100 ) .. "%";
		self.GUI.ValueOption.Input.TextBox.Text = math.floor( self.value * 100 ) .. "%";

	end;

	["finish"] = function ( self )

		if not self.enabled then
			return;
		end;

		-- Remove the GUI
		if self.GUI then
			self.GUI:Destroy();
		end;
		self.GUI = nil;
		self.track_mouse = nil;

		-- Disconnect all temporary connections
		for connection_index, connection in pairs( self.Connections ) do
			connection:disconnect();
			self.Connections[connection_index] = nil;
		end;

		-- Call the callback function that was provided to us
		self.callback( self.hue, self.saturation, self.value );
		self.callback = nil;

		self.enabled = false;

	end;

	["cancel"] = function ( self )

		if not self.enabled then
			return;
		end;

		-- Remove the GUI
		if self.GUI then
			self.GUI:Destroy();
		end;
		self.GUI = nil;
		self.track_mouse = nil;

		-- Disconnect all temporary connections
		for connection_index, connection in pairs( self.Connections ) do
			connection:disconnect();
			self.Connections[connection_index] = nil;
		end;

		-- Call the callback function that was provided to us
		self.callback();
		self.callback = nil;

		self.enabled = false;

	end;

};

------------------------------------------
-- Provide an interface to the
-- import/export system
------------------------------------------
IE = {

	["export"] = function ()

		-- Make sure there's actually items to export
		if #Selection.Items == 0 then
			return;
		end;

		-- Create the export dialog
		local Dialog = Tool.Interfaces.BTExportDialog:Clone();
		Dialog.Loading.Size = UDim2.new( 1, 0, 0, 0 );
		Dialog.Parent = UI;
		Dialog.Loading:TweenSize( UDim2.new( 1, 0, 0, 80 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25 );
		Dialog.Loading.CloseButton.MouseButton1Up:connect( function ()
			Dialog:Destroy();
		end );

		-- Send the export request
		local RequestSuccess, RequestError, ParseSuccess, ParsedData = Tool.ExportInterface.Export:InvokeServer(Selection.Items);

		-- Handle known errors for which we have a suggestion
		if not RequestSuccess and (RequestError == 'Http requests are not enabled' or RequestError == 'Http requests can only be executed by game server') then

			-- Communicate failure
			Dialog.Loading.TextLabel.Text = 'Upload failed, see message(s)';
			Dialog.Loading.CloseButton.Text = 'Okay!';

			-- Show any warnings that might help the user understand
			StartupNotificationsShown = false;
			ShowStartupNotifications();

		-- Handle unknown errors
		elseif not RequestSuccess then

			-- Just tell them there was an unknown error
			Dialog.Loading.TextLabel.Text = 'Upload failed (unknown request error)';
			Dialog.Loading.CloseButton.Text = 'Okay :(';

			-- Show any warnings that might help the user figure it out
			-- (e.g. outdated version notification)
			StartupNotificationsShown = false;
			ShowStartupNotifications();

		-- Handle successful requests without proper responses
		elseif RequestSuccess and (not ParseSuccess or not ParsedData.success) then

			-- Just tell them there was an unknown error
			Dialog.Loading.TextLabel.Text = 'Upload failed (unknown processing error)';
			Dialog.Loading.CloseButton.Text = 'Okay :(';

			-- Show any warnings that might help the user figure it out
			-- (e.g. outdated version notification)
			StartupNotificationsShown = false;
			ShowStartupNotifications();

		-- Handle completely successful requests
		elseif RequestSuccess and ParseSuccess then

			print( "[Building Tools by F3X] Uploaded Export: " .. ParsedData.id );

			-- Display the successful export GUI with the creation ID
			Dialog.Loading.Visible = false;
			Dialog.Info.Size = UDim2.new( 1, 0, 0, 0 );
			Dialog.Info.CreationID.Text = ParsedData.id;
			Dialog.Info.Visible = true;
			Dialog.Info:TweenSize( UDim2.new( 1, 0, 0, 75 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25 );
			Dialog.Tip.Size = UDim2.new( 1, 0, 0, 0 );
			Dialog.Tip.Visible = true;
			Dialog.Tip:TweenSize( UDim2.new( 1, 0, 0, 30 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25 );
			Dialog.Close.Size = UDim2.new( 1, 0, 0, 0 );
			Dialog.Close.Visible = true;
			Dialog.Close:TweenSize( UDim2.new( 1, 0, 0, 20 ), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25 );
			Dialog.Close.Button.MouseButton1Up:connect( function ()
				Dialog:Destroy();
			end );

			-- Play a confirmation sound
			local Sound = RbxUtility.Create "Sound" {
				Name = "BTActionCompletionSound";
				Pitch = 1.5;
				SoundId = Assets.ActionCompletionSound;
				Volume = 1;
				Parent = Player or SoundService;
			};
			Sound:Play();
			Sound:Destroy();

		end;

	end;

};


------------------------------------------
-- Prepare the dock UI
------------------------------------------

Tooltips = {};

-- Create the main GUI
Dock = Tool.Interfaces.BTDockGUI:Clone();
Dock.Parent = UI;
Dock.Visible = false;

-- Add functionality to each tool button
function RegisterToolButton( ToolButton )
	-- Provides functionality to `ToolButton`

	-- Get the tool name and the tool
	local tool_name = ToolButton.Name:match( "(.+)Button" );

	if tool_name then

		-- Create the click connection
		ToolButton.MouseButton1Up:connect( function ()
			local Tool = Tools[tool_name];
			if Tool then
				equipTool( Tool );
			end;
		end );

		ToolButton.MouseEnter:connect( function ()
			local Tooltip = Tooltips[tool_name];
			if Tooltip then
				Tooltip:focus( 'button' );
			end;
		end );

		ToolButton.MouseLeave:connect( function ()
			local Tooltip = Tooltips[tool_name];
			if Tooltip then
				Tooltip:unfocus( 'button' );
			end;
		end );

	end;
end;
for _, ToolButton in pairs( Dock.ToolButtons:GetChildren() ) do
	RegisterToolButton( ToolButton );
end;

-- Prepare the tooltips
function RegisterTooltip( Tooltip )
	local tool_name = Tooltip.Name:match( "(.+)Info" );

	Tooltips[tool_name] = {

		GUI = Tooltip;

		button_focus = false;
		tooltip_focus = false;

		focus = function ( self, source )
			if Dock.HelpInfo.Visible then
				return;
			end;
			if source == 'button' then
				self.button_focus = true;
			elseif source == 'tooltip' then
				self.tooltip_focus = true;
			end;
			for _, Tooltip in pairs( Dock.Tooltips:GetChildren() ) do
				Tooltip.Visible = false;
			end;
			self.GUI.Visible = true;
		end;

		unfocus = function ( self, source )
			if source == 'button' then
				self.button_focus = false;
			elseif source == 'tooltip' then
				self.tooltip_focus = false;
			end;
			if not self.button_focus and not self.tooltip_focus then
				self.GUI.Visible = false;
			end;
		end;

	};

	-- Make it disappear after it's out of mouse focus
	Tooltip.MouseEnter:connect( function ()
		Tooltips[tool_name]:focus( 'tooltip' );
	end );
	Tooltip.MouseLeave:connect( function ()
		Tooltips[tool_name]:unfocus( 'tooltip' );
	end );

	-- Create the scrolling container
	local ScrollingContainer = Gloo.ScrollingContainer( true, false, 15 );
	ScrollingContainer.GUI.Parent = Tooltip;

	-- Put the tooltip content in the container
	for _, Child in pairs( Tooltip.Content:GetChildren() ) do
		Child.Parent = ScrollingContainer.Container;
	end;
	ScrollingContainer.GUI.Size = Dock.Tooltips.Size;
	ScrollingContainer.Container.Size = Tooltip.Content.Size;
	ScrollingContainer.Boundary.Size = Dock.Tooltips.Size;
	ScrollingContainer.Boundary.BackgroundTransparency = 1;
	Tooltip.Content:Destroy();

end;
for _, Tooltip in pairs( Dock.Tooltips:GetChildren() ) do
	RegisterTooltip( Tooltip );
end;

-- Create the scrolling container for the help tooltip
local ScrollingContainer = Gloo.ScrollingContainer( true, false, 15 );
ScrollingContainer.GUI.Parent = Dock.HelpInfo;

-- Put the help tooltip content in the container
for _, Child in pairs( Dock.HelpInfo.Content:GetChildren() ) do
	Child.Parent = ScrollingContainer.Container;
end;
ScrollingContainer.GUI.Size = Dock.HelpInfo.Size;
ScrollingContainer.Container.Size = Dock.HelpInfo.Content.Size;
ScrollingContainer.Boundary.Size = Dock.HelpInfo.Size;
ScrollingContainer.Boundary.BackgroundTransparency = 1;
Dock.HelpInfo.Content:Destroy();

-- Add functionality to the other GUI buttons
Dock.SelectionButtons.UndoButton.MouseButton1Up:connect( function ()
	History:Undo();
end );
Dock.SelectionButtons.RedoButton.MouseButton1Up:connect( function ()
	History:Redo();
end );
Dock.SelectionButtons.DeleteButton.MouseButton1Up:connect( function ()
	deleteSelection();
end );
Dock.SelectionButtons.CloneButton.MouseButton1Up:connect( function ()
	cloneSelection();
end );
Dock.SelectionButtons.ExportButton.MouseButton1Up:connect( function ()
	IE:export();
end );
Dock.SelectionButtons.GroupsButton.MouseButton1Up:connect( function ()
	Groups:ToggleUI();
end );
Dock.InfoButtons.HelpButton.MouseButton1Up:connect( function ()
	toggleHelp();
end );

-- Shade the buttons according to whether they'll function or not
Selection.Changed:connect( function ()

	-- If there are items, they should be active
	if #Selection.Items > 0 then
		Dock.SelectionButtons.DeleteButton.Image = Assets.DeleteActiveDecal;
		Dock.SelectionButtons.CloneButton.Image = Assets.CloneActiveDecal;
		Dock.SelectionButtons.ExportButton.Image = Assets.ExportActiveDecal;

	-- If there aren't items, they shouldn't be active
	else
		Dock.SelectionButtons.DeleteButton.Image = Assets.DeleteInactiveDecal;
		Dock.SelectionButtons.CloneButton.Image = Assets.CloneInactiveDecal;
		Dock.SelectionButtons.ExportButton.Image = Assets.ExportInactiveDecal;
	end;

end );

-- Make the selection/info buttons display tooltips upon hovering over them
for _, SelectionButton in pairs( Dock.SelectionButtons:GetChildren() ) do
	SelectionButton.MouseEnter:connect( function ()
		if SelectionButton:FindFirstChild( 'Tooltip' ) then
			SelectionButton.Tooltip.Visible = true;
		end;
	end );
	SelectionButton.MouseLeave:connect( function ()
		if SelectionButton:FindFirstChild( 'Tooltip' ) then
			SelectionButton.Tooltip.Visible = false;
		end;
	end );
end;
Dock.InfoButtons.HelpButton.MouseEnter:connect( function ()
	Dock.InfoButtons.HelpButton.Tooltip.Visible = true;
end );
Dock.InfoButtons.HelpButton.MouseLeave:connect( function ()
	Dock.InfoButtons.HelpButton.Tooltip.Visible = false;
end );

History.Changed:connect( function ()

	-- If there are any records
	if #History.Data > 0 then

		-- If we're at the beginning
		if History.Index == 0 then
			Dock.SelectionButtons.UndoButton.Image = Assets.UndoInactiveDecal;
			Dock.SelectionButtons.RedoButton.Image = Assets.RedoActiveDecal;

		-- If we're at the end
		elseif History.Index == #History.Data then
			Dock.SelectionButtons.UndoButton.Image = Assets.UndoActiveDecal;
			Dock.SelectionButtons.RedoButton.Image = Assets.RedoInactiveDecal;

		-- If we're neither at the beginning or the end
		else
			Dock.SelectionButtons.UndoButton.Image = Assets.UndoActiveDecal;
			Dock.SelectionButtons.RedoButton.Image = Assets.RedoActiveDecal;
		end;

	-- If there are no records
	else
		Dock.SelectionButtons.UndoButton.Image = Assets.UndoInactiveDecal;
		Dock.SelectionButtons.RedoButton.Image = Assets.RedoInactiveDecal;
	end;

end );


------------------------------------------
-- An interface for the group system
------------------------------------------
Groups = {

	-- A container for the groups
	Data = {};

	-- Create the group manager UI
	UI = Tool.Interfaces.BTGroupsGUI:Clone();

	-- Provide an event to track new groups
	GroupAdded = Support.CreateSignal();

	NewGroup = function ( Groups )
		local Group = {
			Name		= 'Group ' .. ( #Groups.Data + 1 );
			Items		= {};
			Ignoring	= false;
			Changed		= Support.CreateSignal();
			Updated		= Support.CreateSignal();

			Rename = function ( Group, NewName )
				Group.Name = NewName;
				Group.Changed:Fire();
			end;

			SetIgnore = function ( Group, NewIgnoringStatus )
				Group.Ignoring = NewIgnoringStatus;
				Group.Changed:Fire();
			end;

			Update = function ( Group, NewItems )
				-- Set the new items
				Group.Items = Support.CloneTable(NewItems);
				Group.Updated:Fire();
			end;

			Select = function ( Group, Multiselecting )
				if not Multiselecting then
					Selection:clear();
				end;
				for _, Item in pairs( Group.Items ) do
					Selection:add( Item );
				end;
			end;
		};
		table.insert( Groups.Data, Group );
		Groups.GroupAdded:Fire( Group );
		return Group;
	end;

	ToggleUI = function ( Groups )
		Groups.UI.Visible = not Groups.UI.Visible;
	end;

	IsPartIgnored = function ( Groups, Part )
		-- Returns whether `Part` should be ignored in selection

		-- Check for any groups that ignore their parts and if `Part` is in any of them
		for _, Group in pairs( Groups.Data ) do
			if Group.Ignoring and #Support.FindTableOccurrences(Group.Items, Part) > 0 then
				return true;
			end;
		end;

		-- If no groups come up, it's not an ignored part
		return false;
	end;
};

-- Add the group manager UI to the main UI
Groups.UI.Visible = false;
Groups.UI.Parent = Dock;

-- Prepare the functionality of the group manager UI
Groups.UI.Title.CreateButton.MouseButton1Click:connect( function ()
	local Group = Groups:NewGroup();
	Group:Update( Selection.Items );
end );

Groups.GroupAdded:Connect( function ( Group )
	local GroupButton			= Groups.UI.Templates.GroupButton:Clone();
	GroupButton.Position		= UDim2.new( 0, 0, 0, 26 * #Groups.UI.GroupList:GetChildren() );
	GroupButton.Parent			= Groups.UI.GroupList;
	GroupButton.GroupName.Text	= Group.Name;
	GroupButton.GroupNamer.Text	= Group.Name;

	Groups.UI.GroupList.CanvasSize = UDim2.new( 1, -10, 0, 26 * #Groups.UI.GroupList:GetChildren() );

	-- Adjust the tooltip caption on the ignore button
	GroupButton.IgnoreButton.RightTooltip.Text.Text = Group.Ignoring and 'UNIGNORE' or 'IGNORE';

	GroupButton.GroupName.MouseButton1Click:connect( function ()
		Group:Select( ActiveKeys[47] or ActiveKeys[48] );
	end );

	Group.Changed:Connect( function ()
		GroupButton.GroupName.Text		= Group.Name;
		GroupButton.GroupNamer.Text		= Group.Name;
		GroupButton.IgnoreButton.Image	= Group.Ignoring and Assets.GroupLockIcon or Assets.GroupUnlockIcon;

		-- Change the tooltip caption on the ignore button
		GroupButton.IgnoreButton.RightTooltip.Text.Text = Group.Ignoring and 'UNIGNORE' or 'IGNORE';
	end );

	Group.Updated:connect( function ()
		GroupButton.UpdateButton.Image = Assets.GroupUpdateOKIcon;
		coroutine.wrap( function()
			wait( 1 );
			GroupButton.UpdateButton.Image = Assets.GroupUpdateIcon;
		end )();
	end );

	GroupButton.EditButton.MouseButton1Click:connect( function ()
		GroupButton.GroupName.Visible	= false;
		GroupButton.GroupNamer.Visible	= true;
		GroupButton.GroupNamer:CaptureFocus();
	end );

	GroupButton.GroupNamer.FocusLost:connect( function ( EnterPressed )
		if EnterPressed then
			Group:Rename( GroupButton.GroupNamer.Text );
		end;
		GroupButton.GroupNamer.Visible	= false;
		GroupButton.GroupNamer.Text		= Group.Name;
		GroupButton.GroupName.Visible	= true;
	end );

	-- Toggle ignoring when the ignore button is clicked
	GroupButton.IgnoreButton.MouseButton1Click:connect( function ()
		Group:SetIgnore( not Group.Ignoring );
	end );

	GroupButton.UpdateButton.MouseButton1Click:connect( function ()
		Group:Update( Selection.Items );
	end );

	-- Pop up tooltips when the buttons are hovered over
	local ButtonsWithTooltips = { GroupButton.UpdateButton, GroupButton.EditButton, GroupButton.IgnoreButton, GroupButton.GroupNameArea };
	for _, Button in pairs( ButtonsWithTooltips ) do
		local Tooltip = Button:FindFirstChild 'LeftTooltip' or Button:FindFirstChild 'RightTooltip';
		if Tooltip then
			Button.InputBegan:connect( function ( InputData )
				if InputData.UserInputType == Enum.UserInputType.MouseMovement then
					Tooltip.Visible = true;
				end;
			end );
			Button.InputEnded:connect( function ( InputData )
				if InputData.UserInputType == Enum.UserInputType.MouseMovement then
					Tooltip.Visible = false;
				end;
			end );
		end;
	end;
end );


------------------------------------------
-- Attach tool event listeners
------------------------------------------

function equipBT( CurrentMouse )

	Mouse = CurrentMouse;

	-- Enable the move tool if there's no tool currently enabled
	if not CurrentTool then
		equipTool( Tools.Move );
	end;

	if not TargetBox then
		TargetBox = Instance.new( "SelectionBox", UI );
		TargetBox.Name = "BTTargetBox";
		TargetBox.Color = BrickColor.new( "Institutional white" );
		TargetBox.Transparency = 0.5;
	end;

	-- Enable any temporarily-disabled selection boxes
	for _, SelectionBox in pairs( SelectionBoxes ) do
		SelectionBox.Parent = UI;
	end;

	-- Update the internal selection if this is a plugin
	if ToolType == 'plugin' then
		for _, Item in pairs( SelectionService:Get() ) do
			Selection:add( Item );
		end;
	end;

	-- Call the `Equipped` listener of the current tool
	if CurrentTool and CurrentTool.Listeners.Equipped then
		CurrentTool.Listeners.Equipped();
	end;

	-- Show the dock
	Dock.Visible = true;

	-- Display any startup notifications
	coroutine.wrap( ShowStartupNotifications )();

	table.insert( Connections, Mouse.KeyDown:connect( function ( key )

		local key = key:lower();
		local key_code = key:byte();

		-- Provide the abiltiy to delete via the shift + X key combination
		if ActiveKeys[47] or ActiveKeys[48] and key == "x" then
			deleteSelection();
			return;
		end;

		-- Provide the ability to clone via the shift + C key combination
		if ActiveKeys[47] or ActiveKeys[48] and key == "c" then
			cloneSelection();
			return;
		end;

		-- Undo if shift+z is pressed
		if key == "z" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			History:Undo();
			return;

		-- Redo if shift+y is pressed
		elseif key == "y" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			History:Redo();
			return;
		end;

		-- Serialize and dump selection to logs if shift+p is pressed
		if key == "p" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			IE:export();
			return;
		end;

		-- Perform a prism selection if shift + k is pressed
		if key == "k" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			prismSelect();
			return;
		end;

		-- Clear the selection if shift + r is pressed
		if key == "r" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			Selection:clear();
			return;
		end;

		-- Show the groups GUI when shift + g is pressed
		if key == "g" and ( ActiveKeys[47] or ActiveKeys[48] ) then
			Groups:ToggleUI();
			return;
		end;

		-- Select all parts within the parent of the focused part
		-- when [ is pressed
		if key == "[" then

			-- Make sure we have a part that's focused
			local FocusedPart = Selection.Last;
			if not FocusedPart then
				return;
			end;

			-- Make sure the part isn't a child of Workspace,
			-- since that would cause us to select everything
			if FocusedPart.Parent == Workspace then
				return;
			end;

			-- Clear the selection (or not), depending on whether
			-- it's part of a multiselection
			if not (ActiveKeys[47] or ActiveKeys[48]) then
				Selection:clear();
			end;

			-- Select all the parts within the parent of the focused part
			local SearchField = Support.GetAllDescendants(FocusedPart.Parent);
			for _, Item in pairs(SearchField) do
				Selection:add(Item);
			end;

			-- Select the part itself
			Selection:add(FocusedPart);

			return;
		end;

		if key == "z" then
			equipTool( Tools.Move );

		elseif key == "x" then
			equipTool( Tools.Resize );

		elseif key == "c" then
			equipTool( Tools.Rotate );

		elseif key == "v" then
			equipTool( Tools.Paint );

		elseif key == "b" then
			equipTool( Tools.Surface );

		elseif key == "n" then
			equipTool( Tools.Material );

		elseif key == "m" then
			equipTool( Tools.Anchor );

		elseif key == "k" then
			equipTool( Tools.Collision );

		elseif key == "j" then
			equipTool( Tools.NewPart );

		elseif key == "h" then
			equipTool( Tools.Mesh );

		elseif key == "g" then
			equipTool( Tools.Texture );

		elseif key == "f" then
			equipTool( Tools.Weld );

		elseif key == "u" then
			equipTool( Tools.Lighting );

		elseif key == "p" then
			equipTool( Tools.Decorate );

		end;

		ActiveKeys[key_code] = key_code;
		ActiveKeys[key] = key;

		-- If it's now in multiselection mode, update `selecting`
		-- (these are the left/right ctrl & shift keys)
		if ActiveKeys[47] or ActiveKeys[48] or ActiveKeys[49] or ActiveKeys[50] then
			selecting = ActiveKeys[47] or ActiveKeys[48] or ActiveKeys[49] or ActiveKeys[50];
		end;

	end ) );

	table.insert( Connections, Mouse.KeyUp:connect( function ( key )

		local key = key:lower();
		local key_code = key:byte();

		ActiveKeys[key_code] = nil;
		ActiveKeys[key] = nil;

		-- If it's no longer in multiselection mode, update `selecting` & related values
		if selecting and not ActiveKeys[selecting] then
			selecting = false;
			if Select2D.enabled then
				Select2D:select();
				Select2D:finish();
			end;
		end;

		-- Fire tool listeners
		if CurrentTool and CurrentTool.Listeners.KeyUp then
			CurrentTool.Listeners.KeyUp( key );
		end;

	end ) );

	table.insert( Connections, UserInputService.InputEnded:connect( function ( InputData )

		if InputData.UserInputType == Enum.UserInputType.MouseButton1 then
			clicking = false;

			-- Finish any ongoing 2D selection wherever the left mouse button is released
			if Select2D.enabled then
				Select2D:select();
				Select2D:finish();
			end;
		end;

	end ) );

	table.insert( Connections, Mouse.Button1Down:connect( function ()

		clicking = true;
		click_x, click_y = Mouse.X, Mouse.Y;

		-- If multiselection is, just add to the selection
		if selecting then
			return;
		end;

		-- Fire tool listeners
		if CurrentTool and CurrentTool.Listeners.Button1Down then
			CurrentTool.Listeners.Button1Down();
		end;

	end ) );

	table.insert( Connections, Mouse.Move:connect( function ()

		-- Ignore target box updating if selection is temporarily disabled
		if not override_selection then

			-- If the mouse has moved since it was clicked, start 2D selection mode
			if not Select2D.enabled and clicking and selecting and ( click_x ~= Mouse.X or click_y ~= Mouse.Y ) then
				Select2D:start();
			end;

			-- If the target has changed, update the targetbox appropriately
			if TargetBox.Adornee ~= Mouse.Target then
				TargetBox.Adornee = Mouse.Target;

				-- When the part is selectable, show the targetbox
				if isSelectable(Mouse.Target) then
					TargetBox.Transparency = 0.5;

				-- When aiming at something invalid, hide the targetbox
				else
					TargetBox.Transparency = 1;
				end;
			end;

		end;

		-- Fire tool listeners
		if CurrentTool and CurrentTool.Listeners.Move then
			CurrentTool.Listeners.Move();
		end;

		if override_selection then
			override_selection = false;
		end;

	end ) );

	table.insert( Connections, Mouse.Button1Up:connect( function ()

		clicking = false;

		-- Make sure the person didn't accidentally miss a handle or something
		if not Select2D.enabled and ( Mouse.X ~= click_x or Mouse.Y ~= click_y ) then
			override_selection = true;
		end;

		-- If the target when clicking was invalid then clear the selection (unless we're multi-selecting)
		if not override_selection and not selecting and not isSelectable( Mouse.Target ) then
			Selection:clear();
		end;

		-- If multi-selecting, add to/remove from the selection
		if not override_selection and selecting then

			-- If the item isn't already selected, add it to the selection
			if not Selection:find( Mouse.Target ) then
				if isSelectable( Mouse.Target ) then
					Selection:add( Mouse.Target );
				end;

			-- If the item _is_ already selected, remove it from the selection
			else
				if ( Mouse.X == click_x and Mouse.Y == click_y ) and Selection:find( Mouse.Target ) then
					Selection:remove( Mouse.Target );
				end;
			end;

		-- If not multi-selecting, replace the selection
		else
			if not override_selection and isSelectable( Mouse.Target ) then
				Selection:clear();
				Selection:add( Mouse.Target );
			end;
		end;

		-- Fire tool listeners
		if CurrentTool and CurrentTool.Listeners.Button1Up then
			CurrentTool.Listeners.Button1Up();
		end;

		if override_selection then
			override_selection = false;
		end;

	end ) );

	table.insert( Connections, Mouse.Button2Down:connect( function ()
		-- Fire tool listeners
		if CurrentTool and CurrentTool.Listeners.Button2Down then
			CurrentTool.Listeners.Button2Down();
		end;
	end ) );

	table.insert( Connections, Mouse.Button2Up:connect( function ()
		-- Fire tool listeners
		if CurrentTool and CurrentTool.Listeners.Button2Up then
			CurrentTool.Listeners.Button2Up();
		end;
	end ) );

end;

function unequipBT()

	Mouse = nil;

	-- Remove the mouse target SelectionBox from `Player`
	if TargetBox then
		TargetBox:Destroy();
		TargetBox = nil;
	end;

	-- Disable all the selection boxes temporarily
	for _, SelectionBox in pairs( SelectionBoxes ) do
		SelectionBox.Parent = nil;
	end;

	-- Hide the dock
	Dock.Visible = false;

	-- Disconnect temporary platform-related connections
	for connection_index, Connection in pairs( Connections ) do
		Connection:disconnect();
		Connections[connection_index] = nil;
	end;

	-- Call the `Unequipped` listener of the current tool
	if CurrentTool and CurrentTool.Listeners.Unequipped then
		CurrentTool.Listeners.Unequipped();
	end;

end;


------------------------------------------
-- Provide the platform's environment for
-- other tool scripts to extend upon
------------------------------------------

local tool_list = {
	"Anchor",
	"Collision",
	"Material",
	"Mesh",
	"Move",
	"NewPart",
	"Paint",
	"Resize",
	"Rotate",
	"Surface",
	"Texture",
	"Weld",
	"Lighting",
	"Decorate"
};

-- Make sure all the tool scripts are in the tool & deactivate them
for _, tool_name in pairs( tool_list ) do
	local script_name = "BT" .. tool_name .. "Tool";
	repeat wait() until script:FindFirstChild( script_name );
	script[script_name].Disabled = true;
end;

-- Load the platform
if not _G.BTCoreEnv then
	_G.BTCoreEnv = {};
end;
_G.BTCoreEnv[Tool] = getfenv( 0 );
CoreReady = true;

-- Reload the tool scripts
for _, tool_name in pairs( tool_list ) do
	local script_name = "BT" .. tool_name .. "Tool";
	script[script_name].Disabled = false;
end;

-- Wait for all the tools to load
for _, tool_name in pairs( tool_list ) do
	if not Tools[tool_name] then
		repeat wait() until Tools[tool_name];
	end;
	repeat wait() until Tools[tool_name].Loaded;
end;

-- Activate the plugin and tool connections
if ToolType == 'plugin' then
	local plugin_active = false;
	ToolbarButton.Click:connect( function ()
		if plugin_active then
			plugin_active = false;
			unequipBT();
		else
			plugin_active = true;
			plugin:Activate( true );
			equipBT( plugin:GetMouse() );
		end;
	end );
	plugin.Deactivation:connect( unequipBT );

elseif ToolType == 'tool' then
	Tool.Equipped:connect( equipBT );
	Tool.Unequipped:connect( unequipBT );
end;


-- Provide a remote function allowing server-side code to
-- make the tool select the parts in a given model
(Tool:WaitForChild 'SelectModel').OnClientInvoke = function (Model)

	-- Clear the existing selection
	Selection:clear();

	-- Select all the parts within `Model` (filtered by Selection:add)
	local Descendants = Support.GetAllDescendants(Model);
	for _, Descendant in pairs(Descendants) do
		Selection:add(Descendant);
	end;

end;
