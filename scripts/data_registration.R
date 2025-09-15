#!/usr/bin/env Rscript

## Packages
library("here")
library("data.table")
library("readr")
library("stringr")

## IN
regis <- here("data/raw/qc_ratings/registration/complete_data") |>
  list.files(full.names = TRUE) |>
  str_subset("ADNI_Linear_Rater0\\d_Ratings") |>
  lapply(fread) |>
  rbindlist()

## Data Cleaning
setnames(regis, c("Image", "Rater", "Rating", "Comment", "Timestamp"))

regis <- regis[Rating != "Pending"]

# Timing
setorder(regis, cols = "Timestamp")
raters_names <- regis[, unique(Rater)]
for (i in seq_along(raters_names)) {
  rater <- raters_names[[i]]
  regis[Rater == rater, Diff := Timestamp - shift(Timestamp)]
}
rm(i, rater, raters_names)

## OUT
# Cleaned QC ratings
outdir    <- here("data/qc-ratings_clean/linear_registration")
if (!dir.exists(outdir)) dir.create(outdir)
regis[, .(Image, Rating, Comment, Rater)] |>
  fwrite(here(outdir, "ADNI_qc-ratings.csv"))

## Write RDS
outdir    <- here("data/derivatives")
if (!dir.exists(outdir)) dir.create(outdir)
write_rds(regis, here("data/derivatives/registration_dt.rds"))
rm(outdir)
