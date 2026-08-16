createFeatures <- function(connectionDetails = connectionDetails,
                           cdmDatabaseSchema = cdmDatabaseSchema,
                           cohortDatabaseSchema = cohortDatabaseSchema,
                           cohortTable = cohortTable,
                           oracleTempSchema = oracleTempSchema) {
  
  
  covSettingPaths <- file.path(getwd(), "inst/settings", "covariateSettings.json")
  
  covariateSettings <- loadCovariateSettings(covSettingPaths)
  
  covData <- FeatureExtraction::getDbCovariateData(
    connectionDetails = connectionDetails,
    oracleTempSchema  = oracleTempSchema,
    cdmDatabaseSchema = cdmDatabaseSchema,
    cohortTable = cohortTable,
    cohortDatabaseSchema = cohortDatabaseSchema,
    rowIdField = "subject_id",
    covariateSettings = covariateSettings,
    aggregated = FALSE
  )
  
  #... sparse matrix
  
}