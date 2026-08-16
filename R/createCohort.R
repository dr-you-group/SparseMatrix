createCohorts <- function(connectionDetails,
                          cdmDatabaseSchema,
                          vocabularyDatabaseSchema = cdmDatabaseSchema,
                          cohortDatabaseSchema,
                          cohortTable,
                          oracleTempSchema,
                          outputFolder) {
  
  if (!file.exists(outputFolder))
    dir.create(outputFolder)
  
  conn <- DatabaseConnector::connect(connectionDetails)
  
  # Create study cohort table structure:
  sql <- SqlRender::readSql(file.path("inst", "sql", "CreateCohortTable.sql"))
  sql <- SqlRender::render(sql,
                           cohort_database_schema = cohortDatabaseSchema,
                           cohort_table = cohortTable)
  sql <- SqlRender::translate(sql, targetDialect = attr(conn, "dbms"), tempEmulationSchema = oracleTempSchema)
  DatabaseConnector::executeSql(conn, sql, progressBar = FALSE, reportOverallTime = FALSE)
  
  # Instantiate cohorts:
  pathToCsv <- file.path("inst", "settings", "CohortsToCreate.csv")
  cohortsToCreate <- read.csv(pathToCsv)
  for (i in 1:nrow(cohortsToCreate)) {
    writeLines(paste("Creating cohort:", cohortsToCreate$name[i]))
    sql <- SqlRender::readSql(file.path("inst", "sql", paste0(cohortsToCreate$name[i], ".sql")))
    sql <- SqlRender::render(sql,
                             cdm_database_schema = cdmDatabaseSchema,
                             vocabulary_database_schema = vocabularyDatabaseSchema,
                             target_database_schema = cohortDatabaseSchema,
                             target_cohort_table = cohortTable,
                             target_cohort_id = cohortsToCreate$cohortId[i])
    sql <- SqlRender::translate(sql, targetDialect = attr(conn, "dbms"), tempEmulationSchema = oracleTempSchema)
    DatabaseConnector::executeSql(conn, sql, progressBar = TRUE, reportOverallTime = TRUE)
  }
  # Fetch cohort counts:
  sql <- "SELECT cohort_definition_id, COUNT(*) AS count FROM @cohort_database_schema.@cohort_table GROUP BY cohort_definition_id"
  sql <- SqlRender::render(sql,
                           cohort_database_schema = cohortDatabaseSchema,
                           cohort_table = cohortTable)
  sql <- SqlRender::translate(sql, targetDialect = attr(connection, "dbms"))
  counts <- DatabaseConnector::querySql(connection, sql)
  names(counts) <- SqlRender::snakeCaseToCamelCase(names(counts))
  counts <- merge(counts, data.frame(cohortDefinitionId = cohortsToCreate$cohortId,
                                     cohortName  = cohortsToCreate$name))
  write.csv(counts, file.path(outputFolder, "CohortCounts.csv"))
  
  
}
