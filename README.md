# Analyses for the Qrater manuscript

This repo contains the necessary material to reproduce the analysis, tables and figures shown in the manuscript.
The source MRI data used can be requested by the respective dataset providers.

## Contents:
- `data`: Directory with data.
  - `data/raw`: Subdirectory with raw data and lists.
  - `data/derivatives:` Subirectory for derivatives created from the analyses.
  - `data/qc-ratings_clean`: Clean CSV files with QC ratings for all Tasks.
    This subdirectory is created from the analyses.
- `scripts/`: Directory with needed R and shell code.
  - `scripts/backend`: Subdirectory with other code used for managing data
    but unnecessary to reproduce the results.
- `renv/`: Renv sourcedirectory for replicating R library.
- renv.lock: Renv lock file.
- LICENSE: GPL-3.0 license.
- README.md: This file.


## Parse data

### Raw MRI (Acquisition)

#### Proto-balanced dataset: NACC-388
Script: `scripts/data_acquisition388.R`

Requires:
- Raw QC file:
  - `data/raw/qc_ratings/raw/balanced_data/NACC_338_Experts_2022-01-14.csv`
- Case dictionary:
  - `data/raw/nacc/CaseIDs.csv`

Creates:
- A CSV file with the cleaned QC ratings:
  - `data/qc-ratings_clean/raw/NACC-388_qc-ratings.csv`
- A RDS object with the balanced dataset data for the analyses:
  - `acq_388`: `data/derivatives/acquisition_388_dt.rds`

#### Balanced Dataset: NACC-99
Script: `scripts/data_acquisition99.R`

Requires:
- Raw QC files:
  - `data/raw/qc_ratings/raw/balanced_data/NACC_99_Expert_2022-09-23.csv`
  - `data/raw/qc_ratings/raw/balanced_data/NACC_99_Expert_2022-10-28.csv`
  - `data/raw/qc_ratings/raw/balanced_data/NACC_99_Expert_consensus.csv`
  - `data/raw/qc_ratings/raw/balanced_data/NACC_99_trainees_2022-04-05.csv`
- Case dictionary:
  - `data/raw/nacc/CaseIDs.csv`

Creates:
- A CSV file with the cleaned QC ratings:
  - `data/qc-ratings_clean/raw/NACC-99_qc-ratings.csv`
- A TSV file with all rater's qualitative comments:
  - `data/derivatives/acq_99_comments.csv`
- A RDS object with the balanced dataset data for the analyses:
  - `acq_99`: `data/derivatives/acquisition_99_dt.rds`

#### Complete Dataset: ADNI-10196
Script: `scripts/data_acquisition.R`

Requires:
- Raw QC files:
  - `data/raw/qc_ratings/raw/complete_data/ADNI_Raw_Expert_2022-11-23.csv`
  - `data/raw/qc_ratings/raw/complete_data/ADNI_Raw_Raters_2022-06-29.csv`

Creates:
- A CSV file with the cleaned QC ratings:
  - `data/qc-ratings_clean/raw/ADNI_qc-ratings.csv`
- A RDS object with the complete dataset data for the analyses:
  - `acquis`: `data/derivatives/acquisition_dt.rds`

### Linear Registration

#### Balanced Dataset: Multiple-99
Script: `scripts/data_registration99.R`

Requires:
- Raw QC files:
  - `data/raw/qc_ratings/registration/balanced_data/MULTI_99_Linear_Expert_2022-09-23.csv`
  - `data/raw/qc_ratings/registration/balanced_data/MULTI_99_Linear_Expert_2022-10-12.csv`
  - `data/raw/qc_ratings/registration/balanced_data/MULTI_99_Linear_Expert_consensus.csv`
  - `data/raw/qc_ratings/registration/balanced_data/MULTI_99_Linear_Trainees_2022-10-14.csv`
  - `data/raw/qc_ratings/registration/balanced_data/MULTI_99_Linear_Trainees_History_2022-10-14.csv`
- Case dictionary:
  - `data/raw/list_cases_linreg.csv`

Creates:
- A CSV files with the cleaned QC ratings:
  - `data/qc-ratings_clean_linear_registration/MULTI-99_qc-ratings.csv`
- A TSV file with all rater's qualitative comments:
  - `data/derivaitves/reg_99_comments.csv`
- A RDS object with the balanced dataset data for the analyses:
  - `reg_99`: `data/derivatives/registration_99_dt.rds`

#### Complete Dataset: Multiple-10196

##### Ratings before mid-task interruption
Script: `scripts/data_registration_premeeting.R`

Requires:
- Raw QC files:
  - `data/raw/qc_ratings/registration/pre_meeting/ADNI_Linear_Rater01_history_2023-08-03.csv`
  - `data/raw/qc_ratings/registration/pre_meeting/ADNI_Linear_Rater02_history_2023-08-03.csv`
  - `data/raw/qc_ratings/registration/pre_meeting/ADNI_Linear_Rater03_history_2023-08-03.csv`
  - `data/raw/qc_ratings/registration/pre_meeting/ADNI_Linear_Rater04_history_2023-08-03.csv`
  - `data/raw/qc_ratings/registration/pre_meeting/ADNI_Linear_Rater05_history_2023-08-03.csv`
  - `data/raw/qc_ratings/registration/pre_meeting/ADNI_Linear_Rater06_history_2023-08-03.csv`
  - `data/raw/qc_ratings/registration/pre_meeting/ADNI_Linear_Rater07_history_2023-08-03.csv`
  - `data/raw/qc_ratings/registration/pre_meeting/ADNI_Linear_Rater08_history_2023-08-03.csv`

Creates:
- A RDS object with the balanced dataset data for the analyses:
  - `regis_pre`: `data/derivatives/registration_premeeting_dt.rds`

##### Final ratings (Post-interruption)
Script: `scripts/data_registration.R`

Requires:
- Raw QC files:
  - `data/raw/qc_ratings/registration/complete_data/ADNI_Linear_Rater01_Ratings_2022-11-23.csv`
  - `data/raw/qc_ratings/registration/complete_data/ADNI_Linear_Rater02_Ratings_2022-11-18.csv`
  - `data/raw/qc_ratings/registration/complete_data/ADNI_Linear_Rater03_Ratings_2022-11-18.csv`
  - `data/raw/qc_ratings/registration/complete_data/ADNI_Linear_Rater04_Ratings_2022-11-18.csv`
  - `data/raw/qc_ratings/registration/complete_data/ADNI_Linear_Rater05_Ratings_2022-11-18.csv`
  - `data/raw/qc_ratings/registration/complete_data/ADNI_Linear_Rater06_Ratings_2022-11-18.csv`
  - `data/raw/qc_ratings/registration/complete_data/ADNI_Linear_Rater07_Ratings_2022-11-18.csv`
  - `data/raw/qc_ratings/registration/complete_data/ADNI_Linear_Rater08_Ratings_2022-11-18.csv`

Creates:
- A CSV file with the cleaned QC ratings:
  - `data/qc-ratings_clean/linear_registration/ADNI_qc-ratings.csv`
- A RDS object with the complete dataset data for the analyses:
  - `regis`: `data/derivatives/registration_dt.rds`

### Skull Segmentation
Script: `scripts/data_segmentation.R`

Requires:
  - Raw QC file:
    - `data/raw/qc_ratings/skull/ADNI_Skull_Experts_2022-09-23.csv`

Creates:
- A CSV file with the cleaned QC ratings:
  - `data/qc-ratings_clean/skull_segmentation/ADNI_qc-ratings.csv`
- A RDS object with the complete dataset data for the analyses:
  - `rskull`: `data/derivatives/segmentation_dt.rds`

## Tables

### Demographics
Script: `scripts/data_demog.R`

Note: this script requires additional files not included in the repo.

Requires:
- Demographic data
(given the lack of permission to redistribute data,
these files are not included in the repo, but they can be obtained
from the respective Dataset providers with the appropriate permissions):
  - NACC:
    - Demographic data: `data/raw/nacc/NACC.csv`
    - MRI data: `data/raw/nacc/NACCmri.csv`
  - ADNI:
    - Demographic data: `data/raw/adni/ADNIMERGE.csv`
    - MRI data: `data/raw/adni/MRILIST.csv`
  - HCP:
    - Demographic data: `data/raw/hcp/hcp_demog.csv`
  - PPMI:
    - Demographic data: `data/raw/ppmi/ppmi_demog.csv`
  - PreventAD:
    - Demographic data: `data/raw/preventad/preventad_demog.csv`
- List files (data cleaning purposes):
  - `data/raw/nacc/CaseIDs.csv`
  - `data/raw/raw_simon.csv`
  - `data/raw/list_cases_linreg.csv`
  - `data/raw/preventad/link_imgs.csv`
- Clean QC files (filtering purposes;
these files are generated by running the scripts from the Parse Data section):
  - `data/qc-ratings_clean/raw/NACC-338_qc-ratings.csv`
  - `data/qc-ratings_clean/raw/ADNI_qc-ratings.csv`
  - `data/qc-ratings_clean/skull_segmentation/ADNI_qc-ratings.csv`

Creates:
- A Word document with demographic data for the NACC dataset (NACC-99 & NACC-338):
  - `data/derivatives/nacc_demog-table.docx`
- A Word document with demographic data for the ADNI data (ADNI-10196):
  - `data/derivatives/adni-10k_demog-table.docx`
- A Word document with demographic data for the Linear Registration task's Multiple datasets
  (MULTI-99):
  - `data/derivatives/linreg99_demog-table.docx`
- A Word document with demographic data for the subsets of ADNI data in
  the Skull Segmentation task (ADNI-6968 & ADNI-1746):
  - `data/derivatives/skull_demog-table.docx`

### Image Parameters Table
Script: `scripts/img_params.R`

Requires:
- Source data: `data/raw/databases_params.csv`

Creates:
- A Word document with the imaging parameters data for all datasets used:
  - `data/derivatives/imgs_params.docx`

## Analysis

### Agreement
Script: `scripts/agreement.R`

Requires:
- RDS objects of the cleaned data
  (these files are generated by running the scripts from the Parse Data section):
  - `data/derivatives/acquisition_388_dt.rds`
  - `data/derivatives/acquisition_99_dt.rds`
  - `data/derivatives/registration_99_dt.rds`
  - `data/derivatives/registration_dt.rds`
  - `data/derivatives/registration_premeeting_dt.rds`
  - `data/derivatives/segmentation_dt.rds`
- QC ratings of Expert and Trainee off-qrater (Register):
  - `data/raw/qc_ratings/raw/off_qrater/OffQrater_Raw_Rater.csv`
  - `data/raw/qc_ratings/raw/off_qrater/OffQrater_Raw_Expert.csv`
  - `data/raw/qc_ratings/registration/off_qrater/OffQrater_Linear_Rater.csv`
  - `data/raw/qc_ratings/registration/off_qrater/OffQrater_Linear_Expert.csv`

Analysis results:
After running the script, the analysis results are saved in the environment as
the following objects.
- Acquisition 338
  - Inter-rater agreement between experts: `acq_388_kappa`
- Acquisition 99
  - Intra-rater agreement of Expert1's two sessions: `acq_99_kappa_expert`
  - Inter-rater agreement of all raters: `acq_99_kappa_raters`
  - Intra-rater agreement of Expert1 using Register with their Gold-Standard ratings: `acq_99_kappa_off_e`
  - Inter-rater agreement of Rater1 using Register with Expert1's Gold-Standard ratings: `acq_99_kappa_off_r1`
  - Intra-rater agreement of Rater1 between using Register and Qrater: `acq_99_kappa_off_r2`
  - Inter-rater agreement between Expert1 and Rater1 using Register: `acq_99_off_er`
- Registration 99
  - Intra-rater agreement of Expert1's two sessions: `reg_99_kappa_expert`
  - Inter-rater agreement of all raters: `reg_99_kappa_raters`
  - Intra-rater agreement of Expert1 using Register with their Gold-Standard ratings: `reg_99_kappa_off_e`
  - Inter-rater agreement of Rater1 using Register with Expert1's Gold-Standard ratings: `reg_99_kappa_off_r1`
  - Intra-rater agreement of Rater1 between using Register and Qrater: `reg_99_kappa_off_r2`
  - Inter-rater agreement between Expert1 and Rater1 using Register: `reg_99_off_er`
- Skull ADNI
  - Inter-rater agreement between Expert1 and Expert2: `rskull_kappa_experts`

Creates:
- Plots:
  - Acquisition 99:
    - Matrix of agreement between raters (Percentage):
      - `plots/raw_tiles-agreement.png`
    - Matrix of agreement between raters (Correlation):
      - `plots/raw_tiles-agreement2.png`
    - Bar plots of agreement:
      - `plots/raw_bars-agreement.png`
  - Registration 99:
    - Matrix of agreement between raters (Percentage):
      - `plots/lreg_tiles-agreement.png`
    - Matrix of agreement between raters (Correlation):
      - `plots/lreg_tiles-agreement2.png`
    - Bar plots of agreement:
      - `plots/lreg_bars-agreement.png`
- A Word document with a table containing the change before and
  after the Registration task interruption:
  - `data/derivatives/agreement_pre-post_meeting.docx`
- RDS objects with the agreement data:
  - `data/derivatives/qc_count_acq_dt.rds`
  - `data/derivatives/qc_corr_acq_dt.rds`
  - `data/derivatives/qc_count_reg_dt.rds`
  - `data/derivatives/qc_corr_reg_dt.rds`

### Timing
Script: `scripts/timing.R`

Requires:
- RDS objects of the cleaned data
  (these files are generated by running the scripts from the Parse Data section):
  - `data/derivatives/acquisition_99_dt.rds`
  - `data/derivatives/acquisition_dt.rds`
  - `data/derivatives/registration_99_dt.rds`
  - `data/derivatives/registration_dt.rds`
  - `data/derivatives/segmentation_dt.rds`

Analysis results:
After running the script, the analysis results are saved in the environment as
the following objects.
- Acquisition 99
  - Wilcox test of time difference between Expert1's two sessions: `acq_99_e1_e1_test`
  - Effect size of time difference between Expert1's two sessions: `acq_99_e1_e1_es`
  - Wilcox test of time differences between Pass and Fail for all raters: `acq_99_pvf_all_test`
  - Effect size of time differences between Pass and Fail for all raters: `acq_99_pvf_all_es`
  - Wilcox test of time differences between Pass and Fail for trainees: `acq_99_pvf_tr_test`
  - Effect size of time differences between Pass and Fail for trainees: `acq_99_pvf_tr_es`
  - Corrected p values for multiple comparisons: `acq_99_p_fdr`
- Acquisition ADNI
  - Kruskal-Wallis test of time differences between ratings for all raters: `acquis_pvwvf_all_test`
  - Effect size of time differences between ratings for all raters: `acquis_pvwvf_all_es`
  - Post-hoc analysis of time differences between ratings: `acquis_posthoc`
  - Wilcox test of time difference between ADNI and Acq99 task: `acquis_99_adni_test`
  - Effect size of time difference between ADNI and Acq99 task: `acquis_99_adni_es`
  - Corrected p values for multiple comparisons: `acquis_p_fdr`
- Registration 99
  - Wilcox test of time difference between Expert1's two sessions: `reg_99_e1_e1_test`
  - Effect size of time difference between Expert1's two sessions: `reg_99_e1_e1_es`
  - Wilcox test of time differences between Pass and Fail for all raters: `reg_99_pvf_all_test`
  - Effect size of time differences between Pass and Fail for all raters: `reg_99_pvf_all_es`
  - Wilcox test of time differences between Pass and Fail for trainees: `reg_99_pvf_tr_test`
  - Effect size of time differences between Pass and Fail for trainees: `reg_99_pvf_tr_es`
  - Corrected p values for multiple comparisons: `reg_99_p_fdr`
- Registration ADNI
  - Wilcox test of time differences between ratings for all raters: `regis_pvf_all_test`
  - Effect size of time differences between ratings for all raters: `regis_pvf_all_es`
  - Wilcox test of time difference between ADNI and Reg99 task: `regis_99_adni_test`
  - Effect size of time difference between ADNI and Reg99 task: `regis_99_adni_es`
  - Corrected p values for multiple comparisons: `regis_p_fdr`
- Skull ADNI
  - Wilcox test of time differences between ratings for Expert1: `rskull_e1_test`
  - Effect size of time differences between ratings for Expert1: `rskull_e1_es`
  - Wilcox test of time differences between ratings for Expert2: `rskull_e2_test`
  - Effect size of time differences between ratings for Expert2: `rskull_e2_es`

Creates:
- A Word document with the timing data for the Acquisition 99 task:
  - `data/derivatives/acq_99_time.docx`
- A Word document with the timing data for the Acquisition ADNI task:
  - `data/derivatives/acq_adni_time.docx`
- A Word document with the post-hoc data for the Acquisition ADNI task:
  - `data/derivatives/acq_adni_posthoc.docx`
- A Word document with the timing data for the Registration 99 task:
  - `data/derivatives/reg_99_time.docx`
- A Word document with the timing data for the Registration ADNI task:
  - `data/derivatives/reg_adni_time.docx`
- A Word document with the timing data for the Skull Segmentation task:
  - `data/derivatives/seg_adni_time.docx`
- RDS objects with the timing data:
  - `data/derivatives/acq_99_time_dt.rds`
  - `data/derivatives/acquis_time_dt.rds`
  - `data/derivatives/reg_99_time_dt.rds`
  - `data/derivatives/regis_time_dt.rds`

### Correlation Timing and Agreement
Script: `cot_time_agreement.R`

Requires:
- RDS objects of the cleaned data
  (these files are generated by running the scripts from the other scripts in this section):
  - `data/derivatives/qc_count_acq_dt.rds`
  - `data/derivatives/qc_count_reg_dt.rds`
  - `data/derivatives/acq_99_time_dt.rds`
  - `data/derivatives/reg_99_time_dt.rds`

Analysis results:
After running the script, the analysis results are saved in the environment as
the following objects.
- Acquisition 99
  - Correlation between agreement with Expert1 and median time: `acq_99_agree_time_med`
  - Correlation between agreement with Expert1 and total time: `acq_99_agree_time_tot`
- Registration 99
  - Correlation between agreement with Expert1 and median time: `reg_99_agree_time_med`
  - Correlation between agreement with Expert1 and total time: `reg_99_agree_time_tot`
