# ===========================================================
# Thesis-level Common Setup for Quarto Documents
# ===========================================================
# Source this file in the setup chunk of each chapter .qmd:
#
#   ```{r setup}
#   library(here)
#   source(here("_common.R"))
#   ```
#
# Provides:
#   - Core library loading
#   - Global options
#   - gt LaTeX rendering override for thesis PDF
# ===========================================================

# ----- Core Libraries -----
library(data.table)
library(gt)
library(ggplot2)

# ----- Global Options -----
options(scipen = 999, digits = 3)

# ----- gt LaTeX Rendering Override -----
# Intercepts every gt table before PDF rendering to:
#   1. Standardize font size (9pt) across all chapters
#   2. Force tabular (no page-breaking longtable)
#   3. Prevent \fontsize from leaking into body text
#   4. Fix overflow, alignment, Unicode, and HTML tags
registerS3method(
  "knit_print", "gt_tbl",
  function(x, ...) {
    if (knitr::is_latex_output()) {
      # -- Check per-table attributes --
      scale_to_fit <- isTRUE(attr(x, "scale_to_fit"))

      # -- Standardize gt options BEFORE LaTeX conversion --
      font_sz <- if (scale_to_fit) "7pt" else "9pt"
      note_sz <- if (scale_to_fit) "6pt" else "8pt"
      x <- x |>
        gt::tab_options(
          table.font.size = font_sz,
          column_labels.font.size = font_sz,
          column_labels.font.weight = "bold",
          footnotes.font.size = note_sz,
          source_notes.font.size = note_sz,
          latex.use_longtable = FALSE
        )

      latex_code <- as.character(gt::as_latex(x))

      # 0. Strip gt's outer \begin{table}...\end{table}
      #    Quarto provides its own float via tbl-cap.
      strip_pat <- paste0(
        "(?s)^.*?",
        "(\\\\fontsize\\{[^}]+\\}\\{[^}]+\\}",
        "\\\\selectfont\\s*\\n?",
        "\\\\begin\\{(?:tabular|longtable))"
      )
      if (grepl(strip_pat, latex_code, perl = TRUE)) {
        latex_code <- sub(
          strip_pat, "\\1", latex_code, perl = TRUE
        )
      } else {
        latex_code <- sub(
          "(?s)^.*?(\\\\begin\\{(?:tabular|longtable))",
          "\\1", latex_code, perl = TRUE
        )
      }
      latex_code <- sub(
        "\\\\end\\{table\\}\\s*$", "", latex_code
      )
      latex_code <- sub(
        paste0(
          "(\\\\end\\{(?:longtable|tabular)\\})",
          "\\n*\\\\endgroup"
        ),
        "\\1", latex_code, perl = TRUE
      )

      # 1. tabular* -> tabular
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

      # 2. Fix HTML tags from fmt_markdown()
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

      # 3. Fix Unicode symbols
      unicode_map <- list(
        "\u0394" = "$\\\\Delta$",
        "\u03B2" = "$\\\\beta$",
        "\u03BB" = "$\\\\lambda$",
        "\u03C3" = "$\\\\sigma$",
        "\u03B7" = "$\\\\eta$",
        "\u03C7" = "$\\\\chi$",
        "\u03C4" = "$\\\\tau$",
        "\u03B3" = "$\\\\gamma$",
        "\u00B2" = "\\\\textsuperscript{2}",
        "\u2264" = "$\\\\leq$",
        "\u2265" = "$\\\\geq$",
        "\u2260" = "$\\\\neq$",
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
          "\\\\begin{minipage}[t]{0.9\\\\textwidth}",
          "\\\\raggedright\\\\small"
        ),
        latex_code
      )

      # 6. Enforce column alignment
      #    (first column left, rest right)
      fix_alignment.fn <- function(code) {
        pat <- paste0(
          "(\\\\begin\\{(?:tabular|longtable)\\}\\{)",
          "([lcr|]+)(\\})"
        )
        m <- gregexpr(pat, code, perl = TRUE)
        if (m[[1]][1] == -1) return(code)
        matches <- regmatches(code, m)[[1]]
        for (match in matches) {
          col_spec <- gsub(
            ".*\\{([lcr|]+)\\}$", "\\1", match
          )
          pure <- gsub("\\|", "", col_spec)
          n_cols <- nchar(pure)
          if (n_cols > 1) {
            new_pure <- paste0(
              "l",
              paste(rep("r", n_cols - 1), collapse = "")
            )
            # Re-insert | separators at original positions
            pipe_pos <- gregexpr("\\|", col_spec)[[1]]
            new_spec <- new_pure
            if (pipe_pos[1] != -1) {
              # Insert pipes at their original positions
              for (p in rev(pipe_pos)) {
                adj <- p - sum(pipe_pos < p)
                if (adj <= nchar(new_spec)) {
                  new_spec <- paste0(
                    substr(new_spec, 1, adj - 1),
                    "|",
                    substr(
                      new_spec, adj, nchar(new_spec)
                    )
                  )
                }
              }
            }
            new_match <- gsub(
              "\\{[lcr|]+\\}$",
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

      # 7. Add consistent row spacing
      latex_code <- gsub(
        "(\\\\begin\\{tabular\\})",
        "\\\\renewcommand{\\\\arraystretch}{1.05}\\1",
        latex_code
      )

      # 8. Escape bare [ ] in table cells
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

      # 9. Contain font-size in a group so it does not
      #    leak into body text.
      #    - \begingroup/\endgroup contains font changes
      #    - Reduced \tabcolsep prevents wide-table overflow
      #    - scale_to_fit uses 2pt colsep for tighter fit
      colsep <- if (scale_to_fit) "2pt" else "3pt"
      latex_code <- paste0(
        "\\begingroup",
        "\\setlength{\\tabcolsep}{", colsep, "}\n",
        latex_code,
        "\n\\endgroup"
      )

      knitr::asis_output(latex_code)
    } else {
      gt:::knit_print.gt_tbl(x, ...)
    }
  },
  envir = asNamespace("knitr")
)

message("=== thesis _common.R loaded ===")
