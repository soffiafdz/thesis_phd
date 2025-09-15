#!/usr/bin/env Rscript

## Packages
library("here")
library("data.table")
library("readr")

## IN
rskull <- here("data/raw/qc_ratings/skull/ADNI_Skull_Experts_2022-09-23.csv") |>
  fread()
setnames(rskull, c("Image", "Rating", "Rater", "Time"))

## Timing
setorder(rskull, cols = "Time")
for (rater in c("Expert01", "Expert02")) {
    rskull[Rater == rater, Diff := Time - shift(Time)]
}
rm(rater)

## OUT
# Cleaned QC ratings
outdir    <- here("data/qc-ratings_clean/skull_segmentation")
if (!dir.exists(outdir)) dir.create(outdir)
rskull[, .(Image, Rating, Rater)] |>
  dcast(Image ~ Rater, value.var = "Rating") |>
  fwrite(here(outdir, "ADNI_qc-ratings.csv"))

# Write RDS
outdir    <- here("data/derivatives")
if (!dir.exists(outdir)) dir.create(outdir)
write_rds(rskull, here("data/derivatives/segmentation_dt.rds"))
rm(outdir)
