library(SparseMatrix)

# FeatureExtraction settings from SETTINGS.md.
covariateSettingsArgs <- list(
  useDemographicsGender = TRUE,
  useDemographicsAge = TRUE,
  useConditionOccurrenceLongTerm = TRUE,
  useDrugExposureLongTerm = TRUE,
  useProcedureOccurrenceLongTerm = TRUE,
  useMeasurementLongTerm = TRUE,
  longTermStartDays = -365,
  mediumTermStartDays = -180,
  shortTermStartDays = -30,
  endDays = 0,
  includedCovariateConceptIds = c(),
  addDescendantsToInclude = FALSE,
  excludedCovariateConceptIds = c(),
  addDescendantsToExclude = FALSE,
  includedCovariateIds = c()
)

settingsFolder <- file.path(getwd(), "inst/settings")
if (!file.exists(settingsFolder)) {
    dir.create(settingsFolder, recursive = TRUE, showWarnings = FALSE)
  }

covariateSettingsFile <- file.path(settingsFolder, "covariateSettings.json")
saveCovariateSettings(covariateSettingsArgs, covariateSettingsFile)
