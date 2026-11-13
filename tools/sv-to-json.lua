-- Turns the global named by __WANT_NAME into JSON in __OUT (used by release-check.js to read SavedVariables).
local function str(s)
  return '"' .. (s:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end)) .. '"'
end
local function enc(v, depth)
  local t = type(v)
  if t == "string" then return str(v) end
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "null" end
    return string.format("%.17g", v)
  end
  if t == "boolean" then return tostring(v) end
  if t ~= "table" or depth > 30 then return "null" end
  local n, count = #v, 0
  for _ in pairs(v) do count = count + 1 end
  local out = {}
  if n > 0 and n == count then
    for i = 1, n do out[i] = enc(v[i], depth + 1) end
    return "[" .. table.concat(out, ",") .. "]"
  end
  for k, x in pairs(v) do out[#out + 1] = str(tostring(k)) .. ":" .. enc(x, depth + 1) end
  return "{" .. table.concat(out, ",") .. "}"
end
__OUT = enc(_G[__WANT_NAME], 0)
