library(shiny)
library(bslib)
library(leaflet)
library(sf)
library(dplyr)
library(htmltools)
library(tools)
library(DT)
library(sodium)

source("helpers/translations.R")
source("helpers/data_prep.R")
source("helpers/detail_panel.R")

# Load data once at startup
fieldwork <- load_fieldwork("data/fieldwork.csv")

ocgs <- load_ocgs(
  health_path = "data/ZNZ_Facilities_Health.shp",
  edu_path    = "data/ZNZ_Facilities_Education.shp"
)
health_df <- ocgs$health
edu_df    <- ocgs$edu

# Unified district list (fieldwork normalised to match OCGS "Kaskazini B" format)
all_districts <- sort(unique(c(
  normalize_district(fieldwork$district[!is.na(fieldwork$district)]),
  health_df$DISTRICT,
  edu_df$DISTRICT
)))

all_services <- sort(unique(unlist(lapply(fieldwork$service_types, split_field))))
all_services <- all_services[all_services != ""]

all_disabilities <- sort(unique(unlist(lapply(fieldwork$disability_types, split_field))))
all_disabilities <- all_disabilities[all_disabilities != ""]

all_access_feats <- sort(unique(unlist(lapply(fieldwork$access_features, split_field))))
all_access_feats <- all_access_feats[all_access_feats != ""]

# ---------------------------------------------------------------------------
# Colorblind-safe palette (Wong 2011)
# Vermillion / Blue / Reddish-purple — distinct under deuteranopia & protanopia
# ---------------------------------------------------------------------------
ICON_CARE_COLOR   <- "#D55E00"   # vermillion  — circle
ICON_HEALTH_COLOR <- "#0072B2"   # blue        — square
ICON_SCHOOL_COLOR <- "#CC79A7"   # reddish-purple — triangle

# Also expose as single names for backward compat in CSS legend
ICON_CARE   <- ICON_CARE_COLOR
ICON_HEALTH <- ICON_HEALTH_COLOR
ICON_SCHOOL <- ICON_SCHOOL_COLOR

# ---------------------------------------------------------------------------
# Demand layer configuration.
# The app reads DEMAND_RDS_PATH at runtime — a pre-processed .rds bundled
# with the deploy. Refreshing the file is the data owner's responsibility;
# the app itself does not fetch from any external source.
# ---------------------------------------------------------------------------
DEMAND_FIELD     <- "Total.population.with.disabilities"
DEMAND_RDS_PATH  <- file.path("data", "layers", "demand.rds")
GEOHUB_PUBLIC_URL <- "https://geohub.data.undp.org/maps/532"

# Palette: Purples (Jenks), legend bins start at 1, zeros stay transparent
build_demand_palette <- function(vals) {
  purples  <- RColorBrewer::brewer.pal(5, "Purples")[2:5]
  non_zero <- vals[!is.na(vals) & vals > 0]
  if (length(non_zero) >= 4) {
    jenks  <- classInt::classIntervals(non_zero, n = 4, style = "jenks")$brks
    breaks <- unique(sort(c(1, jenks[jenks > 1])))
  } else {
    breaks <- c(1, 10, 50, 100, max(non_zero, na.rm = TRUE) + 1)
  }
  list(
    fn     = colorBin(purples, domain = non_zero, bins = breaks, na.color = "transparent"),
    breaks = breaks
  )
}

# User credentials (gitignored — not in GitHub, bundled in deploy)
users_df <- read.csv("data/users.csv", stringsAsFactors = FALSE)

# Helper: build SVG data URI (avoids DOM overhead of divIcon)
svg_uri <- function(svg) {
  paste0("data:image/svg+xml;charset=utf-8,", utils::URLencode(svg, reserved = TRUE))
}

# SVG marker icons — shape + colour are both encoded
icon_care <- makeIcon(
  iconUrl = svg_uri(paste0(
    '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">',
    '<circle cx="10" cy="10" r="9" fill="', ICON_CARE_COLOR, '" stroke="white" stroke-width="2.5"/>',
    '</svg>'
  )),
  iconWidth = 20, iconHeight = 20,
  iconAnchorX = 10, iconAnchorY = 10,
  popupAnchorX = 0, popupAnchorY = -10
)

icon_health <- makeIcon(
  iconUrl = svg_uri(paste0(
    '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14">',
    '<rect x="1" y="1" width="12" height="12" rx="2" fill="', ICON_HEALTH_COLOR, '" stroke="white" stroke-width="2"/>',
    '</svg>'
  )),
  iconWidth = 14, iconHeight = 14,
  iconAnchorX = 7, iconAnchorY = 7,
  popupAnchorX = 0, popupAnchorY = -7
)

icon_school <- makeIcon(
  iconUrl = svg_uri(paste0(
    '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="16">',
    '<polygon points="7,1 13,15 1,15" fill="', ICON_SCHOOL_COLOR, '" stroke="white" stroke-width="2"/>',
    '</svg>'
  )),
  iconWidth = 14, iconHeight = 16,
  iconAnchorX = 7, iconAnchorY = 15,
  popupAnchorX = 0, popupAnchorY = -15
)
