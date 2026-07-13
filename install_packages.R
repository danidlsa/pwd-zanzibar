# Run this once to install all required packages
pkgs <- c("shiny", "bslib", "leaflet", "sf",
          "dplyr", "htmltools", "tools", "rsconnect",
          "DT", "sodium",
          "classInt", "RColorBrewer")

to_install <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(to_install) > 0) {
  install.packages(to_install)
} else {
  message("All packages already installed.")
}
