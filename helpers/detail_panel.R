# Renders the detail panel for a selected fieldwork care center

photo_card <- function(img_file, caption, facility_name = "") {
  if (is.null(img_file) || img_file == "" || is.na(img_file)) return(NULL)
  src     <- paste0("media/", img_file)
  # Descriptive, respectful alt text: what the photo shows, not who is in it
  alt_txt <- if (nchar(facility_name) > 0)
    paste0(caption, " at ", facility_name)
  else caption
  tags$div(
    class    = "photo-card",
    tabindex = "0",   # keyboard-navigable
    tags$img(src   = src,
             alt   = alt_txt,
             style = "width:100%; max-height:220px; object-fit:cover; border-radius:6px;"),
    tags$p(caption, style = "font-size:0.78rem; color:#666; margin:4px 0 0 0; text-align:center;",
           `aria-hidden` = "true")   # caption already in alt; hide duplicate
  )
}

info_row <- function(label, value, link_type = NULL) {
  if (is.null(value) || is.na(value) || value == "") return(NULL)
  val_el <- switch(link_type %||% "none",
    tel     = tags$a(href = paste0("tel:", gsub("[^+0-9]", "", value)),
                     value, class = "info-value"),
    mailto  = tags$a(href = paste0("mailto:", value),
                     value, class = "info-value"),
    url     = tags$a(href = value, value, target = "_blank",
                     rel = "noopener noreferrer", class = "info-value"),
    tags$span(value, class = "info-value")
  )
  tags$div(
    class = "info-row",
    tags$span(label, class = "info-label"),
    val_el
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a

bullet_list <- function(items) {
  items <- items[!is.na(items) & items != ""]
  if (length(items) == 0) return(NULL)
  tags$ul(lapply(items, function(i) tags$li(i)),
          style = "margin:0; padding-left:1.2em;")
}

render_detail <- function(row, lang, svc_labels, disability_labels, access_labels, t_fn) {
  req(row)

  # ---- helper closures ----
  tr   <- function(key) t_fn(key, lang)
  yn   <- function(x)   if (identical(tolower(x), "yes")) tr("val_yes") else if (identical(tolower(x), "no")) tr("val_no") else x
  mv   <- function(x, map) paste(translate_multivalue(x, map[[lang]]), collapse = " | ")

  # ---- photo vectors ----
  access_photos <- list(
    list(file = row$img_access_ramp,                      cap = tr("lbl_img_ramp")),
    list(file = row$img_handrails,                        cap = tr("lbl_img_handrail")),
    list(file = row$img_adapted_bathroom,                 cap = tr("lbl_img_bathroom")),
    list(file = row$img_widened_doors,                    cap = tr("lbl_img_doors")),
    list(file = row$img_non.slip_flooring,                cap = tr("lbl_img_floors")),
    list(file = row$img_accessible_signage,               cap = tr("lbl_img_signage")),
    list(file = row$img_accessible_icts_or_adapted_devices, cap = tr("lbl_img_icts")),
    list(file = row$img_other_access_features,            cap = tr("lbl_img_other"))
  )

  tagList(
    # Header
    tags$div(
      class = "detail-header",
      tags$h3(row$facility_name, style = "margin:0 0 4px 0;"),
      tags$p(paste(row$facility_type_label, "|", tr("lbl_region"), ":", row$region,
                   "|", tr("lbl_district"), ":", row$district),
             style = "color:#555; margin:0; font-size:0.88rem;")
    ),
    tags$hr(style = "margin:10px 0;"),

    # Tabs
    bslib::navset_card_tab(
      id = "detail_tabs",

      # --- Overview tab ---
      bslib::nav_panel(
        tr("tab_overview"),
        tags$div(
          class = "detail-body",
          info_row(tr("lbl_status"),   tools::toTitleCase(tolower(row$facility_status))),
          info_row(tr("lbl_year"),     row$year_established),
          info_row(tr("lbl_shehia"),   row$shehia),
          info_row(tr("lbl_coverage"), tools::toTitleCase(tolower(row$coverage))),
          info_row(tr("lbl_hours"),    row$operating_hours),
          info_row(tr("lbl_fee"),      tools::toTitleCase(tolower(row$service_fee))),
          info_row(tr("lbl_financing"),tools::toTitleCase(gsub("_", " ", row$financing))),
          info_row(tr("lbl_phone"),   row$phonenumber, link_type = "tel"),
          info_row(tr("lbl_email"),   row$email,       link_type = "mailto"),
          info_row(tr("lbl_website"), row$website,     link_type = "url")
        )
      ),

      # --- Services tab ---
      bslib::nav_panel(
        tr("tab_services"),
        tags$div(
          class = "detail-body",
          info_row(tr("lbl_weekly_users"), row$avg_weekly_users),
          tags$div(class = "info-row",
            tags$span(tr("lbl_services"),  class = "info-label"),
            bullet_list(translate_multivalue(row$service_types, svc_labels[[lang]]))
          ),
          if (!is.na(row$other_service) && row$other_service != "")
            info_row(tr("lbl_other_svc"), row$other_service),
          tags$div(class = "info-row",
            tags$span(tr("lbl_disabilities"), class = "info-label"),
            bullet_list(translate_multivalue(row$disability_types, disability_labels[[lang]]))
          ),
          info_row(tr("lbl_age_groups"),
            paste(split_field(row$age_groups), collapse = ", ")),
          info_row(tr("lbl_access_modes"),
            paste(gsub("_", " ", split_field(row$access_modes)), collapse = " / "))
        )
      ),

      # --- Accessibility tab ---
      bslib::nav_panel(
        tr("tab_access"),
        tags$div(
          class = "detail-body",
          tags$div(class = "info-row",
            tags$span(tr("lbl_access_feat"), class = "info-label"),
            bullet_list(translate_multivalue(row$access_features, access_labels[[lang]]))
          ),
          if (!is.na(row$other_access) && row$other_access != "")
            info_row("Other", row$other_access),
          tags$hr(style = "margin:10px 0;"),
          # Access photos grid
          tags$div(
            class = "photo-grid",
            lapply(access_photos, function(p)
              photo_card(p$file, p$cap, row$facility_name))
          )
        )
      ),

      # --- Staff tab ---
      bslib::nav_panel(
        tr("tab_staff"),
        tags$div(
          class = "detail-body",
          info_row(tr("lbl_staff_total"),  row$total_staff),
          info_row(tr("lbl_women_care"),   yn(row$women_direct_care)),
          info_row(tr("lbl_trained"),      yn(row$staff_trained)),
          info_row(tr("lbl_training_det"), row$training_details),
          info_row(tr("lbl_pwd_employ"),   yn(row$pwd_employment)),
          info_row(tr("lbl_referral"),     yn(row$referral_system))
        )
      ),

      # --- CRPD tab ---
      bslib::nav_panel(
        tr("tab_crpd"),
        tags$div(
          class = "detail-body",

          # Alignment: "no" → treat as NA (not shown); "yes" → show level
          {
            align_val <- tolower(trimws(row$crpd_alignment))
            if (!is.na(align_val) && align_val == "yes") {
              # Clean up the long level label
              level_clean <- if (!is.na(row$crpd_level) && row$crpd_level != "") {
                if (grepl("partial|transition", row$crpd_level, ignore.case = TRUE))
                  tr("lbl_crpd_partial")
                else
                  tools::toTitleCase(gsub("_", " ", tolower(row$crpd_level)))
              } else NULL
              tagList(
                info_row(tr("lbl_crpd_align"), tr("val_yes")),
                info_row(tr("lbl_crpd_level"), level_clean)
              )
            } else {
              # "no" or NA → show nothing for these two fields
              NULL
            }
          },

          tags$div(class = "info-row",
            tags$span(tr("lbl_challenges"), class = "info-label"),
            bullet_list(gsub("_", " ",
              tools::toTitleCase(split_field(row$challenges))))
          ),
          if (!is.na(row$other_challenges) && row$other_challenges != "")
            info_row("Other challenges", row$other_challenges),
          info_row(tr("lbl_monitoring"),
            gsub("_", " ", tools::toTitleCase(tolower(row$monitoring_evaluation_mechanism)))),
          info_row(tr("lbl_user_part"), yn(row$user_participation)),

          # Self-reported disclaimer
          tags$p(tr("lbl_crpd_note"),
                 style = "font-size:0.72rem; color:#696969; font-style:italic;
                          margin-top:12px; padding-top:10px;
                          border-top:1px solid #f0f0f0;")
        )
      ),

      # --- Photos tab ---
      bslib::nav_panel(
        tr("tab_photos"),
        tags$div(
          class = "photo-grid",
          photo_card(row$photo_front, tr("lbl_photo_front"), row$facility_name),
          lapply(access_photos, function(p)
            photo_card(p$file, p$cap, row$facility_name))
        )
      )
    )
  )
}

render_ocgs_popup <- function(row, layer_label) {
  paste0(
    "<strong>", htmltools::htmlEscape(row$NAME), "</strong><br>",
    "<em>", htmltools::htmlEscape(layer_label), "</em><br>",
    row$TYPE, "<br>",
    row$DISTRICT, " | ", row$REGION
  )
}
