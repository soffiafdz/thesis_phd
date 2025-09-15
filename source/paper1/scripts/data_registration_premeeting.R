#!/usr/bin/env Rscript

## Packages
library("here")
library("data.table")
library("readr")
library("stringr")
library("lubridate")

## IN
regis_list <- here("data/raw/qc_ratings/registration/pre_meeting") |>
  list.files(full.names = TRUE) |>
  str_subset("ADNI_Linear_Rater0\\d_history_2023-08-03") |>
  lapply(fread)

## Data cleaning
for (i in seq_along(regis_list)) {
  regis_list[[i]][, V4 := sprintf("Rater%02d", i)]
}

regis_pre <- rbindlist(regis_list)
setnames(regis_pre, c("Image", "Rating", "Timestamp", "Rater"))
regis_pre <- regis_pre[regis_pre[Timestamp < ymd(20221020),
                                 .I[Timestamp == max(Timestamp)],
                                 .(Image, Rater)]$V1]
#rm(regis_list)

## OUT
outdir    <- here("data/derivatives")
if (!dir.exists(outdir)) dir.create(outdir)
write_rds(regis_pre, here(outdir, "registration_premeeting_dt.rds"))
rm(outdir)
