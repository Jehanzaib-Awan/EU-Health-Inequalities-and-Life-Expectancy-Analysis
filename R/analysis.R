# EU Health Inequalities and Life Expectancy Analysis
# Run from the project root with: Rscript R/analysis.R

# 1. Load packages ---------------------------------------------------------
library(tidyverse)
library(DBI)
library(RSQLite)

# Keep paths relative so the script runs from the project root.
data_file <- file.path("data", "eu_health_inequality.csv")

# 2. Import data -----------------------------------------------------------
raw_data <- readr::read_csv(
  data_file,
  col_types = cols(
    country = col_character(),
    year = col_integer(),
    life_expectancy = col_double(),
    income_inequality = col_double()
  ),
  show_col_types = FALSE
)

# 3. Data QA ---------------------------------------------------------------
cat("Data types:\n")
print(vapply(raw_data, class, character(1)))

missing_by_variable <- vapply(raw_data, function(x) sum(is.na(x)), integer(1))
cat("\nMissing values by variable:\n")
print(missing_by_variable)

n_duplicate_rows <- sum(duplicated(raw_data[c("country", "year")]))
cat("\nDuplicate country-year observations:", n_duplicate_rows, "\n")

cat("\nObserved ranges:\n")
print(raw_data %>% summarise(
  min_year = min(year, na.rm = TRUE),
  max_year = max(year, na.rm = TRUE),
  min_life_expectancy = min(life_expectancy, na.rm = TRUE),
  max_life_expectancy = max(life_expectancy, na.rm = TRUE),
  min_income_inequality = min(income_inequality, na.rm = TRUE),
  max_income_inequality = max(income_inequality, na.rm = TRUE)
))

if (n_duplicate_rows > 0) stop("Duplicate country-year records were found.")
if (any(missing_by_variable > 0)) stop("Missing values were found in the final analysis CSV.")
if (any(raw_data$year < 2015 | raw_data$year > 2024)) stop("Year outside the selected 2015-2024 period.")
if (any(raw_data$life_expectancy < 50 | raw_data$life_expectancy > 100)) stop("Life expectancy has an implausible value.")
if (any(raw_data$income_inequality <= 1 | raw_data$income_inequality > 100)) stop("S80/S20 has an implausible value.")

# 4. Data cleaning ---------------------------------------------------------
# The delivered CSV contains complete, unique EU country-year pairs only.
# Keep the explicit cleaning step for reproducibility and to make the rules clear.
clean_data <- raw_data %>%
  filter(
    !is.na(country), country != "",
    !is.na(year),
    !is.na(life_expectancy),
    !is.na(income_inequality)
  ) %>%
  distinct(country, year, .keep_all = TRUE) %>%
  arrange(country, year)

# 5. Descriptive statistics ------------------------------------------------
# Run the supplied SQL against the imported data using an in-memory SQLite DB.
con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
on.exit(DBI::dbDisconnect(con), add = TRUE)
DBI::dbWriteTable(con, "eu_health_data", clean_data, overwrite = TRUE)
sql_query <- paste(readLines(file.path("sql", "analysis.sql"), warn = FALSE), collapse = "\n")
analysis_data <- DBI::dbGetQuery(con, sql_query) %>%
  mutate(year = as.integer(year)) %>%
  as_tibble()

if (nrow(analysis_data) == 0) stop("The SQL query returned no rows.")

n_countries <- n_distinct(analysis_data$country)
year_min <- min(analysis_data$year)
year_max <- max(analysis_data$year)
latest_year <- year_max
latest_data <- analysis_data %>% filter(year == latest_year)
highest_latest <- latest_data %>% slice_max(life_expectancy, n = 1, with_ties = TRUE)
lowest_latest <- latest_data %>% slice_min(life_expectancy, n = 1, with_ties = TRUE)

mean_life_expectancy <- mean(analysis_data$life_expectancy)
mean_income_inequality <- mean(analysis_data$income_inequality)
annual_country_means <- analysis_data %>%
  group_by(year) %>%
  summarise(mean_life_expectancy = mean(life_expectancy), .groups = "drop")
mean_2015 <- annual_country_means %>% filter(year == year_min) %>% pull(mean_life_expectancy)
mean_latest <- annual_country_means %>% filter(year == latest_year) %>% pull(mean_life_expectancy)

# 6. Country comparison ----------------------------------------------------
country_latest <- latest_data %>%
  arrange(life_expectancy) %>%
  mutate(country = forcats::fct_reorder(country, life_expectancy))

# 7. Pearson correlation ---------------------------------------------------
correlation_test <- cor.test(
  analysis_data$income_inequality,
  analysis_data$life_expectancy,
  method = "pearson"
)
r_value <- unname(correlation_test$estimate)
correlation_p <- correlation_test$p.value

# 8. Simple linear regression ---------------------------------------------
linear_model <- lm(life_expectancy ~ income_inequality, data = analysis_data)
model_summary <- summary(linear_model)
regression_coefficient <- unname(coef(linear_model)[["income_inequality"]])
regression_p <- coef(model_summary)["income_inequality", "Pr(>|t|)"]
r_squared <- model_summary$r.squared

# 9. Visualisations --------------------------------------------------------
theme_set(theme_minimal(base_size = 12))

figure_country <- ggplot(country_latest, aes(x = country, y = life_expectancy)) +
  geom_col(fill = "#2F6B8A", width = 0.75) +
  coord_flip() +
  scale_y_continuous(limits = c(0, 90), expand = expansion(mult = c(0, 0.02))) +
  labs(
    title = paste("Life expectancy at birth by EU country,", latest_year),
    subtitle = "Total population; years",
    x = NULL,
    y = "Life expectancy (years)",
    caption = "Source: Eurostat, demo_mlexpec"
  ) +
  theme(panel.grid.major.y = element_blank())
ggsave(file.path("outputs", "life_expectancy_by_country.png"), figure_country,
       width = 9, height = 8, dpi = 300, bg = "white")

annual_mean <- analysis_data %>%
  group_by(year) %>%
  summarise(mean_life_expectancy = mean(life_expectancy), .groups = "drop")
figure_trend <- ggplot(analysis_data, aes(x = year, y = life_expectancy)) +
  geom_line(aes(group = country), colour = "#9CB4C2", alpha = 0.55, linewidth = 0.45) +
  geom_line(data = annual_mean, aes(x = year, y = mean_life_expectancy),
            colour = "#173F5F", linewidth = 1.2, inherit.aes = FALSE) +
  geom_point(data = annual_mean, aes(x = year, y = mean_life_expectancy),
             colour = "#173F5F", size = 2, inherit.aes = FALSE) +
  scale_x_continuous(breaks = year_min:year_max) +
  labs(
    title = "Life expectancy across EU countries over time",
    subtitle = "Thin lines: individual countries; dark line: unweighted EU-country mean",
    x = "Year",
    y = "Life expectancy at birth (years)",
    caption = "Source: Eurostat, demo_mlexpec"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path("outputs", "life_expectancy_trend.png"), figure_trend,
       width = 9, height = 5.5, dpi = 300, bg = "white")

figure_inequality <- ggplot(analysis_data, aes(x = income_inequality, y = life_expectancy)) +
  geom_point(colour = "#2F6B8A", alpha = 0.55, size = 2) +
  geom_smooth(method = "lm", formula = y ~ x, colour = "#D17A22",
              fill = "#E7B77C", linewidth = 0.9) +
  labs(
    title = "Income inequality and life expectancy",
    subtitle = "Country-year observations pooled across 2015-2024",
    x = "Income inequality (S80/S20 ratio)",
    y = "Life expectancy at birth (years)",
    caption = "The fitted line is a simple linear regression. Source: Eurostat, demo_mlexpec and ilc_di11"
  )
ggsave(file.path("outputs", "inequality_vs_life_expectancy.png"), figure_inequality,
       width = 8, height = 5.5, dpi = 300, bg = "white")

# 10. Save results ---------------------------------------------------------
format_p <- function(p) {
  if (p < 0.001) "<0.001" else sprintf("%.3f", p)
}
format_countries <- function(data) {
  paste(sprintf("%s (%.1f years)", data$country, data$life_expectancy), collapse = "; ")
}
if (regression_coefficient < 0) {
  direction_text <- "Higher S80/S20 values were associated with lower life expectancy in this pooled country-year analysis."
} else if (regression_coefficient > 0) {
  direction_text <- "Higher S80/S20 values were associated with higher life expectancy in this pooled country-year analysis."
} else {
  direction_text <- "The fitted linear relationship was essentially flat in this pooled country-year analysis."
}
if (regression_p < 0.05) {
  inference_text <- "The estimated slope differed from zero at the 5% level in this simple model."
} else {
  inference_text <- "The estimated slope did not differ from zero at the 5% level in this simple model."
}

results_lines <- c(
  "EU Health Inequalities and Life Expectancy Analysis",
  "",
  paste0("Countries analysed: ", n_countries),
  paste0("Complete country-year observations: ", nrow(analysis_data)),
  paste0("Years analysed: ", year_min, "-", year_max),
  "",
  paste0("Mean life expectancy across country-year observations: ", sprintf("%.2f", mean_life_expectancy), " years"),
  paste0("Mean income inequality across country-year observations: ", sprintf("%.2f", mean_income_inequality)),
  paste0("Unweighted mean country life expectancy in ", year_min, ": ", sprintf("%.2f", mean_2015), " years"),
  paste0("Unweighted mean country life expectancy in ", latest_year, ": ", sprintf("%.2f", mean_latest), " years"),
  paste0("Change in unweighted mean from ", year_min, " to ", latest_year, ": ", sprintf("%+.2f", mean_latest - mean_2015), " years"),
  "",
  paste0("Latest-year highest life expectancy (", latest_year, "): ", format_countries(highest_latest)),
  paste0("Latest-year lowest life expectancy (", latest_year, "): ", format_countries(lowest_latest)),
  "",
  "Pearson correlation across pooled country-year observations:",
  paste0("r = ", sprintf("%.3f", r_value)),
  paste0("p = ", format_p(correlation_p)),
  "",
  "Simple linear regression: life_expectancy ~ income_inequality",
  paste0("income_inequality coefficient = ", sprintf("%.3f", regression_coefficient), " years per one-point increase in S80/S20"),
  paste0("p = ", format_p(regression_p)),
  paste0("R-squared = ", sprintf("%.3f", r_squared)),
  "",
  "Brief interpretation:",
  direction_text,
  inference_text,
  "These are unadjusted, observational country-year associations; repeated observations from countries are pooled, so results do not establish causation and should not be treated as an individual-level relationship."
)
writeLines(results_lines, file.path("results", "results.txt"))
cat("\n", paste(results_lines, collapse = "\n"), "\n", sep = "")
