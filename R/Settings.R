#' Save FeatureExtraction settings
#'
#' @param covariateSettingsArgs Arguments for
#'   [FeatureExtraction::createCovariateSettings()].
#' @param file Destination JSON file.
#'
#' @export
saveCovariateSettings <- function(covariateSettingsArgs, file) {
  do.call(
    FeatureExtraction::createCovariateSettings,
    covariateSettingsArgs
  )
  if (!file.exists(dirname(file))) {
    dir.create(dirname(file), recursive = TRUE)
  }
  writeLines(
    jsonlite::toJSON(covariateSettingsArgs, auto_unbox = TRUE, pretty = TRUE),
    file
  )
  invisible(NULL)
}

#' Load FeatureExtraction settings
#'
#' @param file JSON file created by [saveCovariateSettings()].
#'
#' @export
loadCovariateSettings <- function(file) {
  args <- jsonlite::fromJSON(file, simplifyDataFrame = FALSE)
  do.call(FeatureExtraction::createCovariateSettings, args)
}
