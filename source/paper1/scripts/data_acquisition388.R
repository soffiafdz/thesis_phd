#!/usr/bin/env Rscript

## Packages
library("here")
library("data.table")
library("readr")

## IN
# Ratings
indir       <- here("data/raw/qc_ratings/raw/balanced_data/")
acq_388     <- here(indir, "NACC_338_Experts_2022-01-14.csv") |> fread()
rm(indir)

# Case Dictionary
case_ids    <- fread(here("data/raw/nacc/CaseIDs.csv"))

## Merge data
acq_388     <- case_ids[acq_388, on = "ID",
                        .(Image_fname = ID, Image_case = CaseID,
                          Expert1, Expert2)]
rm(case_ids)

## OUT
# Cleaned QC ratings
outdir      <- here("data/qc-ratings_clean/raw")
if (!dir.exists(outdir)) dir.create(outdir)
acq_388 |> fwrite(here(outdir, "NACC-338_qc-ratings.csv"))

# Data.table RDS
outdir      <- here("data/derivatives")
if (!dir.exists(outdir)) dir.create(outdir)
acq_388 |> write_rds(here(outdir, "acquisition_388_dt.rds"))
rm(outdir)
