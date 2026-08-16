#' Execute the study
#'
#' @param connectionDetails A DatabaseConnector connection-details object.
#' @param cdmDatabaseSchema Schema containing the OMOP CDM.
#' @param cohortDatabaseSchema Schema containing the cohort table.
#' @param cohortTable Name of the cohort table.
#' @param oracleTempSchema Schema used to emulate temporary tables.
#' @param outputFolder Folder for logs and results.
#' @param createCohorts Create the study cohorts?
#' @param createFeatures Extract and save patient-level features?
#' @param createSparseMatrix Create the sparse matrix?
#' @param covariateSettingsFile FeatureExtraction settings JSON file.
#' @param sparseMatrixBatchSize Number of feature rows processed per batch.
#'
#' @importFrom dplyr %>%
#' @importFrom rlang .data
#' @importFrom utils read.csv write.csv
#' @export
execute <- function(connectionDetails,
                    cdmDatabaseSchema,
                    cohortDatabaseSchema = cdmDatabaseSchema,
                    cohortTable = "cohort",
                    oracleTempSchema = cohortDatabaseSchema,
                    outputFolder,
                    createCohorts = TRUE,
                    createFeatures = TRUE,
                    createSparseMatrix = TRUE,
                    covariateSettingsFile = system.file(
                      "settings",
                      "covariateSettings.json",
                      package = "SparseMatrix"
                    ),
                    sparseMatrixBatchSize = 1e6) {
  if (!file.exists(outputFolder)) {
    dir.create(outputFolder, recursive = TRUE)
  }

  ParallelLogger::addDefaultFileLogger(file.path(outputFolder, "log.txt"))
  ParallelLogger::addDefaultErrorReportLogger(
    file.path(outputFolder, "errorReportR.txt")
  )
  on.exit(ParallelLogger::unregisterLogger(
    "DEFAULT_FILE_LOGGER",
    silent = TRUE
  ))
  on.exit(ParallelLogger::unregisterLogger(
    "DEFAULT_ERRORREPORT_LOGGER",
    silent = TRUE
  ), add = TRUE)

  if (createCohorts) {
    ParallelLogger::logInfo("Creating cohorts")
    createCohorts(connectionDetails = connectionDetails,
                  cdmDatabaseSchema = cdmDatabaseSchema,
                  cohortDatabaseSchema = cohortDatabaseSchema,
                  cohortTable = cohortTable,
                  oracleTempSchema = oracleTempSchema,
                  outputFolder = outputFolder)
  }

  if (createFeatures) {
    ParallelLogger::logInfo("Creating features")
    createFeatures(connectionDetails = connectionDetails,
                   cdmDatabaseSchema = cdmDatabaseSchema,
                   cohortDatabaseSchema = cohortDatabaseSchema,
                   cohortTable = cohortTable,
                   oracleTempSchema = oracleTempSchema,
                   outputFolder = outputFolder,
                   covariateSettingsFile = covariateSettingsFile)
  }

  if (createSparseMatrix) {
    ParallelLogger::logInfo("Creating sparse matrix")
    createSparseMatrix(outputFolder = outputFolder,
                       batchSize = sparseMatrixBatchSize)
  }

  invisible(NULL)
}
