-- Standard RoStrap Debugging Functions
-- @documentation https://rostrap.github.io/Libraries/Debug/
-- @rostrap Debug
-- @author Validark

local Debug = {}

function Debug.DirectoryToString(Object)
	--- Gets the string of the directory of an object, properly formatted
	-- string DirectoryToString(Object)
	-- @returns Objects location in proper Lua format
	-- @author Validark
	-- Corrects the built-in GetFullName function so that it returns properly formatted text.
	return (
		Object
			:GetFullName()
			:gsub("%.(%w*%s%w*)", "%[\"%1\"%]")
			:gsub("%.(%d+[%w%s]+)", "%[\"%1\"%]")
			:gsub("%.(%d+)", "%[%1%]")
		)
end

function Debug.Stringify(Data)
	-- Turns data into "TYPE_NAME NAME"
	local DataType = typeof(Data)
	local DataString

	if DataType == "Instance" then
		DataType = Data.ClassName
		DataString = Debug.DirectoryToString(Data)
	else
		DataString = tostring(Data)
	end
		
	return DataType == DataString and DataString or DataType .. " " .. DataString
end

local GetErrorData do
	-- Standard RoStrap Erroring system
	-- Prefixing errors with '!' makes Error expect the [error origin].Name as first parameter after Error string
	-- Past the initial Error string, subsequent arguments get unpacked in a string.format of the error string
	-- Arguments formmatted into the string get stringified (see above function)
	-- Assert falls back on Error
	-- Error blames the latest item on the traceback as the cause of the error
	-- Error makes it clear which Library and function are being misused
	-- @author Validark

	local Replacers = {
		["Index ?"] = "__index";
		["Newindex ?"] = "__newindex";
	}

	local function Format(String, ...)
		return String:format(...)
	end
	
	local CommandBar = {Name = "Command bar"}

	function GetErrorData(Err, ...) -- Make sure if you don't intend to format arguments in, you do %%f instead of %f
		local t = {...}

		local Traceback = debug.traceback()
		local ErrorDepth = select(2, Traceback:gsub("\n", "")) - 2

		local Prefix
		Err, Prefix = Err:gsub("^!", "", 1)
		local ModuleName = Prefix == 1 and table.remove(t, 1) or (getfenv(ErrorDepth).script or CommandBar).Name
		local FunctionName

		for i = 1, select("#", ...) do
			t[i] = Debug.Stringify(t[i])
		end

		for x in Traceback:sub(1, -11):gmatch("%- [^\r\n]+[\r\n]") do
			FunctionName = x
		end

		FunctionName = FunctionName:sub(3, -2):gsub("%l+ (%S+)$", "%1"):gsub("^%l", string.upper, 1):gsub(" ([^\n\r]+)", " %1", 1)

		local i = 0
		for x in Err:gmatch("%%%l") do
			i = i + 1
			if x == "%q" then
				t[i] = t[i]:gsub(" (%S+)$", " \"%1\"", 1)
			end
		end

		local Success, ErrorString = pcall(Format, "[%s] {%s} " .. Err:gsub("%%q", "%%s"), ModuleName, Replacers[FunctionName] or FunctionName, unpack(t))

		if Success then
			return ErrorString, ErrorDepth
		else
			error(GetErrorData("!Error formatting failed, perhaps try escaping non-formattable tags like so: %%%%f\n(Error Message): " .. ErrorString, "Debug"))
		end
	end

	function Debug.Warn(...)
		warn((GetErrorData(...)))
	end

	function Debug.Error(...)
		error(GetErrorData(...))
	end

	function Debug.Assert(Condition, ...)
		return Condition or error(GetErrorData(...))
	end
end

do
	local function Alphabetically(a, b)
		local typeA = type(a)
		local typeB = type(b)

		if typeA == typeB then
			if typeA == "number" then
				return a < b
			else
				return tostring(a):lower() < tostring(b):lower()
			end
		else
			return typeA < typeB
		end
	end

	function Debug.AlphabeticalOrder(Dictionary)
		--- Iteration function that iterates over a dictionary in alphabetical order
		-- function AlphabeticalOrder(Dictionary)
		-- @param table Dictionary That which will be iterated over in alphabetical order
		-- A dictionary looks like this: {Apple = true, Noodles = 5, Soup = false}
		-- Not case-sensitive
		-- @author Validark

		local Count = 0
		local Order = {}

		for Key in next, Dictionary do
			Count = Count + 1
			Order[Count] = Key
		end

		require(script.SortedArray).new(Order, Alphabetically)

		return function(Table, Previous)
			local Key = Order[Previous == nil and 1 or ((Order:Find(Previous) or error("invalid key to 'AlphabeticalOrder' " .. tostring(Previous))) + 1)]
			return Key, Table[Key]
		end, Dictionary, nil
	end
end

function Debug.UnionIteratorFunctions(...)
	-- Takes in functions ..., and returns a function which unions them, which can be called on a table
	-- Will iterate through a table, using the iterator functions passed in from left to right
	-- Will pass the CurrentIteratorFunction index in the stack as the last variable
	-- UnionIteratorFunctions(Get0, ipairs, Debug.AlphabeticalOrder)(Table)

	local IteratorFunctions = {...}

	for i = 1, #IteratorFunctions do
		if type(IteratorFunctions[i]) ~= "function" then
			error(GetErrorData("Cannot union Iterator functions which aren't functions"))
		end
	end

	return function(Table)
		local Count = 0
		local Order = {[0] = {}}
		local KeysSeen = {}

		for i = 1, #IteratorFunctions do
			local Function, TableToIterateThrough, Next = IteratorFunctions[i](Table)

			if type(Function) ~= "function" or type(TableToIterateThrough) ~= "table" then
				error(GetErrorData("Iterator function " .. i .. " must return a stack of types as follows: Function, Table, Variant"))
			end

			while true do
				local Data = {Function(TableToIterateThrough, Next)}
				Next = Data[1]
				if Next == nil then break end
				if not KeysSeen[Next] then
					KeysSeen[Next] = true
					Count = Count + 1
					Data[#Data + 1] = i
					Order[Count] = Data
				end
			end
		end

		return function(_, Previous)
			for i = 0, Count do
				if Order[i][1] == Previous then
					local Data = Order[i + 1]
					if Data then
						return unpack(Data)
					else
						return nil
					end
				end
			end

			error(GetErrorData("invalid key to unioned iterator function: " .. Previous))
		end, Table, nil
	end
end

local EachOrder do
	-- TODO: Write a function that takes multiple iterator functions and iterates through each passed in function
	-- EachOrder(Get0(Table), ipairs(Table), AlphabeticalOrder(Table))
end

do
	local function Get0(t)
		return function(t2, val)
			if val == nil and t2[0] ~= nil then
				return 0, t2[0]
			end
		end, t, nil
	end

	local typeof = typeof or type
	local ArrayOrderThenAlphabetically = Debug.UnionIteratorFunctions(Get0, ipairs, Debug.AlphabeticalOrder)
	local ConvertTableIntoString

	local function Parse(Object, Multiline, Depth, EncounteredTables)
		local Type = typeof(Object)

		if Type == "table" then
			for TableName, Table in next, EncounteredTables do
				if Table == Object then
					if TableName == 1 then
						return "[self]"
					else
						return "[table " .. TableName .. "]"
					end
				end
			end
			return ConvertTableIntoString(Object, nil, Multiline, (Depth or 1) + 1, EncounteredTables)
		end
		
		if Type == "string" then
			local Chunks = {}
			local ChunkLength = 60
			for i = 1, math.ceil(#Object / ChunkLength) do
				table.insert(Chunks, Object:sub(ChunkLength * (i - 1) + 1, ChunkLength * i))
			end
			return '"' .. table.concat(Chunks, '\n' .. ("   "):rep(Depth + 1)) .. '"'
		end

		return
			Type == "Instance" and "<" .. Debug.DirectoryToString(Object) .. ">" or
			(Type == "function" or Type == "userdata") and Type or
			tostring(Object)
	end

	function ConvertTableIntoString(Table, TableName, Multiline, Depth, EncounteredTables)
		if type(Table) == "table" then
			EncounteredTables[#EncounteredTables + 1] = Table

			local Output = {}
			local OutputCount = 0

			for Key, Value, Iter in ArrayOrderThenAlphabetically(Table) do
				if Iter < 1 then
					if OutputCount == 0 and Multiline then
						Output[OutputCount + 1] = "\n"
						Output[OutputCount + 2] = ("   "):rep(Depth)
						OutputCount = OutputCount + 2
					end

					Output[OutputCount + 1] = (Iter == 1 and "[0] = " or "") .. Parse(Value, Multiline, Depth, EncounteredTables)
					Output[OutputCount + 2] = ", "
					OutputCount = OutputCount + 2
				else
					if Multiline then
						OutputCount = OutputCount + 1
						Output[OutputCount] = "\n"
						Output[OutputCount + 1] = ("   "):rep(Depth)
					else
						OutputCount = OutputCount - 1
					end
					
					if type(Key) == "string" and not Key:find("^%d") and not Key:find("%s") then
						Output[OutputCount + 2] = Key
						OutputCount = OutputCount - 2
					else
						Output[OutputCount + 2] = "["
						Output[OutputCount + 3] = Parse(Key, Multiline, Depth, EncounteredTables)
						Output[OutputCount + 4] = "]"
					end

					Output[OutputCount + 5] = " = "
					Output[OutputCount + 6] = Parse(Value, Multiline, Depth, EncounteredTables)
					Output[OutputCount + 7] = Multiline and ";" or ", "
					OutputCount = OutputCount + 7
				end
			end
			
			local OutputStart = 1
			
			if Output[OutputCount] == ", " then
				if Multiline then
					OutputStart = OutputStart + 2
				end
				OutputCount = OutputCount - 1
			elseif Multiline and OutputCount ~= 0 then
				Output[OutputCount + 1] = "\n"
				Output[OutputCount + 2] = ("   "):rep(Depth)
				OutputCount = OutputCount + 2
			end

			local Metatable = getmetatable(Table)

			OutputStart = OutputStart - 1

			if not Multiline or Output[OutputCount - 1] ~= "\n" then
				OutputCount = OutputCount + 1
			end

			Output[OutputStart] = "{"
			Output[OutputCount] = OutputCount > 1 and (("   "):rep(Depth - 1) .. "}") or "}"

			if Metatable then
				if type(Metatable) == "table" then
					Output[OutputCount + 1] = " <- "
--					Output[OutputCount + 2] = ConvertTableIntoString(Metatable, nil, Multiline, nil, EncounteredTables)
					Output[OutputCount + 2] = ConvertTableIntoString(Metatable, nil, Multiline, Depth, EncounteredTables)
					OutputCount = OutputCount + 2
				else
					warn((GetErrorData((TableName or "Table") .. "'s metatable cannot be accessed. Got:\n" .. tostring(Metatable))))
				end
			end

			if TableName then
				Output[OutputStart - 1] = " = "
				Output[OutputStart - 2] = TableName
				OutputStart = OutputStart - 2
			end

			return table.concat(Output, "", OutputStart, OutputCount)
		else
			error(GetErrorData("[Debug] TableToString needs a table to convert to a string! Got type " .. typeof(Table)))
		end
	end

	function Debug.TableToString(Table, TableName, Multiline)
		--- Converts a table into a readable string
		-- string TableToString(Table, TableName, Multiline)
		-- @param table Table The Table to convert into a readable string
		-- @param string TableName Optional Name parameter that puts a "[TableName] = " at the beginning
		-- @returns a readable string version of the table

		return ConvertTableIntoString(Table, TableName, Multiline, 1, {})
	end
end

do
	local EscapedCharacters = {"%", "^", "$", "(", ")", ".", "[", "]", "*", "+", "-", "?"}
	local Escapable = "([%" .. table.concat(EscapedCharacters, "%") .. "])"

	function Debug.EscapeString(String)
		--- Turns strings into Lua-readble format
		-- string Debug.EscapeString(String)
		-- @returns Objects location in proper Lua format
		-- @author Validark
		-- Useful for when you are doing string-intensive coding
		-- Those minus signs always get me when I'm not using this function!

		return (
			String
				:gsub(Escapable, "%%%1")
				:gsub("([\"\'\\])", "\\%1")
		)
	end
end

--- Returns a string representation of anything.
-- @param any Object The object you wish to represent as a string.
-- @returns a readable string representation of the object.
-- @author evaera
function Debug.Inspect(Object)
	if type(Object) == "table" then
		return "table " .. Debug.TableToString(Object)
	else
		return Debug.Stringify(Object)
	end
end

return Debug