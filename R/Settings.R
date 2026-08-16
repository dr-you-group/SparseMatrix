saveCovariateSettings <- function(covariateSettingsArgs, file) {
  checkmate::assertList(covariateSettingsArgs)
  checkmate::assertCharacter(file, len = 1)
  
  do.call(
    FeatureExtraction::createCovariateSettings,
    covariateSettingsArgs
  )
  
  json <- jsonlite::toJSON(
    covariateSettingsArgs,
    auto_unbox = TRUE,
    pretty = TRUE
  )
  
  writeLines(json, file)
}

loadCovariateSettings <- function(file) {
  checkmate::assertCharacter(file, len = 1)
  checkmate::assertFileExists(file)
  
  args <- jsonlite::fromJSON(
    file,
    simplifyDataFrame = FALSE
  )
  
  do.call(
    FeatureExtraction::createCovariateSettings,
    args
  )
}