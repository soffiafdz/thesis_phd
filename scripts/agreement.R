#!/usr/bin/env Rscript

## Packages
library("here")
library("data.table")
library("irr")
library("purrr")
library("stringr")
library("readr")
library("ggplot2")
library("ggforce")
library("cowplot")
library("flextable")

## Recreation
# Recreate plots if existing
rec_plots   <- FALSE

# Recreate table if existing
rec_table   <- FALSE


## IN
# Acquisition 338
fpath       <- here("data/derivatives/acquisition_388_dt.rds")
if (!file.exists(fpath)) {
  source(here("scripts/data_acquisition388.R"))
} else {
  acq_388   <- read_rds(fpath)
}

# Acquisition 99
fpath       <- here("data/derivatives/acquisition_99_dt.rds")
if (!file.exists(fpath)) {
  source(here("scripts/data_acquisition99.R"))
} else {
  acq_99    <- read_rds(fpath)
}

# Acquisition Register
fpath       <- here("data/raw/qc_ratings/raw/off_qrater")
acq_99_off1 <- fread(here(fpath, "OffQrater_Raw_Rater.csv"))
acq_99_off2 <- fread(here(fpath, "OffQrater_Raw_Expert.csv"),
                     nrows = 90)

# Registration 99
fpath       <- here("data/derivatives/registration_99_dt.rds")
if (!file.exists(fpath)) {
    source(here("scripts/data_registration99.R"))
} else {
  reg_99    <- read_rds(fpath)
}

# Pre/post protocol meeting agreement
fnames <- sprintf("registration_%s.rds", c("dt", "premeeting_dt"))
fpaths <- here("data/derivatives", fnames)

if (!file.exists(fpaths[1])) {
  source(here("scripts/data_registration.R"))
} else {
  reg_post  <- read_rds(fpaths[1])
}

if (!file.exists(fpaths[2])) {
  source(here("scripts/data_registration_premeeting.R"))
} else {
  reg_pre   <- read_rds(fpaths[2])
}

# Registration Register
fpath       <- "data/raw/qc_ratings/registration/off_qrater"
reg_99_off1 <- fread(here(fpath, "OffQrater_Linear_Rater.csv"))
reg_99_off2 <- fread(here(fpath, "OffQrater_Linear_Expert.csv"),
                     nrows = 44)

# Skull segmentation
fpath <- here("data/derivatives/segmentation_dt.rds")
if (!file.exists(fpath)) {
  source(here("scripts/data_segmentation.R"))
} else {
  rskull <- read_rds(fpath)
}

rm(fpath, fpaths, fnames)



## Data Cleaning
# Acquisition 99
# Expert First v Second session
acq_99_exp  <- acq_99[Session %in% c("First", "Second"),
                         .(Image = Image_case, Session, Rating)]
#acq_99_exp[
  #Rating == "Pass", Rating := 1][
  #Rating == "Fail", Rating := 0][
  #, Rating := as.integer(Rating)
               #]

acq_99_exp  <- dcast(acq_99_exp, Image ~ Session, value.var = "Rating")

# Matrix of ratings
acq_99_bin <- acq_99[!Session %in% c("First", "Second"),
                     .(Image = Image_case, Rater, Rating)]

acq_99_bin[
  Rating == "Pass", Rating := 1][
  Rating == "Fail", Rating := 0][
  , Rating := as.integer(Rating)]

acq_99_wide <- dcast(acq_99_bin, Image ~ Rater, value.var = "Rating")[, -1]
rm(acq_99_bin)

# Calculate Count and Correlations for Raw agreement
acq_99_corr <- acq_99_count <- vector("list", length(acq_99_wide))
for (i in seq_along(acq_99_wide)) {
  acq_99_corr[[i]] <- acq_99_count[[i]] <- vector("list", length(acq_99_wide))
  for (j in seq_along(acq_99_wide)) {
    acq_99_count[[i]][[j]] <- sum(acq_99_wide[[i]] == acq_99_wide[[j]])
    acq_99_corr[[i]][[j]] <- cor(acq_99_wide[[i]], acq_99_wide[[j]],
                                 method = "spearman")
  }
}
rm(i, j)

names(acq_99_wide) <- acq_99_wide |>
  names() |>
  str_replace("Rater", "R") |>
  str_replace("Expert", "E")

acq_99_count <- setDT(lapply(acq_99_count, unlist))
acq_99_count[upper.tri(acq_99_count, diag = TRUE)] <- NA
names(acq_99_count) <- names(acq_99_wide)
acq_99_count[, Rater := names(acq_99_wide)]
acq_99_count        <- melt(acq_99_count, id.vars = "Rater",
                            variable.factor = FALSE, na.rm = TRUE,
                            variable.name = "Rater2", value.name = "Count")
acq_99_count[, Perc := sprintf("%.0f%%", Count / 99 * 100)]

acq_99_corr <- setDT(lapply(acq_99_corr, unlist))
acq_99_corr[upper.tri(acq_99_corr, diag = TRUE)] <- NA
names(acq_99_corr)  <- names(acq_99_wide)
acq_99_corr[, Rater := names(acq_99_wide)]
acq_99_corr         <- melt(acq_99_corr, id.vars = "Rater",
                            variable.factor = FALSE, na.rm = TRUE,
                            variable.name = "Rater2", value.name = "Corr")
acq_99_corr[, Corr := round(Corr, 2)]

# Data.table for Plot
acq_agree   <- acq_99[Session == "First", .(Image_case, First = Rating)
                      ][acq_99[Session == "Second",
                               .(Image_case, Second = Rating)],
                      on = "Image_case"
                      ][First == Second, .(Image = Image_case, Expert = "*")]

acq_exp1    <- acq_agree[acq_99[Session == "Consensus",
                                .(Image = Image_case, Rating)],
                         on = "Image"]
acq_exp1[is.na(Expert), Expert := "†"]

acq_exp1[Expert == "*", GS := Rating]
acq_exp1[Expert == "†" & Rating == "Fail", GS := "rFail"]
acq_exp1[Expert == "†" & Rating == "Pass", GS := "rPass"]

acq_99_n <- acq_99[Rater != "Expert01", .N,
                   .(QC_orig, Image = Image_case, Rating)]
acq_99_plot <- acq_exp1[, .(Image, GS)][acq_99_n, on = "Image"]
acq_99_plot[, `:=`(Image = factor(Image,
                                  levels = c(acq_99_plot[GS %like% "Pass"
                                                         ][Rating == "Pass"
                                                         ][order(N), Image],
                                             acq_99_plot[GS %like% "Fail"
                                                         ][Rating == "Fail"
                                                         ][order(-N), Image])),
                   GS = factor(GS, levels = c("Pass", "rPass", "Fail", "rFail"),
                               labels = sprintf("Expert: %s",
                                                c("Pass",
                                                  "Pass (after revision)",
                                                  "Fail",
                                                  "Fail (after revision)"))))]

acq_99_summary      <- acq_99_plot |> dcast(... ~ Rating, value.var = "N")
acq_99_summary[is.na(Fail), Fail := 0]
acq_99_summary[is.na(Pass), Pass := 0]
acq_99_summary      <- acq_99_summary[, .(Image, QC_orig, Expert = GS,
                                          Trainees_Fail = Fail,
                                          Trainees_Pass = Pass)]

rm(acq_agree, acq_exp1, acq_99_n)


# Acquisition Register
# Rater 1:
acq_99_off1 <- acq_99[Rater == "Rater01",
                      .(Image = Image_case, Prev = Rating)
                      ][acq_99_off1, on = "Image", .(Image, Prev, Off = QC)]

acq_99_off1 <- acq_99[Session == "Consensus",
                      .(Image = Image_case, GS = Rating)
                      ][acq_99_off1, on = "Image",
                      .(Image, Prev, GS, Off)
                      ][, `:=`(Off = fifelse(Off == "Pass", 1, 0),
                               Prev = fifelse(Prev == "Pass", 1, 0),
                               GS = fifelse(GS == "Pass", 1, 0))]

# Expert1
acq_99_off2 <- acq_99[Session == "Consensus",
                      .(Image = Image_case, GS = Rating)
                      ][acq_99_off2, on = "Image",
                      .(Image, GS, Off = QC)
                      ][, `:=`(Off = fifelse(Off == "fail", 0, 1),
                               GS = fifelse(GS == "Pass", 1, 0))]

acq_99_off  <- acq_99_off1[acq_99_off2,
                           on = .(Image, GS),
                           .(Image, GS, E1_register = i.Off,
                             R1_qrater = Prev, R1_register = Off)]
rm(acq_99, acq_99_off1, acq_99_off2)


# Registration 99
# Binarize
reg_99_bin  <- copy(reg_99)
reg_99_bin[
  Rating == "Pass", Rating := 1][
  Rating == "Fail", Rating := 0][
  , Rating := as.integer(Rating)]

# Expert Firsv v Second session
reg_99_exp  <- dcast(reg_99_bin[Session %in% c("First", "Second")],
                     Image ~ Session, value.var = "Rating")

# Matrix of ratings
reg_99_wide <- dcast(reg_99_bin[!Session %in% c("First", "Second")],
                     Image ~ Rater, value.var = "Rating")[, -1]
rm(reg_99_bin)

# Calculate Count and Correlations for Registration agreement
reg_99_corr <- reg_99_count <- vector("list", length(reg_99_wide))
for (i in seq_along(reg_99_wide)) {
  reg_99_corr[[i]] <- reg_99_count[[i]] <- vector("list", length(reg_99_wide))
  for (j in seq_along(reg_99_wide)) {
    reg_99_count[[i]][[j]] <- sum(reg_99_wide[[i]] == reg_99_wide[[j]])
    reg_99_corr[[i]][[j]] <- cor(reg_99_wide[[i]], reg_99_wide[[j]],
                                 method = "spearman")
  }
}
rm(i, j)

names(reg_99_wide) <- reg_99_wide |>
  names() |>
  str_replace("Rater", "R") |>
  str_replace("Expert", "E")

reg_99_count <- setDT(lapply(reg_99_count, unlist))
reg_99_count[upper.tri(reg_99_count, diag = TRUE)] <- NA
names(reg_99_count) <- names(reg_99_wide)
reg_99_count[, Rater := names(reg_99_wide)]
reg_99_count    <- melt(reg_99_count, id.vars = "Rater",
                        variable.factor = FALSE, na.rm = TRUE,
                        variable.name = "Rater2", value.name = "Count")
reg_99_count[, Perc := sprintf("%.0f%%", Count / 99 * 100)]

reg_99_corr <- setDT(lapply(reg_99_corr, unlist))
reg_99_corr[upper.tri(reg_99_corr, diag = TRUE)] <- NA
names(reg_99_corr) <- names(reg_99_wide)
reg_99_corr[, Rater := names(reg_99_wide)]
reg_99_corr    <- melt(reg_99_corr, id.vars = "Rater",
                        variable.factor = FALSE, na.rm = TRUE,
                        variable.name = "Rater2", value.name = "Corr")
reg_99_corr[, Corr := round(Corr, 2)]

# Data.table for Plot
reg_agree   <- reg_99[Session == "First", .(Image, First = Rating)
                      ][reg_99[Session == "Second",
                               .(Image, Second = Rating)],
                      on = "Image"
                      ][First == Second, .(Image, Expert = "*")]

reg_exp1    <- reg_agree[reg_99[Session == "Consensus", .(Image, Rating)],
                         on = "Image"]
reg_exp1[is.na(Expert), Expert := "†"]

reg_exp1[Expert == "*", GS := Rating]
reg_exp1[Expert == "†" & Rating == "Fail", GS := "rFail"]
reg_exp1[Expert == "†" & Rating == "Pass", GS := "rPass"]

reg_99_n <- reg_99[Rater != "Expert01", .N, .(QC_orig, Image, Rating)]
reg_99_plot <- reg_exp1[, .(Image, GS)][reg_99_n, on = "Image"]
reg_99_plot[, `:=`(Image = factor(Image,
                                  levels = c(reg_99_plot[GS %like% "Pass"
                                                         ][Rating == "Pass"
                                                         ][order(N), Image],
                                             reg_99_plot[GS %like% "Fail"
                                                         ][Rating == "Fail"
                                                         ][order(-N), Image])),
                   GS = factor(GS, levels = c("Pass", "rPass", "Fail", "rFail"),
                               labels = sprintf("Expert: %s",
                                                c("Pass",
                                                  "Pass (after revision)",
                                                  "Fail",
                                                  "Fail (after revision)"))))]
reg_99_summary      <- reg_99_plot |> dcast(... ~ Rating, value.var = "N")
reg_99_summary[is.na(Fail), Fail := 0]
reg_99_summary[is.na(Pass), Pass := 0]
reg_99_summary      <- reg_99_summary[, .(Image, QC_orig, Expert = GS,
                                          Trainees_Fail = Fail,
                                          Trainees_Pass = Pass)]
rm(reg_agree, reg_exp1, reg_99_n)


# Registration Register
# Rater1
reg_99_off1 <- reg_99[Rater == "Rater01", .(Image, Prev = Rating)
                      ][reg_99_off1, on = "Image", .(Image, Prev, Off = QC)]

reg_99_off1 <- reg_99[Session == "Consensus", .(Image, GS = Rating)
                      ][reg_99_off1, on = "Image",
                      .(Image, Prev, GS, Off)
                      ][, `:=`(Off = fifelse(Off == "Pass", 1, 0),
                               Prev = fifelse(Prev == "Pass", 1, 0),
                               GS = fifelse(GS == "Pass", 1, 0))]

# Expert1
reg_99_off2 <- reg_99[Session == "Consensus", .(Image, GS = Rating)
                      ][reg_99_off2, on = "Image",
                      .(Image, GS, Off = QC)
                      ][, `:=`(Off = fifelse(Off == "fail", 0, 1),
                               GS = fifelse(GS == "Pass", 1, 0))]

reg_99_off <- reg_99_off1[reg_99_off2, on = .(Image, GS),
                          .(Image, GS, E1_register = i.Off,
                            R1_qrater = Prev, R1_register = Off)]
rm(reg_99, reg_99_off1, reg_99_off2)


# Registration pre/post interruption
reg_pre[, Timestamp := NULL]
reg_pre <- reg_pre[!Rating == "Pending"]
#reg_pre <- reg_pre[!Rating %in% c("Warning", "Pending")]
setnames(reg_pre, "Rating", "Pre")

reg_post <- reg_post[reg_post[, .I[Timestamp == max(Timestamp)],
                              .(Image, Rater)]$V1]
reg_post[, c("Comment", "Diff", "Timestamp") := NULL]
setnames(reg_post, "Rating", "Post")

reg_pre_n <- reg_pre[, .N, .(Rater, Pre)] |>
               dcast(Rater ~ Pre, value.var = "N")
reg_pre_avg <- reg_pre_n[, lapply(.SD, mean, na.rm = TRUE), .SDcols = 2:4]
reg_pre_avg[, Rater := "Average"]

reg_pre_n <- rbindlist(list(reg_pre_n, reg_pre_avg), use.names = TRUE)
reg_pre_n[is.na(Warning), Warning := 0]
reg_pre_n[, Total := Pass + Fail + Warning]
setnames(reg_pre_n, 2:5, str_c("pre", names(reg_pre_n)[-1]))

reg_pre_post <- unique(reg_post[reg_pre, on = .(Image, Rater)])

reg_post_n <- reg_pre_post[, .N, .(Rater, Post)] |>
                dcast(Rater ~ Post, value.var = "N")
reg_post_avg <- reg_post_n[, lapply(.SD, mean, na.rm = TRUE), .SDcols = 2:3]
reg_post_avg[, Rater := "Average"]
reg_post_n <- rbindlist(list(reg_post_n, reg_post_avg), use.names = TRUE)
reg_post_n[, Total := Pass + Fail]
setnames(reg_post_n, 2:4, str_c("post", names(reg_post_n)[-1]))

reg_meeting_n <- reg_pre_n[reg_post_n, on = "Rater"]

reg_change <- reg_pre_post[Pre != "Warning"
                           ][Post == Pre, .(Agreed = .N), Rater
                           ][reg_pre_n, on = "Rater",
                           .(Rater, N = (preTotal - preWarning) - Agreed)]
reg_change[Rater == "Average", N := reg_change[-.N, mean(N)]]

reg_meeting <- reg_change[reg_meeting_n, on = "Rater",
                      .(Rater = str_replace(Rater, "0", "-"),
                        Before_Pass = sprintf("%.0f (%.0f%%)", prePass,
                                              prePass / preTotal * 100),
                        Before_Warning = sprintf("%.0f (%.0f%%)", preWarning,
                                                 preWarning / preTotal * 100),
                        Before_Fail = sprintf("%.0f (%.0f%%)", preFail,
                                                 preFail / preTotal * 100),
                        After_Pass = sprintf("%.0f (%.0f%%)", postPass,
                                              postPass / postTotal * 100),
                        After_Fail = sprintf("%.0f (%.0f%%)", postFail,
                                                 postFail / postTotal * 100),
                        Change = sprintf("%.0f (%.0f%%)", N,
                                         N / (preTotal - preWarning) * 100))]
rm(reg_pre, reg_pre_n, reg_pre_avg, reg_post, reg_post_n,
   reg_post_avg, reg_change, reg_meeting_n, reg_pre_post)


# Skull segmentation
rskull_qc   <- dcast(rskull, Image ~ Rater, value.var = "Rating")
rm(rskull)



## Analyses
# Acquisition 338
# Inter-rater agreement: Experts
# Kappa = 0.401, Z = 9.83
acq_388_kappa       <- kappa2(acq_388[, .(Expert1, Expert2)])
rm(acq_388)


# Acquisition 99
# Intra-rater agreement: Expert between sessions
# Kappa = 0.81, Z = 8.14
acq_99_kappa_expert <- kappa2(acq_99_exp[, -1])

# Gold_standard: new images
acq_99_summary[, .N, Expert]

# Inter-rater agreement
# Calculate Fleiss' Kappa
# Kappa = 0.439; Z = 32.4
acq_99_kappa_raters <- kappam.fleiss(acq_99_wide)
rm(acq_99_wide)


# Acquisition Register
# Agreement Gold-Standard
# Count
acq_99_off[R1_register == GS, .N] ## 68 / 79
acq_99_off[E1_register == GS, .N] ## 74 / 90

# Kappa
acq_99_kappa_off_e  <- kappa2(acq_99_off[, .(E1_register, GS)])
acq_99_kappa_off_r1 <- kappa2(acq_99_off[, .(R1_register, GS)])

# Agreement Previous task
# Count
acq_99_off[R1_register == R1_qrater, .N] ## 53 / 79

# Kappa
acq_99_kappa_off_r2 <- kappa2(acq_99_off[, .(R1_register, R1_qrater)])

# Inter-rater agreement
acq_99_off[E1_register == R1_register, .N] ## 66 / 79
acq_99_kappa_off_er <- kappa2(acq_99_off[, .(R1_register, E1_register)])

# Number of images with full agreement
acq_99_summary[Trainees_Fail == 9 | Trainees_Pass == 9] #29:99
acq_99_summary[Trainees_Fail == 7 | Trainees_Pass >= 7] #29:99


# Registration 99
# Intra-rater agreement: Expert between sessions
# K=0.873, z=8.69
reg_99_kappa_expert <- kappa2(reg_99_exp[, -1])
sum(reg_99_exp[[1]] == reg_99_exp[[2]])
# 93/99

# Gold standard: new images
reg_99_summary[, .N, Expert]

# Inter-rater agreement
# Calculate Fleiss' Kappa
reg_99_kappa_raters <- kappam.fleiss(reg_99_wide)
# Kappa = 0.563; Z = 33.6
rm(reg_99_wide)


# Registration Register
# Agreement Gold-Standard
# Count
reg_99_off[R1_register == GS, .N] ## 24 / 31
reg_99_off[E1_register == GS, .N] ## 34 / 44

# Kappa
reg_99_kappa_off_e  <- kappa2(reg_99_off[, .(E1_register, GS)])
reg_99_kappa_off_r1 <- kappa2(reg_99_off[, .(R1_register, GS)])

# Agreement Previous task
# Count
reg_99_off[R1_qrater == R1_register, .N] ## 20 / 31

# Kappa
reg_99_kappa_off_r2 <- kappa2(reg_99_off[, .(R1_qrater, R1_register)])

# Inter-rater agreement
reg_99_off[E1_register == R1_register, .N] ## 26 / 31
reg_99_kappa_off_er <- kappa2(reg_99_off[, .(R1_register, E1_register)])

# Number of images with full agreement
reg_99_summary[Trainees_Fail == 8 | Trainees_Pass == 8]
reg_99_summary[Trainees_Fail == 6 | Trainees_Pass >= 6]


# Skull segmentation
# Inter-rater reliability: 0.836 Kappa
rskull_kappa_experts <- kappa2(rskull_qc[, .(Expert01, Expert02)])
rm(rskull_qc)



## OUT: Plots
# Acquisition
fp_count    <- here("plots/raw_tiles-agreement.png")
if (!file.exists(fp_count) | rec_plots) {
  p_count   <- ggplot(acq_99_count, aes(Rater, Rater2)) +
    theme_classic() +
    theme(text = element_text(size = 14), legend.position = "right") +
    geom_tile(aes(fill = Count)) + geom_text(aes(label = Perc), size = 3.5) +
    scale_fill_gradient(low = "white", high = "#028202", limits = c(0, 1)) +
    labs(y = "Rater", fill = "Agreement\n(Percentage)")

  ggsave(fp_count, width = 8, height = 8, units = "in", dpi = 600)
  rm(p_count)
}
rm(fp_count)

fp_corr     <- here("plots/raw_tiles-agreement2.png")
if (!file.exists(fp_corr) | rec_plots) {
  p_corr      <- ggplot(acq_99_corr, aes(Rater, Rater2)) +
    theme_classic() +
    theme(text = element_text(size = 14), legend.position = "right") +
    geom_tile(aes(fill = Corr)) + geom_text(aes(label = Corr), size = 3.5) +
    scale_fill_gradient(low = "white", high = "#028202", limits = c(0, 1)) +
    labs(y = "Rater", fill = "Agreement\n(Correlation)")

  ggsave(fp_corr, width = 8, height = 8, units = "in", dpi = 600)
  rm(p_corr)
}
rm(fp_corr)

fp_agree_99 <- here("plots/raw_bars-agreement.png")
if (!file.exists(fp_agree_99) | rec_plots) {
  p_pass  <- ggplot(acq_99_plot[QC_orig == "Pass"],
                    aes(Image, N, fill = Rating)) +
    theme_classic() +
    theme(text = element_text(size = 9),
          #axis.text.y = element_blank(),
          #axis.ticks.y = element_blank(),
          legend.position = "left") +
    geom_bar(stat = "identity") +
    coord_flip() +
    scale_fill_manual(values = c("#9d0000", "#028202")) +
    scale_y_continuous(breaks = 1:9) +
    scale_x_discrete(labels = 1:99) +
    facet_col(vars(GS), scales = "free", space = "free") +
    labs(title = 'Selected "Pass" Cases',
         x = "Cases", y = "Ratings",
         fill = "Trainees\nratings")

  p_bline  <- ggplot(acq_99_plot[QC_orig == "Borderline"],
                     aes(Image, N, fill = Rating)) +
    theme_classic() +
    theme(text = element_text(size = 9),
          #axis.text.y = element_blank(),
          #axis.ticks.y = element_blank(),
          legend.position = "none") +
    geom_bar(stat = "identity") +
    coord_flip() +
    scale_fill_manual(values = c("#9d0000", "#028202")) +
    scale_y_continuous(breaks = 1:9) +
    scale_x_discrete(labels = 1:99) +
    facet_col(vars(GS), scales = "free", space = "free") +
    labs(title = 'Selected Borderline Cases',
         x = "Cases", y = "Ratings")

  p_fail  <- ggplot(acq_99_plot[QC_orig == "Fail"],
                    aes(Image, N, fill = Rating)) +
    theme_classic() +
    theme(text = element_text(size = 9),
          #axis.text.y = element_blank(),
          #axis.ticks.y = element_blank(),
          legend.position = "none") +
    geom_bar(stat = "identity") +
    coord_flip() +
    scale_fill_manual(values = c("#9d0000", "#028202")) +
    scale_y_continuous(breaks = 1:9) +
    scale_x_discrete(labels = 1:99) +
    facet_col(vars(GS), scales = "free", space = "free") +
    labs(title = 'Selected "Fail" Cases',
         x = "Cases", y = "Ratings")

  plot_grid(p_pass, p_bline, p_fail, nrow = 1, rel_widths = c(1.3, 1, 1))

  ggsave(fp_agree_99, width = 8, height = 8, units = "in", dpi = 600)
  rm(p_pass, p_bline, p_fail)
}
rm(fp_agree_99, acq_99_plot)

# Registration

fp_count    <- here("plots/lreg_tiles-agreement.png")
if (!file.exists(fp_count) | rec_plots) {
  p_count   <- ggplot(reg_99_count, aes(Rater, Rater2)) +
    theme_classic() +
    theme(text = element_text(size = 14), legend.position = "right") +
    geom_tile(aes(fill = Count)) + geom_text(aes(label = Perc), size = 3.5) +
    scale_fill_gradient(low = "white", high = "#028202", limits = c(0, 1)) +
    labs(y = "Rater", fill = "Agreement\n(Percentage)")

  ggsave(fp_count, width = 8, height = 8, units = "in", dpi = 600)
  rm(p_count)
}
rm(fp_count)

fp_corr     <- here("plots/lreg_tiles-agreement2.png")
if (!file.exists(fp_corr) | rec_plots) {
  p_corr <- ggplot(reg_99_corr, aes(Rater, Rater2)) +
    theme_classic() +
    theme(text = element_text(size = 14), legend.position = "right") +
    geom_tile(aes(fill = Corr)) + geom_text(aes(label = Corr), size = 3.5) +
    scale_fill_gradient(low = "white", high = "#028202", limits = c(0, 1)) +
    labs(y = "Rater", fill = "Agreement\n(Correlation)")

  ggsave(fp_corr, width = 8, height = 8, units = "in", dpi = 600)
  rm(p_corr)
}
rm(fp_corr)

fp_reg_99   <- here("plots/lreg_bars-agreement.png")
if (!file.exists(fp_reg_99) | rec_plots) {
  p_pass  <- ggplot(reg_99_plot[QC_orig == "Pass"],
                    aes(Image, N, fill = Rating)) +
    theme_classic() +
    theme(text = element_text(size = 9),
          #axis.text.y = element_blank(),
          #axis.ticks.y = element_blank(),
          legend.position = "left") +
    geom_bar(stat = "identity") +
    coord_flip() +
    scale_fill_manual(values = c("#9d0000", "#028202")) +
    scale_y_continuous(breaks = 1:8) +
    scale_x_discrete(labels = 1:99) +
    facet_col(vars(GS), scales = "free", space = "free") +
    labs(title = 'Selected "Pass" Cases',
         x = "Cases", y = "Ratings",
         fill = "Trainees\nratings")

  p_bline  <- ggplot(reg_99_plot[QC_orig == "Borderline"],
                    aes(Image, N, fill = Rating)) +
    theme_classic() +
    theme(text = element_text(size = 9),
          #axis.text.y = element_blank(),
          #axis.ticks.y = element_blank(),
          legend.position = "none") +
    geom_bar(stat = "identity") +
    coord_flip() +
    scale_fill_manual(values = c("#9d0000", "#028202")) +
    scale_y_continuous(breaks = 1:8) +
    scale_x_discrete(labels = 1:99) +
    facet_col(vars(GS), scales = "free", space = "free") +
    labs(title = 'Selected Borderline Cases',
         x = "Cases", y = "Ratings")

  p_fail  <- ggplot(reg_99_plot[QC_orig == "Fail"],
                    aes(Image, N, fill = Rating)) +
    theme_classic() +
    theme(text = element_text(size = 9),
          #axis.text.y = element_blank(),
          #axis.ticks.y = element_blank(),
          legend.position = "none") +
    geom_bar(stat = "identity") +
    coord_flip() +
    scale_fill_manual(values = c("#9d0000", "#028202")) +
    scale_y_continuous(breaks = 1:8) +
    scale_x_discrete(labels = 1:99) +
    facet_col(vars(GS), scales = "free", space = "free") +
    labs(title = 'Selected "Fail" Cases',
         x = "Cases", y = "Ratings")

  plot_grid(p_pass, p_bline, p_fail, nrow = 1, rel_widths = c(1.3, 1, 1))

  ggsave(fp_reg_99, width = 8, height = 8, units = "in", dpi = 600)
  rm(p_pass, p_bline, p_fail)
}
rm(fp_reg_99, reg_99_plot, rec_plots)


## OUT: Table
f_table     <- here("data/derivatives/agreement_pre-post_meeting.docx")
if (!file.exists(f_table) | rec_table) {
reg_meeting |>
  flextable() |>
  separate_header() |>
  labelizor(part = "header", labels = c("Change" = "Images changed")) |>
  bold(part = "header") |>
  italic(~ Rater == "Average") |>
  hline(i = ~ before(Rater, "Average"),
        border = fp_border_default(width = 2)) |>
  autofit() |>
  save_as_docx(path = f_table)
}
rm(f_table, rec_table)

## OUT: RDS objects
# Acquisition 99 — Count
write_rds(acq_99_count, here("data/derivatives/qc_count_acq_dt.rds"))

# Acquisition 99 — Correlation
write_rds(acq_99_corr, here("data/derivatives/qc_corr_acq_dt.rds"))

# Registration 99 — Count
write_rds(reg_99_count, here("data/derivatives/qc_count_reg_dt.rds"))

# Registration 99 — Correlation
write_rds(reg_99_corr, here("data/derivatives/qc_corr_reg_dt.rds"))
