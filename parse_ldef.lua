#! /usr/bin/env lua

local BASE, ME = arg[0]:match("(.*)[/\\](.*)$")
BASE, ME = BASE or ".", ME or arg[0]

package.path = (BASE.."/?.lua;"
		..BASE.."/?/init.lua;"
		..package.path)

local function printf(fmt, ...)
	io.stdout:write(fmt:format(...).."\n")
	io.stdout:flush()
end

local function perrorf(fmt, ...)
	io.stderr:write(fmt:format(...).."\n")
	io.stderr:flush()
end

local function trim(s)
	return s:match("^%s*(.-)%s*$")
end

local function split(s, sep)
	-- TODO: Implement proper split
	return (s..sep):gmatch("(.-)%"..sep)
end

local Namespace_meta = { }
Namespace_meta.__index = Namespace_meta

local function Namespace(name)
	local self = { }
	self.type = "namespace"
	self.name = name
	self.syms = { }
	return setmetatable(self, Namespace_meta)
end

function Namespace_meta:add(name, def)
	assert(type(name)=="string")
	assert(type(def)=="table")
	if self.syms[name] then
		return nil, "duplicate definition: "..name
	end
	def.name = def.name or name
	self.syms[name] = def
	return true
end

local State_meta = { }
State_meta.__index = State_meta

local function State()
	local self = { }
	-- TODO: Add nested namespace support
	self.global_space = Namespace("")
	self.cur_space = self.global_space
	self.namespaces = { [""]=self.cur_space }
	return setmetatable(self, State_meta)
end

function State_meta:parse_function(line, tags)
	local decl = assert(line:match("^function%s*(.*)"))
	local name, sargs, srets
	name, decl = trim(decl):match("^([A-Za-z_][A-Za-z0-9_]*)%s*(.*)")
	if not name then return nil, "function name expected" end
	sargs, decl = trim(decl):match("^(%b())%s*(.*)")
	if not sargs then return nil, "function arguments expected" end
	if decl:find(":") then
		srets = trim(decl):match("^:%s*(.*)")
		if not srets then
			return nil, "function return types expected"
		end
	end
	return self.cur_space:add(name, {
		type = "function",
		args = sargs,
		rets = srets,
		tags = tags,
	})
end

function State_meta:parse_constructor(line, tags)
	assert(self.cur_space.type == "class",
			"constructor only allowed in classes")
	local decl = assert(line:match("^constructor%s*(.*)"))
	local sargs
	sargs, decl = trim(decl):match("^(%b())%s*(.*)")
	if not sargs then return nil, "function arguments expected" end
	return self.cur_space:add("__call", {
		type = "function",
		args = sargs,
		rets = self.cur_space.name,
		tags = tags,
	})
end

function State_meta:parse_var(line, tags)
	local decl = assert(line:match("^var%s*(.*)"))
	local name, typ = decl:match("^([A-Za-z_][A-Za-z0-9_]*)%s*:%s*(.*)")
	if not name then
		return nil, "malformed variable/field declaration"
	end
	return self.cur_space:add(name, {
		type = "var",
		vtype = typ,
	})
end

function State_meta:parse_table(line, tags)
	local decl = assert(line:match("^table%s*(.*)"))
	local name = decl:match("^[A-Za-z_][A-Za-z0-9_]*")
	if not name then
		return nil, "type name expected"
	end
	local new_space = self.namespaces[name]
	if new_space ~= nil then
		error("duplicate definition: "..name)
	end
	new_space = Namespace(name)
	new_space.type = "table"
	local old_space = self.cur_space
	self.cur_space = new_space
	return old_space:add(name, new_space)
end

function State_meta:parse_namespace(line, tags)
	local decl = assert(line:match("^namespace%s*(.*)"))
	local name = decl:match("^[A-Za-z_][A-Za-z0-9_]*")
	if not name then
		return nil, "namespace name expected"
	end
	local new_space = self.namespaces[name]
	if new_space == nil then
		new_space = Namespace(name)
		self.namespaces[name] = new_space
	elseif type(new_space) ~= "table" then
		error("duplicate definition: "..name)
	end
	local old_space = self.cur_space
	self.cur_space = new_space
	return old_space:add(name, new_space)
end

function State_meta:parse_class(line, tags)
	local decl = assert(line:match("^class%s*(.*)"))
	local name = decl:match("^[A-Za-z_][A-Za-z0-9_]*")
	if not name then
		return nil, "type name expected"
	end
	local new_space = self.namespaces[name]
	if new_space ~= nil then
		error("duplicate definition: "..name)
	end
	new_space = Namespace(name)
	new_space.type = "class"
	local old_space = self.cur_space
	self.cur_space = new_space
	return old_space:add(name, new_space)
end

function State_meta:parse_end(line, tags)
	-- TODO: Add nested namespace support
	self.cur_space = self.global_space
	return true
end

function State_meta:parse_enum(line, tags)
	local decl = assert(line:match("^enum%s*(.*)"))
	local name, values = decl:match("^([A-Za-z_][A-Za-z0-9_]*)%s*=%s*(.*)")
	if not name then
		return nil, "malformed enum declaration"
	end
	local valuelist = { }
	for item in split(values, ",") do
		item = trim(item)
		table.insert(valuelist, item)
	end
	return self.cur_space:add(name, {
		type = "enum",
		values = valuelist,
		tags = tags,
	})
end

function State_meta:read(file)
	local lineno = 0
	local function read_logline(file)
		local logline
		while true do
			lineno = lineno + 1
			local line, err = file:read("*l")
			local ret = true
			if not line then return logline, err end
			--print(("%q"):format(line))
			if line:match("%\\$") then
				line, ret = line:sub(1, -2), false
			end
			logline = (logline and (logline.." ") or "")..line
			if ret then return logline end
		end
	end
	local close
	if file == nil then
		ldef, file = "<stdin>", io.stdin
	elseif type(file) == "string" then
		local f, err = io.open(file)
		if not f then return nil, err end
		ldef, file, close = file, f, true
	else
		ldef = "<"..tostring(file)..">"
	end
	local cur_line
	local function error(fmt, ...)
		if close then file:close() file=nil end
		return nil, ("%s:%d: %s\n%s"):format(ldef, lineno,
				fmt:format(...), cur_line)
	end
	while true do
		local line = read_logline(file)
		if not line then break end
		cur_line = line
		line = trim(line)
		if #line>0 and (not line:match("^%-%-")) then
			local tags = { }
			while line:sub(1, 1) == "\x5B" do
				local endp = line:find("\x5D", 1, true)
				if not endp then
					return error("unfinished tag")
				end
				local tag = line:sub(2, endp-1)
				local name, val = tag:match("^[^=]+=(.*)")
				if not name then name, val = tag, "" end
				tags[name] = val
				line = line:sub(endp+1)
			end
			local decl = line:match("^[a-zA-Z]+")
			if not decl then
				return error("missing declaration")
			end
			local handler = self["parse_"..decl]
			if not handler then
				return error("unknown declaration type: %s", decl)
			end
			local ok, err = handler(self, line, tags)
			if not ok then
				return error(err or "unknown error")
			end
		end
	end
	return true
end

local formatters = require "formatters"

local function usage()
	printf("Usage: %s [OPTIONS] [FILE...]\n", ME)
	print([[
Available options:
  -h,--help                     Show this help text and exit.
  -f,--formatter FORMATTER      Set output formatter.
  -F,--formatter-option OPT     Set formatter options.
  -o,--output OUTFILE           Set output file.

Mandatory arguments for long options are mandatory for short options too.

If FILE is `-`, or no FILE is given, read from standard input.
If `-o` is not specified, write to standard output.
Errors always go to standard error.

If `-f` is not specified, the default formatter, `null` is used. If it is
specified, and `-h` is also specified, information such as version,
human-readable name, and authors about the formatter is printed instead of
this text.

The `-F` option may be specified more than once. Each `OPT` may have the
form `KEY=VALUE`, or `KEY` (which equals `KEY=`).
]])
	return os.exit()
end

local function parse_args(arg)
	local i, opts = 0, { }
	opts.inputs = { }
	opts.formatter_options = { }
	local function getarg()
		i = i + 1
		return arg[i]
	end
	while true do
		local a = getarg()
		if not a then break end
		if a=="-h" or a=="--help" then
			local m = opts.formatter
			if m then
				print("Name: "..(m.name or ""))
				print("Version: "..(m.version or ""))
				print("Authors: "..(m.authors
						and table.concat(m.authors, "; ")
						or ""))
				return os.exit()
			else
				return usage()
			end
		elseif a=="-f" or a=="--formatter" then
			local f = getarg()
			if not f then
				return nil, ("missing parameter for `%s`"):format(a)
			end
			local fmt, err = formatters.find(f)
			if not fmt then
				return nil, err
			end
			opts.formatter = fmt
		elseif a=="-F" or a=="--formatter-option" then
			local opt = getarg()
			if not opt then
				return nil, ("missing parameter for `%s`"):format(a)
			end
			local key, val = opt:match("^([^=]+)=(.*)")
			if not key then
				key, val = opt, ""
			end
			opts.formatter_options[key] = val
		elseif a=="-o" or a=="--output" then
			local out = getarg()
			if not out then
				return nil, ("missing parameter for `%s`"):format(a)
			end
			opts.output = out
		elseif a:sub(1, 1) == "-" then
			return nil, ("unknown option `%s`"):format(a)
		else
			table.insert(opts.inputs, a)
		end
	end
	return opts
end

local function main(arg)

	local opts, err = parse_args(arg)
	if not opts then
		perrorf(err or "unknown error")
		return -1
	end

	local state = State()

	if #opts.inputs > 0 then
		for _, input in ipairs(opts.inputs) do
			local ok, err = state:read(input)
			if not ok then
				perrorf(err or "unknown error")
				return 1
			end
		end
	else
		local ok, err = state:read()
		if not ok then
			perrorf(err or "unknown error")
			return 1
		end
	end

	if opts.formatter then
		local out, close = opts.output, nil
		if out then
			local f, err = io.open(out, "wt")
			if not f then
				perrorf(err)
				return 1
			end
			out, close = f, true
		else
			out = io.stdout
		end
		local ok, err = opts.formatter.write(state, out,
				opts.formatter_options)
		if close then out:close() end
		if not ok then
			perrorf(err)
			return 1
		end
	end

end

os.exit(main(arg) or 0)
