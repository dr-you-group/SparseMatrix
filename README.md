SparseMatrix
============

SparseMatrix is an OHDSI study package that creates a configured OMOP cohort,
extracts patient-level covariates with FeatureExtraction, and converts the
persisted covariates into a deterministic sparse matrix.

Requirements
============

- An [OMOP Common Data Model version 5](https://github.com/OHDSI/CommonDataModel)
  database on Microsoft SQL Server.
- Read access to the CDM and vocabulary tables, plus permission to create and
  drop the configured study cohort table.
- R 4.0.0 or newer and Java with a compatible Microsoft SQL Server JDBC driver.
  R package dependencies are declared in `DESCRIPTION`.
- Docker with Docker Compose when using the included Web RStudio environment.
- Enough local disk space for Andromeda temporary data and study artifacts, and
  enough memory for the final sparse matrix.

The current Docker environment uses:

- Microsoft SQL Server `16.0.1000.6` (64-bit).
- R `4.1.2` from `rocker/rstudio:4.1.2`.
- OpenJDK from the distribution `default-jdk` package (not pinned).
- Microsoft JDBC Driver for SQL Server `8.4.1`, downloaded by DatabaseConnector `5.0.2`.
- Andromeda `0.6.0`.
- DatabaseConnector `5.0.2`.
- CohortGenerator `0.4.0`.
- FeatureExtraction `3.2.0`.
- Matrix from the configured R package repository (not pinned).
- ParallelLogger `2.0.2`.
- SqlRender `1.9.0`.

The project has been exercised in an Ubuntu virtual environment with 12 CPU
cores and 128 GB of RAM. The included Web RStudio service uses port `28787`.

How to run
==========

1. Build Docker image, by entering the following command in a shell: (takes about ~5 minutes on fresh start)

```sh
   docker build -f .\DockerImage\Dockerfile -t sparsematrix:latest .
```

2. Run docker container:

```sh
   $projectPath = (Get-Location).Path

   docker run -d --name sparsematrix-rstudio `              
   -p 127.0.0.1:8787:8787 `
   -e PASSWORD='password' `
   --mount "type=bind,source=$projectPath,target=/home/rstudio/SparseMatrix" `
   -w /home/rstudio/SparseMatrix `
   sparsematrix:latest
```

3. After container run, enter ``localhost:8787`` on a web brower and enter ID: `rstudio`, PW: `password` to access to R studio. `File -> Open Project -> Go To SparseMatrix/SparseMatrix.Rproj` to open the project.

   **Covariate settings**

   To configure the covariates used for feature extraction, edit and run
   `extras/CreateCovariateSettings.R`.

   ```r
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
   ```

   The settings are saved to `inst/settings/covariateSettings.json` and included
   with the package.

   For the available covariate arguments, see the
   [FeatureExtraction `createCovariateSettings()` reference](https://ohdsi.github.io/FeatureExtraction/reference/createCovariateSettings.html).
4. Run the study using `extras/CodeToRun.R`.

   Before executing, you can set environmental variables by uncommenting `usethis::edit_r_environ(scope = "project")` can paste the environment settings as given in `env.example`.

   ```r
   library(SparseMatrix)

   # Local folders used for Andromeda and study artifacts:
   options(
     andromedaTempFolder = Sys.getenv("SPARSE_MATRIX_ANDROMEDA_TEMP_FOLDER")
   )
   outputFolder <- Sys.getenv("SPARSE_MATRIX_OUTPUT_FOLDER")

   # SQL Server connection details:
   connectionDetails <- DatabaseConnector::createConnectionDetails(
     dbms = "sql server",
     server = Sys.getenv("SPARSE_MATRIX_DB_SERVER"),
     user = Sys.getenv("SPARSE_MATRIX_DB_USER"),
     password = Sys.getenv("SPARSE_MATRIX_DB_PASSWORD"),
     port = Sys.getenv("SPARSE_MATRIX_DB_PORT")
   )

   # OMOP CDM and study cohort locations:
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
   ```

   The cohort stage drops and recreates the entire configured cohort table.
   Always use a study-specific writable table. Set an individual stage flag to
   `FALSE` only when its required artifact already exists.
5. Optionally create the patient-level long-format CSV and print a validated
   sparse-matrix summary:

   ```r
   source("extras/PostprocessSparseMatrix.R")
   ```

   The long-format CSV and sparse-matrix labels contain patient row identifiers
   and must be handled as sensitive derived data.

Output
======

The main runner writes these files under `SPARSE_MATRIX_OUTPUT_FOLDER`:

- `CohortCounts.csv`: number of rows in each configured cohort.
- `covariateData`: persisted FeatureExtraction CovariateData backed by
  Andromeda.
- `sparseMatrix.rds`: the mapped sparse-matrix result.
- `log.txt` and `errorReportR.txt`: execution and error logs.

`extras/PostprocessSparseMatrix.R` additionally writes
`featureExtractionLong.csv` with the columns `rowId`, `covariateId`, and
`covariateValue`.

`sparseMatrix.rds` is a plain R list, not a PatientLevelPrediction object. It
contains:

- `dataMatrix`: a `Matrix::dgCMatrix` without dimension names.
- `labels`: the one-based matrix `rowId` and its source cohort `subject_id` as
  `originalRowId`.
- `covariateRef`: FeatureExtraction metadata for the observed covariates.
- `covariateMap`: the deterministic `covariateId` to `columnId` mapping.

Only observed row and covariate identifiers are mapped. Covariate values are
preserved, duplicate row-column coordinates are summed, and aggregated or
temporal CovariateData is not supported. Andromeda is used for mapping and
batched coordinate transfer; the complete coordinate buffers and final sparse
matrix are still materialized in memory.

Project structure
=================

Runtime-only entries such as `.env`, `jdbc/`, `data/`, and `output/` are shown
because the study uses them, but they are excluded from Git.

```text
SparseMatrix/
├── R/
│   ├── Main.R                          # Orchestrates cohort, feature, and matrix stages
│   ├── Settings.R                      # Reads and writes covariate-settings JSON
│   ├── createCohort.R                  # Creates configured cohorts and cohort counts
│   ├── createFeatures.R                # Extracts and saves FeatureExtraction covariates
│   └── createSparseMatrix.R            # Maps Andromeda coordinates into a dgCMatrix
├── inst/
│   ├── settings/
│   │   ├── CohortsToCreate.csv         # Cohort IDs and packaged SQL resource names
│   │   └── covariateSettings.json      # Packaged FeatureExtraction settings
│   └── sql/sql_server/
│       ├── CreateCohortTable.sql       # Recreates the SQL Server cohort table
│       └── LLT_HTE_moderate_intensity_statin_with_ezetimibe_v2.sql  # ATLAS cohort SQL
└── extras/
    ├── CodeToRun.R                     # Environment-driven end-to-end runner
    ├── CreateCovariateSettings.R       # Regenerates packaged covariate settings
    └── PostprocessSparseMatrix.R       # Writes long CSV and validates matrix output
```

License
=======

The SparseMatrix package is licensed under the Apache License 2.0.

Development
===========

SparseMatrix was developed as an OHDSI R study package using ATLAS-generated
cohort SQL, FeatureExtraction, Andromeda, Matrix, and RStudio.

### Development status

Experimental (version 0.0.1).
