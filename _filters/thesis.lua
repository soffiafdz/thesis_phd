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
    local short_doc = pandoc.Pandoc(
      {pandoc.Plain(inlines[1].content)}
    )
    local short_text = pandoc.write(short_doc, "latex")
    -- Strip trailing newline from pandoc.write output
    short_text = short_text:gsub("%s+$", "")
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
  local in_appendix = false

  for i, block in ipairs(blocks) do
    if block.t == "Header" and block.level == 1 then
      local text = pandoc.utils.stringify(block.content)

      -- New chapter resets appendix state
      if in_appendix then
        table.insert(new_blocks, pandoc.RawBlock("latex",
          "% Restore standard float numbering\n" ..
          "\\renewcommand{\\thefigure}" ..
            "{\\thechapter.\\arabic{figure}}\n" ..
          "\\renewcommand{\\thetable}" ..
            "{\\thechapter.\\arabic{table}}"))
        in_appendix = false
      end

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

      -- For unnumbered chapters, manually set the running
      -- header (LaTeX's \chapter* does not call \chaptermark)
      if text ~= "" and block.classes and
         block.classes:includes("unnumbered") then
        table.insert(new_blocks, pandoc.RawBlock("latex",
          "\\markboth{" .. text .. "}{}"))
      end

    -- Detect "Appendix" headings at level 2 or 3:
    -- switch float numbering to S-prefix
    elseif block.t == "Header" and
           (block.level == 2 or block.level == 3) then
      local text = pandoc.utils.stringify(block.content)
      if not in_appendix and
         text:match("^Appendix") then
        in_appendix = true
        table.insert(new_blocks, pandoc.RawBlock("latex",
          "% Appendix: prefix float numbers with S\n" ..
          "\\renewcommand{\\thefigure}" ..
            "{S\\thechapter.\\arabic{figure}}\n" ..
          "\\renewcommand{\\thetable}" ..
            "{S\\thechapter.\\arabic{table}}"))
      end
      table.insert(new_blocks, block)

    -- Bibliography Div(s): set running header to References
    -- section-bibliographies filter creates refs-* divs
    elseif block.t == "Div" and
           (block.identifier == "refs" or
            block.identifier:match("^refs%-")) then
      table.insert(new_blocks, pandoc.RawBlock("latex",
        "\\markboth{References}{}"))
      table.insert(new_blocks, block)

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
