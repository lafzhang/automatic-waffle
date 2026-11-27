args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, args %in% c("r", "bioc", "tcga"))
stopifnot(getRversion() == Sys.getenv("R_VERSION"))
stopifnot(normalizePath(.libPaths()[1]) == normalizePath(Sys.getenv("R_LIBS_USER")))

jobs <- as.integer(Sys.getenv("WORKBENCH_R_JOBS", "2"))
stopifnot(!is.na(jobs), jobs >= 1L)
options(
  repos = c(CRAN = Sys.getenv("CRAN_REPO")),
  timeout = max(600, getOption("timeout")),
  Ncpus = jobs,
  BiocManager.check_repositories = FALSE
)

missing_packages <- function(packages) {
  setdiff(packages, rownames(installed.packages(lib.loc = .libPaths()[1])))
}

cran_packages <- c("data.table", "ggplot2", "jsonlite")
if (args != "r") {
  cran_packages <- c(cran_packages, "BiocManager")
}
to_install <- missing_packages(cran_packages)
if (length(to_install)) {
  install.packages(to_install, type = "source")
}
stopifnot(length(missing_packages(cran_packages)) == 0L)

if (args != "r") {
  version <- Sys.getenv("BIOC_VERSION")
  # Select the pinned release before installing packages in a new library.
  if (length(missing_packages("BiocVersion"))) {
    BiocManager::install(version = version, ask = FALSE, update = FALSE, type = "source")
  }
  bioc_packages <- c("BiocVersion", "SummarizedExperiment", "limma")
  if (args == "tcga") {
    bioc_packages <- c(bioc_packages, "TCGAbiolinks")
  }
  if (length(missing_packages(bioc_packages))) {
    BiocManager::install(
      missing_packages(bioc_packages),
      version = version, ask = FALSE, update = FALSE, type = "source"
    )
  }
  stopifnot(length(missing_packages(bioc_packages)) == 0L)
  installed_bioc <- sub("^([0-9]+\\.[0-9]+).*$", "\\1", as.character(packageVersion("BiocVersion")))
  stopifnot(identical(installed_bioc, version))
}
