-- bookbox.lua
-- One source, two outputs. Write boxes as fenced divs:
--
--   ::: {.bookbox title="Detailed balance"}
--   ...
--   :::
--
-- Classes: .bookbox (definitions, algorithms, summaries), .quiz (Quiz yourself!),
-- .exercise (end-of-chapter exercises). In HTML the div is kept and styled by
-- bayesrules.css; in PDF it becomes a tcolorbox in the `bookgraybox` style
-- defined in bayesrules.sty. This replaces the duplicated raw-LaTeX / raw-HTML
-- blocks used in the 2025 addendum.

local box_classes = { bookbox = "bookgraybox", quiz = "bookgraybox", exercise = "bookgraybox" }

local function box_style(el)
  for _, cls in ipairs(el.classes) do
    if box_classes[cls] then return box_classes[cls], cls end
  end
  return nil
end

function Div(el)
  local style, cls = box_style(el)
  if not style then return nil end

  local title = el.attributes["title"]
  el.attributes["title"] = nil

  if FORMAT:match("latex") then
    local opts = style
    if title then
      opts = opts .. ",title={" .. title .. "}"
    end
    local out = pandoc.List()
    out:insert(pandoc.RawBlock("latex", "\\begin{tcolorbox}[" .. opts .. "]"))
    out:extend(el.content)
    out:insert(pandoc.RawBlock("latex", "\\end{tcolorbox}"))
    return out
  end

  -- HTML and everything else: prepend a title div, keep the class for CSS.
  if title then
    local t = pandoc.Div(pandoc.Para(pandoc.Str(title)), pandoc.Attr("", { "title" }))
    el.content:insert(1, t)
  end
  el.classes:insert("bookgraybox")
  return el
end
