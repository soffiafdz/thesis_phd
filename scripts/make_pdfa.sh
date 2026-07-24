#!/usr/bin/env bash
# Convert the rendered thesis PDF to PDF/A-2b for McGill myThesis
# submission. Run AFTER `quarto render`.
#
#   scripts/make_pdfa.sh
#
# Produces a PDF/A-2b file in place (same name) under _book/.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
PDF="$HERE/_book/Fernandez-Lozano_Sofia_IPN_thesis.pdf"
DEF="$HERE/scripts/pdfa_def.ps"
TMP="$(mktemp --suffix=.pdf)"

[ -f "$PDF" ] || { echo "Render first: $PDF not found"; exit 1; }

gs -dPDFA=2 -dBATCH -dNOPAUSE -dNOOUTERSAVE \
   -sColorConversionStrategy=RGB \
   -sDEVICE=pdfwrite -dPDFACompatibilityPolicy=1 \
   -sOutputFile="$TMP" "$DEF" "$PDF"

mv "$TMP" "$PDF"
echo "PDF/A-2b written: $PDF"
