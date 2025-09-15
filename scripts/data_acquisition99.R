#!/usr/bin/env Rscript

## Packages
library("here")
library("data.table")
library("readr")

## IN
# Path to data
indir     <- here("data/raw/qc_ratings/raw/balanced_data")

# Rater 1
expert_1  <- here(indir, "NACC_99_Expert_2022-09-23.csv") |> fread()
expert_2  <- here(indir, "NACC_99_Expert_2022-10-28.csv") |> fread()
expert_c  <- here(indir, "NACC_99_Expert_consensus.csv") |>
  fread(header = FALSE)

# Trainees: Rater 2-10
trainees  <- here(indir, "NACC_99_Trainees_2022-04-05.csv") |> fread()
rm(indir)

# Case dictionary
case_ids  <- here("data/raw/nacc/CaseIDs.csv") |> fread()

## Data cleaning
# Change colnames
setnames(expert_1, c("Image", "Rating", "Rater", "Comment", "Time"))
setnames(expert_2, c("Image", "Rating", "Rater", "Comment", "Time"))
setnames(expert_c, c("Image", "Rating", "Comment"))
setnames(trainees, c("Image", "Rater", "Rating", "Comment", "Time"))

# Assign Session No
expert_1[, Session := "First"]
expert_2[, Session := "Second"]
expert_c[, Session := "Consensus"]
trainees[, Session := NA]

# Change Rater 8's Warning -> Pass
trainees[Rater == "Rater08" & Rating == "Warning", Rating := "Pass"]

# Join expert's two timepoints
expert    <- rbindlist(list(expert_1, expert_2, expert_c),
                       use.names = TRUE, fill = TRUE)
expert[is.na(Rater), Rater := "Expert01"]
rm(expert_1, expert_2, expert_c)

## Timing
setorder(expert, cols = "Time")
expert[!is.na(Time) & Session == "First", Diff := Time - shift(Time)]
expert[!is.na(Time) & Session == "Second", Diff := Time - shift(Time)]

setorder(trainees, cols = "Time")
trainees_ids  <- trainees[, unique(Rater)]
for (i in seq_along(trainees_ids)) {
    rater     <- trainees_ids[[i]]
    trainees[Rater == rater, Diff := Time - shift(Time)]
}
rm(i, rater, trainees_ids)

## Merge all raters
acq_99    <- rbindlist(list(expert, trainees), fill = TRUE)
rm(expert, trainees)

## Leading 0 for Cases
acq_99[, Image := purrr::map_chr(
  stringr::str_split(Image, "_"),
  ~ paste(.[[1]], sprintf("%02d", as.integer(.[[2]])), sep = "_")
)]

## Matrix of comments
setorder(acq_99, cols = "Rater")
acq_99_comments <- acq_99[
  (!Session %in% c("First", "Second")) & Image %in% acq_99[
    Session == "Consensus" & Rating == "Fail", Image],
  .(Image, Rater, Comment)] |>
    dcast(Image ~ Rater, value.var = "Comment")
#acq_99_comments[1]

## Original Label
case_ids[, QC := factor(QC,
                        levels = c("Pass", "Warn", "Fail"),
                        labels = c("Pass", "Borderline", "Fail"))]
acq_99    <- case_ids[, .(Image_fname = ID, QC_orig = QC, Image_case = CaseID)
                      ][acq_99, on = .(Image_case = Image)]
rm(case_ids)

## OUT
# Cleaned QC ratings
outdir    <- here("data/qc-ratings_clean/raw")
if (!dir.exists(outdir)) dir.create(outdir)
acq_99[, .(Image = Image_fname, QC_orig, Rating, Comment, Rater, Session)] |>
  fwrite(here(outdir, "NACC-99_qc-ratings.csv"))

# TSV (Comments)
outdir    <- here("data/derivatives")
if (!dir.exists(outdir)) dir.create(outdir)
write_delim(acq_99_comments, here(outdir, "acq_99_comments.csv"), delim = "\t")
rm(acq_99_comments)

# Data.table RDS
write_rds(acq_99, here(outdir, "acquisition_99_dt.rds"))
rm(outdir)
