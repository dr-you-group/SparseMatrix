# Copyright 2026 SparseMatrix Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.

#' Create a PLP sparse matrix from saved FeatureExtraction data
#'
#' Loads the saved covariate data and delegates identifier mapping and sparse
#' matrix construction to [PatientLevelPrediction::toSparseM()].
#'
#' @param outputFolder Folder containing the saved `covariateData` artifact.
#'
#' @return Invisibly returns the path to `sparseMatrix.rds`.
#' @export
createSparseMatrix <- function(outputFolder) {
  checkmate::assertString(outputFolder, min.chars = 1)
  covariateFile <- file.path(outputFolder, "covariateData")
  if (!file.exists(covariateFile)) {
    stop("Cannot find saved covariateData: ", covariateFile, call. = FALSE)
  }

  covariateData <- FeatureExtraction::loadCovariateData(covariateFile)
  on.exit({
    if (Andromeda::isValidAndromeda(covariateData)) {
      try(Andromeda::close(covariateData), silent = TRUE)
    }
  }, add = TRUE)

  labels <- covariateData$covariates %>%
    dplyr::distinct(.data$rowId) %>%
    dplyr::arrange(.data$rowId) %>%
    dplyr::collect()
  sparseData <- PatientLevelPrediction::toSparseM(list(
    covariateData = covariateData,
    labels = labels
  ))

  outputFile <- file.path(outputFolder, "sparseMatrix.rds")
  saveRDS(sparseData, outputFile)
  invisible(outputFile)
}
