#!/usr/bin/env Rscript

## Packages
library("here")
library("data.table")
library("readr")

# Raw acquisition
fpath <- here("data/derivatives/acquisition_dt.rds")

if (!file.exists(fpath)) {
  source(here("scripts/data_acquisition.R"))
} else {
  acquis <- read_rds(fpath)
}

rm(fpath)

# Create lists
qc_acquis <- acquis[, .(Image, Rating, Comment)]
acquis_fail <- acquis[Rating == "Fail", .(Image)]

# Export products
fwrite(qc_acquis,
       here("data/derivatives/adni_acquisition_qc.csv"),
       col.names = FALSE)

fwrite(acquis_fail,
       here("data/derivatives/adni_acquisition_failures.lst"),
       col.names = FALSE)

## Linear registration
fpath <- here("data/derivatives/registration_dt.rds")

if (!file.exists(fpath)) {
  source(here("scripts/data_registration.R"))
} else {
  regis <- read_rds(fpath)
}

rm(fpath)

# Create lists
qc_regis <- regis[, .(Image, Rating, Comment)]
regis_fail <- regis[Rating == "Fail", .(Image)]

# Export products
fwrite(qc_regis,
       here("data/derivatives/adni_lin-reg_qc.csv"),
       col.names = FALSE)

fwrite(regis_fail,
       here("data/derivatives/adni_lin-reg_failures.lst"),
       col.names = FALSE)
