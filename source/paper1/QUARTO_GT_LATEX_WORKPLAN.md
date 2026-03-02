# Workplan: gt Tables in Quarto-to-LaTeX Thesis Pipeline

## Context

Research projects that use Quarto (`.qmd`) documents for drafting manuscripts or thesis chapters often rely on the `gt` package for table formatting. These documents serve a dual purpose:

1. **HTML output** for iterative review during drafting
2. **LaTeX output** for inclusion in a thesis compiled with a LaTeX document class

The pipeline is: `Quarto (.qmd) → render → .tex file → \input{} in thesis main.tex`

## Problem

gt's integration with Quarto's PDF/LaTeX pipeline produces several issues:

### 1. Table width
Tables stretch to full page width (`\textwidth`) regardless of content. This is because Quarto wraps gt output in containers that enforce full-width layout.

### 2. `fmt_markdown()` emits HTML in LaTeX
gt's `fmt_markdown()` function renders inline formatting as HTML (`<em>`, `<sub>`, etc.) even when the output target is LaTeX. These tags appear as literal text in the PDF.

### 3. Quarto processing interference
Quarto's post-processing of table output can add wrappers, rewrite captions, or alter the table environment in ways that conflict with thesis class requirements.

### 4. Caption/label conflicts
gt produces `\caption{}` and `\label{}` inside longtable environments. Thesis classes may expect these to be handled differently (e.g., via `\captionof`, custom float environments, or external `\addcontentsline` calls).

## Solution: Override `knit_print.gt_tbl`

Intercept gt objects at render time with a custom S3 method. For LaTeX output, bypass Quarto's default pipeline and emit `gt::as_latex()` directly with optional post-processing.

### Why this approach

| Approach | Pros | Cons |
|----------|------|------|
| **knit_print override** | Zero qmd changes; single control point; clean LaTeX output | Overrides gt internal method |
| Modify terminal pipe function | Explicit; already wired in | Changes return type by format; needs `output: asis` |
| Conditional chunks per format | Full control | 2× code duplication; maintenance burden |
| Switch to kableExtra for PDF | Mature LaTeX backend | Lose gt styling; duplicated formatting logic |

The knit_print override wins because:
- **No qmd changes**: All existing table code works unmodified
- **Centralized**: One file controls all table rendering behavior
- **Post-processing hook**: LaTeX output can be adjusted for thesis compatibility in one place
- **Format-aware**: Only activates for LaTeX; HTML rendering unchanged
- **Portable**: The same `_common.R` pattern works across projects

## Implementation

### Step 1: YAML header configuration

Add `latex` as an explicit format alongside `html` and `pdf`:

```yaml
format:
  html:
    toc: true
    embed-resources: true
  pdf:
    toc: true
    documentclass: article
    geometry:
      - margin=1in
    include-in-header:
      text: |
        \usepackage{booktabs}
        \usepackage{longtable}
        \usepackage{array}
        % Prevent longtables from stretching to full width
        \setlength{\LTleft}{0pt}
        \setlength{\LTright}{\fill}
```

To produce a `.tex` file for thesis inclusion, render with:
```bash
quarto render document.qmd --to pdf
# The intermediate .tex is in the _output/ or alongside the .qmd
# Or use: quarto render document.qmd --to latex (Quarto 1.4+)
```

### Step 2: Register knit_print override

In your shared setup file (e.g., `_common.R` or `reports-src/_setup.R`):

```r
# Override gt's knit_print method for LaTeX-quality table output
# This ensures gt tables produce clean longtable environments
# compatible with thesis document classes.
registerS3method("knit_print", "gt_tbl", function(x, ...) {
  if (knitr::is_latex_output()) {
    latex_code <- as.character(gt::as_latex(x))

    # Post-processing for thesis compatibility (optional, adjust as needed):

    # 1. Remove \centering if your thesis class handles alignment
    # latex_code <- gsub("\\\\centering\n", "", latex_code)

    # 2. Replace longtable with tabular if chapters don't need page breaks
    # (only for short tables; longtable is fine for most cases)

    # 3. Adjust caption placement or format if needed
    # latex_code <- gsub("\\\\caption\\{", "\\\\caption[short]{", latex_code)

    knitr::asis_output(latex_code)
  } else {
    # HTML: use gt's default rendering
    gt:::knit_print.gt_tbl(x, ...)
  }
})
```

### Step 3: Handle `fmt_markdown()` incompatibility

For tables that use inline formatting (italics, subscripts, etc.), replace `fmt_markdown()` with format-aware alternatives:

**Option A**: Use Unicode characters (simplest, works everywhere):
```r
# Instead of: fmt_markdown(columns = "Variable")
# Use Unicode directly in data:
dt[, Variable := gsub("g", "\u0067", Variable)]  # italic g → use actual symbol
dt[, Variable := gsub("Speed_s", "Speed\u209B", Variable)]  # subscript s
```

**Option B**: Conditional formatting function:
```r
fmt_crossformat <- function(gt_tbl, columns, rows = everything()) {
  if (knitr::is_latex_output()) {
    # Apply LaTeX formatting
    fmt(gt_tbl, columns = columns, rows = rows, fns = function(x) {
      x <- gsub("\\*([^*]+)\\*", "\\\\textit{\\1}", x)  # *italic*
      x <- gsub("~([^~]+)~", "\\\\textsubscript{\\1}", x)  # ~sub~
      x
    })
  } else {
    fmt_markdown(gt_tbl, columns = columns, rows = rows)
  }
}
```

### Step 4: Style function for consistent table appearance

Keep a terminal pipe function that applies consistent styling without interfering with the knit_print override:

```r
style_thesis_table <- function(gt_tbl, font_size = 10) {
  gt_tbl |>
    tab_options(
      table.font.size = px(font_size),
      heading.title.font.size = px(font_size + 2),
      heading.subtitle.font.size = px(font_size),
      column_labels.font.size = px(font_size),
      table.width = NULL,  # Don't force width
      quarto.disable_processing = TRUE  # Prevent Quarto HTML wrappers
    ) |>
    opt_horizontal_padding(scale = 2)
}
```

### Step 5: Quarto chunk options for tables

Ensure table chunks use appropriate options:

```r
#| label: tbl-my-table
#| tbl-cap: "Table caption goes here for Quarto cross-referencing."
```

Notes:
- `tbl-cap` in the chunk header is used by Quarto for cross-referencing (`@tbl-my-table`)
- gt's own `tab_header(title = ...)` produces the visible title in the table itself
- For thesis: you may want to remove `tab_header()` and rely solely on `tbl-cap` to avoid duplicate captions. Alternatively, keep `tab_header()` for the HTML draft and strip it in the knit_print post-processing.

## Verification

After implementing, verify both outputs:

```bash
# HTML (for review)
quarto render document.qmd --to html

# PDF (check table rendering)
quarto render document.qmd --to pdf
```

Check for:
- [ ] Tables are not full-width in PDF
- [ ] Inline formatting (italics, subscripts) renders correctly
- [ ] Captions and labels are present and correct
- [ ] Cross-references (`@tbl-*`) resolve in both formats
- [ ] Tables don't break across pages unexpectedly (or do so gracefully with longtable)

## Thesis Integration Notes

### Including rendered .tex in thesis

```latex
% In thesis main.tex
\chapter{My Chapter}
\input{chapters/my_chapter}  % The .tex from quarto render
```

Potential issues:
- Quarto's `.tex` output includes `\begin{document}` / preamble — you'll need to extract just the body content
- Alternative: use Quarto Book format with `thesis` as the project type

### Quarto Book format (recommended for multi-chapter theses)

If the thesis has multiple Quarto chapters, consider using Quarto's book project:

```yaml
# _quarto.yml
project:
  type: book
  output-dir: _thesis

book:
  title: "My Thesis"
  chapters:
    - index.qmd
    - chapter1.qmd
    - chapter2.qmd

format:
  pdf:
    documentclass: report  # or your thesis class
```

This produces a single compiled PDF with all chapters, handling cross-references across chapters automatically.

### Standalone chapter extraction

If you need individual `.tex` chapter files for inclusion in an external thesis template:

```bash
# Render to LaTeX without compiling
quarto render chapter.qmd --to latex --no-execute
# Or with execution:
quarto render chapter.qmd --to pdf --keep-tex
```

The `--keep-tex` flag preserves the intermediate `.tex` file alongside the PDF.

## Applicability

This workplan applies to any project that:
1. Uses `gt` for table formatting in `.qmd` documents
2. Needs both HTML preview and LaTeX/PDF output
3. Will eventually integrate into a LaTeX thesis or report

The knit_print override pattern is project-agnostic — copy the `registerS3method()` block into any project's common setup file.
