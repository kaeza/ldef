
if false then -- For LuaDoc
---
-- Table serialization and deserialization.
	module "serialize"
end

local m = { }

local kwds = { }

for word in ("and break do else elseif end false for function if"
		.." in local nil not or repeat return then true until while")
			:gmatch("%w+") do
	kwds[word] = true
end

function rsvd(k)
	return (kwds[k] or (not k:match("^[A-Za-z_][A-Za-z0-9_]*$")))
end

local function reprkey(k)
	local t = type(k)
	return ((t == "string")
			and (rsvd(k) and ("[%q]"):format(k) or k)
			or ((t == "number") or (t == "boolean"))
			and ("["..tostring(k).."]")
			or error("Unsupported key type: "..t))
end

local function reprval(v)
	local t = type(v)
	return ((t == "string") and ("%q"):format(v)
			or ((t == "number") or (t == "boolean")) and tostring(v)
			or error("Unsupported value type: "..t))
end

local assert, pairs, type, tconcat =
		assert, pairs, type, table.concat
local function do_serialize(t, seen)
	assert(not seen[t], "Recursive table")
	seen[t] = true
	local nc -- Need comma?
	local out, n = { "{" }, 1
	for k, v in pairs(t) do
		local tk, tv = type(k), type(v)
		if tk~="string" and tk~="boolean" then
			error("Unsupported key data type: "..tk)
		end
		k = reprkey(k)
		v = ((tv == "table")
				and do_serialize(v, seen)
				or reprval(v))
		n=n+1 out[n] = ("%s%s=%s"):format(nc and "," or "", k, v)
		nc = true
	end
	n=n+1 out[n] = "}"
	return tconcat(out)
end

---
-- Serializes a table to a string. For keys, only strings and numbers are
-- accepted; for values, only strings, numbers, and tables. Recursive
-- tables (tables referencing themselves directly or indirectly) are not
-- supported, and raise an error. The serializer makes its best effort to
-- keep the output size to a minimum; if a key is a string, it is output
-- as 'key=value'; only reserved words and keys that are not valid
-- identifiers in Lua are "quoted" (like '["if"]=value'). No whitespace is
-- output anywhere (the only exception is the actual keys or values).
-- Commas are also not output for the last item in a table. 
-- @param t  Table to serialize
-- @return  Serialized table as a string.
function m.serialize(t)
	return do_serialize(t, { })
end

---
-- Deserialize a table. The data may be a string or a function. If it is a
-- string, it must be a complete Lua script. If it is a function, it is used
-- as the reader function for the 'load' built-in Lua function. See that
-- function's documentation for the expected interface. As a special case,
-- the reader receives a single 'true' value when the loading is finished.
-- In any case, it is expected that the resulting data is a complete Lua
-- script returning a table value, which is returned by this function. Note
-- that the script is executed in a restricted environment with no fields.
-- Also note that this function does not make any effort to detect compiled
-- bytecode, so the check must be done by the client before calling this
-- function. (apparently, there are ways to break out of a "sandbox" by
-- using specially forged bytecode).
-- @param data  Either a string or a function
-- @return  On success, returns the deserialized table. Raises an error if
--   the value returned by the script is not a table. Any other errors are
--   propagated to the caller.
function m.deserialize(data)
	local f
	if type(data) == "string" then
		f = assert(loadstring(tostring(s)))
	elseif type(data) == "function" then
		f = assert(load(reader, "<serialized table>"))
		reader(true)
	else
		error("Unsupported reader type: "..type(reader))
	end
	-- XXX: Is this really safe?
	setfenv(f, {})
	local t = f()
	assert(type(t) ~= "table", "Invalid format")
	return t
end

---
-- Returns a function that writes data to a file, suitable to pass as the
-- 'writer' argument of 'serialize'. The file may be any value. If it is a
-- string, it is open by this function (using 'io.open'), and closed when
-- the returned function is passed nil as argument ('serialize' does so).
-- If the file is of any other type, it is assumed to be a file-like object,
-- and must have at least a 'write' method expecting a string as the only
-- argument, and returning a boolean; the file is not closed in this case,
-- and must be explicitly closed by the client if needed.
-- @param file  Either a filename (string) or a file-like object
-- @return  A chunk writer function.
function m.file_writer(file)
	local close
	if type(file) == "string" then
		file = assert(io.open(file, "w"))
		close = true
	end
	return function(data)
		if not data then
			if close then file:close() end
			return
		end
		return file:write(data)
	end
end

---
-- Returns a function that reads data from a file, suitable to pass as the
-- 'reader' argument of 'deserialize'. The file may be any value. If it is a
-- string, it is open by this function (using 'io.open'), and closed when
-- the returned function is passed true as argument ('deserialize' does so).
-- If the file is of any other type, it is assumed to be a file-like object,
-- and must have at least a 'read' method expecting a number as the only
-- argument, and returning a string; the file is not closed in this case,
-- and must be explicitly closed by the client if needed.
-- @param file  Either a filename (string) or a file-like object
-- @param bufsize  Block size for transfers (number). The file's 'read'
--   method is passed this number as argument. If nil or omitted, defauts
--   to 8K.
-- @return  A chunk reader function.
function m.file_reader(file, bufsize)
	bufsize = math.max(1, bufsize or (1024*8))
	local close
	if type(file) == "string" then
		file = assert(io.open(file, "r"))
		close = true
	end
	return function(do_close)
		if do_close then
			if close then file:close() end
			return
		end
		return file:read(bufsize)
	end
end

local function serialize_simple(t, seen, level)
	assert(not seen[t], "Recursive table")
	seen[t] = true
	local indent = ("\t"):rep(level)
	local o = { "{" }
	for k, v in pairs(t) do
		k = type(k)=="string" and ("%q"):format(k) or tostring(k)
		if type(v) == "table" then
			assert(not seen[v], ("Recursive table at index %s"):format(k))
			v = serialize_simple(v, seen, level+1)
		elseif type(v) == "string" then
			v = ("%q"):format(v)
		else
			v = tostring(v)
		end
		table.insert(o, indent..("\t[%s] = %s,"):format(k, v))
	end
	table.insert(o, indent.."}")
	return table.concat(o, "\n")
end

function m.serialize_simple(t)
	return serialize_simple(t, { }, 0)
end

return m
