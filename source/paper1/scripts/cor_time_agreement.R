#!/usr/bin/env Rscript

## Packages
library("here")
library("data.table")
library("readr")

## IN
path        <- here("data/derivatives")
fnames      <- here(path, c("qc_count_acq_dt.rds", "qc_count_reg_dt.rds",
                            "acq_99_time_dt.rds", "reg_99_time_dt.rds"))

# Agreement data
if (any(!file.exists(fnames[1:2]))) {
  source(here("scripts/agreement.R"))
} else {
  acq_99_count <- read_rds(fnames[1])
  reg_99_count <- read_rds(fnames[2])
}

# Timing data
if (any(!file.exists(fnames[3:4]))) {
  source(here("scripts/timing.R"))
} else {
  acq_99_time_dt <- read_rds(fnames[3])
  reg_99_time_dt <- read_rds(fnames[4])
}
rm(fnames)


## Data Cleaning
# Acquisition
acq_99 <- acq_99_time_dt[Rater %like% "Rater",
                         .(Total = sum(as.numeric(Diff), na.rm = T),
                           Median = median(as.numeric(Diff), na.rm = T)),
                         Rater]
acq_99[, Agree := acq_99_count[order(Rater)][Rater2 == "E01", Count]]

# Registration
reg_99 <- reg_99_time_dt[Rater %like% "Rater",
                         .(Total = sum(as.numeric(Diff), na.rm = T),
                           Median = median(as.numeric(Diff), na.rm = T)),
                         Rater]
reg_99[, Agree := reg_99_count[order(Rater)][Rater2 == "E01", Count]]



## Correlation of Agreement (Count) and Time
# Acquisition
acq_99_agree_time_tot <- acq_99[, cor.test(Agree, Total, method = "spearman")]
acq_99_agree_time_med <- acq_99[, cor.test(Agree, Median, method = "spearman")]
rm(acq_99)

# Registration
reg_99_agree_time_tot <- reg_99[, cor.test(Agree, Total, method = "spearman")]
reg_99_agree_time_med <- reg_99[, cor.test(Agree, Median, method = "spearman")]
rm(reg_99)
