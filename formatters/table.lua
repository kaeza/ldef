
local m = { }

m.name = "Table formatter"
m.version = "0.1.0"
m.authors = { "Diego Martínez <kaeza>" }

local serialize = require "serialize".serialize_simple

local function do_write(state, file)
	return file:write(("return %s\n")
			:format(serialize(state.namespaces)))
end

function m.write(state, file)
	local ok, r, err = pcall(do_write, state, file)
	if not ok then return nil, r end
	return r, err
end

return m
