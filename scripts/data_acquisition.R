#!/usr/bin/env Rscript

## Packages
library("here")
library("data.table")
library("readr")

## IN
indir     <- "data/raw/qc_ratings/raw/complete_data"
acquis_e  <- here(indir, "ADNI_Raw_Expert_2022-11-23.csv") |> fread()
acquis_t  <- here(indir, "ADNI_Raw_Trainees_2022-06-29.csv") |> fread()
rm(indir)

## Data cleaning
setnames(acquis_e, c("Image", "Rater", "Rating", "Comment", "Time"))
setnames(acquis_t, c("Image", "Rater", "Rating", "Time", "Comment"))
acquis_t  <- acquis_t[Rating != "Pending"]

## Merge data
acquis <- rbindlist(list(acquis_e, acquis_t), use.names = TRUE)
rm(acquis_e, acquis_t)

## Timing
setorder(acquis, cols = "Time")
for (rater in acquis[, unique(Rater)]) {
    acquis[Rater == rater, Diff := Time - shift(Time)]
}
rm(rater)

# Remove duplicate rating:
acquis <- acquis[-6355]

## OUT
# Cleaned QC ratings
outdir      <- here("data/qc-ratings_clean/raw")
if (!dir.exists(outdir)) dir.create(outdir)
acquis[, .(Image, Rating, Comment, Rater)] |>
  fwrite(here(outdir, "ADNI_qc-ratings.csv"))

# Data.table RDS
outdir      <- here("data/derivatives")
if (!dir.exists(outdir)) dir.create(outdir)
acquis |> write_rds(here(outdir, "acquisition_dt.rds"))
rm(outdir)
