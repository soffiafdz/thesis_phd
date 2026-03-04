-- thesis.lua: Pandoc Lua filter for McGill thesis structure
--
-- Handles frontmatter/mainmatter transitions that must appear
-- BEFORE chapter headings (which Quarto always emits first).
--
-- 1. Removes empty chapter headings (from headingless index.qmd)
-- 2. Injects \frontmatter before the Abstract chapter
-- 3. Injects TOC/LOF/LOT + \mainmatter before the Introduction
-- 4. Strips \markright{} commands (headers managed by fancyhdr)

-- Extract short caption from Quarto's FloatRefTarget.
-- Quarto (v1.4+) converts figures/tables to FloatRefTarget
-- custom elements BEFORE user Lua filters run, so the
-- standard Figure() and Table() callbacks never fire.
-- FloatRefTarget.caption_long is a single Block (Plain),
-- and the LaTeX renderer reads float.attributes["fig-scap"]
-- to produce \caption[short]{long}.
function FloatRefTarget(float)
  -- Skip if fig-scap already set manually
  if float.attributes and float.attributes["fig-scap"] then
    return float
  end
  if not float.caption_long then
    return float
  end
  -- caption_long is a single Block (Plain or Para)
  if float.caption_long.t ~= "Plain" and
     float.caption_long.t ~= "Para" then
    return float
  end
  local inlines = float.caption_long.content
  if #inlines > 0 and inlines[1].t == "Strong" then
    local short_text = pandoc.utils.stringify(
      inlines[1].content
    )
    float.attributes["fig-scap"] = short_text
  end
  return float
end

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

    -- Strip \markright{...} commands to prevent section-level
    -- headers from polluting running headers. We use fancyhdr
    -- with only chapter-level marks (\chaptermark).
    elseif block.t == "RawBlock" and block.format == "latex" and
           block.text:match("^%s*\\markright%b{}%s*$") then
      goto continue

    else
      table.insert(new_blocks, block)
    end

    ::continue::
  end

  doc.blocks = new_blocks
  return doc
end
