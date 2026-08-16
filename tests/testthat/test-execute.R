test_that("execute gates and orders the three study stages", {
  outputFolder <- tempfile("execute-")
  dir.create(outputFolder)
  on.exit(unlink(outputFolder, recursive = TRUE), add = TRUE)
  settingsFile <- file.path(outputFolder, "settings.json")
  writeLines("{}", settingsFile)
  connectionDetails <- structure(list(), class = "connectionDetails")

  calls <- character()
  sparseArguments <- NULL
  testthat::local_mocked_bindings(
    createCohorts = function(...) calls <<- c(calls, "cohorts"),
    createFeatures = function(...) calls <<- c(calls, "features"),
    createSparseMatrix = function(...) {
      calls <<- c(calls, "sparseMatrix")
      sparseArguments <<- list(...)
    },
    .package = "SparseMatrix"
  )

  run <- function(createCohorts, createFeatures, createSparseMatrix) {
    execute(
      connectionDetails = connectionDetails,
      cdmDatabaseSchema = "cdm",
      cohortDatabaseSchema = "results",
      cohortTable = "cohort",
      oracleTempSchema = "temp",
      outputFolder = outputFolder,
      createCohorts = createCohorts,
      createFeatures = createFeatures,
      createSparseMatrix = createSparseMatrix,
      covariateSettingsFile = settingsFile
    )
  }

  run(TRUE, TRUE, TRUE)
  expect_identical(calls, c("cohorts", "features", "sparseMatrix"))
  expect_identical(names(sparseArguments), "outputFolder")
  expect_identical(sparseArguments$outputFolder, outputFolder)

  calls <- character()
  run(FALSE, FALSE, TRUE)
  expect_identical(calls, "sparseMatrix")
})
