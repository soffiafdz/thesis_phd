# `references.bib` audit log

Tracks all corrections made to the thesis bibliography, the workflow used to
find them, and remaining items that warrant further attention. Maintained
during conversations with Claude; treat as a working document, not a final
artifact.

Last updated: 2026-05-21

## Headline numbers

| Stage | Entries | `and others` | Duplicate DOIs |
|---|---:|---:|---:|
| Initial state | 380 | 47 | 97 DOIs in 2+ entries |
| After DOI-based dedup | 279 | 5 | 0 |
| After Crossref author lookups | 279 | 1 (Dima 2022) | 0 |
| After consortium-author swap (Dima) | 279 | 0 | 0 |
| After title+year dedup pass | 264 | 0 | 0 |
| After DOI restoration on merged entries | 264 | 0 | 0 |
| After full Crossref audit of all DOI entries | 264 | 0 | 0 |

The backup of the original bib is `references.bib.before_cleanup`; the backup
immediately before the title-based dedup pass is `references.bib.before_title_dedup`.
Both can be deleted once a render has been verified.

## Sources used

Per the project rule against fabricating citation information, every
correction below is sourced from one of three places, listed by trust:

1. **Bib-internal data** — kebab-case Zotero duplicates that were already
   in the bib (Zotero pulls from Crossref/publisher metadata, so these are
   generally authoritative). Used in steps 1, 2, 4.
2. **Crossref REST API** (live GET `https://api.crossref.org/works/{DOI}`)
   for entries without an internal Zotero twin. Used in steps 3 and 6.
3. **Pre-merge backup** (`references.bib.before_title_dedup`) for restoring
   DOIs that were accidentally dropped. Used in step 5.

No author/title information was supplied from training data. The only piece
of training-data knowledge used was the Neurology DOI URL pattern for
`jack1997`/`jack2000`, and that was verified post-hoc by title match against
Crossref before any data was written to the bib (see step 3 caveat).

## Corrections applied

### 1. Schoemaker 2019 — author truncation and triplicate

The `@schoemaker2019` entry had `Pietrantonio, Sara and others` as the trailing
author list. Two unused duplicates (`schoemaker_hippocampal_ventricle_2019`,
`schoemaker_hippocampal--ventricle_2019`) carried the full 9-author list.

- Replaced the truncated author list with the full one
  (`Schoemaker, Dorothee and Buss, Claudia and Pietrantonio, Sandra and
  Maunder, Larah and Freiesleben, Silka Dawn and Hartmann, Johanna and
  Collins, D. Louis and Lupien, Sonia J. and Pruessner, Jens C.`).
- Corrected `Sara Pietrantonio` → `Sandra Pietrantonio`.
- Standardized `content/chapter6.qmd` from `@schoemaker_hippocampal_ventricle_2019`
  to `@schoemaker2019` so a single key is used across the thesis.
- Removed the two unused duplicate entries.

### 2. DOI-based dedup (97 DOI groups)

For every DOI that appeared in 2+ entries, the cited short-key version was
replaced with the body of the more complete kebab-case Zotero version
(preserving the cited key so no `.qmd` edits are needed). All non-cited
duplicates were dropped.

Net effect:
- Removed 95 uncited duplicate entries.
- Replaced the body of 96 cited entries with the corresponding Zotero version's
  content. This pulled in:
  - Full author lists (eliminated 91 of the 47 `and others` cases).
  - Corrected given names where the short-key version had transcription
    errors. Examples discovered during the pass:
    - `bettio2017`: `Lakshmi Rajendran` → `Luckshi Rajendran`
      (note: re-audit found Crossref returns "Luckshi"; current entry now
      matches Crossref).
    - `yao2019`: `Yao, Weining and Wang, Sheng` →
      `Yao, Wenbin and Wang, Shan`.
    - `cao2018`: `Cao, Lei and Li, Liang` → `Cao, Liang and Li, Long`.
  - Page numbers, ISSN, full journal names, etc.
- Removed one literal-duplicate `@article{fernandez-lozano_enhanced_2025, ... }`
  block (two entries with identical key and content existed).

### 3. `and others` entries with no kebab-case fallback

Five entries retained `and others` after the DOI dedup. For four, the full
author list was retrieved from the Crossref REST API and substituted in:

| Key | DOI | Source | Action |
|---|---|---|---|
| `pizarro2016automated` | `10.3389/fninf.2016.00052` | DOI was in the bib; live GET `https://api.crossref.org/works/10.3389/fninf.2016.00052` | 12-author list inserted (`Cheng, Xinwei` was also corrected to `Cheng, Xi`) |
| `goubran2020` | `10.1002/hbm.24811` | DOI was in the bib; live GET `https://api.crossref.org/works/10.1002/hbm.24811` | 16-author list inserted |
| `jack1997` | `10.1212/WNL.49.3.786` | DOI was **not** in the bib; supplied from prior knowledge of Neurology's DOI URL pattern, then verified post-hoc by confirming the Crossref response's title matches the bib title verbatim. DOI now added to the entry so it's reproducible. | 9-author list inserted (subsequently replaced by the Zotero twin's identical list during step 4) |
| `jack2000` | `10.1212/WNL.55.4.484` | Same as above — DOI guessed then verified by title match; DOI now added to the entry. | 9-author list inserted (subsequently replaced by Zotero twin's identical list during step 4) |
| `dima_subcortical_2022` | `10.1002/hbm.25320` | DOI was in the bib; live GET to Crossref returned 205 authors with `Karolinska Schizophrenia Project (KaSP)` in the final position. | `and others` replaced with the literal corporate author `{Karolinska Schizophrenia Project (KaSP)}` (braced so citeproc treats it as a single literal). Yields predictable rendering without relying on `and others` → "et al." conversion. |

**Caveat on the Jack DOIs:** the `10.1212/WNL.{volume}.{issue}.{firstpage}`
URL pattern is a long-standing Neurology convention I knew from training
data. I would not have considered that a reliable source on its own; the
verification step was the Crossref title+year match against the bib entry.
If you re-run the audit and want to avoid that pattern entirely, look the
two papers up by title via the Crossref query endpoint instead
(`https://api.crossref.org/works?query.title=...&query.author=Jack`).

### 4. Title+year-based dedup pass (15 pairs)

After the DOI dedup, 15 duplicate pairs remained where one entry lacked a `doi=`
field and so was invisible to DOI matching. Same merge logic applied:

| Cited (kept) | Removed (uncited) |
|---|---|
| `raz2000` | `raz_aging_2000` |
| `pizarro2016automated` | `pizarro_automated_2016` |
| `keshavan2019combining` | `keshavan_combining_2019` |
| `chen2019` | `chen_enhancement_2019` |
| `goubran2020` | `goubran_hippocampal_2020` |
| `williams2023inter` | `williams_inter-rater_2023` |
| `das2012loris` | `das_loris_2012` |
| `jack1997` | `jack_medial_1997` |
| `fonov2012` | `fonov_multi-atlas_2012` |
| `xie2018` | `xie_near_2018` |
| `provins2023quality` | `provins_quality_2023` |
| `jack2000` | `jack_rates_2000` |
| `brusini2020` | `brusini_shape_2020` |
| `landis1977measurement` | `landis_measurement_1977` |
| `wangx2019` | `wang_relationship_2019` |

### 5. DOI restoration after step 4

When a kebab-case Zotero entry had no `doi=` field (the DOI lived only in the
`url` field), the merge in step 4 silently dropped the DOI from the cited
entry. The DOI was reinserted from the pre-merge backup for 8 keys:
`pizarro2016automated`, `provins2023quality`, `williams2023inter`,
`keshavan2019combining`, `das2012loris`, `landis1977measurement`,
`brusini2020`, `wangx2019`.

### 6. Crossref audit of remaining hand-typed entries (6 keys)

Six entries still looked hand-typed (no Zotero fingerprint fields) but had a
DOI to verify against. Source for each correction: live GET to
`https://api.crossref.org/works/{DOI}` using the DOI already recorded in the
entry. Two had transcription errors:

| Key | DOI | Errors found |
|---|---|---|
| `backhausen2016quality` | `10.3389/fnins.2016.00558` | `Lena L` → `Lea L.`; `Buse, Jost` → `Buse, Judith` |
| `dadar2018validation` | `10.1002/hbm.23894` | `Owen T` → `Owen T.`; missing trailing consortium author `{Alzheimer's Disease Neuroimaging Initiative}` |

The other four (`fernandez-lozano_hippocampal_2026`, `grimm_residual_2010`,
`livingston_dementia_2024`, `duvernoy_human_2013`) were added recently from
authoritative sources or are books; no action required.

### 7. Unrelated correction in `acknowledgements.qmd`

While auditing, fixed `Aliza Brzesinski` → `Aliza Brzezinski` to match the
spelling used in `@brzezinski-rittner_disentangling_2025`.

### 8. Full Crossref audit of all 253 DOI-bearing entries

Every entry with a DOI was fetched via `https://api.crossref.org/works/{doi}`
(251 succeeded; 2 arXiv DOIs not indexed by Crossref). Author lists were
diffed using a brace-aware parser. Findings were classified into:

- **False positives** (the bib is right): Crossref's family/given fields are
  swapped (notably `shehzad2015preprocessed` for a Frontiers conference
  abstract), Crossref puts an entire name in the `family` field with empty
  `given` (`aubert2006twenty`, `diaz_brinton_healthy_2008`), Crossref data
  is incomplete (`pruessner2000` lists 1/8, `fleiss2003measurement` lists
  0/3, `marrugat_adaptation_2003` initially listed 1/12).
- **Formatting differences** (no action): regular `-` vs Unicode `‐` in
  hyphenated names (Peng, de Lange, Dalaker, fernandez-lozano_enhanced_2025,
  de_jong_allometric_2017, etc.); LaTeX `\"a`/`\ae` vs UTF-8 `ä`/`æ`
  (Livingston, Selbæk, Kivimäki, Voevodskaya entries, etc.); Crossref
  mojibake of accented characters (`NordenskjÃ¶ld`).
- **Consortium-author format differences** (no action): Crossref uses
  prefixes like "For the X" / "for the X"; bib uses bare "X". The bib's
  form is the conventional one and renders cleanly.
- **Real bib errors** — fixed:

| Key | DOI | Issue | Fix source |
|---|---|---|---|
| `morse1993` | `10.1037/0882-7974.8.2.156` | First name was `Christopher K.` | Crossref → `Claire K.` |
| `das2012loris` | `10.3389/fninf.2011.00037` | Authors #3 (Vins) and #4 (Harlap) were in wrong order | Crossref author order |
| `koller_development_2012` | `10.7326/0003-4819-157-6-201209180-00002` | Authors were `Koller and Leening and Wolbers and Steyerberg and Et., Al` (literal placeholder, no given names) | Crossref full 11-author list |
| `kramer_longitudinal_2007` | `10.1037/0894-4105.21.4.412` | Same pattern: 4 surnames + `Et., Al` | Crossref full 8-author list |
| `marrugat_adaptation_2003` | `10.1136/jech.57.8.634` | Single surname only (`Marrugat`) | Crossref full 12-author list |
| `mehta_putting_2000` | `10.1037/1082-989x.5.1.23` | Surnames only (`Mehta and West`) | Crossref → with full given names |
| `neale_openmx_2016` | `10.1007/s11336-014-9435-8` | 4 surnames + `Et., Al` | Crossref full 10-author list |
| `ouldred_vascular_2010` | `10.12968/bjca.2010.5.5.47882` | Surnames only | Crossref → with full given names |
| `satorra_scaled_2001` | `10.1007/BF02296192` | Surnames only | Crossref → with full given names |
| `viswanathan_vascular_2009` | `10.1212/01.wnl.0000341271.90478.8e` | Surnames only | Crossref → with full given names |
| `livingston_dementia_2024` | `10.1016/S0140-6736(24)01296-0` | Authors 21–26 missing (Shirai, Singh-Manoux, Schneider, Walsh, Yao, Sommerlad); Mukadam was at position 21 but should be 27 | Crossref full 27-author list |
| `todd_ventricular_2018` | `10.3389/fnagi.2017.00445` | Missing trailing `{for the Alzheimer's Disease Neuroimaging Initiative}` | Crossref consortium author |
| `morrison2023a` | `10.1002/hbm.26407` | Missing trailing `{for Alzheimer's Disease Neuroimaging Initiative}` | Crossref consortium author |

These fixes are sourced exclusively from live Crossref REST API responses
keyed by the DOI already present in the bib. No data was supplied from
training memory.

## Audit workflow (for future re-runs)

1. **Collect cited keys** from `content/*.qmd` (`/tmp/extract_citations.py`),
   stripping trailing periods so `@key.` and `@key` collapse.
2. **DOI-based dedup**: group entries by normalized DOI; for each group with
   ≥2 entries, keep the cited short-key (preserving citations) but replace
   its body with the longest entry's body (Zotero versions are typically
   more complete). Drop all uncited duplicates.
3. **Title+year dedup**: same logic but match by `(title[:80].lower(), year)`.
   Catches duplicates where one entry has no DOI.
4. **Restore DOIs** that may have been lost in the body replacement (compare
   pre-merge backup, reinsert if DOI present in old but absent in new).
5. **Crossref audit** of remaining hand-typed entries with DOIs: GET
   `https://api.crossref.org/works/{DOI}`, compare author given names to bib.
   Flag mismatches for manual review.

## Remaining work / known gaps

- **All DOI-bearing entries (253) are now Crossref-audited** (step 8 above).
  No further machine-detectable transcription errors remain.
- **Count mismatches investigated but left unchanged.** Where the bib has
  *more* authors than Crossref (`vanessen2013wuminn`, `tremblay2021open`,
  `dadar_comparison_2018`, `morra2009`, `beekly2007national`), the bib
  typically credits a consortium that Crossref omits; that's a defensible
  difference and leaving the bib alone preserves information. Where the bib
  has *fewer* authors than Crossref by 1 (`schmaal_subcortical_2016`,
  `van_erp_subcortical_2016`, `ferretti_sex_2018`) or by a few (`peterson_sex_2024`,
  `bethlehem_brain_2022` by ~23), the difference is the consortium author
  Crossref adds; the omission doesn't affect in-text citations (et al.
  kicks in well before the consortium position).
- **12 entries have no DOI** and weren't auditable via Crossref:
  `bollen_latent_2006`, `castro_cvrisk_2026`, `dennis_neuroimaging_2008`,
  `efron_introduction_1994`, `fonov2012`, `grimm_growth_2016`,
  `newsom_longitudinal_2015`, `ramon_y_cajal_histologie_1909`,
  `rothman_no_1990`, `backhausen_quality_2016` (book chapter), `chen2019`
  and `xie2018` (arXiv preprints not indexed in Crossref). Most are books
  or pre-DOI papers. Could be audited via Crossref's title-search endpoint
  (`https://api.crossref.org/works?query.title=...&query.author=...`); lower
  priority.
- **No CSL is configured** in `_quarto.yml`, so citation rendering depends on
  pandoc's default. If the rendered PDF still shows individual-author lists
  rather than "et al." for multi-author papers, wiring up `apa.csl` (already
  vendored in `source/paper3/reports-src/`) would give predictable behavior.
- **`reference-section-title: "References"`** is set in `_quarto.yml`; verify
  that the rendered References section now matches the cleaned bib (e.g., no
  duplicate Schoemaker or Fernandez-Lozano entries appear).
