-- chapter-bib.lua: Per-chapter + global bibliography for Quarto books
--
-- Must be used with `citeproc: false` in _quarto.yml.
-- Runs citeproc manually, then duplicates relevant bibliography
-- entries into per-chapter "References" sections.
-- The global bibliography is preserved at the end (Bibliography chapter).
--
-- Does NOT rename any identifiers — cross-references are untouched.

local stringify = pandoc.utils.stringify

--- Collect all citation keys from a list of blocks.
local function collect_keys(blocks)
  local keys = {}
  for _, block in ipairs(blocks) do
    pandoc.walk_block(block, {
      Cite = function(cite)
        for _, c in ipairs(cite.citations) do
          keys[c.id] = true
        end
      end
    })
  end
  return keys
end

--- Extract rendered bibliography entries from the #refs div.
--- Returns a table mapping citation keys to cloned Div blocks.
local function build_refs_lookup(refs_div)
  local lookup = {}
  if not refs_div then return lookup end
  for _, block in ipairs(refs_div.content) do
    if block.t == "Div" and block.identifier:match("^ref%-") then
      local key = block.identifier:sub(5)
      lookup[key] = block
    end
  end
  return lookup
end

--- Build a per-chapter references section.
local function make_chapter_refs(keys, lookup, chapter_num)
  local entries = {}
  local sorted_keys = {}
  for k in pairs(keys) do
    sorted_keys[#sorted_keys + 1] = k
  end
  table.sort(sorted_keys)

  for _, key in ipairs(sorted_keys) do
    if lookup[key] then
      -- Clone and give unique id to avoid duplicate id warnings
      local entry = lookup[key]:clone()
      entry.identifier = entry.identifier .. "-ch" .. chapter_num
      entries[#entries + 1] = entry
    end
  end

  if #entries == 0 then return nil end

  local refs_div = pandoc.Div(entries,
    pandoc.Attr("refs-ch" .. chapter_num,
      {"references", "csl-bib-body", "hanging-indent"},
      {["entry-spacing"] = "0"}))

  local header = pandoc.Header(2,
    {pandoc.Str("References")},
    pandoc.Attr("references-ch" .. chapter_num, {"unnumbered"}))

  return {
    pandoc.RawBlock("latex", "\\FloatBarrier"),
    header,
    refs_div
  }
end

function Pandoc(doc)
  if not (FORMAT:match("latex") or FORMAT:match("pdf")) then
    return doc
  end

  -- Step 1: Collect per-chapter citation keys BEFORE citeproc
  -- (Cite elements exist before citeproc replaces them)
  local blocks = doc.blocks
  local chapters = {}
  local current_start = 1
  local chapter_num = 0

  for i, block in ipairs(blocks) do
    if block.t == "Header" and block.level == 1 and i > 1 then
      local prev_blocks = {}
      for j = current_start, i - 1 do
        prev_blocks[#prev_blocks + 1] = blocks[j]
      end
      local title = ""
      for j = current_start, i - 1 do
        if blocks[j].t == "Header" and blocks[j].level == 1 then
          title = stringify(blocks[j].content)
          break
        end
      end
      chapters[#chapters + 1] = {
        start_idx = current_start,
        end_idx = i - 1,
        keys = collect_keys(prev_blocks),
        title = title,
        num = chapter_num
      }
      current_start = i
      chapter_num = chapter_num + 1
    end
  end
  -- Last chapter
  local last_blocks = {}
  local last_title = ""
  for j = current_start, #blocks do
    last_blocks[#last_blocks + 1] = blocks[j]
    if blocks[j].t == "Header" and blocks[j].level == 1 and
       last_title == "" then
      last_title = stringify(blocks[j].content)
    end
  end
  chapters[#chapters + 1] = {
    start_idx = current_start,
    end_idx = #blocks,
    keys = collect_keys(last_blocks),
    title = last_title,
    num = chapter_num
  }

  -- Step 2: Run citeproc
  doc = pandoc.utils.citeproc(doc)
  blocks = doc.blocks

  -- Step 3: Find the global #refs div in the citeprocced document
  local refs_div = nil
  local refs_idx = nil
  for i, block in ipairs(blocks) do
    if block.t == "Div" and block.identifier == "refs" then
      refs_div = block
      refs_idx = i
      break
    end
  end

  if not refs_div then
    return doc
  end

  local lookup = build_refs_lookup(refs_div)
  if next(lookup) == nil then
    return doc
  end

  -- Step 4: Rebuild document with per-chapter refs inserted
  -- After citeproc, the block indices may have shifted slightly
  -- (citeproc replaces Cite inlines but doesn't add/remove blocks
  -- except for the #refs div). Re-detect chapter boundaries.
  local skip = {
    ["Abstract"] = true,
    ["Abrégé"] = true,
    ["Acknowledgements"] = true,
    ["Acronyms"] = true,
    ["Bibliography"] = true,
    [""] = true,
  }

  local new_blocks = {}
  local ch_idx = 0
  local current_keys = {}
  local current_title = ""
  local need_flush = false

  for i, block in ipairs(blocks) do
    if block.t == "Header" and block.level == 1 then
      -- Flush previous chapter's references
      if need_flush and next(current_keys) and
         not skip[current_title] then
        local ref_blocks = make_chapter_refs(
          current_keys, lookup, ch_idx)
        if ref_blocks then
          for _, rb in ipairs(ref_blocks) do
            new_blocks[#new_blocks + 1] = rb
          end
        end
      end

      current_title = stringify(block.content)
      ch_idx = ch_idx + 1

      -- Find matching pre-citeproc chapter keys
      current_keys = {}
      for _, ch in ipairs(chapters) do
        if ch.title == current_title then
          current_keys = ch.keys
          break
        end
      end
      need_flush = true
    end

    new_blocks[#new_blocks + 1] = block
  end

  -- Flush last chapter (before global bibliography)
  -- The Bibliography chapter itself shouldn't get per-chapter refs
  if need_flush and next(current_keys) and
     not skip[current_title] then
    local ref_blocks = make_chapter_refs(
      current_keys, lookup, ch_idx)
    if ref_blocks then
      for _, rb in ipairs(ref_blocks) do
        new_blocks[#new_blocks + 1] = rb
      end
    end
  end

  doc.blocks = new_blocks
  return doc
end
