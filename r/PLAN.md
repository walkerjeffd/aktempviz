# Plan: Replace Daymet with ERA5-Land Air Temperature Data

## Overview

Replace the Daymet air temperature data retrieval with ERA5-Land dataset from Google Earth Engine (GEE). ERA5-Land provides daily mean 2m air temperature at 9km resolution through the `ECMWF/ERA5_LAND/DAILY_AGGR` dataset.

## Current Daymet Implementation

### Files to Modify/Replace
- `r/R/daymet.R` - Core data retrieval logic (211 lines)
- `r/_targets.R` - Pipeline targets (lines 35-36, 110-124)
- `r/R/combined.R` - Merging air temp with station data (lines 21-52)

### Current Workflow
1. **Find Last Available Year** (`find_daymet_last_year()`): Downloads 3 years of data for a test location to determine latest available year
2. **Extract Station-Tile-Years** (`extract_station_tile_years()`): Spatially joins stations to Daymet tiles, extracts years from water temp data
3. **Extract Tile-Years to Download** (`extract_daymet_tile_years()`): Filters to 1980-{last_year}, gets unique tile-year combinations
4. **Download Tiles** (`download_daymet_tile()`): Downloads tmin/tmax NetCDF files from ORNL DAAC, converts to GeoTIFF, caches locally
5. **Collect Tile Files** (`collect_daymet_tile_files()`): Manages parallel downloads, returns file paths
6. **Extract Values** (`extract_daymet_tile_values()`): Extracts pixel values at station coordinates, handles leap years
7. **Extract Air Temp** (`extract_daymet_airtemp()`): Combines tmin/tmax, calculates mean as (tmin+tmax)/2
8. **Merge** (`merge_data_airtemp()`): Joins air temp to station data, fills missing dates

### Caching Strategy
- **Spatial**: GeoTIFF files stored in `daymet_dir` (e.g., `tmin_2020_12345.tif`)
- **Temporal**: Files persist across runs; downloads skipped if file exists (unless `force=TRUE`)
- **Targets**: File paths tracked as targets; data re-extracted only if files change

## Proposed ERA5-Land Implementation

### Google Earth Engine Setup

**Requirements:**
1. GEE account with Earth Engine enabled
2. Service account credentials JSON file
3. R package `rgee` for GEE API access

**Authentication:**
- Use service account for non-interactive authentication
- Store service account JSON key file at: `r/gee-service-account.json` (gitignored)
- Or set environment variable `GEE_SERVICE_ACCOUNT_JSON` with full JSON content
- Initialize once per session: `ee_Initialize(service_account = ...)`

### New Workflow

#### 1. Initialize GEE (`init_gee()`)
- Load `rgee` package
- Authenticate using service account credentials from environment variable
- Initialize Earth Engine session
- Called once at start of pipeline

#### 2. Find Last Available Date (`find_era5_last_date()`)
- Query `ECMWF/ERA5_LAND/DAILY_AGGR` ImageCollection
- Get date of most recent image
- Return as date object
- Cache result as target (re-run on each pipeline execution to get latest)

#### 3. Determine Data to Fetch (`determine_era5_fetch_plan()`)
- **Input**: Combined station data (with date ranges per station)
- **Output**: Station-date ranges that need air temp data
- **Logic**:
  - For each station, extract min/max date from water temp data
  - Set date range to match observations: (station_start_date to min(last_era5_date, station_end_date))
  - Check against cached data (see #4)
  - Return only date ranges not yet cached

#### 4. Cache Management (`era5_cache.csv`)
- **Location**: `s3://{bucket}/{prefix}/cache/era5_cache.csv`
- **Schema**:
  ```
  station_id, latitude, longitude, date, mean_airtemp_c
  ```
- **Read Cache** (`read_era5_cache()`):
  - Download from S3 to local temp file (if exists)
  - Load CSV (or return empty tibble if no cache exists)
  - Use `aws.s3::s3read_using()` or AWS CLI
- **Write Cache** (`write_era5_cache()`):
  - Append new data to cache tibble
  - Write to local file
  - Upload to S3 (overwrite existing)
  - Use `aws.s3::s3write_using()` or AWS CLI
- **Filter Cached** (`filter_uncached_dates()`): Remove dates already in cache for each station
- **Error Handling**: If S3 download fails (cache doesn't exist or network error), start with empty cache

#### 5. Fetch ERA5 Data by Station (`fetch_era5_station()`)
- **Input**: station_id, latitude, longitude, start_date, end_date
- **Process**:
  - Create point geometry at station coordinates
  - Filter ERA5 ImageCollection to date range
  - Select `temperature_2m_mean` band
  - Extract time series at point using `ee$ImageCollection$getRegion()`
  - Convert from Kelvin to Celsius: `temp_c = temp_kelvin - 273.15`
  - Return tibble with columns: `date`, `mean_airtemp_c`
- **Rate Limiting**: Add `Sys.sleep(0.5)` between requests to avoid GEE throttling
- **Error Handling**: Use `possibly()` wrapper to handle failed extractions

#### 6. Batch Fetch (`collect_era5_data()`)
- **Input**: Fetch plan from #3
- **Process**:
  - Download existing cache from S3
  - For each station with missing dates:
    - Fetch new data via `fetch_era5_station()`
    - Append to cache incrementally
    - Upload updated cache to S3 after each station (so partial failures don't lose progress)
  - Return combined cache (existing + new)
- **Progress**: Use `logger::log_info()` to track progress
- **Error Handling**: If GEE fetch fails, log error and continue with stale cache data

#### 7. Join to Station Data (`merge_era5_to_stations()`)
- **Input**: Combined station data, ERA5 cache
- **Process**:
  - For each station:
    - Filter cache to matching station_id
    - Join to water temp data by date
    - Fill missing dates between min/max station date
    - Add columns: `min_airtemp_c = NA`, `max_airtemp_c = NA`, `mean_airtemp_c` (from ERA5)
- **Output**: Combined data with air temp columns (matching current schema)

### File Structure

**New Files:**
- `r/R/era5.R` - All ERA5-related functions (replaces `daymet.R`)
- `r/.Renviron.example` - Document required environment variables

**Modified Files:**
- `r/_targets.R` - Update targets for ERA5 workflow
- `r/R/combined.R` - Update `merge_data_airtemp()` if needed (likely minimal changes)
- `r/Dockerfile` - Add `rgee` package and system dependencies
- `r/renv.lock` - Update with `rgee` and dependencies
- `README.md` - Update documentation (air temp source, GEE setup instructions)

**S3 Storage Structure:**
```
s3://{bucket}/{prefix}/
  cache/
    era5_cache.csv      # persistent cache of all fetched data
  data/                 # final output data (stations.json, etc.)
  gis/                  # watershed boundaries
  meta/                 # targets metadata (via tar_option_set(repository_meta = "aws"))
  objects/              # targets objects (via tar_option_set(repository = "aws"))
```

**Local Data Directory (temporary):**
```
r/data/
  era5/
    era5_cache.csv      # downloaded from S3, updated locally, uploaded back
  gis/
    WBD_19_HU2_GDB/     # watershed boundaries (downloaded separately)
  output/               # final output before S3 upload
_targets/
  meta/                 # local metadata (synced with S3)
  objects/              # local cache of S3 objects (as needed)
```

### Targets Pipeline Updates

**Configure Cloud Storage (add to top of `_targets.R`):**
```r
# Load paws.storage for S3 integration
library(paws.storage)

# Configure targets to use AWS S3
tar_option_set(
  packages = c(...),  # existing packages
  repository = "aws",
  repository_meta = "aws",
  resources = tar_resources(
    aws = tar_resources_aws(
      bucket = Sys.getenv("AWS_S3_BUCKET"),
      prefix = glue("{Sys.getenv('AWS_S3_PREFIX')}")  # e.g., "viz/data"
    )
  )
)
```

**Remove:**
```r
tar_target(daymet_dir, mkdirp(file.path(data_dir, "daymet")))
tar_target(combined_station_tile_years, extract_station_tile_years(combined_data))
tar_target(daymet_last_year, find_daymet_last_year())
tar_target(daymet_tile_years, extract_daymet_tile_years(...))
tar_target(daymet_tile_files, collect_daymet_tile_files(...))
tar_target(airtemp, extract_airtemp(...))
```

**Add:**
```r
tar_target(era5_dir, mkdirp(file.path(data_dir, "era5")))
tar_target(gee_init, init_gee())  # dependency for other GEE targets
tar_target(era5_last_date, find_era5_last_date(gee_init))
tar_target(era5_fetch_plan, determine_era5_fetch_plan(combined_data, era5_dir, era5_last_date))
tar_target(era5_cache, collect_era5_data(era5_fetch_plan, era5_dir, gee_init))
tar_target(airtemp, merge_era5_to_stations(combined_data, era5_cache))
```

**Modify:**
```r
# Update config to use era5_last_date instead of daymet_last_year
tar_target(config, list(
  era5_last_date = era5_last_date,
  last_updated = format_ISO8601(...)
))
```

### Docker/Environment Setup

**System Dependencies:**
- Python 3.x (for `rgee` to interface with GEE Python API)
- `earthengine-api` Python package
- GDAL/GEOS (already in `rocker/geospatial`)

**R Packages:**
- `rgee` - R interface to Google Earth Engine
- `reticulate` - R-Python interface (dependency of `rgee`)
- `paws.storage` - AWS S3 integration for targets cloud storage

**Environment Variables:**
```bash
# GEE service account credentials (JSON key file path or content)
export GEE_SERVICE_ACCOUNT_EMAIL="aktempviz@project.iam.gserviceaccount.com"
export GEE_SERVICE_ACCOUNT_KEY="/path/to/service-account-key.json"
# OR
export GEE_SERVICE_ACCOUNT_JSON='{...json content...}'
```

**Dockerfile Updates:**
```dockerfile
# Install Python and GEE API
RUN apt-get update && apt-get install -y python3-pip
RUN pip3 install earthengine-api

# Install R packages
RUN R -e "install.packages(c('rgee', 'reticulate', 'paws.storage'))"
```

### Migration Strategy

**Phase 1: Development**
1. Create `r/R/era5.R` with all functions
2. Update `r/_targets.R` to use ERA5 (comment out Daymet targets)
3. Test locally with small subset of stations
4. Verify output schema matches current format

**Phase 2: Cache Building**
1. Run pipeline to fetch all historical data (1980-present)
2. Build complete `era5_cache.csv` (may take several hours due to GEE rate limits)
3. Verify cache file integrity

**Phase 3: S3 Integration**
1. Configure targets for AWS S3 cloud storage:
   - Add `paws.storage` package to dependencies
   - Update `_targets.R` with `repository = "aws"` and `repository_meta = "aws"`
   - Set S3 bucket/prefix via `tar_resources_aws()`
2. Test targets cloud storage:
   - Run `tar_make()` - automatically uploads objects/metadata to S3
   - Verify S3 structure: `s3://{bucket}/{prefix}/meta/` and `objects/`
   - Test `tar_read()` - automatically downloads from S3 as needed
3. Upload initial ERA5 cache to S3: `s3://{bucket}/{prefix}/cache/era5_cache.csv`
4. Remove manual S3 sync code from `run.R` (no longer needed with native targets S3 support)

**Phase 4: Deployment**
1. Update Dockerfile and rebuild image
2. Add GEE credentials to environment variables (not Secrets Manager for simplicity)
3. Update AWS Batch job definition to remove EFS mount, use S3 only
4. Deploy to AWS Batch
5. Test scheduled runs

**Phase 5: Cleanup**
1. Remove `r/R/daymet.R`
2. Remove Daymet directory references from README
3. Remove `daymetr` package from renv.lock
4. Archive old Daymet data (optional)

### Advantages of ERA5-Land

1. **Data Availability**: ERA5-Land is actively maintained, updated within 5 days of real-time
2. **Global Coverage**: Single global dataset (no tile management)
3. **Consistent Resolution**: 9km grid (Daymet is ~1km but Alaska-only)
4. **Quality**: Reanalysis product with better temporal consistency
5. **Future-Proof**: Part of Copernicus Climate Data Store infrastructure

### Considerations

1. **Spatial Resolution**: ERA5 (9km) is coarser than Daymet (1km) - may be less accurate in complex terrain
2. **API Limits**: GEE has query limits (concurrent requests, computation time) - need rate limiting
3. **Temperature Variable**: ERA5 provides mean daily temp directly; Daymet required (tmin+tmax)/2 calculation
4. **Historical Extent**: Only fetch data matching observation periods at each station (not full 1950-present archive)
5. **Authentication**: Requires GEE service account setup (additional deployment complexity)
6. **Storage**: S3-based caching eliminates need for EFS, simplifies deployment

### Testing Plan

1. **Integration Test**: Run pipeline on 5-10 stations across date ranges
2. **Performance**: Monitor GEE query times, estimate full dataset fetch time
3. **Cache Integrity**: Verify no duplicate dates, complete coverage
4. **S3 Cloud Storage**:
   - Test targets automatically uploads/downloads objects and metadata
   - Verify S3 bucket structure (`meta/`, `objects/`, `cache/`)
   - Test pipeline runs on different machines using same S3 backend

## Implementation Checklist

- [x] Save GEE service account credentials to `r/gee-service-account.json`
- [x] Install `rgee`, `paws.storage` and configure locally
- [x] Create `r/R/era5.R` with all functions
- [x] Update `r/_targets.R` pipeline:
  - [x] Add targets cloud storage configuration (`repository = "aws"`)
  - [x] Remove Daymet targets
  - [x] Add ERA5 targets
- [x] Remove Daymet code from `r/R/combined.R`
- [ ] Test locally with subset of data
- [ ] Update Dockerfile (add Python, GEE API, rgee, paws.storage)
- [ ] Update README.md with GEE setup and targets S3 cloud storage
- [ ] Build initial ERA5 cache for all stations
- [ ] Upload cache to S3
- [ ] Update AWS Batch job definition (remove EFS mount, add GEE env vars)
- [ ] Deploy and test
- [ ] Remove Daymet code and references
- [ ] Document migration in git commit

## Decisions Made

1. **Service Account**: Credentials stored in `r/gee-service-account.json` (local) or `GEE_SERVICE_ACCOUNT_JSON` env var (Docker)
2. **Cache Location**: S3 at `s3://{bucket}/{prefix}/cache/era5_cache.csv`
3. **Targets Store**: Native S3 cloud storage via `paws.storage`:
   - Metadata: `s3://{bucket}/{prefix}/meta/`
   - Objects: `s3://{bucket}/{prefix}/objects/`
   - No manual sync needed - targets handles automatically
4. **Historical Extent**: Only fetch data matching observation periods at each station (not arbitrary 1980 cutoff)
5. **Validation**: Skip validation report for now
6. **Error Handling**: If GEE fails, log error and continue with stale cache (graceful degradation)
7. **EFS Removal**: Eliminate EFS dependency - use S3 for all persistent storage
