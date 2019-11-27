local NamePattern = '([A-Za-z0-9_-]+)/([A-Za-z0-9_-]+)';
local VersionPattern = '[A-Za-z0-9_-]+/[A-Za-z0-9_-]+@([%^~]?)([0-9]+)%.([0-9]+)%.([0-9]+)';

-- Initialize cached library list
_G.BTLibraryList = _G.BTLibraryList or {};
local LibraryList = _G.BTLibraryList;

function GetLibrary(LibraryID)
	-- Returns the requested library

	-- Parse library ID
	local Creator, Name = LibraryID:match(NamePattern);
	local VersionRange, Major, Minor, Patch = LibraryID:match(VersionPattern);

	-- Convert version data to numbers
	local Major, Minor, Patch = tonumber(Major), tonumber(Minor), tonumber(Patch);

	-- Validate version information
	assert(VersionRange and (Major and Minor and Patch), 'Invalid version');

	-- Ensure library ID was given
	if not (Creator and Name) then
		return;
	end;

	-- If no version provided, return latest
	if not VersionRange then
		for _, Library in ipairs(LibraryList) do
			if (Library.Creator:lower() == Creator:lower()) and
			   (Library.Name:lower() == Name:lower()) then
				return Library.Library;
			end;
		end;

	-- If exact version provided, return that version
	elseif VersionRange == '' then
		for _, Library in ipairs(LibraryList) do
			if (Library.Creator:lower() == Creator:lower()) and
			   (Library.Name:lower() == Name:lower()) and
			   (Library.Version.Major == Major) and
			   (Library.Version.Minor == Minor) and
			   (Library.Version.Patch == Patch) then
				return Library.Library;
			end;
		end;

	-- If minor version specified, return latest compatible patch version
	elseif VersionRange == '~' then
		for _, Library in ipairs(LibraryList) do
			if (Library.Creator:lower() == Creator:lower()) and
			   (Library.Name:lower() == Name:lower()) and
			   (Library.Version.Major == Major) and
			   (Library.Version.Minor == Minor) then
				return Library.Library;
			end;
		end;

	-- If major version specified, return latest compatible minor or patch version
	elseif VersionRange == '^' then
		for _, Library in ipairs(LibraryList) do
			if (Library.Creator:lower() == Creator:lower()) and
			   (Library.Name:lower() == Name:lower()) and
			   (Library.Version.Major == Major) then
				return Library.Library;
			end;
		end;
	end;

end;

function GetLibraries(...)
	-- Returns the requested libraries by their IDs

	local RequestedLibraries = { ... };
	local FoundLibraries = {};

	-- Get each library
	for Index, LibraryID in ipairs(RequestedLibraries) do
		FoundLibraries[Index] = GetLibrary(LibraryID);
	end;

	-- Return the found libraries
	return unpack(FoundLibraries, 1, table.maxn(FoundLibraries));

end;

function RegisterLibrary(Metadata, Library)
	-- Registers the given library with its metadata into the cache list

	-- Validate metadata
	assert(type(Metadata.Name) == 'string', 'Library name must be a string');
	assert(type(Metadata.Creator) == 'string', 'Library creator must be a string');
	assert(Metadata.Name:match('^[A-Za-z0-9_-]+$'), 'Library name contains invalid characters');
	assert(Metadata.Creator:match('^[A-Za-z0-9_-]+$'), 'Library creator contains invalid characters');
	assert(type(Metadata.Version) == 'table', 'Invalid library version data');
	assert(type(Metadata.Version.Major) == 'number', 'Invalid library version data');
	assert(type(Metadata.Version.Minor) == 'number', 'Invalid library version data');
	assert(type(Metadata.Version.Patch) == 'number', 'Invalid library version data');

	-- Structure metadata
	local Metadata = {
		Name = Metadata.Name,
		Creator = Metadata.Creator,
		Version = {
			Major = Metadata.Version.Major,
			Minor = Metadata.Version.Minor,
			Patch = Metadata.Version.Patch
		},
		Library = Library
	};

	-- Insert the library and its metadata into the list
	table.insert(LibraryList, Metadata);

	-- Sort the list by version (from latest to earliest)
	table.sort(LibraryList, function (A, B)

		-- Sort by major version
		if A.Version.Major > B.Version.Major then
			return true;

		-- Sort by minor version when major version is same
		elseif A.Version.Major == B.Version.Major then
			if A.Version.Minor > B.Version.Minor then
				return true;

			-- Sort by patch version when same major and minor version
			elseif A.Version.Minor == B.Version.Minor then
				return A.Version.Patch > B.Version.Patch;
			else
				return false;
			end;

		-- Sort A after B if earlier version
		else
			return false;
		end;
	end);

end;

-- Load tool completely before loading cached libraries
local Tool = script.Parent;
local Indicator = Tool:WaitForChild 'Loaded';
while not Indicator.Value do
	Indicator.Changed:Wait();
end;

-- Populate library list with cached libraries
for _, Library in pairs(script:GetChildren()) do
	pcall(function () RegisterLibrary(require(Library.Metadata), require(Library)) end);
end;

-- Expose GetLibraries function
_G.GetLibraries = GetLibraries;
return GetLibraries