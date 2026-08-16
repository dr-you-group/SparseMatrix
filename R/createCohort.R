#' Create the study cohorts
#'
#' @param connectionDetails A DatabaseConnector connection-details object.
#' @param cdmDatabaseSchema Schema containing the OMOP CDM.
#' @param vocabularyDatabaseSchema Schema containing the OMOP vocabulary.
#' @param cohortDatabaseSchema Schema where cohorts will be created.
#' @param cohortTable Name of the cohort table.
#' @param oracleTempSchema Schema used to emulate temporary tables.
#' @param outputFolder Folder for cohort counts.
#'
#' @export
createCohorts <- function(connectionDetails,
                          cdmDatabaseSchema,
                          vocabularyDatabaseSchema = cdmDatabaseSchema,
                          cohortDatabaseSchema,
                          cohortTable,
                          oracleTempSchema,
                          outputFolder) {
  if (!file.exists(outputFolder)) {
    dir.create(outputFolder, recursive = TRUE)
  }

  connection <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(connection))

  sql <- SqlRender::loadRenderTranslateSql(
    sqlFilename = "CreateCohortTable.sql",
    packageName = "SparseMatrix",
    dbms = attr(connection, "dbms"),
    tempEmulationSchema = oracleTempSchema,
    cohort_database_schema = cohortDatabaseSchema,
    cohort_table = cohortTable
  )
  DatabaseConnector::executeSql(
    connection,
    sql,
    progressBar = FALSE,
    reportOverallTime = FALSE
  )

  pathToCsv <- system.file(
    "settings",
    "CohortsToCreate.csv",
    package = "SparseMatrix"
  )
  cohortsToCreate <- read.csv(pathToCsv)
  for (i in seq_len(nrow(cohortsToCreate))) {
    ParallelLogger::logInfo("Creating cohort: ", cohortsToCreate$name[i])
    sql <- SqlRender::loadRenderTranslateSql(
      sqlFilename = paste0(cohortsToCreate$name[i], ".sql"),
      packageName = "SparseMatrix",
      dbms = attr(connection, "dbms"),
      tempEmulationSchema = oracleTempSchema,
      cdm_database_schema = cdmDatabaseSchema,
      vocabulary_database_schema = vocabularyDatabaseSchema,
      target_database_schema = cohortDatabaseSchema,
      target_cohort_table = cohortTable,
      target_cohort_id = cohortsToCreate$cohortId[i]
    )
    DatabaseConnector::executeSql(connection, sql)
  }

  sql <- paste(
    "SELECT cohort_definition_id, COUNT(*) AS count",
    "FROM @cohort_database_schema.@cohort_table",
    "GROUP BY cohort_definition_id"
  )
  sql <- SqlRender::render(
    sql,
    cohort_database_schema = cohortDatabaseSchema,
    cohort_table = cohortTable
  )
  sql <- SqlRender::translate(
    sql,
    targetDialect = attr(connection, "dbms")
  )
  counts <- DatabaseConnector::querySql(connection, sql)
  names(counts) <- SqlRender::snakeCaseToCamelCase(names(counts))
  counts <- merge(
    counts,
    data.frame(
      cohortDefinitionId = cohortsToCreate$cohortId,
      cohortName = cohortsToCreate$name
    )
  )
  write.csv(counts, file.path(outputFolder, "CohortCounts.csv"), row.names = FALSE)

  invisible(NULL)
}
