library(data.table)
library(dplyr)
args <- commandArgs(trailingOnly = TRUE)
param1 <- args[1]
param2 <- args[2]
data <- fread(param1)
output <- param2
extract_sequences <- function(data) {
  data %>%
    mutate(
      diff = c(NA, diff(Position)),       # Calculate differences
      group = cumsum(is.na(diff) | diff != 1) # Group rows where diff > abs(1)
    ) %>%
    group_by(group) %>%
    filter(n_distinct(Chr) == 1) %>%     # Ensure all Chr values in a group are the same
    summarize(
      Chr = first(Chr),                  # Use the consistent Chr value
      start_position = first(Position),  # First Position in the group
      end_position = last(Position),     # Last Position in the group
      avg_Depth = mean(Depth, na.rm = T), # Average of Depth
      avg_prop = mean(prop, na.rm = T),   # Average of prop
      avg_mean = mean(mean, na.rm = T),   # Average of mean
      avg_std = mean(std, na.rm = T),     # Average of std
      avg_expDepth = mean(expDepth, na.rm = T), # Average of expDepth
      avg_zscore = mean(zscore, na.rm = T),     # Average of zscore
      avg_copynumber = mean(copynumber, na.rm = T), # Average of copynumber
      .groups = "drop" # Ungroup after summarizing
    ) %>%
    select(-group)  %>%
    filter(!is.na(avg_copynumber))
}

result <- extract_sequences(data)
write.table(result, file = output, quote = F, col.names = F, row.names = F)
