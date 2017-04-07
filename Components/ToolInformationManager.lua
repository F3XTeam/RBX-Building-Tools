local View = script.Parent;
while not _G.GetLibraries do wait() end;

-- Load libraries
local Support, Cheer = _G.GetLibraries(
	'F3X/SupportLibrary@^1.0.0',
	'F3X/Cheer@^0.0.0'
);

-- Import services
Support.ImportServices();

-- Create component
local Component = Cheer.CreateComponent('BTToolInformationManager', View);

function Component.Start(Core)

	-- Save reference to core API
	getfenv(1).Core = Core;

	-- Return component for chaining
	return Component;

end;

function Component.RegisterSection(SectionName)
	-- Registers triggers for the given section

	-- Get section
	local Section = Component.GetSection(SectionName);

	-- Reset fade timer on hover
	Cheer.Bind(Section.MouseEnter, function ()
		if Component.CurrentSection == Section then
			Component.CurrentFadeTimer = false;
		end;
	end);

	-- Start fade time on unhover
	Cheer.Bind(Section.MouseLeave, function ()
		Component.StartFadeTimer(true);
	end);

end;

function Component.StartFadeTimer(Override)
	-- Creates timer to disappear current section after 2 seconds unless overridden

	if Component.CurrentFadeTimer == false and not Override then
		return;
	end;

	-- Generate unique trigger ID
	local TriggerId = HttpService:GenerateGUID();

	-- Register timer
	Component.CurrentFadeTimer = TriggerId;

	-- Start timer
	Delay(2, function ()
		if Component.CurrentFadeTimer == TriggerId then
			Component.HideCurrentSection();
		end;
	end);

end;

function Component.ProcessHover(Tool, SectionName)

	-- Only override current section if also triggered by hover
	if Component.LastTrigger == 'Click' then
		return;
	end;

	-- Hide any current section
	Component.HideCurrentSection();

	-- Get section
	local Section = Component.GetSection(SectionName);

	-- Set new current section
	Component.CurrentSection = Section;
	Component.LastTrigger = 'Hover';

	-- Show the new section
	Section.Visible = true;

end;

function Component.ProcessUnhover(Tool, SectionName)

	-- Only override current section if triggered by a hover
	if Component.LastTrigger == 'Click' then
		return;
	end;

	-- Get section
	local Section = Component.GetSection(SectionName);

	-- Disappear after 2 seconds unless overridden
	if Component.CurrentSection == Section then
		Component.StartFadeTimer();
	end;

end;

function Component.ProcessClick(Tool, SectionName)

	-- Hide any current section
	Component.HideCurrentSection();

	-- Get section
	local Section = Component.GetSection(SectionName);

	-- Set new current section
	Component.CurrentSection = Section;
	Component.LastTrigger = 'Click';

	-- Show the new section
	Section.Visible = true;

	-- Disappear after 2 seconds unless overridden
	Component.StartFadeTimer();

end;

function Component.HideCurrentSection()

	-- Ensure there is a current section
	if not Component.CurrentSection then
		return;
	end;

	-- Hide section
	Component.CurrentSection.Visible = false;

	-- Disable section fade timer if any
	Component.CurrentFadeTimer = nil;

	-- Unregister current section
	Component.CurrentSection = nil;
	Component.LastTrigger = nil;

end;

function Component.GetSection(SectionName)

	-- Return the information section with the given name
	return View:FindFirstChild(SectionName);

end;

return Component;