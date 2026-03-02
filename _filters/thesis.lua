-- thesis.lua: Pandoc Lua filter for McGill thesis structure
--
-- Handles frontmatter/mainmatter transitions that must appear
-- BEFORE chapter headings (which Quarto always emits first).
--
-- 1. Removes empty chapter headings (from headingless index.qmd)
-- 2. Injects \frontmatter before the Abstract chapter
-- 3. Injects TOC/LOF/LOT + \mainmatter before the Introduction

function Pandoc(doc)
  local dominated_by_format = FORMAT:match("latex") or
                               FORMAT:match("pdf")
  if not dominated_by_format then
    return doc
  end

  local blocks = doc.blocks
  local new_blocks = {}

  for i, block in ipairs(blocks) do
    if block.t == "Header" and block.level == 1 then
      local text = pandoc.utils.stringify(block.content)

      -- Remove empty chapter headings (from index.qmd)
      if text == "" then
        goto continue

      -- Before Abstract: inject \frontmatter
      elseif text == "Abstract" then
        table.insert(new_blocks, pandoc.RawBlock("latex",
          "\\frontmatter"))
        table.insert(new_blocks, block)

      -- Before Introduction: inject TOC/LOF/LOT + \mainmatter
      elseif text == "Introduction" then
        table.insert(new_blocks, pandoc.RawBlock("latex",
          "\\tableofcontents\n" ..
          "\\listoffigures\n" ..
          "\\listoftables\n" ..
          "\\clearpage\n" ..
          "\\mainmatter"))
        table.insert(new_blocks, block)

      else
        table.insert(new_blocks, block)
      end

    -- Remove the \frontmatter RawBlock from index.qmd
    -- (now handled by the filter injection above)
    elseif block.t == "RawBlock" and block.format == "latex" and
           block.text:match("^%s*\\frontmatter%s*$") then
      goto continue

    else
      table.insert(new_blocks, block)
    end

    ::continue::
  end

  doc.blocks = new_blocks
  return doc
end
