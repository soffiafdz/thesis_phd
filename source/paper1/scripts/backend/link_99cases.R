#!/usr/bin/env Rscript

## Packages
library("here")
library("data.table")
library("stringr")

## Raw MRI
# Use size of jpgs to link fullnames to Cases

ls1 <- fread(here('data/raw/list_rawmri1.csv'))
ls2 <- fread(here('data/raw/list_rawmri2.csv'))

lst <- ls1[ls2, on = "V1", .(CASE = i.V2, FULLFILE = V2)]

# Clean
lst[, `:=`(CASE = str_sub(CASE, 1, -5),
           DIR1 = str_extract(FULLFILE, "^mri\\d*(?=_)"),
           DIR2 = str_extract(FULLFILE, ".*(?=_\\d{1,2}_mri)"),
           FILE = str_extract(FULLFILE, "(?<=\\d_).*(?=_T1.jpg)"))]

lst[, FILE := paste(FILE, "mnc", sep = ".")]

predir <- "/ipl/ipl14/Mahsa/NACC/Data_MNC"
lst <- lst[, .(CASE, FILENAME = paste(predir, DIR1, DIR2, FILE, sep = "/"))]
fwrite(lst, here("data/raw/list_cases_rawmri.csv"), col.names = FALSE)
rm(ls1, ls2, lst)

## LinReg
ls1 <- fread(here("data/raw/cases_linreg.csv"))
pre <- "data/raw/qc_ratings/registration/balanced_data"
ls2 <- fread(here(pre, "MULTI_99_Linear_Expert_consensus.csv"),
             header = FALSE)
lst <- ls1[ls2, on = .(ID = V1), .(ID, Address, QC)]

lst[Address %like% "data", Address := str_sub(Address, 6)]
lst[, Session   := dirname(dirname(Address))]
lst[, Subject   := dirname(Session)]
lst[, Database  := dirname(Subject)]
lst[, Method    := dirname(Database)]

lst[, `:=`(File     = basename(Address),
           Session  = basename(Session),
           Subject  = basename(Subject),
           Database = basename(Database),
           Method   = basename(Method))]

lst[, Address := NULL]

fwrite(lst, here("data/raw/list_cases_linreg.csv"))
#rm(ls1, ls2, lst)
