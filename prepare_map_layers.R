# ============================================================================
# prepare_map_layers.R
# ----------------------------------------------------------------------------
# Run this LOCALLY whenever the source map data changes, before redeploying.
#
#   source("prepare_map_layers.R")
#   rsconnect::deployApp()   # or the deploy command for your target server
#
# What it does: fetches / reads each map layer, trims and simplifies it for
# fast browser rendering, and saves the result to data/layers/*.rds. The
# deployed app reads those .rds files directly from disk — no runtime calls
# to any external service.
#
# Currently only the PWD demand layer is prepared here. When the accessibility
# layers are added (see handover note §3.1), extend this script to bundle
# each of them the same way.
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
