# =============================================================================
# Thesis-level Common Setup for Quarto Documents
# =============================================================================
# Source this file in the setup chunk of each chapter .qmd that uses R:
#
#   ```{r setup}
#   library(here)
#   source(here("_common.R"))
#   ```
#
# Provides:
#   - Core library loading
#   - Global options
#   - gt LaTeX rendering override (consolidated from Papers 3 & 4)
# =============================================================================

# ----- Core Libraries -----
library(data.table)
library(gt)
library(ggplot2)

# ----- Global Options -----
options(scipen = 999, digits = 3)

# ----- gt LaTeX Rendering Override -----
# Override gt's knit_print to produce clean LaTeX output for PDF.
# Consolidated from hvr_sex_differences and hvr_cvr_mediation.
# For HTML output, gt's default rendering is used unchanged.
registerS3method("knit_print", "gt_tbl", function(x, ...) {
  if (knitr::is_latex_output()) {
    latex_code <- as.character(gt::as_latex(x))

    # 0. Strip gt's outer \begin{table}...\end{table} float wrapper.
    #    Quarto provides its own float via tbl-cap; keeping gt's
    #    wrapper creates nested floats that can drop content.
    strip_pat <- paste0(
      "(?s)^.*?(\\\\fontsize\\{[^}]+\\}\\{[^}]+\\}",
      "\\\\selectfont\\s*\n?",
      "\\\\begin\\{(?:tabular|longtable))"
    )
    if (grepl(strip_pat, latex_code, perl = TRUE)) {
      latex_code <- sub(strip_pat, "\\1", latex_code, perl = TRUE)
    } else {
      latex_code <- sub(
        "(?s)^.*?(\\\\begin\\{(?:tabular|longtable))",
        "\\1", latex_code, perl = TRUE
      )
    }
    latex_code <- sub(
      "\\\\end\\{table\\}\\s*$", "", latex_code
    )

    # 1. Fix table width: tabular* → tabular
    latex_code <- gsub(
      paste0(
        "\\\\begin\\{tabular\\*\\}",
        "\\{\\\\linewidth\\}",
        "\\{@\\{\\\\extracolsep\\{\\\\fill\\}\\}"
      ),
      "\\\\begin{tabular}{",
      latex_code
    )
    latex_code <- gsub(
      "\\\\end\\{tabular\\*\\}",
      "\\\\end{tabular}",
      latex_code
    )

    # 2. Fix HTML tags that fmt_markdown() produces
    latex_code <- gsub(
      "<em>([^<]+)</em>",
      "\\\\textit{\\1}", latex_code
    )
    latex_code <- gsub(
      "<strong>([^<]+)</strong>",
      "\\\\textbf{\\1}", latex_code
    )
    latex_code <- gsub(
      "<sub>([^<]+)</sub>",
      "\\\\textsubscript{\\1}", latex_code
    )
    latex_code <- gsub(
      "<sup>([^<]+)</sup>",
      "\\\\textsuperscript{\\1}", latex_code
    )

    # 3. Fix Unicode symbols not in default LaTeX font
    unicode_map <- list(
      # Greek letters
      "\u0394" = "$\\\\Delta$",
      "\u03B2" = "$\\\\beta$",
      "\u03BB" = "$\\\\lambda$",
      "\u03C3" = "$\\\\sigma$",
      "\u03B7" = "$\\\\eta$",
      "\u03C7" = "$\\\\chi$",
      "\u03C4" = "$\\\\tau$",
      "\u03B3" = "$\\\\gamma$",
      # Superscripts / math
      "\u00B2" = "\\\\textsuperscript{2}",
      # Relational
      "\u2264" = "$\\\\leq$",
      "\u2265" = "$\\\\geq$",
      "\u2260" = "$\\\\neq$",
      # Operators
      "\u00D7" = "$\\\\times$"
    )
    for (uc in names(unicode_map)) {
      latex_code <- gsub(
        uc, unicode_map[[uc]], latex_code
      )
    }

    # 4. Fix Unicode text commands missing {} terminator
    latex_code <- gsub(
      paste0(
        "\\\\(texttimes|texttwosuperior|",
        "texttwosuperiorp|textendash|textemdash)",
        "([A-Za-z])"
      ),
      "\\\\\\1{}\\2", latex_code
    )

    # 5. Fix footnote/source note minipage width
    latex_code <- gsub(
      "\\\\begin\\{minipage\\}\\{\\\\linewidth\\}",
      paste0(
        "\\\\begin{minipage}[t]{0.8\\\\textwidth}",
        "\\\\raggedright\\\\small"
      ),
      latex_code
    )

    # 6. Enforce column alignment (first left, rest right)
    fix_alignment.fn <- function(code) {
      pattern <- paste0(
        "(\\\\begin\\{(?:tabular|longtable)\\}\\{)",
        "([lcr]+)(\\})"
      )
      m <- gregexpr(pattern, code, perl = TRUE)
      if (m[[1]][1] == -1) return(code)
      matches <- regmatches(code, m)[[1]]
      for (match in matches) {
        col_spec <- gsub(
          ".*\\{([lcr]+)\\}$", "\\1", match
        )
        n_cols <- nchar(col_spec)
        if (n_cols > 1) {
          new_spec <- paste0(
            "l",
            paste(rep("r", n_cols - 1), collapse = "")
          )
          new_match <- gsub(
            "\\{[lcr]+\\}$",
            paste0("{", new_spec, "}"),
            match
          )
          code <- sub(
            match, new_match, code, fixed = TRUE
          )
        }
      }
      code
    }
    latex_code <- fix_alignment.fn(latex_code)

    # 7. Add consistent table spacing
    latex_code <- gsub(
      "\\\\begin\\{tabular\\}",
      paste0(
        "\\\\renewcommand{\\\\arraystretch}{1.15}",
        "\\\\begin{tabular}"
      ),
      latex_code
    )

    # 8. Center each tabular inside the float
    latex_code <- gsub(
      paste0(
        "(\\\\renewcommand\\{\\\\arraystretch\\}",
        "\\{1\\.15\\})",
        "(\\\\begin\\{tabular\\})"
      ),
      "\\\\begin{center}\\1\\2",
      latex_code
    )
    latex_code <- gsub(
      "\\\\end\\{tabular\\}",
      "\\\\end{tabular}\\\\end{center}",
      latex_code
    )

    # 9. Escape bare [ ] in table cells (protect LaTeX)
    latex_code <- gsub(
      "\\\\addlinespace\\[([^]]+)\\]",
      "<<ADDLNSP_\\1_>>", latex_code
    )
    latex_code <- gsub(
      "\\\\\\\\\\[([0-9.]+pt)\\]",
      "<<LINEBRK_\\1_>>", latex_code
    )
    latex_code <- gsub(
      "\\\\begin\\{minipage\\}\\[([a-z])\\]",
      "<<MINIPAGE_\\1_>>", latex_code
    )
    latex_code <- gsub("\\[", "{[}", latex_code)
    latex_code <- gsub("\\]", "{]}", latex_code)
    latex_code <- gsub(
      "<<ADDLNSP_([^_]+)_>>",
      "\\\\addlinespace[\\1]", latex_code
    )
    latex_code <- gsub(
      "<<LINEBRK_([^_]+)_>>",
      "\\\\\\\\[\\1]", latex_code
    )
    latex_code <- gsub(
      "<<MINIPAGE_([a-z])_>>",
      "\\\\begin{minipage}[\\1]", latex_code
    )

    knitr::asis_output(latex_code)
  } else {
    gt:::knit_print.gt_tbl(x, ...)
  }
}, envir = asNamespace("knitr"))

message("=== thesis _common.R loaded ===")
