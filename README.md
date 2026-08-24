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

The current tested environment uses:

- Microsoft SQL Server `16.0.1000.6` (64-bit).
- R `4.6.1`.
- OpenJDK `21.0.11` and Microsoft JDBC Driver for SQL Server `9.2.0`.
- Andromeda `1.2.1`
- DatabaseConnector `7.2.0`
- FeatureExtraction `3.14.0`,
- Matrix `1.7.6`
- ParallelLogger `3.5.1`, and SqlRender `1.19.6`.

The project has been exercised in an Ubuntu virtual environment with 12 CPU
cores and 128 GB of RAM. The included Web RStudio service uses port `28787`.

How to run
==========

1. Copy the environment template and enter the RStudio password, database
   connection, schema, cohort-table, and batch-size settings. Keep `.env`
   private:

   ```sh
   cp .env.example .env
   chmod 600 .env
   ```

   Use site-specific values following this structure:

   ```dotenv
   FEATURE_EXTRACTION_V2_RSTUDIO_PASSWORD='change-me'
   SPARSE_MATRIX_DB_SERVER='sql-server.example.org'
   SPARSE_MATRIX_DB_PORT='1433'
   SPARSE_MATRIX_DB_USER='database-user'
   SPARSE_MATRIX_DB_PASSWORD='change-me'
   SPARSE_MATRIX_CDM_DATABASE_SCHEMA='database.schema'
   SPARSE_MATRIX_COHORT_DATABASE_SCHEMA='database.schema'
   SPARSE_MATRIX_COHORT_TABLE='cohort'
   SPARSE_MATRIX_BATCH_SIZE='1000000'
   ```

   Place a compatible Microsoft SQL Server JDBC driver in `jdbc/`. If `.env`
   is changed after the container has been created, recreate the service so the
   new values are injected:

   ```sh
   docker compose up -d --force-recreate rstudio
   ```

2. Build and start Web RStudio:

   ```sh
   docker compose up -d --build rstudio
   ```

   Open `http://localhost:28787` and sign in as `rstudio` using
   `FEATURE_EXTRACTION_V2_RSTUDIO_PASSWORD`. When Docker runs on the configured
   remote host, the included relay can be managed with:

   ```sh
   scripts/rstudio-28787-proxy-control.sh start
   scripts/rstudio-28787-proxy-control.sh status
   ```

3. Open the project in RStudio. If the covariates need to be changed, edit and
   run `extras/CreateCovariateSettings.R`. Then select **Build** and **Install
   and Restart** so the current R functions, SQL, and settings are installed.

4. Run the study using `extras/CodeToRun.R`. Its essential configuration and
   stage call are shown below:

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
├── DESCRIPTION                         # R package metadata and dependencies
├── NAMESPACE                           # Generated exports and imports
├── README.md                           # Installation, execution, and output guide
├── SETTINGS.md                         # Additional environment and covariate notes
├── FeatureExtractionExample.R          # Original sparse-conversion reference example
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
├── extras/
│   ├── CodeToRun.R                     # Environment-driven end-to-end runner
│   ├── CreateCovariateSettings.R       # Regenerates packaged covariate settings
│   └── PostprocessSparseMatrix.R       # Writes long CSV and validates matrix output
├── man/
│   ├── createCohorts.Rd                # createCohorts API documentation
│   ├── createFeatures.Rd               # createFeatures API documentation
│   ├── createSparseMatrix.Rd           # createSparseMatrix API documentation
│   ├── execute.Rd                      # execute API documentation
│   ├── loadCovariateSettings.Rd        # Settings-loader documentation
│   └── saveCovariateSettings.Rd        # Settings-writer documentation
├── tests/
│   ├── testthat.R                      # Package test entry point
│   └── testthat/
│       ├── test-createSparseMatrix.R   # Andromeda batching and mapping contract test
│       └── test-execute.R              # Pipeline flag and stage-order test
├── docker/
│   ├── Dockerfile.rstudio              # Pinned R, Java, OHDSI, and RStudio image
│   ├── rserver.conf                    # RStudio Server R executable setting
│   └── rsession.conf                   # Default RStudio project directory
├── scripts/
│   ├── rstudio-28787-proxy.py          # Relays remote-Docker RStudio traffic
│   └── rstudio-28787-proxy-control.sh  # Starts, stops, and checks the relay
├── jdbc/                               # Local SQL Server JDBC driver files (ignored)
├── data/                               # Andromeda and DuckDB temporary data (ignored)
├── output/                             # Cohort, feature, matrix, and log artifacts (ignored)
├── compose.yaml                        # Web RStudio service on port 28787
├── .env.example                        # Environment-variable template without secrets
├── .env                                # Local credentials and site settings (ignored)
├── .gitignore                          # Git runtime-artifact exclusions
├── .dockerignore                       # Docker build-context exclusions
└── .Rbuildignore                       # R package-build exclusions
```

License
========

The SparseMatrix package is licensed under the Apache License 2.0.

Development
===========

SparseMatrix was developed as an OHDSI R study package using ATLAS-generated
cohort SQL, FeatureExtraction, Andromeda, Matrix, and RStudio.

### Development status

Experimental (version 0.0.1).
