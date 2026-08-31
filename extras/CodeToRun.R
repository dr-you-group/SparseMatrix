# Below codes creates .Renviron for setting environmental variables. Uncomment and execute to create.
#usethis::edit_r_environ(scope = "project")

# Import SparseMatrix library
library(SparseMatrix)

# Use a local disk with enough capacity for Andromeda temporary files.
options(
  andromedaTempFolder = Sys.getenv("SPARSE_MATRIX_ANDROMEDA_TEMP_FOLDER")
)

# Folder for study artifacts.
outputFolder <- Sys.getenv("SPARSE_MATRIX_OUTPUT_FOLDER")

# SQL Server connection details. Keep credentials in environment variables.
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sql server",
  server = Sys.getenv("SPARSE_MATRIX_DB_SERVER"),
  user = Sys.getenv("SPARSE_MATRIX_DB_USER"),
  password = Sys.getenv("SPARSE_MATRIX_DB_PASSWORD"),
  port = Sys.getenv("SPARSE_MATRIX_DB_PORT")
)

# OMOP CDM and study cohort locations.
cdmDatabaseSchema <- Sys.getenv("SPARSE_MATRIX_CDM_DATABASE_SCHEMA")
cohortDatabaseSchema <- Sys.getenv("SPARSE_MATRIX_COHORT_DATABASE_SCHEMA")
cohortTable <- Sys.getenv("SPARSE_MATRIX_COHORT_TABLE", unset = "cohort")
oracleTempSchema <- NULL

sparseMatrixBatchSize <- as.numeric(
  Sys.getenv("SPARSE_MATRIX_BATCH_SIZE", unset = "1000000")
)

execute(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTable = cohortTable,
  oracleTempSchema = oracleTempSchema,
  outputFolder = outputFolder,
  createCohorts = TRUE,
  createFeatures = TRUE,
  createSparseMatrix = TRUE,
  sparseMatrixBatchSize = sparseMatrixBatchSize
)
