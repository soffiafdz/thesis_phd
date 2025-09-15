#!/usr/bin/env Rscript

## Packages
library("here")
library("data.table")
library("readr")
library("purrr")
library("stringr")

## IN
# Path to data
indir     <- "data/raw/qc_ratings/registration/balanced_data"

# Rater 1
expert_1  <- here(indir, "MULTI_99_Linear_Expert_2022-09-23.csv") |> fread()
expert_2  <- here(indir, "MULTI_99_Linear_Expert_2022-10-12.csv") |> fread()
expert_c  <- here(indir, "MULTI_99_Linear_Expert_consensus.csv") |>
  fread(header = FALSE)

# Trainees
trainees  <- here(indir, "MULTI_99_Linear_Trainees_2022-10-14.csv") |> fread()
tr_hist   <- here(indir, "MULTI_99_Linear_Trainees_History_2022-10-14.csv") |>
  fread()
rm(indir)

# Case dictionary
case_ids  <- here("data/raw/list_cases_linreg.csv") |> fread()

## Data cleaning
# Change colnames
setnames(expert_1, c("Image", "Rating", "Rater", "Comment", "Timestamp"))
setnames(expert_2, c("Image", "Rating", "Rater", "Comment", "Timestamp"))
setnames(expert_c, c("Image", "Rating", "Comment"))
setnames(trainees, c("Image", "Rating", "Rater", "Comment", "Timestamp"))
setnames(tr_hist, c("Image", "Rater", "Rating", "Comment", "Timestamp"))
setnames(case_ids, c("ID", "QC"), c("Image", "QC_orig"))

# Merge history and ratings (and remove duplicate rows)
trainees <- unique(rbindlist(list(trainees, tr_hist), use.names = TRUE))
rm(tr_hist)

# Remove duplicate rating for Case_33:Rater02
# Ground-truth is Fail (Checked current rating on Qrater)
trainees <- trainees[!(Image == "Case_33" &
                       Rater == "Rater02" &
                       Rating == 'Pass')]


# Extract most recent & non-Pending or Warning ratings from history
trainees <- trainees[trainees[!Rating %in% c("Pending", "Warning"),
                              .I[Timestamp == max(Timestamp)],
                              by = .(Image, Rater)]$V1]

# Mark passing session
expert_1[, Session := "First"]
expert_2[, Session := "Second"]
expert_c[, `:=`(Rater = "Expert01", Session = "Consensus")]
trainees[, Session := NA]

# Check numbers
#trainees[, .N, by = Rater]

# Add rater 1
reg_99 <- rbindlist(list(expert_1, expert_2, expert_c, trainees),
                    use.names = TRUE, fill = TRUE)
rm(expert_1, expert_2, expert_c, trainees)

## Timing
setorder(reg_99, cols = "Timestamp")
raters_names <- reg_99[, unique(Rater)]
for (i in seq_along(raters_names)) {
    reg_99[Rater == raters_names[[i]], Diff := Timestamp - shift(Timestamp)]
}
rm(i, raters_names)

## Load original QC
reg_99 <- case_ids[, .(Image, QC_orig)][reg_99, on = "Image"]

# Leading 0 for Cases
reg_99[, Image := map_chr(str_split(Image, "_"),
                          ~ paste(.[[1]],
                                  sprintf("%03d", as.integer(.[[2]])),
                                  sep = "_"))]

## Matrix of comments
setorder(reg_99, cols = "Rater")
reg_99_comments <- reg_99[
  (!Session %in% c("First", "Second")) & Image %in% reg_99[
    Session == "Consensus" & Rating == "Fail", Image],
  .(Image, Rater, Comment)] %>%
    dcast(Image ~ Rater, value.var = "Comment")
#reg_99_comments[1]


## OUT
# Cleaned QC ratings
outdir    <- here("data/qc-ratings_clean/linear_registration")
if (!dir.exists(outdir)) dir.create(outdir)
case_ids[reg_99, on = "Image",
         .(Database, Subject, Session, RegistMethod = Method,
           QC_orig, Rating, Comment, Rater, Session)] |>
  fwrite(here(outdir, "MULTI-99_qc-ratings.csv"))
rm(case_ids)

# TSV (Comments)
outdir    <- here("data/derivatives")
if (!dir.exists(outdir)) dir.create(outdir)
write_delim(reg_99_comments, here(outdir, "reg_99_comments.csv"), delim = "\t")
rm(reg_99_comments)

# Data.table RDS
write_rds(reg_99, here(outdir, "registration_99_dt.rds"))
rm(outdir)
