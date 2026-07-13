# Zanzibar PWD Dashboard

An R Shiny dashboard mapping care and support services for persons with disabilities (PWD) in Unguja, Zanzibar — built under UNDP's **Care Georeferencing Tool (CGT)**, part of the joint global programme *"Unpaid Care, Disability, and Gender Transformative Approach Programme"*.

**Live app:** https://cgtundp.shinyapps.io/zanzibar-pwd-dashboard/

See [METHODOLOGICAL_NOTE.md](METHODOLOGICAL_NOTE.md) for full background on the CGT, data sources, and intended use.

## Features

- Interactive Leaflet map of specialized care and support facilities, health facilities, and education facilities across Unguja
- Filtering by district, service type, disability type, and accessibility features
- Bilingual interface (English / Kiswahili)
- Facility detail panel with service, staffing, and accessibility information
- Data table view with CSV / Excel export
- Authenticated view with demand-side (PWD population) and accessibility layers
- Built-in accessibility menu — text size, high-contrast, and night mode toggles (targets WCAG 2.1 AA)
- Mobile-responsive layout

## Repository structure

```
├── app.R                  # Entry point
├── global.R               # Data loading and setup, run once at startup
├── ui.R                   # UI layout
├── server.R               # Server logic
├── helpers/
│   ├── data_prep.R        # Data loading/cleaning helpers
│   ├── detail_panel.R     # Facility detail panel builder
│   └── translations.R     # EN/SW translation strings
├── www/                   # Static assets (logo, CSS/JS) — field photos excluded, see below
├── install_packages.R     # One-off script to install required R packages
├── METHODOLOGICAL_NOTE.md # CGT background, data sources, intended use
├── LICENSE                # MIT (code only)
└── data/                  # NOT included in this repo — see Data below
```

## Data

This repository does **not** include the underlying data, because the fieldwork dataset contains personal information (interviewee names, phone numbers, emails, and GPS coordinates) collected under informed consent for internal project use only. Facility site photos (`www/media/`) are excluded for the same reason.

To run the app locally you need to supply your own `data/` folder with:

| File | Description |
|---|---|
| `data/fieldwork.csv` | Specialized care and support services, from ODK fieldwork (see column list in `helpers/data_prep.R`) |
| `data/ZNZ_Facilities_Health.shp` (+ `.dbf`, `.shx`, `.prj`, `.cpg`) | Health facilities (OCGS administrative data) |
| `data/ZNZ_Facilities_Education.shp` (+ `.dbf`, `.shx`, `.prj`, `.cpg`) | Education facilities (OCGS administrative data) |
| `data/layers/demand.rds` | Pre-processed PWD demand hexagons (population layer shown behind the login) |
| `data/users.csv` | App login credentials: `username,email,password_hash,role,name` (hash via `sodium`) |
| `www/media/` | Facility photos from fieldwork |

Contact the project team for access to the source data.

## Running locally

```r
# 1. Install dependencies
source("install_packages.R")

# 2. Add your data/ folder (see Data above)

# 3. Run the app
shiny::runApp()
```

## Deployment

The live app is deployed to [shinyapps.io](https://www.shinyapps.io/). Deployment config (`rsconnect/`) is excluded from version control since it's account-specific. To deploy your own copy:

```r
rsconnect::deployApp()
```

## License

Source code is released under the [MIT License](LICENSE). This license covers the application code only — it does not extend to the underlying fieldwork data (not included in this repo), the UNDP logo, or other UNDP branding assets.
