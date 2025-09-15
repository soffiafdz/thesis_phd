#!/usr/bin/env Rscript

## Packages
library("here")
library("data.table")
library("readr")
library("stringr")
library("lubridate")
library("hms")
library("flextable")
library("dunn.test")
library("rstatix")

## Recreation
# Recreate tables
rec_tables  <- FALSE

## IN
## Data.table Acquisition 99
fpath       <- here("data/derivatives/acquisition_99_dt.rds")

if (!file.exists(fpath)) {
  source(here("scripts/data_acquisition99.R"))
} else {
  acq_99    <- read_rds(fpath)
}

# Data.table Acquisition ADNI
fpath       <- here("data/derivatives/acquisition_dt.rds")

if (!file.exists(fpath)) {
  source(here("scripts/data_acquisition.R"))
} else {
  acquis    <- read_rds(fpath)
}

# Data.table Registration 99
fpath       <- here("data/derivatives/registration_99_dt.rds")

if (!file.exists(fpath)) {
  source(here("scripts/data_registration99.R"))
} else {
  reg_99    <- read_rds(fpath)
}

# Data.table Registration ADNI
fpath       <- here("data/derivatives/registration_dt.rds")

if (!file.exists(fpath)) {
  source(here("scripts/data_registration.R"))
} else {
  regis     <- read_rds(fpath)
}

# Data.table Skull segmentation
fpath       <- here("data/derivatives/segmentation_dt.rds")

if (!file.exists(fpath)) {
  source(here("scripts/data_segmentation.R"))
} else {
  rskull    <- read_rds(fpath)
}

rm(fpath)



## Data Cleaning
# Acquisition 99
acq_99[Session == "First" & Rater == "Expert01", Rater := "Expert-1 (S1)"]
acq_99[Session == "Second" & Rater == "Expert01", Rater := "Expert-1 (S2)"]
acq_99      <- acq_99[Rater != "Expert01"]

#acq_99_N <- acq_99[, .N, by = .(Rater, Rating)]
#acq_99_N[, .(X = mean(N), SD = sd(N)), by = Rating]

acq_99[Diff > duration(15, "minutes"), Rest := TRUE]
acq_99_time <- acq_99[, .(Image = Image_case,
                          Rater = str_replace(Rater, "0", "-"),
                          Rating, Diff, Rest)]
acq_99_time[!is.na(Rest), Diff := NA]

# Session and Pass vs Fail (Wilcoxon test)
acq_99_summ1  <-
  acq_99_time[, .(N = .N,
                  Rests = sum(Rest, na.rm = TRUE),
                  Session = as_hms(sum(Diff, na.rm = TRUE)),
                  PvF = suppressWarnings(
                          wilcox.test(as.numeric(Diff) ~ Rating,
                                      na.action = na.omit))$p.value), Rater]

acq_99_all1 <- acq_99_summ1[, .(Rater = "All",
                                N = 99,
                                Rests = round(median(Rests)),
                                Session = as_hms(round(median(Session))))]
acq_99_all1[, PvF := acq_99_time[, wilcox.test(as.numeric(Diff) ~ Rating,
                                               na.action = na.omit)$p.value]]

acq_99_summ1  <- rbindlist(list(acq_99_summ1, acq_99_all1), use.names = TRUE)

acq_99_summ2  <- acq_99_time[, .(N = .N,
                                 Median = as_hms(median(Diff, na.rm = TRUE)),
                                 Sd = hms(sd(Diff, na.rm = TRUE))),
                             .(Rater, Rating)] |>
                  dcast(Rater ~ Rating, value.var = c("N", "Median", "Sd"))

acq_99_all2 <- acq_99_time[, .(Rater = "All",
                               Median = as_hms(median(Diff, na.rm = TRUE)),
                               Sd = hms(sd(Diff, na.rm = TRUE))), Rating] |>
               dcast(Rater ~ Rating, value.var = c("Median", "Sd"))

acq_99_all2 <- cbind(acq_99_all2,
                     acq_99_summ2[, lapply(.SD, median), .SDcols = 2:3])

acq_99_summ2  <- rbindlist(list(acq_99_summ2, acq_99_all2), use.names = TRUE)

time_format <- "%02d:%02.0f (%02d:%02.0f)"
acq_99_summ <- acq_99_summ1[acq_99_summ2, on = "Rater",
                            .(Rater, Session, Rests,
                              Pass_N = round(N_Pass),
                              Pass_Time = sprintf(time_format,
                                                  minute(Median_Pass),
                                                  second(Median_Pass),
                                                  minute(Sd_Pass),
                                                  second(Sd_Pass)),
                              Fail_N = round(N_Fail),
                              Fail_Time = sprintf(time_format,
                                                  minute(Median_Fail),
                                                  second(Median_Fail),
                                                  minute(Sd_Fail),
                                                  second(Sd_Fail)),
                              p = round(PvF, digits = 3))]

rm(acq_99, acq_99_summ1, acq_99_all1, acq_99_summ2, acq_99_all2)


# Acquisition ADNI
acquis[Diff > duration(15, "minutes"), Rest := TRUE]
acquis_time <- acquis[, .(Image, Rater = str_replace(Rater, "0", "-"),
                          Rating, Diff, Rest)]
acquis_time[!is.na(Rest), Diff := NA]

#Session and Pass vs Warning vs Fail (Kruskal-Wallis rank sum test)
acquis_summ1 <-
  acquis_time[, .(N = .N,
                  Rests = sum(Rest, na.rm = TRUE),
                  Session = as_hms(sum(Diff, na.rm = TRUE)),
                  PvWvF = suppressWarnings(
                            kruskal.test(as.numeric(Diff) ~ Rating,
                                         na.action = na.omit))$p.value), Rater]

# Wilcox for Expert-1 and Rater-4 who don't have Warnings
no_w_raters <- c("Expert-1", "Rater-4")
acquis_wilcox <- acquis_time[Rater %in% no_w_raters,
                             .(PvWvF = wilcox.test(as.numeric(Diff) ~ Rating,
                                                   na.action = na.omit)$p.value),
                             Rater]

acquis_summ1[Rater %in% no_w_raters, PvWvF := acquis_wilcox$PvWvF]

acquis_all1 <- acquis_summ1[, .(Rater = "All", N = sum(N),
                                Rests = round(median(Rests)),
                                Session = as_hms(round(median(Session))))]
acquis_all1[, PvWvF := acquis_time[, kruskal.test(as.numeric(Diff) ~ Rating,
                                                  na.action = na.omit)$p.value]]

acquis_summ1 <- rbindlist(list(acquis_summ1[order(Rater)], acquis_all1),
                          use.names = TRUE)

acquis_summ2 <- acquis_time[, .(N = .N,
                                Median = as_hms(median(Diff, na.rm = TRUE)),
                                Sd = hms(sd(Diff, na.rm = TRUE))),
                            .(Rater, Rating)] |>
                  dcast(Rater ~ Rating, value.var = c("N", "Median", "Sd"))

acquis_all2 <- acquis_time[, .(Rater = "All", N = .N,
                               Median = as_hms(median(Diff, na.rm = TRUE)),
                               Sd = hms(sd(Diff, na.rm = TRUE))), Rating] |>
                dcast(Rater ~ Rating, value.var = c("N", "Median", "Sd"))

acquis_summ2 <- rbindlist(list(acquis_summ2, acquis_all2), use.names = TRUE)

acquis_summ <- acquis_summ1[acquis_summ2, on = "Rater",
                            .(Rater, Session, Rests,
                              Pass_N = sprintf("%d (%.0f%%)",
                                               N_Pass, N_Pass / N * 100),
                              Pass_Time = sprintf(time_format,
                                                  minute(Median_Pass),
                                                  second(Median_Pass),
                                                  minute(Sd_Pass),
                                                  second(Sd_Pass)),
                              Warning_N = sprintf("%d (%.0f%%)",
                                                  N_Warning,
                                                  N_Warning / N * 100),
                              Warning_Time = sprintf(time_format,
                                                     minute(Median_Warning),
                                                     second(Median_Warning),
                                                     minute(Sd_Warning),
                                                     second(Sd_Warning)),
                              Fail_N = sprintf("%d (%.0f%%)",
                                               N_Fail, N_Fail / N * 100),
                              Fail_Time = sprintf(time_format,
                                                  minute(Median_Fail),
                                                  second(Median_Fail),
                                                  minute(Sd_Fail),
                                                  second(Sd_Fail)),
                              p = sprintf("%04.3f", PvWvF))]

acquis_summ[Rater %in% no_w_raters, `:=`(Warning_N = "0 (0%)",
                                        Warning_Time = "-")]


# Registration 99
reg_99[Session == "First" & Rater == "Expert01", Rater := "Expert-1 (S1)"]
reg_99[Session == "Second" & Rater == "Expert01", Rater := "Expert-1 (S2)"]
reg_99 <- reg_99[Rater != "Expert01"]

reg_99[Diff > duration(15, "minutes"), Rest := TRUE]
reg_99_time <- reg_99[, .(Image, Rater = str_replace(Rater, "0", "-"),
                          Rating, Diff, Rest)]
reg_99_time[!is.na(Rest), Diff := NA]

reg_99_summ1 <-
  reg_99_time[, .(N = .N,
                  Rests = sum(Rest, na.rm = TRUE),
                  Session = as_hms(sum(Diff, na.rm = TRUE)),
                  PvF = suppressWarnings(
                          wilcox.test(as.numeric(Diff) ~ Rating,
                                      na.action = na.omit))$p.value), Rater]

reg_99_all1 <- reg_99_summ1[, .(Rater = "All",
                                N = 99,
                                Rests = round(median(Rests)),
                                Session = as_hms(round(median(Session))))]
reg_99_all1[, PvF := reg_99_time[, wilcox.test(as.numeric(Diff) ~ Rating,
                                               na.action = na.omit)$p.value]]

reg_99_summ1 <- rbindlist(list(reg_99_summ1, reg_99_all1), use.names = TRUE)

reg_99_summ2 <- reg_99_time[, .(N = .N,
                                Median = as_hms(median(Diff, na.rm = TRUE)),
                                Sd = hms(sd(Diff, na.rm = TRUE))),
                            .(Rater, Rating)] |>
                  dcast(Rater ~ Rating, value.var = c("N", "Median", "Sd"))

reg_99_all2 <- reg_99_time[, .(Rater = "All",
                               Median = as_hms(median(Diff, na.rm = TRUE)),
                               Sd = hms(sd(Diff, na.rm = TRUE))), Rating] |>
                  dcast(Rater ~ Rating, value.var = c("Median", "Sd"))

reg_99_all2 <- cbind(reg_99_all2,
                      reg_99_summ2[, lapply(.SD, median), .SDcols = 2:3])

reg_99_summ2 <- rbindlist(list(reg_99_summ2, reg_99_all2), use.names = TRUE)

reg_99_summ <- reg_99_summ1[reg_99_summ2, on = "Rater",
                            .(Rater, Session, Rests,
                              Pass_N = round(N_Pass),
                              Pass_Time = sprintf(time_format,
                                                  minute(Median_Pass),
                                                  second(Median_Pass),
                                                  minute(Sd_Pass),
                                                  second(Sd_Pass)),
                              Fail_N = round(N_Fail),
                              Fail_Time = sprintf(time_format,
                                                  minute(Median_Fail),
                                                  second(Median_Fail),
                                                  minute(Sd_Fail),
                                                  second(Sd_Fail)),
                              p = round(PvF, digits = 3))]

rm(reg_99, reg_99_summ1, reg_99_all1, reg_99_summ2, reg_99_all2)


# Registration ADNI
regis[Diff > duration(15, "minutes"), Rest := TRUE]
regis_time <- regis[, .(Image, Rater = str_replace(Rater, "0", "-"),
                        Rating, Diff, Rest)]
regis_time[!is.na(Rest), Diff := NA]

regis_summ1 <-
  regis_time[, .(N = .N,
                 Rests = sum(Rest, na.rm = TRUE),
                 Session = as_hms(sum(Diff, na.rm = TRUE)),
                 PvF = suppressWarnings(
                         wilcox.test(as.numeric(Diff) ~ Rating,
                                     na.action = na.omit))$p.value), Rater]

regis_all1 <- regis_summ1[, .(Rater = "All", N = sum(N),
                              Rests = round(median(Rests)),
                              Session = as_hms(round(median(Session))))]
regis_all1[, PvF := regis_time[, wilcox.test(as.numeric(Diff) ~ Rating,
                                             na.action = na.omit)$p.value]]

regis_summ1 <- rbindlist(list(regis_summ1[order(Rater)], regis_all1),
                         use.names = TRUE)

regis_summ2 <- regis_time[, .(N = .N,
                              Median = as_hms(median(Diff, na.rm = TRUE)),
                              Sd = hms(sd(Diff, na.rm = TRUE))),
                          .(Rater, Rating)] |>
                  dcast(Rater ~ Rating, value.var = c("N", "Median", "Sd"))

regis_all2 <- regis_time[, .(Rater = "All", N = .N,
                             Median = as_hms(median(Diff, na.rm = TRUE)),
                             Sd = hms(sd(Diff, na.rm = TRUE))), Rating] |>
                dcast(Rater ~ Rating, value.var = c("N", "Median", "Sd"))

regis_summ2 <- rbindlist(list(regis_summ2, regis_all2), use.names = TRUE)

regis_summ <- regis_summ1[regis_summ2, on = "Rater",
                          .(Rater, Session, Rests,
                            Pass_N = sprintf("%d (%.0f%%)",
                                             N_Pass, N_Pass / N * 100),
                            Pass_Time = sprintf(time_format,
                                                minute(Median_Pass),
                                                second(Median_Pass),
                                                minute(Sd_Pass),
                                                second(Sd_Pass)),
                            Fail_N = sprintf("%d (%.0f%%)",
                                             N_Fail, N_Fail / N * 100),
                            Fail_Time = sprintf(time_format,
                                                minute(Median_Fail),
                                                second(Median_Fail),
                                                minute(Sd_Fail),
                                                second(Sd_Fail)),
                            p = sprintf("%04.3f", PvF))]

# Will need these P-values for later
regis_p_pvf <- regis_summ1[, .(Comp = "PvF", Rater, p = PvF)]

rm(regis, regis_summ1, regis_all1, regis_summ2, regis_all2)


# Skull Segmentation
rskull[Diff > duration(15, "minutes"), Rest := TRUE]
rskull_time <- rskull[, .(Image, Rater = str_c("Expert-", str_sub(Rater, -1)),
                          Rating, Diff, Rest)]
rskull_time[!is.na(Rest), Diff := NA]

rskull_summ1 <-
  rskull_time[, .(N = .N,
                  Rests = sum(Rest, na.rm = TRUE),
                  Session = as_hms(sum(Diff, na.rm = TRUE)),
                  PvF = wilcox.test(as.numeric(Diff) ~ Rating,
                                    na.action = na.omit)$p.value), Rater]

rskull_summ2 <- rskull_time[, .(N = .N,
                                Median = as_hms(median(Diff, na.rm = TRUE)),
                                Sd = hms(sd(Diff, na.rm = TRUE))),
                            .(Rater, Rating)] |>
                  dcast(Rater ~ Rating, value.var = c("N", "Median", "Sd"))

rskull_summ <- rskull_summ1[rskull_summ2, on = "Rater",
                            .(Rater, Session, Rests,
                              Pass_N = sprintf("%d (%.0f%%)",
                                               N_Pass, N_Pass / N * 100),
                              Pass_Time = sprintf(time_format,
                                                  minute(Median_Pass),
                                                  second(Median_Pass),
                                                  minute(Sd_Pass),
                                                  second(Sd_Pass)),
                              Fail_N = sprintf("%d (%.0f%%)",
                                               N_Fail, N_Fail / N * 100),
                              Fail_Time = sprintf(time_format,
                                                  minute(Median_Fail),
                                                  second(Median_Fail),
                                                  minute(Sd_Fail),
                                                  second(Sd_Fail)),
                              p = sprintf("%04.3f", PvF))]

# Will need these p-values for later
rskull_p_pvf  <- rskull_summ1[, PvF]

rm(rskull, rskull_summ1, rskull_summ2, time_format)


## Analyses
# Acquisition 99
# Time between expert sessions
acq_99_time[Rater %like% "Expert", median(Diff, na.rm = TRUE), Rater]
acq_99_e1_e1_test <- wilcox.test(acq_99_time[Rater %like% "S1",
                                             as.numeric(Diff)],
                                 acq_99_time[Rater %like% "S2",
                                             as.numeric(Diff)],
                                 paired = TRUE)
acq_99_e1_e1_es   <- wilcox_effsize(acq_99_time[Rater %like% "Expert",
                                    .(Diff = as.numeric(Diff), Rater)],
                                    Diff ~ Rater, paired = TRUE)


# Time between ratings (with expert):
acq_99_time[, median(Diff, na.rm = TRUE), by = Rating]
acq_99_pvf_all_test <- wilcox.test(acq_99_time[Rating == "Pass",
                                               as.numeric(Diff)],
                                   acq_99_time[Rating == "Fail",
                                               as.numeric(Diff)])
acq_99_pvf_all_es   <- wilcox_effsize(acq_99_time[, .(Diff = as.numeric(Diff),
                                                      Rating)],
                                      Diff ~ Rating)

## Time between ratings (only trainees):
acq_99_time[Rater %like% "Rater", median(Diff, na.rm = TRUE), Rating]

acq_99_pvf_tr_test  <- wilcox.test(acq_99_time[Rater %like% "Rater" &
                                               Rating == "Pass",
                                               as.numeric(Diff)],
                                   acq_99_time[Rater %like% "Rater" &
                                               Rating == "Fail",
                                               as.numeric(Diff)])
acq_99_pvf_tr_es    <- wilcox_effsize(acq_99_time[Rater %like% "Rater",
                                                  .(Diff = as.numeric(Diff),
                                                    Rating)],
                                      Diff ~ Rating)

# Multiple comparison corrections
acq_99_p_pvf <- acq_99_summ[, .(Comp = "PvF", Rater, p)]
acq_99_p_fdr <- rbindlist(list(acq_99_p_pvf,
                               data.table(Comp = "PvF", Rater = "Trainees",
                                     p = acq_99_pvf_tr_test$p.value),
                               data.table(Comp = "S1 v S2", Rater = "Expert-1",
                                     p = acq_99_e1_e1_test$p.value)))
acq_99_p_fdr[, p_adj := p.adjust(p, method = "holm")]
acq_99_summ[, p2 := acq_99_p_fdr[1:12, round(p_adj, digits = 3)]]
rm(acq_99_p_pvf)

# Acquisition ADNI
# Time between ratings:
acquis_time[, median(Diff, na.rm = TRUE), Rating]
acquis_pvwvf_all_test <- kruskal.test(Diff ~ Rating, acquis_time)
acquis_pvwvf_all_es   <- kruskal_effsize(acquis_time, Diff ~ Rating)

# ADNI vs training (Expert only)
#acq_99_time[startsWith(Rater, "Expert01"), median(Diff)]
#acquis_time[Rater == "Expert01", median(Diff)]
#wilcox.test(acq_99_time[startsWith(Rater, "Expert01"), as.numeric(Diff)],
            #acquis_time[Rater == "Expert01", as.numeric(Diff)])

# ADNI vs training
raters_adni <- acquis_time[Rater %like% "Rater", unique(Rater)]
acq_99_acquis_time <- rbindlist(list(acq_99_time[Rater %in% c("Expert-1 (S1)",
                                                              raters_adni),
                                                 .(Task = "Balanced",
                                                   Time = as.numeric(Diff))],
                                     acquis_time[,
                                                 .(Task = "ADNI",
                                                   Time = as.numeric(Diff))]))
acq_99_acquis_time[, median(Time, na.rm = TRUE), Task]
acquis_99_adni_test <- wilcox.test(Time ~ Task, acq_99_acquis_time)
acquis_99_adni_es   <- wilcox_effsize(acq_99_acquis_time, Time ~ Task)
rm(raters_adni, acq_99_acquis_time)

# Post-hoc analysis
raters_kruskal <- acquis_summ[, unique(Rater)][c(2:4, 6, 8)]
acquis_posthoc <- acquis_time[Rater %in% raters_kruskal,
                              dunn.test(as.numeric(Diff), Rating,
                                        method = "holm"), Rater]
acquis_posthoc_all <- acquis_time[, dunn.test(as.numeric(Diff), Rating,
                                              method = "holm")]
acquis_posthoc_all[, Rater := "All"]
acquis_posthoc <- rbindlist(list(acquis_posthoc[order(Rater)],
                                 acquis_posthoc_all),
                            use.names = TRUE)

rm(raters_kruskal, acquis_posthoc_all)

# Multiple comparison correction
acquis_p_fdr <- rbindlist(list(acquis_p_pvwvf,
                               data.table(Comp = "99vADNI", Rater = "All",
                                     p = acquis_99_adni_test$p.value)))
rm(acquis_p_pvwvf)

# Add the post-hoc comparisons:
# 8 raters + All
# 3 comparisons X (5 raters + All)
# Total of 18 comparisons
acquis_p_fdr[, p_adj := p.adjust(p, method = "holm", n = 18)]

acquis_posthoc[, P.adjusted := p.adjust(P, method = "holm", n = 18)]

acquis_summ[, p2 := acquis_p_fdr[1:9, sprintf("%04.3f", p_adj)]]

# Registration 99
# Time between expert sessions
reg_99_time[Rater %like% "Expert", median(Diff, na.rm = TRUE), Rater]
reg_99_e1_e1_test <- wilcox.test(as.numeric(Diff) ~ Rater,
                                 reg_99_time[Rater %like% "Expert"],
                                 paired = TRUE)
reg_99_e1_e1_es   <- wilcox_effsize(reg_99_time[Rater %like% "Expert",
                                    .(Diff = as.numeric(Diff), Rater)],
                                    Diff ~ Rater)

# Time between ratings (with expert):
reg_99_time[, median(Diff, na.rm = TRUE), Rating]
reg_99_pvf_all_test <- wilcox.test(as.numeric(Diff) ~ Rating, reg_99_time)
reg_99_pvf_all_es   <- wilcox_effsize(reg_99_time[,
                                      .(Diff = as.numeric(Diff), Rating)],
                                      Diff ~ Rating)

# Time between ratings (only trainees):
reg_99_time[Rater %like% "Rater", median(Diff, na.rm = TRUE), Rating]
reg_99_pvf_tr_test  <- wilcox.test(as.numeric(Diff) ~ Rating,
                                   reg_99_time[Rater %like% "Rater"])
reg_99_pvf_tr_es    <- wilcox_effsize(reg_99_time[Rater %like% "Rater",
                                      .(Diff = as.numeric(Diff), Rating)],
                                      Diff ~ Rating)

# Multiple comparison correction
reg_99_p_pvf <- reg_99_summ[, .(Comp = "PvF", Rater, p)]
reg_99_p_fdr <- rbindlist(list(reg_99_p_pvf,
                               data.table(Comp = "PvF", Rater = "Trainees",
                                     p = reg_99_pvf_tr_test$p.value),
                               data.table(Comp = "S1 v S2", Rater = "Expert-1",
                                     p = reg_99_e1_e1_test$p.value)))
reg_99_p_fdr[, p_adj := p.adjust(p, method = "holm")]
reg_99_summ[, p2 := reg_99_p_fdr[1:11, round(p_adj, digits = 3)]]
rm(reg_99_p_pvf)


# Registration ADNI
# Time between ratings:
regis_time[, median(Diff, na.rm = TRUE), Rating]
regis_pvf_test <- wilcox.test(as.numeric(Diff) ~ Rating, regis_time)
regis_pvf_es   <- wilcox_effsize(regis_time[, .(Diff = as.numeric(Diff),
                                                Rating)], Diff ~ Rating)

# ADNI vs training
raters_adni <- regis_time[, unique(Rater)]
reg_99_regis_time <- rbindlist(list(reg_99_time[Rater %in% raters_adni,
                                                .(Task = "Balanced",
                                                  Time = as.numeric(Diff))],
                                    regis_time[, .(Task = "ADNI",
                                                   Time = as.numeric(Diff))]))
reg_99_regis_time[, median(Time, na.rm = TRUE), Task]
regis_99_adni_test <- wilcox.test(Time ~ Task, reg_99_regis_time)
regis_99_adni_es   <- wilcox_effsize(reg_99_regis_time, Time ~ Task)
rm(raters_adni, reg_99_regis_time)

# Multiple comparisons correction
regis_p_fdr <- rbindlist(list(regis_p_pvf,
                              data.table(Comp = "99vADNI", Rater = "All",
                                         p = regis_99_adni_test$p.value)))
regis_p_fdr[, p_adj := p.adjust(p, method = "holm")]
regis_summ[, p2 := regis_p_fdr[1:9, sprintf("%04.3f", p_adj)]]
rm(regis_p_pvf)


# Skull segmentation
rskull_time[, median(Diff, na.rm = TRUE), .(Rating, Rater)]

# Expert-1
rskull_e1_test <- wilcox.test(as.numeric(Diff) ~ Rating,
                              rskull_time[Rater %like% "1"])
rskull_e1_es   <- wilcox_effsize(rskull_time[Rater %like% "1",
                                 .(Diff = as.numeric(Diff), Rating)],
                                 Diff ~ Rating)

# Expert-2
rskull_e2_test <- wilcox.test(as.numeric(Diff) ~ Rating,
                              rskull_time[Rater %like% "2"])
rskull_e2_es   <- wilcox_effsize(rskull_time[Rater %like% "2",
                                 .(Diff = as.numeric(Diff), Rating)],
                                 Diff ~ Rating)


## OUT: Tables
# Acquisition 99
fname       <- here("data/derivatives/acq_99_time.docx")
if (!file.exists(fname) | rec_tables) {
  acq_99_summ |>
    flextable() |>
    separate_header() |>
    labelizor(part = "header", labels = c("Session" = "Total Time",
                                          "p2" = "p adj.")) |>
    bold(part = "header") |>
    #italic(part = "header", j = "p") |>
    italic(~ Rater == "All") |>
    hline(i = ~ before(Rater, "All"), border = fp_border_default(width = 2)) |>
    bold(~ p < 0.05, j = "p") |>
    bold(~ p2 < 0.05, j = "p2") |>
    autofit() |>
    save_as_docx(path = fname)
}


# Acquisition ADNI
fname       <- here("data/derivatives/acq_adni_time.docx")
if (!file.exists(fname) | rec_tables) {
  acquis_summ |>
    flextable() |>
    separate_header() |>
    labelizor(part = "header", labels = c("Session" = "Total Time",
                                          "p2" = "p adj.")) |>
    bold(part = "header") |>
    #italic(part = "header", j = "p") |>
    italic(~ Rater == "All") |>
    hline(i = ~ before(Rater, "All"), border = fp_border_default(width = 2)) |>
    bold(~ p < 0.05, j = "p") |>
    bold(~ p2 < 0.05, j = "p2") |>
    labelizor(j = "p", labels = c("0.000" = "<0.001")) |>
    labelizor(j = "p2", labels = c("0.000" = "<0.001")) |>
    autofit() |>
    save_as_docx(path = fname)
}


# Acquisition ADNI: Post-hoc
fname       <- here("data/derivatives/acq_adni_posthoc.docx")
if (!file.exists(fname) | rec_tables) {
  acquis_posthoc |>
    flextable() |>
    colformat_double(digits = 3) |>
    labelizor(part = "header", labels = c("chi2" = "Chi-squared",
                                          "P" = "p",
                                          "P.adjusted" = "p adj.",
                                          "comparisons" = "Comparisons")) |>
    bold(part = "header") |>
    italic(part = "header", j = 4:5) |>
    merge_v(j = 1:2) |>
    italic(~ Rater == "All") |>
    hline(i = 15, border = fp_border_default(width = 2)) |>
    fix_border_issues() |>
    bold(~ P < 0.05, j = 4) |>
    bold(~ P.adjusted < 0.05, j = 5) |>
    labelizor(j = 4:5, labels = c("0.000" = "<0.001")) |>
    autofit() |>
    save_as_docx(path = fname)
}


# Registration 99
fname       <- here("data/derivatives/reg_99_time.docx")
if (!file.exists(fname) | rec_tables) {
  reg_99_summ |>
    flextable() |>
    separate_header() |>
    labelizor(part = "header", labels = c("Session" = "Total Time",
                                          "p2" = "p adj.")) |>
    bold(part = "header") |>
    #italic(part = "header", j = "p") |>
    italic(~ Rater == "All") |>
    hline(i = ~ before(Rater, "All"), border = fp_border_default(width = 2)) |>
    bold(~ p < 0.05, j = "p") |>
    bold(~ p2 < 0.05, j = "p2") |>
    autofit() |>
    save_as_docx(path = fname)
}


# Registration ADNI
fname       <- here("data/derivatives/reg_adni_time.docx")
if (!file.exists(fname) | rec_tables) {
  regis_summ |>
    flextable() |>
    separate_header() |>
    labelizor(part = "header", labels = c("Session" = "Total Time",
                                          "p2" = "p adj.")) |>
    bold(part = "header") |>
    #italic(part = "header", j = "p") |>
    italic(~ Rater == "All") |>
    hline(i = ~ before(Rater, "All"), border = fp_border_default(width = 2)) |>
    bold(~ p < 0.05, j = "p") |>
    labelizor(j = "p", labels = c("0.000" = "<0.001")) |>
    labelizor(j = "p2", labels = c("0.000" = "<0.001")) |>
    autofit() |>
    save_as_docx(path = fname)
}

# Skull segmentation
fname       <- here("data/derivatives/seg_adni_time.docx")
if (!file.exists(fname) | rec_tables) {
  rskull_summ |>
    flextable() |>
    separate_header() |>
    labelizor(part = "header", labels = c("Session" = "Total Time",
                                          "p" = "p adj.")) |>
    bold(part = "header") |>
    #italic(part = "header", j = "p") |>
    bold(~ p < 0.05, j = "p") |>
    bold(~ p2 < 0.05, j = "p2") |>
    labelizor(j = "p", labels = c("0.000" = "<0.001")) |>
    labelizor(j = "p2", labels = c("0.000" = "<0.001")) |>
    autofit() |>
    save_as_docx(path = fname)
}
rm(fname, rec_tables)


## OUT: RDS
write_rds(acq_99_time, here("data/derivatives/acq_99_time_dt.rds"))
write_rds(acquis_time, here("data/derivatives/acquis_time_dt.rds"))
write_rds(reg_99_time, here("data/derivatives/reg_99_time_dt.rds"))
write_rds(regis_time, here("data/derivatives/regis_time_dt.rds"))
