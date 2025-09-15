#!/usr/bin/env Rscript

## Packages
library("here")
library("data.table")
library("flextable")

### Recreate Table ###
rec_table   <- FALSE

## IN
params      <- here("data/raw/databases_params.csv") |> fread()

## OUT
imgs_table  <- here("data/derivatives/imgs_params.docx")
if (!file.exists(imgs_table) | rec_table) {
  params |>
    flextable() |>
    bold(part = "header") |>
    bold(j = 1) |>
    autofit() |>
    save_as_docx(path = imgs_table)
}
rm(rec_table, params, imgs_table)
