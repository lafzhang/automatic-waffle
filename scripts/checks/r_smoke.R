args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L, args[1L] %in% c("r", "bioc", "tcga"))
profile <- args[1L]
fixture <- args[2L]
output <- args[3L]
dir.create(output, recursive = TRUE, showWarnings = FALSE)

r_version <- Sys.getenv("R_VERSION")
bioc_version <- Sys.getenv("BIOC_VERSION")
stopifnot(nzchar(r_version), nzchar(bioc_version))
stopifnot(getRversion() == r_version)

if (profile == "r") {
  packages <- c("data.table", "ggplot2", "jsonlite")
  measurements <- data.table::fread(fixture)
  summary <- measurements[, .(count = .N, mean = mean(signal)), by = condition]
  stopifnot(identical(summary$condition, c("control", "treated")))
  stopifnot(identical(summary$count, c(3L, 3L)))
  stopifnot(identical(summary$mean, c(4, 10)))

  fit <- stats::lm(signal ~ batch + condition, data = measurements)
  estimates <- stats::coef(fit)
  stopifnot(isTRUE(all.equal(unname(estimates), c(2, 2, 6))))
  data.table::fwrite(summary, file.path(output, "summary.csv"))
  model_path <- file.path(output, "fit.json")
  jsonlite::write_json(as.list(estimates), model_path, auto_unbox = TRUE)
  readback <- jsonlite::read_json(model_path, simplifyVector = TRUE)
  stopifnot(isTRUE(all.equal(unname(unlist(readback)), c(2, 2, 6))))

  plot <- ggplot2::ggplot(summary, ggplot2::aes(x = condition, y = mean)) +
    ggplot2::geom_col() +
    ggplot2::labs(y = "Mean signal")
  ggplot2::ggsave(file.path(output, "signal.png"), plot, width = 4, height = 3, dpi = 100)
  stopifnot(file.info(file.path(output, "signal.png"))$size > 0L)
} else {
  packages <- c("BiocManager", "BiocVersion", "SummarizedExperiment", "limma")
  installed_bioc <- sub("^([0-9]+\\.[0-9]+).*$", "\\1", as.character(packageVersion("BiocVersion")))
  stopifnot(identical(installed_bioc, bioc_version))

  counts <- matrix(
    c(10L, 20L, 12L, 22L, 30L, 40L, 32L, 42L),
    nrow = 2L,
    dimnames = list(c("gene_a", "gene_b"), c("C1", "C2", "T1", "T2"))
  )
  samples <- S4Vectors::DataFrame(
    condition = factor(c("control", "control", "treated", "treated")),
    row.names = colnames(counts)
  )
  experiment <- SummarizedExperiment::SummarizedExperiment(
    assays = list(counts = counts), colData = samples
  )
  stopifnot(methods::validObject(experiment))
  stopifnot(identical(colnames(experiment), rownames(SummarizedExperiment::colData(experiment))))
  stopifnot(identical(SummarizedExperiment::assay(experiment), counts))

  fit <- limma::lmFit(counts, stats::model.matrix(~ samples$condition))
  estimated_difference <- unname(fit$coefficients[, 2L])
  stopifnot(isTRUE(all.equal(estimated_difference, c(20, 20))))
  experiment_path <- file.path(output, "experiment.rds")
  saveRDS(experiment, experiment_path)
  stopifnot(identical(SummarizedExperiment::assay(readRDS(experiment_path)), counts))
  utils::write.csv(
    data.frame(feature = rownames(counts), estimated_difference),
    file.path(output, "effect.csv"),
    row.names = FALSE
  )

  if (profile == "tcga") {
    packages <- c(packages, "TCGAbiolinks")
    exports <- getNamespaceExports("TCGAbiolinks")
    stopifnot(all(c("GDCquery", "GDCdownload", "GDCprepare") %in% exports))
  }
}

versions <- vapply(packages, function(name) as.character(packageVersion(name)), character(1))
utils::write.csv(
  data.frame(package = c("R", names(versions)), version = c(r_version, unname(versions))),
  file.path(output, "versions.csv"),
  row.names = FALSE
)
cat(sprintf("R %s, profile %s: verified\n", getRversion(), profile))
