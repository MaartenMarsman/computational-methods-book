# Sourced at the top of every chapter (working directory is the project root
# because _quarto.yml sets execute-dir: project).

suppressPackageStartupMessages({
  library(tidyverse)
})

set.seed(84735)  # the Bayes Rules! seed, as a nod

# A shared ggplot theme so figures look the same across chapters.
theme_book <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      plot.title.position = "plot",
      legend.position = "bottom"
    )
}
theme_set(theme_book())

knitr::opts_chunk$set(
  fig.align = "center",
  out.width = "90%",
  collapse = TRUE,
  comment = "#>"
)
