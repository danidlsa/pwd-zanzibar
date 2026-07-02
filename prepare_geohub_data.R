# ============================================================================
# prepare_geohub_data.R
# ----------------------------------------------------------------------------
# Run this LOCALLY whenever you want fresh demand data from GeoHub, before
# deploying to shinyapps.io.
#
#   source("prepare_geohub_data.R")
#   rsconnect::deployApp()
#
# Why: shinyapps.io GDAL doesn't include the PMTiles driver, so the demand
# layer is pre-fetched here and cached as a small, pre-filtered .rds that the
# deployed app reads directly from disk (instant, no network on each session).
#
# Only ONE layer is cached now (PWD demand). All other accessibility / care-
# and-support-desert layers are linked to GeoHub directly (open in new tab).
# ============================================================================

library(sf)
source("global.R")   # loads DEMAND_URL, DEMAND_FIELD, DEMAND_RDS_PATH

outdir <- dirname(DEMAND_RDS_PATH)
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

cat("\nDownloading PWD demand layer from GeoHub...\n")

https_url <- sub("^/vsicurl/", "", DEMAND_URL)
tmp <- tempfile(fileext = ".pmtiles")
on.exit(unlink(tmp), add = TRUE)

download.file(https_url, tmp, mode = "wb", quiet = TRUE)
dat <- sf::st_read(tmp, quiet = TRUE)
dat <- sf::st_transform(dat, 4326)

# Trim to only the columns the app actually uses
keep_cols <- intersect(
  c(DEMAND_FIELD,
    "Hexagon.identifier",
    "Female.population.with.disabilities",
    "Male.population.with.disabilities"),
  names(dat)
)
dat <- dat[, keep_cols]

# Replace 0 with NA so empty hexagons render transparent / are dropped
dat[[DEMAND_FIELD]] <- ifelse(
  is.na(dat[[DEMAND_FIELD]]) | dat[[DEMAND_FIELD]] == 0,
  NA_real_, dat[[DEMAND_FIELD]]
)

# Drop empty hexagons entirely — they were ~10k of ~15k features
dat <- dat[!is.na(dat[[DEMAND_FIELD]]), ]

# Reduce coordinate precision (~11m), drastically shrinks the payload
dat <- sf::st_set_precision(dat, 1e4)
dat <- sf::st_make_valid(dat)

saveRDS(dat, DEMAND_RDS_PATH, compress = "xz")

cat(sprintf("OK (%d hexagons, %d KB) -> %s\n",
            nrow(dat),
            round(file.size(DEMAND_RDS_PATH) / 1024),
            DEMAND_RDS_PATH))
cat("\nNext step: rsconnect::deployApp()\n\n")
