test_that("createSparseMatrix uses PLP sparse-matrix mapping semantics", {
  skip_if_not_installed("Andromeda")
  skip_if_not_installed("FeatureExtraction")
  skip_if_not_installed("PatientLevelPrediction")

  outputFolder <- tempfile("sparse-matrix-")
  dir.create(outputFolder)
  on.exit(unlink(outputFolder, recursive = TRUE), add = TRUE)

  covariateData <- FeatureExtraction::createEmptyCovariateData(
    cohortIds = 1L,
    aggregated = FALSE,
    temporal = FALSE
  )
  on.exit({
    if (Andromeda::isValidAndromeda(covariateData)) {
      Andromeda::close(covariateData)
    }
  }, add = TRUE)
  covariateData$covariates <- data.frame(
    cohortDefinitionId = rep(1L, 5),
    rowId = c(20, 10, 20, 10, 30),
    covariateId = c(300, 200, 100, 200, 300),
    covariateValue = c(1.5, 2, 3, 4, 5)
  )
  covariateData$covariateRef <- data.frame(
    covariateId = c(300, 100, 200),
    covariateName = c("three hundred", "one hundred", "two hundred"),
    analysisId = 1L,
    conceptId = c(300, 100, 200)
  )
  FeatureExtraction::saveCovariateData(
    covariateData,
    file.path(outputFolder, "covariateData")
  )

  createSparseMatrix(outputFolder = outputFolder)
  result <- readRDS(file.path(outputFolder, "sparseMatrix.rds"))

  expect_named(
    result,
    c("dataMatrix", "labels", "covariateRef", "covariateMap"),
    ignore.order = FALSE
  )
  expect_s4_class(result$dataMatrix, "dgCMatrix")
  expect_identical(dimnames(result$dataMatrix), list(NULL, NULL))
  expect_equal(
    unname(as.matrix(result$dataMatrix)),
    matrix(c(0, 6, 0, 3, 0, 1.5, 0, 0, 5), nrow = 3, byrow = TRUE)
  )
  expect_identical(names(result$labels), c("originalRowId", "rowId"))
  expect_equal(result$labels$originalRowId, c(10, 20, 30))
  expect_equal(result$labels$rowId, 1:3)
  expect_equal(result$covariateMap$covariateId, c(100, 200, 300))
  expect_equal(result$covariateMap$columnId, 1:3)
})
