library(SparseMatrix)

# FeatureExtraction settings from SETTINGS.md.
covariateSettingsArgs <- list(
  useDemographicsGender = TRUE,
  useDemographicsAge = TRUE,
  useConditionOccurrenceAnyTimePrior = TRUE,
  useDrugExposureAnyTimePrior = TRUE
)

settingsFolder <- file.path(getwd(), "inst/settings")
if (!file.exists(settingsFolder)) {
    dir.create(settingsFolder, recursive = TRUE, showWarnings = FALSE)
  }

covariateSettingsFile <- file.path(settingsFolder, "covariateSettings.json")
saveCovariateSettings(covariateSettingsArgs, covariateSettingsFile)