# SparseMatrix settings

`extras/CodeToRun.R` reads site-specific values from environment variables.
Keep database credentials outside tracked files.

## Environment

Set these variables before running the study:

- `SPARSE_MATRIX_ANDROMEDA_TEMP_FOLDER`: local Andromeda temporary folder.
- `SPARSE_MATRIX_OUTPUT_FOLDER`: study artifact folder.
- `SPARSE_MATRIX_DB_SERVER`, `SPARSE_MATRIX_DB_PORT`: SQL Server location.
- `SPARSE_MATRIX_DB_USER`, `SPARSE_MATRIX_DB_PASSWORD`: SQL credentials.
- `SPARSE_MATRIX_CDM_DATABASE_SCHEMA`: OMOP CDM schema.
- `SPARSE_MATRIX_COHORT_DATABASE_SCHEMA`: writable cohort schema.

`SPARSE_MATRIX_COHORT_TABLE` defaults to `cohort`, and
`SPARSE_MATRIX_BATCH_SIZE` defaults to `1000000`.

## Covariates

The runner writes `outputFolder/settings/covariateSettings.json` using:

```r
covariateSettingsArgs <- list(
  useDemographicsGender = TRUE,
  useDemographicsAge = TRUE,
  useConditionOccurrenceAnyTimePrior = TRUE,
  useDrugExposureAnyTimePrior = TRUE
)
```

Install the package and run `Rscript extras/CodeToRun.R`. The runner calls
cohort creation, feature extraction, and sparse-matrix creation explicitly.
