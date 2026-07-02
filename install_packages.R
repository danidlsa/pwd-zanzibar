# Run this once to install all required packages
pkgs <- c("shiny", "bslib", "leaflet", "leaflet.extras", "sf",
          "dplyr", "htmltools", "tools", "rsconnect",
          "DT", "sodium", "shinyjs", "viridisLite", "future", "promises",
          "classInt", "RColorBrewer")

to_install <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(to_install) > 0) {
  install.packages(to_install)
} else {
  message("All packages already installed.")
}
