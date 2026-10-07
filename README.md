# EU Health Inequalities and Life Expectancy Analysis

## Overview

This junior-level public-health data project describes life expectancy differences across the 27 EU member states and explores how country-year life expectancy observations relate to the Eurostat S80/S20 income inequality ratio. It uses two official Eurostat indicators, a small SQL extraction step, and a reproducible R script. The analysis is descriptive and does not test causal explanations.

## Research Questions

- How does life expectancy differ across EU countries?
- How has life expectancy changed over time?
- Is income inequality associated with life expectancy?

## Data

The data come from Eurostat's Statistics Database and were downloaded on **7 October 2026**. The API metadata reported the life-expectancy dataset was updated on 25 September 2026 and the income-inequality dataset on 5 October 2026.

| Indicator | Eurostat dataset | Selection used | Official source |
|---|---|---|---|
| Life expectancy at birth | **Life expectancy by age and sex** (`demo_mlexpec`) | Annual; total sex (`T`); age less than 1 year (`Y_LT1`, life expectancy at birth); years (`YR`) | [Eurostat Data Browser: demo_mlexpec](https://ec.europa.eu/eurostat/databrowser/product/view/demo_mlexpec) |
| Income inequality | **Income quintile share ratio S80/S20 for disposable income by sex and age group** (`ilc_di11`) | Annual (`A`); total age (`TOTAL`); total sex (`T`); ratio (`RAT`) | [Eurostat Data Browser: ilc_di11](https://ec.europa.eu/eurostat/databrowser/product/view/ilc_di11) |

The Eurostat API endpoints used to retrieve the data are [demo_mlexpec](https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/demo_mlexpec) and [ilc_di11](https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ilc_di11). The API was filtered to EU member-state codes and years **2015–2024**. Each year in the delivered complete-case dataset includes all **27 EU countries**, for **270 country-year observations**.

Life expectancy at birth is the mean number of years a newborn would be expected to live if the mortality conditions observed for that period continued throughout the person's life. The S80/S20 ratio divides the total equivalised disposable income received by the richest 20% of people by the total received by the poorest 20%; a higher value indicates greater income inequality.

The CSV is a four-column, cleaned analysis extract of published Eurostat observations. It contains complete country-year pairs with no duplicate country-year records. Eurostat source observations can carry flags (for example, estimates, provisional values, or breaks in series); the requested compact CSV does not retain flag columns, so consult the source tables for those metadata when interpreting individual observations.

## Variables

| Variable | Description |
|---|---|
| `country` | EU country name as supplied by Eurostat |
| `year` | Eurostat observation year |
| `life_expectancy` | Life expectancy at birth, in years |
| `income_inequality` | S80/S20 income quintile share ratio |

## Workflow

**Eurostat → SQL extraction → R cleaning/QA → descriptive statistics → correlation → linear regression → visualisation → interpretation**

## SQL

`sql/analysis.sql` selects the four required fields for 2015–2024, removes incomplete indicator pairs, and sorts the observations by country and year. `R/analysis.R` loads the CSV into an in-memory SQLite table and executes this query, so the SQL step is run against the supplied data as part of the reproducible workflow.

## R Analysis

`R/analysis.R` performs:

- data import and type checks
- missing-value, duplicate, and plausible-range checks
- cleaning of complete country-year rows
- descriptive summaries and latest-year country comparisons
- Pearson correlation and simple linear regression
- creation of the three figures in `outputs/`
- saving the computed findings to `results/results.txt`

Run the complete analysis from the project root:

```r
install.packages(c("tidyverse", "DBI", "RSQLite"))
```

```sh
Rscript R/analysis.R
```

## Statistical Methods

Only straightforward methods are used:

- Descriptive statistics
- Pearson correlation
- Simple linear regression (`life_expectancy ~ income_inequality`)

The correlation and regression pool country-year observations across 2015–2024. As the same countries appear repeatedly, the simple model does not account for within-country dependence or other country differences; its p-values should be read cautiously.

## Results

All figures below are calculated from the delivered Eurostat extract and reproduced in [`results/results.txt`](results/results.txt).

- **27 countries** and **270 complete country-year observations** were analysed from **2015 to 2024**.
- Mean life expectancy across all country-year observations was **79.97 years**; mean S80/S20 was **4.81**.
- The unweighted mean life expectancy across EU countries increased from **79.53 years in 2015** to **80.89 years in 2024**, a change of **1.36 years**.
- In 2024, the highest life expectancy was in **Spain (84.0 years)** and the lowest was in **Bulgaria (75.8 years)**.
- Across pooled country-year observations, Pearson's correlation was **r = -0.428 (p < 0.001)**.
- The simple regression slope was **-1.065 years per one-point increase in S80/S20 (p < 0.001; R² = 0.183)**.

In this unadjusted pooled analysis, higher country-year inequality ratios coincided with lower life expectancy on average. The slope is a descriptive association across country-years, not an estimate of the effect of changing inequality on life expectancy; the repeated observations also make the conventional significance tests potentially overconfident.

## Limitations

- This is observational, country-level data; association does not establish causation.
- Countries differ in many factors not included in the simple analysis, such as health systems, income levels, demographics, and disease burden.
- Country-year rows are repeated observations from the same countries. The Pearson test and simple regression do not adjust for that dependence.
- Eurostat observations may have source flags such as estimates, provisional values, or breaks in series; those flags are not retained in the compact CSV.
- The unweighted country mean gives each member state equal weight, regardless of population size.

## Conclusion

Life expectancy differed across EU countries in 2024 and the unweighted country average was higher in 2024 than in 2015. Across the pooled country-year observations, higher S80/S20 ratios were associated with lower life expectancy in the simple analysis. This pattern is useful for describing a public-health inequality question, but the analysis does not establish causality or account for repeated country observations and other differences between countries.
