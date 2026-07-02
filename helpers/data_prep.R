# Data loading and cleaning — sourced once from global.R

load_fieldwork <- function(path) {
  df <- read.csv(path, stringsAsFactors = FALSE, na.strings = c("", "NA", "null", "NULL"))

  # Clean coordinates
  df <- df[!is.na(df$gps.Latitude) & !is.na(df$gps.Longitude), ]

  # Normalize photo columns: NA → ""
  photo_cols <- c("photo_front", "img_access_ramp", "img_handrails",
                  "img_adapted_bathroom", "img_widened_doors",
                  "img_non.slip_flooring", "img_accessible_signage",
                  "img_accessible_icts_or_adapted_devices", "img_other_access_features")
  for (col in photo_cols) {
    if (col %in% names(df)) {
      df[[col]] <- ifelse(is.na(df[[col]]), "", df[[col]])
    }
  }

  # Clean text fields
  text_cols <- c("facility_name", "facility_type", "facility_status", "coverage",
                 "operating_hours", "service_fee", "financing", "crpd_level",
                 "training_details", "other_service", "challenges", "other_challenges",
                 "Enumerator_observation", "unpaid_arrangement")
  for (col in text_cols) {
    if (col %in% names(df)) {
      df[[col]] <- trimws(df[[col]])
    }
  }

  # Readable facility type
  df$facility_type_label <- dplyr::case_when(
    grepl("ngo", df$facility_type, ignore.case = TRUE)        ~ "NGO",
    grepl("gov", df$facility_type, ignore.case = TRUE)        ~ "Government",
    grepl("private", df$facility_type, ignore.case = TRUE)    ~ "Private",
    grepl("faith", df$facility_type, ignore.case = TRUE)      ~ "Faith-based",
    TRUE                                                        ~ tools::toTitleCase(tolower(df$facility_type))
  )

  # Binary yes/no normalization
  yn_cols <- c("referral_system", "pwd_employment", "staff_trained",
               "training_last_2yrs", "user_participation",
               "women_direct_care", "unpaid_workers")
  for (col in yn_cols) {
    if (col %in% names(df)) {
      df[[col]] <- tolower(trimws(df[[col]]))
    }
  }

  # Unique row id for click handling
  df$row_id <- seq_len(nrow(df))

  df
}

load_ocgs <- function(health_path, edu_path) {
  # GDAL cannot handle macOS NFD-encoded paths (common with OneDrive folders
  # that contain accented characters). We copy the shapefile components to a
  # temporary directory with a plain ASCII path and read from there.
  copy_shp_to_tmp <- function(shp_path) {
    tmp   <- file.path(tempdir(), paste0("shp_", basename(shp_path)))
    base  <- sub("\\.shp$", "", shp_path)
    tmp_b <- sub("\\.shp$", "", tmp)
    for (ext in c(".shp", ".dbf", ".shx", ".prj", ".cpg", ".qmd")) {
      src <- paste0(base, ext)
      if (file.exists(src)) file.copy(src, paste0(tmp_b, ext), overwrite = TRUE)
    }
    tmp
  }

  health <- sf::st_read(copy_shp_to_tmp(health_path), quiet = TRUE)
  edu    <- sf::st_read(copy_shp_to_tmp(edu_path),    quiet = TRUE)

  health <- sf::st_transform(health, 4326)
  edu    <- sf::st_transform(edu,    4326)

  # Extract coords as columns for leaflet
  health_coords <- sf::st_coordinates(health)
  health$lng <- health_coords[, 1]
  health$lat <- health_coords[, 2]

  edu_coords <- sf::st_coordinates(edu)
  edu$lng <- edu_coords[, 1]
  edu$lat <- edu_coords[, 2]

  # Drop geometry for speed (we use lng/lat columns in leaflet directly)
  health <- sf::st_drop_geometry(health)
  edu    <- sf::st_drop_geometry(edu)

  # Keep Unguja island only (exclude Pemba: Kaskazini Pemba, Kusini Pemba)
  unguja_regions <- c("Kaskazini Unguja", "Kusini Unguja", "Mjini Magharibi")
  health <- health[health$REGION %in% unguja_regions, ]
  edu    <- edu[edu$REGION    %in% unguja_regions, ]

  list(health = health, edu = edu)
}
