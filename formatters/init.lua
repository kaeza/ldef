
local m = { }

function m.find(name)
	local ok, m = pcall(require, "formatters."..name)
	if ok and type(m)=="table" and type(m.write)=="function" then
		return m
	end
	return nil, "unknown formatter: "..name
end

return m
