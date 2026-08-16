#' Create patient-level features
#'
#' @param connectionDetails A DatabaseConnector connection-details object.
#' @param cdmDatabaseSchema Schema containing the OMOP CDM.
#' @param cohortDatabaseSchema Schema containing the cohort table.
#' @param cohortTable Name of the cohort table.
#' @param oracleTempSchema Schema used to emulate temporary tables.
#' @param outputFolder Folder for extracted features.
#' @param covariateSettingsFile FeatureExtraction settings JSON file.
#'
#' @export
createFeatures <- function(connectionDetails,
                           cdmDatabaseSchema,
                           cohortDatabaseSchema,
                           cohortTable,
                           oracleTempSchema,
                           outputFolder,
                           covariateSettingsFile = system.file(
                             "settings",
                             "covariateSettings.json",
                             package = "SparseMatrix"
                           )) {
  if (!file.exists(outputFolder)) {
    dir.create(outputFolder, recursive = TRUE)
  }

  covariateSettings <- loadCovariateSettings(covariateSettingsFile)
  covariateData <- FeatureExtraction::getDbCovariateData(
    connectionDetails = connectionDetails,
    oracleTempSchema = oracleTempSchema,
    cdmDatabaseSchema = cdmDatabaseSchema,
    cohortTable = cohortTable,
    cohortDatabaseSchema = cohortDatabaseSchema,
    rowIdField = "subject_id",
    covariateSettings = covariateSettings,
    aggregated = FALSE
  )
  FeatureExtraction::saveCovariateData(
    covariateData,
    file.path(outputFolder, "covariateData")
  )

  invisible(NULL)
}
