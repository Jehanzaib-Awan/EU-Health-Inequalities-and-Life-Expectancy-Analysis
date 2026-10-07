-- The R script loads the cleaned Eurostat extract into this table, then runs this query.
SELECT
    country,
    year,
    life_expectancy,
    income_inequality
FROM eu_health_data
WHERE year BETWEEN 2015 AND 2024
  AND life_expectancy IS NOT NULL
  AND income_inequality IS NOT NULL
ORDER BY country, year;
