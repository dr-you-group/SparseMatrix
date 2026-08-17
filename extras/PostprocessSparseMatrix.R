library(SparseMatrix)

# Use a local disk with enough capacity for Andromeda temporary files.
options(
  andromedaTempFolder = Sys.getenv("SPARSE_MATRIX_ANDROMEDA_TEMP_FOLDER")
)

outputFolder <- Sys.getenv("SPARSE_MATRIX_OUTPUT_FOLDER")
sparseMatrixBatchSize <- as.numeric(
  Sys.getenv("SPARSE_MATRIX_BATCH_SIZE", unset = "1000000")
)

featureData <- FeatureExtraction::loadCovariateData(
  file.path(outputFolder, "covariateData")
)
featureCoordinates <- featureData$covariates |>
  dplyr::select(dplyr::all_of(c(
    "rowId",
    "covariateId",
    "covariateValue"
  )))
featureRowCount <- featureCoordinates |>
  dplyr::summarise(n = dplyr::n()) |>
  dplyr::collect()
featureCoordinates <- featureCoordinates |>
  dplyr::arrange(rowId, covariateId)

featureCsvFile <- file.path(outputFolder, "featureExtractionLong.csv")
writeLines("rowId,covariateId,covariateValue", featureCsvFile)
Andromeda::batchApply(
  featureCoordinates,
  function(batch, file) {
    names(batch)[1] <- "rowId"
    utils::write.table(
      batch,
      file = file,
      sep = ",",
      row.names = FALSE,
      col.names = FALSE,
      append = TRUE,
      quote = FALSE
    )
  },
  file = featureCsvFile,
  batchSize = sparseMatrixBatchSize,
  progressBar = FALSE,
  safe = FALSE
)
Andromeda::close(featureData)
Sys.chmod(featureCsvFile, mode = "600")

cat("\nFeatureExtraction long-format CSV created:\n")
print(data.frame(
  file = normalizePath(featureCsvFile),
  rows = featureRowCount$n
))
cat("\nFirst 10 patient-covariate rows:\n")
print(utils::read.csv(featureCsvFile, nrows = 10))

sparseMatrixFile <- file.path(outputFolder, "sparseMatrix.rds")
sparseMatrixResult <- readRDS(sparseMatrixFile)
stopifnot(
  inherits(sparseMatrixResult$dataMatrix, "dgCMatrix"),
  isTRUE(methods::validObject(sparseMatrixResult$dataMatrix, test = TRUE)),
  nrow(sparseMatrixResult$dataMatrix) == nrow(sparseMatrixResult$labels),
  ncol(sparseMatrixResult$dataMatrix) == nrow(sparseMatrixResult$covariateMap),
  nrow(sparseMatrixResult$covariateRef) ==
    nrow(sparseMatrixResult$covariateMap),
  all(is.finite(sparseMatrixResult$dataMatrix@x))
)

cat("\nSparse matrix created successfully:\n")
print(data.frame(
  file = normalizePath(sparseMatrixFile),
  rows = nrow(sparseMatrixResult$dataMatrix),
  columns = ncol(sparseMatrixResult$dataMatrix),
  nonzero = Matrix::nnzero(sparseMatrixResult$dataMatrix)
))

previewRows <- seq_len(min(10, nrow(sparseMatrixResult$dataMatrix)))
previewColumns <- seq_len(min(10, ncol(sparseMatrixResult$dataMatrix)))
cat("\nTop-left sparse-matrix preview:\n")
print(sparseMatrixResult$dataMatrix[
  previewRows,
  previewColumns,
  drop = FALSE
])
