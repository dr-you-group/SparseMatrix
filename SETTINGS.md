
covariateSettingsArgs <- list(

  useDemographicsGender = TRUE,

  useDemographicsAge = TRUE,

  useConditionOccurrenceAnyTimePrior = TRUE,

  useDrugExposureAnyTimePrior = TRUE

)

saveCovariateSettings(

  covariateSettingsArgs,

  "covariateSettings.json"

)

covariateSettings <- loadCovariateSettings(

  "covariateSettings.json"

)
