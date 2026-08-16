# Copyright 2026 SparseMatrix Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.

.fillSparseMatrixBatch <- function(batch, buffer) {
  if (nrow(batch) == 0L) {
    return(invisible(NULL))
  }
  values <- as.numeric(batch$covariateValue)
  if (any(!is.finite(values))) {
    stop("Covariate values must be finite and non-missing.", call. = FALSE)
  }
  index <- buffer$position + seq_len(nrow(batch))
  buffer$i[index] <- as.integer(batch$matrixRowId)
  buffer$j[index] <- as.integer(batch$columnId)
  buffer$x[index] <- values
  buffer$position <- buffer$position + nrow(batch)
  invisible(NULL)
}

#' Create a sparse matrix from saved FeatureExtraction data
#'
#' Maps observed row and covariate identifiers to deterministic one-based
#' indices, then transfers the mapped coordinates from Andromeda in batches.
#'
#' @param outputFolder Folder containing the saved `covariateData` artifact.
#' @param batchSize Maximum number of mapped coordinates transferred per batch.
#'
#' @return Invisibly returns the path to `sparseMatrix.rds`.
#' @export
createSparseMatrix <- function(outputFolder, batchSize = 1e6) {
  checkmate::assertString(outputFolder, min.chars = 1)
  checkmate::assertCount(batchSize, positive = TRUE)
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
  if (FeatureExtraction::isAggregatedCovariateData(covariateData)) {
    stop("Aggregated CovariateData is not supported.", call. = FALSE)
  }
  if (FeatureExtraction::isTemporalCovariateData(covariateData)) {
    stop("Temporal CovariateData is not supported.", call. = FALSE)
  }

  rowMap <- covariateData$covariates %>%
    dplyr::distinct(.data$rowId) %>%
    dplyr::arrange(.data$rowId) %>%
    dplyr::collect()
  if (nrow(rowMap) > .Machine$integer.max) {
    stop("There are too many rows for a Matrix sparse object.", call. = FALSE)
  }
  rowMap$matrixRowId <- seq_len(nrow(rowMap))
  labels <- data.frame(
    rowId = rowMap$matrixRowId,
    originalRowId = rowMap$rowId
  )
  covariateData$rowMap <- rowMap

  covariateMap <- covariateData$covariates %>%
    dplyr::distinct(.data$covariateId) %>%
    dplyr::arrange(.data$covariateId) %>%
    dplyr::collect()
  if (nrow(covariateMap) > .Machine$integer.max) {
    stop("There are too many columns for a Matrix sparse object.", call. = FALSE)
  }
  covariateMap$columnId <- seq_len(nrow(covariateMap))
  covariateData$covariateMap <- covariateMap

  covariateRef <- covariateData$covariateMap %>%
    dplyr::inner_join(covariateData$covariateRef, by = "covariateId") %>%
    dplyr::arrange(.data$columnId) %>%
    dplyr::collect()
  if (nrow(covariateRef) != nrow(covariateMap)) {
    stop("Each observed covariateId must have one reference row.", call. = FALSE)
  }
  covariateRef$columnId <- NULL

  coordinates <- covariateData$covariates %>%
    dplyr::inner_join(covariateData$rowMap, by = "rowId") %>%
    dplyr::inner_join(covariateData$covariateMap, by = "covariateId") %>%
    dplyr::select(dplyr::all_of(c(
      "matrixRowId",
      "columnId",
      "covariateValue"
    )))
  coordinateCount <- coordinates %>%
    dplyr::summarise(n = dplyr::n()) %>%
    dplyr::collect()
  nCoordinates <- as.numeric(coordinateCount$n[[1]])
  if (nCoordinates > .Machine$integer.max) {
    stop("There are too many coordinates for a Matrix sparse object.", call. = FALSE)
  }
  ParallelLogger::logInfo(
    "Estimated peak sparse-matrix memory: ",
    round(nCoordinates * 40 / 1024^3, 1),
    " GB"
  )
  coordinates <- coordinates %>%
    dplyr::arrange(.data$columnId, .data$matrixRowId)

  buffer <- new.env(parent = emptyenv())
  buffer$i <- integer(nCoordinates)
  buffer$j <- integer(nCoordinates)
  buffer$x <- numeric(nCoordinates)
  buffer$position <- 0
  if (nCoordinates != 0) {
    Andromeda::batchApply(
      coordinates,
      .fillSparseMatrixBatch,
      buffer = buffer,
      batchSize = batchSize,
      progressBar = FALSE,
      safe = FALSE
    )
  }
  dataMatrix <- Matrix::sparseMatrix(
    i = buffer$i,
    j = buffer$j,
    x = buffer$x,
    dims = c(nrow(rowMap), nrow(covariateMap)),
    dimnames = NULL,
    use.last.ij = FALSE
  )
  result <- list(
    dataMatrix = dataMatrix,
    labels = labels,
    covariateRef = as.data.frame(covariateRef),
    covariateMap = as.data.frame(covariateMap)
  )

  outputFile <- file.path(outputFolder, "sparseMatrix.rds")
  stagingFile <- tempfile("sparseMatrix-", tmpdir = outputFolder)
  on.exit(unlink(stagingFile, force = TRUE), add = TRUE)
  saveRDS(result, stagingFile, compress = FALSE)
  if (file.exists(outputFile)) {
    unlink(outputFile, force = TRUE)
  }
  if (!file.rename(stagingFile, outputFile)) {
    stop("Failed to save sparseMatrix.rds.", call. = FALSE)
  }
  invisible(outputFile)
}
