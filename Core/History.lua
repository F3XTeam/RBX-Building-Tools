local Tool = script.Parent.Parent

-- Libraries
local Libraries = Tool:WaitForChild 'Libraries'
local Signal = require(Libraries:WaitForChild 'Signal')

History = {

	-- Record stack
	Stack = {},

	-- Current position in record stack
	Index = 0,

	-- History change event
	Changed = Signal.new()

};

function History.Undo()
	-- Unapplies the previous record in stack

	-- Stay within boundaries
	if History.Index - 1 < 0 then
		return;
	end;

	-- Get the history record, unapply it
	local Record = History.Stack[History.Index];
	Record:Unapply();

	-- Update the index
	History.Index = History.Index - 1;

	-- Fire the Changed event
	History.Changed:Fire();

end;

function History.Redo()
	-- Applies the next record in stack

	-- Stay within boundaries
	if History.Index + 1 > #History.Stack then
		return;
	end;

	-- Update the index
	History.Index = History.Index + 1;

	-- Get the history record and apply it
	local Record = History.Stack[History.Index];
	Record:Apply();

	-- Fire the Changed event
	History.Changed:Fire();

end;

function History.Add(Record)
	-- Adds new history record to stack

	-- Update the index
	History.Index = History.Index + 1;

	-- Register the new history record
	History.Stack[History.Index] = Record;

	-- Clear history ahead
	for Index = History.Index + 1, #History.Stack do
		History.Stack[Index] = nil;
	end;

	-- Fire the Changed event
	History.Changed:Fire();

end;

return History;