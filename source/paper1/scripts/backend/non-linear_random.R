#!/usr/bin/env Rscript

library("here")
library("data.table")

# Read Louis' ratings
ratings <- fread(here('data/raw/QC-nlin_Louis_all-raters_2022-12-08.csv'),
                 header = F, drop = 2, col.names = c("id", "qc", "comm"))

# All Fail: N=39
fails <- ratings[qc == "Fail"]

# All Warnings: N = 26
warnings <- ratings[qc == "Warning"]

# Passes
# 13 no comments
pass_clear <- ratings[qc == "Pass" & comm == "", .SD[sample(.N, 13)]]
# 21 with comments
pass_comms <- ratings[qc == "Pass" & comm != "", .SD[sample(.N, 21)]]

# Merge all together in list and reorder
final <- rbindlist(list(fails, warnings, pass_clear, pass_comms))
setorder(final, id)

final_ids <- final[, .(id)]
fwrite(final_ids, here('data/derivatives/nlin_ids.lst'), col.names = FALSE)
