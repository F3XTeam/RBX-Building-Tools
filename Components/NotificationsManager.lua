local View = script.Parent;
while not _G.GetLibraries do wait() end;

-- Load libraries
local Support, Cheer = _G.GetLibraries(
	'F3X/SupportLibrary@^1.0.0',
	'F3X/Cheer@^0.0.0'
);

-- Create component
local Component = Cheer.CreateComponent('BTNotificationsManager', View);

function Component.Start(Core)

	-- Display update notification if tool is outdated
	if Core.IsVersionOutdated() then
		if Core.Mode == 'Plugin' then
			Cheer(View.PluginUpdateNotification).Start(Component.AdjustLayout);
		elseif Core.Mode == 'Tool' then
			Cheer(View.ToolUpdateNotification).Start(Component.AdjustLayout);
		end;
	end;

	-- Display HttpEnabled warning if HttpService is disabled
	if not Core.SyncAPI:Invoke('IsHttpServiceEnabled') then
		Cheer(View.HttpDisabledWarning).Start(Component.AdjustLayout);
	end;

	-- Adjust layout
	View.UIListLayout:ApplyLayout();

	-- Animate opening
	View.Position = UDim2.new(0.5, 0, 1.5, 0);
	View.Visible = true;
	View:TweenPosition(UDim2.new(0.5, 0, 0.5, 0), nil, nil, 0.2);

	-- Destroy notifications container on tool unequip
	coroutine.wrap(function ()
		Core.Disabling:Wait();
		View:Destroy();
	end)()

	-- Return component for chaining
	return Component;

end;

function Component.AdjustLayout()
	View.UIListLayout:ApplyLayout();
end;

return Component;