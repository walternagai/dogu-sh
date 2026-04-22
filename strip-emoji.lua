local emoji_ranges = {
  {0x1F600, 0x1F64F},
  {0x1F300, 0x1F5FF},
  {0x1F680, 0x1F6FF},
  {0x1F1E0, 0x1F1FF},
  {0x2600, 0x26FF},
  {0x2700, 0x27BF},
  {0xFE00, 0xFE0F},
  {0x1F900, 0x1F9FF},
  {0x1FA00, 0x1FA6F},
  {0x1FA70, 0x1FAFF},
  {0x200D, 0x200D},
  {0x20E3, 0x20E3},
  {0xE0020, 0xE007F},
}

local function is_emoji(cp)
  for _, r in ipairs(emoji_ranges) do
    if cp >= r[1] and cp <= r[2] then return true end
  end
  return false
end

local function strip_emoji(str)
  local result = {}
  for _, code in utf8.codes(str) do
    if not is_emoji(code) then
      table.insert(result, utf8.char(code))
    end
  end
  return table.concat(result)
end

function Str(el)
  local s = strip_emoji(el.text)
  if s == "" then return {} end
  if s ~= el.text then return pandoc.Str(s) end
  return el
end

function Code(el)
  local s = strip_emoji(el.text)
  if s == "" then return {} end
  if s ~= el.text then return pandoc.Code(s) end
  return el
end

function CodeBlock(el)
  local s = strip_emoji(el.text)
  if s == "" then return {} end
  if s ~= el.text then return pandoc.CodeBlock(s, el.attr) end
  return el
end