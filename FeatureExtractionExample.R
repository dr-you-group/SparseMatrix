# ###INSTALL rJava####
# Sys.setenv(JAVA_HOME = "/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home")
# install.packages("rJava", type = "source")
# ####################
# 
# ####Install OHDSI packages####
# install.packages("devtools")
# devtools::install_github("ohdsi/Andromeda")
# devtools::install_github("ohdsi/Eunomia")
# devtools::install_github("ohdsi/FeatureExtraction")
# #####
# 
# ####Additional library####
# install.packages("Matrix")
# #####

library(dplyr)
library(Matrix)

eunomiaConnectionDetails <- Eunomia::getEunomiaConnectionDetails()
covSettings <- FeatureExtraction::createDefaultCovariateSettings()
Eunomia::createCohorts(
  connectionDetails = eunomiaConnectionDetails,
  cdmDatabaseSchema = "main",
  cohortDatabaseSchema = "main",
  cohortTable = "cohort"
)
covData1 <- FeatureExtraction::getDbCovariateData(
  connectionDetails = eunomiaConnectionDetails,
  tempEmulationSchema = NULL,
  cdmDatabaseSchema = "main",
  cdmVersion = "5",
  cohortTable = "cohort",
  cohortDatabaseSchema = "main",
  cohortTableIsTemp = FALSE,
  cohortId = 1,
  rowIdField = "subject_id",
  covariateSettings = covSettings,
  aggregated = FALSE
)

covData1

# 2-1. Andromeda 테이블을 data.table로 가져오기
dt_cov <- data.table::as.data.table(covData1$covariates %>% collect())

# 2-2. 1-based Index 생성
# i: rowId에 대한 순차적인 행 인덱스 (Sparse Matrix의 행)
# j: covariateId에 대한 순차적인 열 인덱스 (Sparse Matrix의 열)
dt_cov[, i := .GRP, by = rowId] 
dt_cov[, j := .GRP, by = covariateId]

# 2-3. 인덱스와 원본 ID 매핑 정보 추출
# 이 정보가 rowId와 covariateId를 보존합니다.
row_map <- unique(dt_cov[, .(i, rowId)])
col_map <- unique(dt_cov[, .(j, covariateId)])

# 2-4. Column 이름 매핑 테이블 생성
# col_map과 dt_ref를 병합하여 j (인덱스)와 covariateName을 연결
col_names_dt <- merge(col_map, covData1$covariateRef, by = "covariateId")

# 2-5. Sparse Matrix 생성
sparse_mat <- Matrix::sparseMatrix(
  i = dt_cov$i,
  j = dt_cov$j,
  x = dt_cov$covariateValue,
  dims = c(max(dt_cov$i), max(dt_cov$j)),
  dimnames = list(
    # Row Names: i 순서대로 정렬된 rowId 할당
    Rows = as.character(row_map[order(i)]$rowId),
    # Column Names: j 순서대로 정렬된 covariateName 할당
    Columns = as.character(col_names_dt[order(j)]$covariateName) 
  )
)

# 2-6. 결과 확인
# print(sparse_mat[1:5, 1:5]) # (선택 사항)
# head(rownames(sparse_mat))
# head(colnames(sparse_mat))

# 3. 메모리 정리
rm(dt_cov, row_map, col_map, dt_ref, col_names_dt)
gc()


# 1. Andromeda 테이블을 data.table로 가져오기 (가장 무거운 단계)
# collect()로 가져온 뒤 바로 data.table로 변환하여 복사본 생성 최소화
dt_cov <- data.table::as.data.table(covData1$covariates %>% collect())

# 2. 1-based Index 생성 (factor보다 훨씬 빠르고 메모리 효율적)
# .GRP는 그룹 번호를 생성하는 data.table 특수 기호입니다.
# rowId를 기준으로 그룹을 지어 1부터 순차적인 ID를 부여합니다.
dt_cov[, i := .GRP, by = rowId] 
dt_cov[, j := .GRP, by = covariateId]

# 3. 매핑 정보 저장 (나중에 행/열 이름 복원을 위해 필요하다면)
# unique()를 사용하여 맵핑 테이블을 가볍게 만듭니다.
row_map <- unique(dt_cov[, .(i, rowId)])
col_map <- unique(dt_cov[, .(j, covariateId)])

# 4. Sparse Matrix 생성
# 이미 정수형(integer)으로 변환되었으므로 바로 사용 가능합니다.
sparse_mat <- Matrix::sparseMatrix(
  i = dt_cov$i,
  j = dt_cov$j,
  x = dt_cov$covariateValue,
  dims = c(max(dt_cov$i), max(dt_cov$j)),
  dimnames = list(
    as.character(row_map[order(i)]$rowId),       # i 순서대로 정렬하여 이름 할당
    as.character(col_map[order(j)]$covariateId)  # j 순서대로 정렬하여 이름 할당
  )
)

# 5. 메모리 정리
rm(dt_cov, row_map, col_map)
gc() # 가비지 컬렉션

# sparse matrix로 변환
# 희소 행렬 직접 생성
row_ids <- as.integer(factor(covData1$covariates %>% pull(rowId)))
col_ids <- as.integer(factor(covData1$covariates %>% pull(covariateId)))
values <- covData1$covariates %>% pull(covariateValue)

# 희소 행렬 생성
sparse_mat <- Matrix::sparseMatrix(
  i = row_ids,
  j = col_ids,
  x = values,
  dims = c(length(unique(row_ids)), length(unique(col_ids))),
  dimnames = list(
    as.character(unique(covData1$covariates %>% pull(rowId))),
    as.character(unique(covData1$covariates %>% pull(covariateId)))
  )
)

colnames(sparse_mat)
dim(sparse_mat)
