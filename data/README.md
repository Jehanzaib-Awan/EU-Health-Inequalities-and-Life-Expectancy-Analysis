# Data provenance

`eu_health_inequality.csv` is a cleaned analysis dataset derived from real observations retrieved from Eurostat's official dissemination API on **7 October 2026**. It contains four selected variables and no additional source dimensions.

## Eurostat sources

1. **Life expectancy by age and sex** — dataset code [`demo_mlexpec`](https://ec.europa.eu/eurostat/databrowser/product/view/demo_mlexpec) (API: [data endpoint](https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/demo_mlexpec)). The selection is annual, total sex (`T`), age less than one year (`Y_LT1`, life expectancy at birth), and years (`YR`). Eurostat's API metadata showed an update timestamp of 25 September 2026.
2. **Income quintile share ratio S80/S20 for disposable income by sex and age group** — dataset code [`ilc_di11`](https://ec.europa.eu/eurostat/databrowser/product/view/ilc_di11) (API: [data endpoint](https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/ilc_di11)). The selection is annual (`A`), total age (`TOTAL`), total sex (`T`), and ratio (`RAT`). Eurostat's API metadata showed an update timestamp of 5 October 2026.

The extraction covers the 27 EU member states and observation years 2015–2024. The two source series were matched by Eurostat country name and year. Only rows with both indicator values were retained. At extraction, every selected member state had both indicators in each selected year, yielding 270 country-year rows and no missing values or duplicate country-year combinations.

## Variables in the CSV

- `country`: country name from the Eurostat country dimension
- `year`: observation year
- `life_expectancy`: life expectancy at birth in years
- `income_inequality`: income quintile share ratio S80/S20

Eurostat's source tables provide observation flags (including break-in-series, estimated, and provisional statuses). The compact analysis CSV retains the numeric published observations but not the flags; consult the official Data Browser/API metadata when a flag for a particular observation matters.
