
local m = { }

m.name = "ZeroBrane Studio 1.10 API formatter"
m.version = "0.1.0"
m.authors = { "Diego Martínez <kaeza>" }

local serialize_simple = require "serialize".serialize_simple
local serialize = require "serialize".serialize

local function format_enum(state, e)
	local out, childs = { }, { }
	out.type = "class"
	out.childs = childs
	for _, k in ipairs(e.values) do
		childs[k] = {
			type = "value",
			description = k,
		}
	end
	return out
end

local function format_func(state, e)
	return {
		type = "function",
		description = e.name,
		args = e.args,
		returns = e.rets,
	}
end

local function format_var(state, e)
	return {
		type = "value",
		description = e.vtype,
	}
end

local formatters -- forward

local function format_table(state, e)
	local out, childs = { }, { }
	out.type = "class"
	out.childs = childs
	for symname, sym in pairs(e.syms) do
		local fmt = formatters[sym.type]
		if fmt then
			childs[symname] = fmt(state, sym, file)
		end
	end
	return out
end

local function format_ns(state, e)
	local out, childs = { }, { }
	out.type = "lib"
	out.childs = childs
	for symname, sym in pairs(e.syms) do
		--io.stderr:write("sym: ", symname, "\n")
		local fmt = formatters[sym.type]
		if fmt then
			childs[symname] = fmt(state, sym, file)
		else
			io.stderr:write(("WARNING: Unsupported type: %q\n"):format(sym.type))
		end
	end
	return out
end

formatters = {
	enum = format_enum,
	["function"] = format_func,
	var = format_var,
	table = format_table,
	class = format_table,
	namespace = format_ns,
}

function m.write(state, file, options)
	for k, v in pairs(options) do
		print(k, v)
	end
	local out = format_ns(state, state.namespaces[""]).childs
	for i, ns in ipairs(state.namespaces) do
		if ns.name ~= "" then
			out[ns.name] = format_ns(state, ns, file)
		end
	end
	local ser = options.pretty and serialize_simple or serialize
	file:write("return ", ser(out), "\n")
	return true
end

return m
