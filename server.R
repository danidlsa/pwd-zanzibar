server <- function(input, output, session) {

  # Tiny helper for default values
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

  # ── Authentication (custom — sodium password verification) ────────────────
  auth_user   <- reactiveVal(NULL)   # NULL = not logged in; row from users_df = logged in
  login_error <- reactiveVal(FALSE)

  is_authed   <- reactive({ !is.null(auth_user()) })

  observeEvent(input$login_submit, {
    uname <- trimws(input$login_username)
    pwd   <- input$login_password
    row   <- users_df[users_df$username == uname | users_df$email == uname, ]
    if (nrow(row) == 1 && sodium::password_verify(row$password_hash[1], pwd)) {
      auth_user(row)
      login_error(FALSE)
    } else {
      login_error(TRUE)
    }
  })

  observeEvent(input$logout_btn, {
    auth_user(NULL)
    login_error(FALSE)
  })

  # ── Request access modal ──────────────────────────────────────────────────
  # Embeds a Microsoft Form (UNDP M365 tenant). The destination email stays
  # hidden — responses are logged to the form owner's account directly.
  MS_FORM_URL <- paste0(
    "https://forms.office.com/Pages/ResponsePage.aspx?id=",
    "Xtvls0QpN0iZ9XSIrOVDGQ1AbWqJxuhCuBP5HwrApQdUOTVWTjhFR0pDMDROUUMwRE5ESTdYSjdNOC4u",
    "&embed=true"
  )

  observeEvent(input$request_access_open, {
    showModal(modalDialog(
      title = tr("request_title"),
      easyClose = TRUE,
      size  = "l",
      footer = modalButton(tr("request_cancel")),
      tags$iframe(
        src    = MS_FORM_URL,
        width  = "100%",
        height = "600px",
        style  = paste0("border:none; max-width:100%; ",
                        "max-height:80vh; min-height:500px;"),
        frameborder       = "0",
        marginwidth       = "0",
        marginheight      = "0",
        allowfullscreen   = NA,
        title             = tr("request_title")  # for screen readers
      )
    ))
  })

  # ── Language ──────────────────────────────────────────────────────────────
  lang <- reactiveVal("en")
  observeEvent(input$lang_btn, { lang(if (lang() == "en") "sw" else "en") })
  tr <- function(key) t(key, lang())

  # ── Update HTML lang attribute for screen readers ─────────────────────────
  observe({
    session$sendCustomMessage("setLang", list(lang = lang()))
  })

  # ── Accessibility menu labels ─────────────────────────────────────────────
  output$a11y_menu_label   <- renderText(tr("a11y_menu"))
  output$a11y_menu_label2  <- renderText(tr("a11y_menu"))
  output$a11y_lbl_size     <- renderText(tr("a11y_text_size"))
  output$a11y_lbl_hc       <- renderText(tr("a11y_high_contrast"))
  output$a11y_lbl_night    <- renderText(tr("a11y_night_mode"))
  # These live inside a display:none panel that JS toggles — Shiny would
  # otherwise suspend them and they'd never populate on first open.
  outputOptions(output, "a11y_menu_label2", suspendWhenHidden = FALSE)
  outputOptions(output, "a11y_lbl_size",    suspendWhenHidden = FALSE)
  outputOptions(output, "a11y_lbl_hc",      suspendWhenHidden = FALSE)
  outputOptions(output, "a11y_lbl_night",   suspendWhenHidden = FALSE)

  # ── Text size (chosen directly from A / A+ / A++ pill buttons) ────────────
  text_size <- reactiveVal("normal")

  observeEvent(input$text_size_set, {
    text_size(input$text_size_set)
  })

  observe({
    session$sendCustomMessage("setTextSize", list(size = text_size()))
  })

  # ── Night mode (checkbox in accessibility menu) ───────────────────────────
  night_mode <- reactiveVal(FALSE)
  observeEvent(input$night_check, { night_mode(isTRUE(input$night_check)) },
               ignoreInit = TRUE)
  observe({
    session$sendCustomMessage("setNightMode", list(on = night_mode()))
  })

  # ── High-contrast mode (checkbox in accessibility menu) ───────────────────
  hc_mode <- reactiveVal(FALSE)
  observeEvent(input$hc_check, { hc_mode(isTRUE(input$hc_check)) },
               ignoreInit = TRUE)
  observe({
    session$sendCustomMessage("setHighContrast", list(on = hc_mode()))
  })

  # ── Header text ───────────────────────────────────────────────────────────
  output$hdr_title      <- renderText(tr("app_title"))
  output$hdr_subtitle   <- renderText(tr("subtitle"))
  output$lang_btn_label <- renderText(tr("lang_toggle"))

  # ── Tab labels ────────────────────────────────────────────────────────────
  output$tab_map_label   <- renderUI(tr("tab_map"))
  output$tab_table_label  <- renderUI(tr("tab_table"))
  output$tab_demand_label <- renderUI({
    # Add a lock icon suffix when not authenticated (ASCII-safe)
    if (is_authed()) tr("tab_demand")
    else paste(tr("tab_demand"), "[lock]")
  })
  output$tab_about_label  <- renderUI(tr("tab_about"))

  # ── Auth header: show username + logout when logged in ────────────────────
  output$auth_header_ui <- renderUI({
    if (!is_authed()) return(NULL)
    row <- auth_user()
    tags$div(
      style = "display:flex; align-items:center; gap:8px;",
      tags$span(
        style = "font-size:0.78rem; opacity:0.85;",
        paste(tr("logged_as"), row$name[1])
      ),
      tags$button(
        id      = "logout_btn",
        class   = "lang-btn",
        style   = "background:rgba(255,100,100,0.25); border-color:rgba(255,150,150,0.5);",
        onclick = "Shiny.setInputValue('logout_btn', Math.random())",
        tr("logout_btn")
      )
    )
  })

  # ── Demand & Accessibility tab (private) ─────────────────────────────────
  output$demand_tab_ui <- renderUI({
    if (!is_authed()) {
      # Custom login form
      tags$div(
        class = "p-4",
        style = "max-width:400px; margin:40px auto;",
        tags$div(
          class = "card shadow-sm",
          tags$div(
            class = "card-body p-4",
            tags$div(
              style = "text-align:center; margin-bottom:20px;",
              tags$span(style = "font-size:2.5rem; color:#555;", "[lock]"),
              tags$h4(tr("login_title"),
                      style = "color:#0468B1; margin:8px 0 4px 0;"),
              tags$p(tr("login_subtitle"),
                     style = "font-size:0.85rem; color:#555; margin:0;")
            ),
            tags$div(
              class = "mb-3",
              tags$label(tr("login_user"),
                         `for` = "login_username",
                         class = "form-label fw-semibold"),
              tags$input(id          = "login_username",
                         type        = "text",
                         class       = "form-control",
                         autocomplete = "username",
                         onkeydown   = "if(event.key==='Enter'){document.getElementById('login_password').focus();}")
            ),
            tags$div(
              class = "mb-3",
              tags$label(tr("login_pwd"),
                         `for` = "login_password",
                         class = "form-label fw-semibold"),
              tags$div(
                style = "position:relative;",
                tags$input(id           = "login_password",
                           type         = "password",
                           class        = "form-control",
                           style        = "padding-right:42px;",
                           autocomplete = "current-password",
                           onkeydown    = "if(event.key==='Enter') Shiny.setInputValue('login_submit', Math.random())"),
                tags$button(
                  type    = "button",
                  style   = paste0("position:absolute; right:8px; top:50%; transform:translateY(-50%);",
                                   "background:none; border:none; cursor:pointer;",
                                   "color:#666; padding:0; line-height:1; font-size:1.1rem;"),
                  `aria-label` = "Show/hide password",
                  onclick = "
                    var inp = document.getElementById('login_password');
                    if (inp.type === 'password') {
                      inp.type = 'text';
                      this.innerHTML = '<svg width=\"18\" height=\"18\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94\"/><path d=\"M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19\"/><line x1=\"1\" y1=\"1\" x2=\"23\" y2=\"23\"/></svg>';
                    } else {
                      inp.type = 'password';
                      this.innerHTML = '<svg width=\"18\" height=\"18\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z\"/><circle cx=\"12\" cy=\"12\" r=\"3\"/></svg>';
                    }
                  ",
                  # eye icon (SVG)
                  HTML('<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>')
                )
              )
            ),
            if (login_error()) tags$div(
              class = "alert alert-danger py-2 mb-3",
              style = "font-size:0.85rem;",
              tr("login_error")
            ),
            tags$button(
              id      = "login_submit",
              class   = "btn btn-primary w-100",
              style   = "min-height:44px;",
              onclick = "Shiny.setInputValue('login_submit', Math.random())",
              tr("login_btn")
            ),
            tags$div(
              style = "text-align:center; margin-top:14px; padding-top:12px; border-top:1px solid #eee;",
              tags$button(
                id      = "request_access_open",
                class   = "btn btn-link",
                style   = "font-size:0.85rem; color:#0468B1; text-decoration:none; padding:6px 12px;",
                onclick = "Shiny.setInputValue('request_access_open', Math.random())",
                tr("request_access_btn")
              )
            )
          )
        )
      )
    } else {
      # Authenticated: intro + menu (cards) OR demand map view
      tags$div(
        class = "p-3",
        uiOutput("demand_intro"),
        if (demand_view() == "demand_map") {
          tagList(
            tags$div(
              style = "display:flex; align-items:center; gap:14px; margin-bottom:10px; flex-wrap:wrap;",
              tags$button(
                class   = "btn btn-outline-secondary btn-sm",
                style   = "min-height:36px;",
                onclick = "Shiny.setInputValue('demand_back_to_menu', Math.random())",
                HTML(paste0("&larr; ", tr("demand_back_btn")))
              ),
              # Inline notice with spinner — fades out via CSS after first paint
              tags$div(
                id    = "demand_loading_notice",
                style = paste0(
                  "display:flex; align-items:center; gap:8px;",
                  "font-size:0.85rem; color:#696969; font-style:italic;",
                  "animation: fadeOutLoad 8s ease-in forwards;"
                ),
                tags$div(style = paste0(
                  "width:16px; height:16px; border:2px solid #e0e0e0;",
                  "border-top-color:#0468B1; border-radius:50%;",
                  "animation: spin 0.9s linear infinite; flex-shrink:0;"
                )),
                tags$span(tr("demand_loading"))
              ),
              tags$style(HTML(
                "@keyframes spin { to { transform: rotate(360deg); } }
                 @keyframes fadeOutLoad {
                   0%   { opacity: 1; }
                   85%  { opacity: 1; }
                   100% { opacity: 0; visibility: hidden; }
                 }"
              ))
            ),
            tags$div(
              class = "map-container",
              style = "margin-top:4px;",
              leafletOutput("demand_map", height = "calc(100vh - 340px)")
            )
          )
        } else {
          # Menu view: two cards
          tags$div(
            tags$h5(style = "color:#333; margin-bottom:14px;", tr("demand_menu_title")),
            tags$div(
              style = "display:grid; grid-template-columns:repeat(auto-fit, minmax(280px, 1fr)); gap:16px; max-width:900px;",
              # Card 1: Demand
              tags$div(
                class = "card shadow-sm h-100",
                tags$div(
                  class = "card-body d-flex flex-column",
                  tags$h5(class = "card-title",
                          style = "color:#0468B1;",
                          tr("demand_card_demand_title")),
                  tags$p(class = "card-text flex-grow-1",
                         style = "font-size:0.9rem; color:#555;",
                         tr("demand_card_demand_desc")),
                  tags$button(
                    class   = "btn btn-primary mt-2",
                    style   = "min-height:44px;",
                    onclick = "Shiny.setInputValue('demand_show_map', Math.random())",
                    tr("demand_card_demand_btn")
                  )
                )
              ),
              # Card 2: Accessibility (external link)
              tags$div(
                class = "card shadow-sm h-100",
                tags$div(
                  class = "card-body d-flex flex-column",
                  tags$h5(class = "card-title",
                          style = "color:#0468B1;",
                          tr("demand_card_access_title")),
                  tags$p(class = "card-text flex-grow-1",
                         style = "font-size:0.9rem; color:#555;",
                         tr("demand_card_access_desc")),
                  tags$a(
                    href   = GEOHUB_PUBLIC_URL,
                    target = "_blank",
                    rel    = "noopener noreferrer",
                    class  = "btn btn-outline-primary mt-2",
                    style  = "min-height:44px; display:inline-flex; align-items:center; justify-content:center;",
                    HTML(paste0(tr("demand_card_access_btn"), " &nearr;"))
                  )
                )
              )
            )
          )
        }
      )
    }
  })

  # ── Demand view state (menu | demand_map) ────────────────────────────────
  demand_view <- reactiveVal("menu")
  observeEvent(input$demand_show_map, {
    # Toast feedback: tells the user the map is loading (since renderLeaflet
    # blocks for a moment on this many polygons)
    showNotification(tr("demand_loading"), type = "default", duration = 4)
    demand_view("demand_map")
  })
  observeEvent(input$demand_back_to_menu, { demand_view("menu") })
  # Reset to menu when user logs out
  observeEvent(is_authed(), { if (!is_authed()) demand_view("menu") })

  # ── Demand map: rendered only when view is "demand_map" ──────────────────
  output$demand_map <- renderLeaflet({
    req(demand_view() == "demand_map", file.exists(DEMAND_RDS_PATH))
    dat  <- readRDS(DEMAND_RDS_PATH)
    vals <- dat[[DEMAND_FIELD]]
    pal  <- build_demand_palette(vals)
    fill_colors <- pal$fn(vals)

    popup_html <- paste0(
      "<strong>", htmltools::htmlEscape(dat$Hexagon.identifier), "</strong><br>",
      tr("demand_total"),  ": <strong>", vals, "</strong><br>",
      tr("demand_female"), ": ", dat$Female.population.with.disabilities, "<br>",
      tr("demand_male"),   ": ", dat$Male.population.with.disabilities
    )

    leaflet(options = leafletOptions(preferCanvas = TRUE)) |>
      addProviderTiles("CartoDB.Positron",  group = "Light") |>
      addProviderTiles("Esri.WorldImagery", group = "Satellite") |>
      addPolygons(
        data         = dat,
        fillColor    = fill_colors,
        fillOpacity  = 0.55,
        stroke       = FALSE,
        smoothFactor = 2,
        popup        = popup_html
      ) |>
      addLegend(
        position  = "bottomright",
        pal       = pal$fn,
        values    = vals,
        title     = "PWD population",
        na.label  = "",
        opacity   = 0.85
      ) |>
      addLayersControl(
        baseGroups = c("Light", "Satellite"),
        options    = layersControlOptions(collapsed = TRUE)
      ) |>
      setView(lng = 39.35, lat = -6.15, zoom = 10)
  })

  # Demand & Accessibility tab intro (bilingual)
  output$demand_intro <- renderUI({
    l <- lang()
    tags$div(
      style = "max-width:800px; margin-bottom:16px; font-size:0.92rem; line-height:1.6;",
      tags$h4(style = "color:#0468B1; margin-bottom:12px;", tr("tab_demand")),
      if (l == "sw") tagList(
        tags$p(
          "Sehemu hii inaonyesha usambazaji wa anga wa ",
          tags$strong("mahitaji yanayowezekana"),
          " ya huduma, kulingana na data ya idadi ya watu kutoka Ofisi ya Mkuu wa Mtakwimu wa Serikali (OCGS)."
        ),
        tags$p(
          tags$strong("Upatikanaji"),
          " unakadiria kwa kutumia nyakati za safari zilizohesabiwa kupitia Overpass API (OpenStreetMap), ",
          "inayoruhusu makadirio ya muda inachukua kufikia kwa miguu huduma mbalimbali kutoka maeneo yenye watu."
        ),
        tags$p(
          "Kulingana na mchanganyiko wa mahitaji na nyakati za safari, ",
          tags$strong('"maeneo ya ukame wa huduma za utunzaji na msaada"'),
          " yanatambuliwa kama maeneo ambayo mkusanyiko mkubwa wa watu wenye ulemavu unapatikana pamoja na ",
          "upatikanaji mdogo wa kimwili kwa huduma (yaani, nyakati ndefu za safari hadi huduma inayofaa iliyo karibu ",
          "- zaidi ya dakika 20 kwa miguu)."
        ),
        tags$p(
          "Maeneo haya yanaonyesha kanda za kipaumbele kwa ajili ya kupanua na kusambaza vizuri huduma za utunzaji na msaada kwa watu wenye ulemavu."
        )
      ) else tagList(
        tags$p(
          "This section presents the spatial distribution of ",
          tags$strong("potential demand"),
          " for services, based on population data from the Office of the Chief Government Statistician (OCGS)."
        ),
        tags$p(
          tags$strong("Accessibility"),
          " is estimated using travel times calculated through the Overpass API (OpenStreetMap), ",
          "allowing for an approximation of how long it takes to reach by foot different services from populated areas."
        ),
        tags$p(
          "Based on the combination of demand and travel times, ",
          tags$strong('"care and support deserts"'),
          " are identified as areas where high concentrations of persons with disabilities coincide with ",
          "limited physical access to services (i.e., long travel times to the nearest relevant service ",
          "- more than 20 minutes on foot)."
        ),
        tags$p(
          "These areas highlight priority zones for expanding and better distributing care and support services for PWD."
        )
      )
    )
  })

  # ── Sidebar + accessibility labels ────────────────────────────────────────
  output$lbl_skip             <- renderText(tr("skip_to_content"))
  output$lbl_primary_question <- renderText(tr("primary_question"))
  output$lbl_refine_heading   <- renderText(tr("refine_heading"))
  output$lbl_district         <- renderText(tr("filter_district"))
  output$lbl_service          <- renderText(tr("filter_service"))
  output$lbl_disability       <- renderText(tr("filter_disability"))
  output$lbl_access           <- renderText(tr("filter_access"))
  output$lbl_fee              <- renderText(tr("filter_fee"))
  output$lbl_clear            <- renderText(tr("btn_clear"))
  output$lbl_map_desc         <- renderText(tr("a11y_map_desc"))
  output$lbl_table_intro      <- renderText(tr("table_intro"))
  output$legend_care          <- renderText(tr("layer_care"))
  output$legend_health        <- renderText(tr("layer_health"))
  output$legend_school        <- renderText(tr("layer_schools"))

  # ── Update filter choices when language changes ───────────────────────────
  observe({
    l   <- lang()
    all <- tr("all_option")

    # Primary "what to show" radio buttons
    prim_ch <- c(
      setNames("all",     tr("primary_all")),
      setNames("care",    tr("primary_care")),
      setNames("health",  tr("primary_health")),
      setNames("schools", tr("primary_schools"))
    )
    updateRadioButtons(session, "primary_filter",
      choices = prim_ch, selected = isolate(input$primary_filter) %||% "all")

    # Districts — no translation needed
    updateSelectInput(session, "filter_district",
      choices  = c(setNames("", all), setNames(as.list(all_districts), all_districts)),
      selected = "")

    # Service types — just real care service types now
    svc_map <- svc_labels[[l]]
    svc_ch  <- c(
      setNames("", all),
      setNames(as.list(all_services),
               ifelse(all_services %in% names(svc_map),
                      svc_map[all_services],
                      tools::toTitleCase(gsub("[_-]", " ", all_services))))
    )
    updateSelectInput(session, "filter_service", choices = svc_ch, selected = "")

    # Disability types — no special options
    dis_map <- disability_labels[[l]]
    dis_ch  <- c(
      setNames("", all),
      setNames(as.list(all_disabilities),
               ifelse(all_disabilities %in% names(dis_map),
                      dis_map[all_disabilities],
                      tools::toTitleCase(gsub("[_-]", " ", all_disabilities))))
    )
    updateSelectInput(session, "filter_disability", choices = dis_ch, selected = "")

    # Accessibility features — no special options
    acc_map <- access_labels[[l]]
    acc_ch  <- c(
      setNames("", all),
      setNames(as.list(all_access_feats),
               ifelse(all_access_feats %in% names(acc_map),
                      acc_map[all_access_feats],
                      tools::toTitleCase(gsub("[_-]", " ", all_access_feats))))
    )
    updateSelectInput(session, "filter_access", choices = acc_ch, selected = "")

    # Fee
    fee_ch <- c(setNames("", all),
                setNames("free", tr("free")),
                setNames("paid", tr("paid")))
    updateSelectInput(session, "filter_fee", choices = fee_ch, selected = "")
  })

  # ── Helper: active filter values (drop blanks) ────────────────────────────
  active_districts  <- reactive({ v <- input$filter_district;  v[!is.na(v) & v != ""] })
  active_services   <- reactive({ v <- input$filter_service;   v[!is.na(v) & v != ""] })
  active_disability <- reactive({ v <- input$filter_disability; v[!is.na(v) & v != ""] })
  active_access     <- reactive({ v <- input$filter_access;    v[!is.na(v) & v != ""] })

  # Any care-specific filter active (besides district)?
  any_care_filter_active <- reactive(
    length(active_services())   > 0 ||
    length(active_disability()) > 0 ||
    length(active_access())     > 0 ||
    (!is.null(input$filter_fee) && input$filter_fee != "")
  )

  # ── Filtered fieldwork ────────────────────────────────────────────────────
  filtered_fw <- reactive({
    df <- fieldwork

    # District (normalize fieldwork underscores → spaces to match OCGS)
    if (length(active_districts()) > 0)
      df <- df[normalize_district(df$district) %in% active_districts(), ]

    # Service type
    if (length(active_services()) > 0) {
      keep <- sapply(df$service_types, function(x) any(active_services() %in% split_field(x)))
      df <- df[keep, ]
    }

    # Disability
    if (length(active_disability()) > 0) {
      keep <- sapply(df$disability_types, function(x) any(active_disability() %in% split_field(x)))
      df <- df[keep, ]
    }

    # Accessibility
    if (length(active_access()) > 0) {
      keep <- sapply(df$access_features, function(x) any(active_access() %in% split_field(x)))
      df <- df[keep, ]
    }

    # Fee
    if (!is.null(input$filter_fee) && input$filter_fee != "") {
      if (input$filter_fee == "free")
        df <- df[tolower(df$service_fee) == "free", ]
      else
        df <- df[tolower(df$service_fee) != "free", ]
    }

    df
  })

  # ── Filtered health (district only) ──────────────────────────────────────
  filtered_health <- reactive({
    df <- health_df
    if (length(active_districts()) > 0)
      df <- df[df$DISTRICT %in% active_districts(), ]
    df
  })

  # ── Filtered schools (district only) ─────────────────────────────────────
  filtered_edu <- reactive({
    df <- edu_df
    if (length(active_districts()) > 0)
      df <- df[df$DISTRICT %in% active_districts(), ]
    df
  })

  # ── Primary mode & locked state ──────────────────────────────────────────
  primary_mode <- reactive({ input$primary_filter %||% "all" })
  refine_locked <- reactive({ primary_mode() %in% c("health", "schools") })

  # Clear care-specific filters when switching to Health/Schools mode
  observeEvent(primary_mode(), {
    if (refine_locked()) {
      updateSelectInput(session, "filter_service",    selected = character(0))
      updateSelectInput(session, "filter_disability", selected = character(0))
      updateSelectInput(session, "filter_access",     selected = character(0))
      updateSelectInput(session, "filter_fee",        selected = "")
    }
    session$sendCustomMessage("refineLock", list(locked = refine_locked()))
  })

  # ── Summary counts ────────────────────────────────────────────────────────
  output$n_care   <- renderText(nrow(filtered_fw()))
  output$n_health <- renderText(nrow(filtered_health()))
  output$n_school <- renderText(nrow(filtered_edu()))
  output$lbl_sum_care   <- renderText(tr("summary_centers"))
  output$lbl_sum_health <- renderText(tr("summary_health"))
  output$lbl_sum_school <- renderText(tr("summary_schools"))

  # ── Base map (rendered once) ──────────────────────────────────────────────
  # Custom panes set z-order: schools (back) < health < care centers (front)
  output$map <- renderLeaflet({
    leaflet(options = leafletOptions(zoomControl = TRUE)) |>
      addMapPane("schoolPane", zIndex = 400) |>
      addMapPane("healthPane", zIndex = 410) |>
      addMapPane("carePane",   zIndex = 420) |>
      addProviderTiles("CartoDB.Positron",  group = "Light") |>
      addProviderTiles("Esri.WorldImagery", group = "Satellite") |>
      addLayersControl(
        baseGroups = c("Light", "Satellite"),
        options    = layersControlOptions(collapsed = TRUE)
      ) |>
      setView(lng = 39.35, lat = -6.15, zoom = 10)
  })

  # ── Care centre markers (SVG circle — colorblind safe) ───────────────────
  observe({
    df <- filtered_fw()
    popup_html <- if (nrow(df) == 0) character(0) else
      paste0("<strong>", htmltools::htmlEscape(df$facility_name), "</strong><br>",
             "<em>", df$facility_type_label, "</em><br>",
             normalize_district(df$district), " &middot; ", df$shehia)
    proxy <- leafletProxy("map") |> clearGroup("care")
    if (nrow(df) > 0) {
      proxy |> addMarkers(
        data         = df,
        lng          = ~gps.Longitude, lat = ~gps.Latitude,
        layerId      = ~paste0("care_", row_id),
        group        = "care",
        icon         = icon_care,
        popup        = popup_html,
        label        = ~facility_name,
        labelOptions = labelOptions(style = list("font-size" = "12px")),
        options      = markerOptions(pane = "carePane")
      )
    }
  })

  # ── Health markers (SVG square — colorblind safe) ─────────────────────────
  observeEvent(filtered_health(), {
    df <- filtered_health()
    popup_html <- if (nrow(df) == 0) character(0) else
      paste0("<strong>", htmltools::htmlEscape(df$NAME), "</strong><br>",
             df$TYPE, "<br>", df$DISTRICT, " &middot; ", df$REGION)
    proxy <- leafletProxy("map") |> clearGroup("health")
    if (nrow(df) > 0) {
      proxy |> addMarkers(
        data         = df,
        lng          = ~lng, lat = ~lat,
        layerId      = ~paste0("health_", code),
        group        = "health",
        icon         = icon_health,
        popup        = popup_html,
        label        = ~NAME,
        labelOptions = labelOptions(style = list("font-size" = "11px")),
        options      = markerOptions(pane = "healthPane")
      )
    }
  })

  # ── School markers (SVG triangle — colorblind safe) ───────────────────────
  observeEvent(filtered_edu(), {
    df <- filtered_edu()
    popup_html <- if (nrow(df) == 0) character(0) else
      paste0("<strong>", htmltools::htmlEscape(df$NAME), "</strong><br>",
             df$TYPE, "<br>", df$DISTRICT, " &middot; ", df$REGION)
    proxy <- leafletProxy("map") |> clearGroup("school")
    if (nrow(df) > 0) {
      proxy |> addMarkers(
        data         = df,
        lng          = ~lng, lat = ~lat,
        layerId      = ~paste0("school_", code),
        group        = "school",
        icon         = icon_school,
        popup        = popup_html,
        label        = ~NAME,
        labelOptions = labelOptions(style = list("font-size" = "11px")),
        options      = markerOptions(pane = "schoolPane")
      )
    }
  })

  # ── Layer visibility via Leaflet show/hideGroup (native, reliable) ───────
  observe({
    mode <- primary_mode()
    proxy <- leafletProxy("map")

    if (mode %in% c("all", "care"))    proxy |> showGroup("care")
    else                                proxy |> hideGroup("care")

    if (mode %in% c("all", "health"))  proxy |> showGroup("health")
    else                                proxy |> hideGroup("health")

    if (mode %in% c("all", "schools")) proxy |> showGroup("school")
    else                                proxy |> hideGroup("school")
  })

  # ── Dimming via CSS — instant, no redraw (only relevant in "all" mode) ───
  observe({
    mode <- primary_mode()
    dim_ocgs <- mode == "all" && any_care_filter_active()

    session$sendCustomMessage("ocgsDim",
      list(care_opacity   = 1,
           health_opacity = if (dim_ocgs) 0.25 else 1,
           school_opacity = if (dim_ocgs) 0.25 else 1))
  })

  # ── Click → detail panel ──────────────────────────────────────────────────
  selected_row <- reactiveVal(NULL)

  observeEvent(input$map_marker_click, {
    click_id <- input$map_marker_click$id
    if (is.null(click_id) || !startsWith(click_id, "care_")) return()
    row_id_val <- as.integer(sub("care_", "", click_id))
    row <- fieldwork[fieldwork$row_id == row_id_val, ]
    if (nrow(row) == 1) selected_row(row)
  })

  output$detail_ui <- renderUI({
    row <- selected_row()
    if (is.null(row)) {
      return(tags$div(class = "click-prompt",
        tags$p("\U0001F4CD", style = "font-size:2rem; margin-bottom:10px;"),
        tags$p(tr("click_prompt"))))
    }
    render_detail(row, lang(), svc_labels, disability_labels, access_labels, t)
  })

  observeEvent(selected_row(), {
    row <- selected_row()
    req(row)
    leafletProxy("map") |>
      setView(lng = row$gps.Longitude, lat = row$gps.Latitude, zoom = 14)
    # Move keyboard focus to detail panel heading
    session$sendCustomMessage("focusDetail", list())
  })

  # ── Escape key: clear selected facility ───────────────────────────────────
  observeEvent(input$escape_pressed, {
    selected_row(NULL)
  })

  # ── Clear all filters ─────────────────────────────────────────────────────
  observeEvent(input$clear_filters, {
    updateRadioButtons(session,  "primary_filter",    selected = "all")
    updateSelectInput(session,   "filter_district",   selected = character(0))
    updateSelectInput(session,   "filter_service",    selected = character(0))
    updateSelectInput(session,   "filter_disability", selected = character(0))
    updateSelectInput(session,   "filter_access",     selected = character(0))
    updateSelectInput(session,   "filter_fee",        selected = "")
  })

  # ── Data table — accessible alternative to the map ────────────────────────
  output$facilities_table <- DT::renderDataTable({
    l <- lang()

    care_rows <- if (nrow(filtered_fw()) > 0) {
      data.frame(
        Layer    = tr("layer_care"),
        Name     = filtered_fw()$facility_name,
        Type     = filtered_fw()$facility_type_label,
        District = normalize_district(filtered_fw()$district),
        Fee      = tools::toTitleCase(tolower(filtered_fw()$service_fee)),
        Contact  = ifelse(
          !is.na(filtered_fw()$phonenumber) & filtered_fw()$phonenumber != "",
          filtered_fw()$phonenumber, ""),
        stringsAsFactors = FALSE
      )
    } else data.frame()

    health_rows <- if (nrow(filtered_health()) > 0) {
      data.frame(
        Layer    = tr("layer_health"),
        Name     = filtered_health()$NAME,
        Type     = filtered_health()$TYPE,
        District = filtered_health()$DISTRICT,
        Fee      = "",
        Contact  = "",
        stringsAsFactors = FALSE
      )
    } else data.frame()

    school_rows <- if (nrow(filtered_edu()) > 0) {
      data.frame(
        Layer    = tr("layer_schools"),
        Name     = filtered_edu()$NAME,
        Type     = filtered_edu()$TYPE,
        District = filtered_edu()$DISTRICT,
        Fee      = "",
        Contact  = "",
        stringsAsFactors = FALSE
      )
    } else data.frame()

    combined <- dplyr::bind_rows(care_rows, health_rows, school_rows)
    if (nrow(combined) == 0) combined <- data.frame(
      Layer="", Name="", Type="", District="", Fee="", Contact="")

    names(combined) <- c(
      tr("lbl_layer_col"), tr("lbl_name_col"), tr("lbl_subtype_col"),
      tr("lbl_district_col"), tr("lbl_fee_col"), tr("lbl_contact_col"))

    DT::datatable(
      combined,
      rownames  = FALSE,
      filter    = "top",
      extensions = "Buttons",
      options   = list(
        pageLength  = 20,
        dom         = "Bfrtip",
        buttons     = list("csv", "excel"),
        language    = if (l == "sw")
          list(search = "Tafuta:", lengthMenu = "Onyesha _MENU_",
               info = "Inaonyesha _START_ hadi _END_ ya _TOTAL_",
               paginate = list(previous = "Iliyotangulia", `next` = "Inayofuata"))
          else list(),
        columnDefs  = list(list(className = "dt-left", targets = "_all"))
      ),
      class = "stripe hover"
    )
  }, server = TRUE)

  # ── District zoom: fit map bounds to all points in selected district(s) ───
  observeEvent(active_districts(), {
    sel <- active_districts()

    if (length(sel) == 0) {
      # No district selected — reset to full Zanzibar view
      leafletProxy("map") |> setView(lng = 39.35, lat = -6.15, zoom = 10)
      return()
    }

    # Collect all visible lngs/lats across the three layers
    fw_sub  <- filtered_fw()
    hlt_sub <- filtered_health()
    edu_sub <- filtered_edu()

    lngs <- c(fw_sub$gps.Longitude, hlt_sub$lng, edu_sub$lng)
    lats <- c(fw_sub$gps.Latitude,  hlt_sub$lat, edu_sub$lat)
    lngs <- lngs[!is.na(lngs)]; lats <- lats[!is.na(lats)]

    if (length(lngs) == 0) return()

    leafletProxy("map") |>
      fitBounds(
        lng1 = min(lngs), lat1 = min(lats),
        lng2 = max(lngs), lat2 = max(lats)
      )
  }, ignoreNULL = FALSE)

  # ── About / methodology tab ───────────────────────────────────────────────
  output$about_content <- renderUI({
    l <- lang()
    if (l == "sw") {
      # Swahili version — key sections translated, full rewrite pending colleague review
      tagList(
        tags$h4("1. Madhumuni"),
        tags$p("Dashibodi hii inatoa muhtasari wa kijiografia wa huduma muhimu zinazohusiana na watu wenye ulemavu huko Unguja, Zanzibar. Inalenga kusaidia", tags$strong("mipango inayotegemea ushahidi, uratibu, na upatikanaji wa taarifa"), ", kwa kuleta pamoja datasets tofauti katika jukwaa moja la kuona."),
        tags$h4("2. Muktadha"),
        tags$p("Dashibodi iliundwa ndani ya mfumo wa", tags$strong("Zana ya Georeferencing ya Utunzaji ya UNDP (CGT)"), ", chini ya programu ya pamoja ya kimataifa", tags$em('"Unpaid Care, Disability, and Gender Transformative Approach Programme"'), ", inayofadhiliwa na Global Disability Fund, na kutekelezwa katika nchi tano na mashirika sita ya UN (UNDP, UN Women, UNICEF, UNFPA, ILO, na OHCHR). CGT ilipigwa marubuni huko Unguja kushughulikia pengo la data muhimu: ukosefu wa taarifa zilizounganishwa na za kijiografia kuhusu huduma za utunzaji na msaada kwa watu wenye ulemavu."),
        tags$h4("3. Zana ya Georeferencing ya Utunzaji (CGT)"),
        tags$p("CGT ni zana ya taarifa za kijiografia iliyoundwa na UNDP-RBLAC, iliyoundwa ili: kupanga ramani ya usambazaji wa huduma za utunzaji na msaada; kuunganisha na mahitaji yanayowezekana; na kusaidia uchambuzi wa upatikanaji na mapengo ya eneo."),
        tags$p("Dashibodi hii inazingatia", tags$strong("huduma za utunzaji na msaada"), "kwa watu wenye ulemavu, wakati taarifa za mahitaji na upatikanaji zinahifadhiwa kwenye dashibodi ya ndani kwa watunga sera."),
        tags$h4("4. Vyanzo vya Data"),
        tags$p(tags$strong("4.1 Huduma maalum za utunzaji na msaada (kazi ya uwandani):"),
          "Watoa huduma 32 waliochorwa ramani kupitia ukusanyaji wa data msingi uliofanyika Februari 2026 kwa kutumia hojaji za dijiti za ODK. Data inajumuisha taarifa za kina kuhusu huduma zinazotolewa, aina za ulemavu unaohudumika, vipengele vya ufikiaji, wafanyakazi, ufadhili, na ulinganifu wa CRPD. Picha za tovuti zimejumuishwa."),
        tags$p(tags$strong("4.2 Huduma za afya (OCGS):"),
          "Kulingana na data ya kiutawala iliyotolewa na Ofisi ya Mkuu wa Mtakwimu wa Serikali (OCGS). Inashughulikia vituo vya afya katika Unguja."),
        tags$p(tags$strong("4.3 Huduma za elimu (OCGS):"),
          "Pia imetokana na rekodi za kiutawala za OCGS. Inajumuisha vituo vya elimu vinavyotoa huduma za elimu jumuishi au za kawaida."),
        tags$h4("5. Matumizi ya Dashibodi"),
        tags$p("Dashibodi inaruhusu watumiaji: kuona usambazaji wa huduma; kuchunguza aina za utunzaji; kutambua maeneo yenye upatikanaji mdogo wa huduma; na kusaidia majadiliano ya mipango na sera."),
        tags$h4("6. Tahadhari"),
        tags$ul(
          tags$li("Data ya huduma za utunzaji na msaada inashughulikia kisiwa cha Unguja pekee."),
          tags$li("Tabaka za vituo vya afya na shule zinatokana na rekodi za kiutawala za OCGS na hazionyeshi uwezo wa huduma zinazojumuisha ulemavu."),
          tags$li("Dashibodi hii inakusudiwa kama zana ya kusaidia maamuzi, si rejista kamili.")
        )
      )
    } else {
      tagList(
        tags$h4("1. Purpose"),
        tags$p("This dashboard provides a consolidated and georeferenced overview of key services relevant to persons with disabilities in Unguja, Zanzibar. It aims to support",
               tags$strong("evidence-based planning, coordination, and access to information"),
               ", by bringing together different datasets into a single visual platform."),

        tags$h4("2. Context"),
        tags$p("The dashboard was developed in the framework of",
               tags$strong("UNDP's Care Georeferencing Tool (CGT)"),
               ", under the joint global programme",
               tags$em('"Unpaid Care, Disability, and Gender Transformative Approach Programme"'),
               ", funded by the Global Disability Fund, and implemented in five countries by six UN agencies (UNDP, UN Women, UNICEF, UNFPA, ILO, and OHCHR). The programme promotes an intersectional approach to care system reforms, linking gender equality, disability inclusion, and economic justice."),
        tags$p("Within this context, the CGT was piloted in Unguja to address a key data gap: the lack of",
               tags$strong("integrated, georeferenced information on care and support services for persons with disabilities.")),

        tags$h4("3. The Care Georeferencing Tool (CGT)"),
        tags$p("The CGT is a geospatial information tool developed by UNDP-RBLAC, designed to: map the supply of care and support services; link it to the potential demand (population with disabilities); and support analysis of accessibility and territorial gaps."),
        tags$p("It integrates multiple data sources into harmonized georeferenced datasets and makes them available through interactive dashboards and maps, intended for both",
               tags$strong("institutional use"), "(planning, policy, coordination) and",
               tags$strong("public use"), "(access to information on services)."),
        tags$p("This particular dashboard focuses on",
               tags$strong("care and support services"),
               "for persons with disabilities, while demand and accessibility information are hosted in an internal dashboard tailored for policymakers."),

        tags$h4("4. Data Sources"),
        tags$p(tags$strong("4.1 Specialized care and support services (fieldwork).")),
        tags$p("32 service providers mapped through primary data collection carried out in February 2026 using structured digital questionnaires (ODK - Open Data Kit). Enumerators visited each facility and recorded detailed information on services offered, disability groups served, accessibility features, staffing, financing, and CRPD alignment. Site photos are included. This dataset provides",
               tags$strong("granular and qualitative information"),
               ", including services not captured in official records."),
        tags$p(tags$strong("4.2 Health services (OCGS).")),
        tags$p("Based on administrative data provided by the Office of the Chief Government Statistician (OCGS). Covers health facilities across Unguja, including those serving persons with disabilities. Ensures standardized territorial coverage."),
        tags$p(tags$strong("4.3 Education services (OCGS).")),
        tags$p("Also derived from OCGS administrative records. Includes education facilities offering inclusive or general education services. Enables analysis of access to basic services relevant to persons with disabilities."),

        tags$h4("5. Use of the Dashboard"),
        tags$p("The dashboard enables users to: visualize the distribution of services; explore types of care provision; identify areas with limited service availability; and support planning and policy discussions."),

        tags$h4("6. Caveats"),
        tags$ul(
          tags$li("Care and support service data covers Unguja island only."),
          tags$li("Health facility and school layers are drawn from OCGS administrative records and do not reflect disability-inclusive service capacity or certification status."),
          tags$li("This dashboard is intended as a decision-support tool, not a fully exhaustive registry.")
        ),
        tags$h4("Accessibility"),
        tags$p("This dashboard has been designed to meet WCAG 2.1 Level AA accessibility standards, including keyboard navigation, screen reader support, colorblind-safe map markers (circle / square / triangle), and a full data table alternative to the map."),
        tags$p(
          "Found a barrier? Please ",
          tags$a("report an accessibility issue",
                 href = "mailto:daniela.de.los.santos@undp.org?subject=Zanzibar%20PWD%20Dashboard%20accessibility",
                 rel = "noopener"),
          " and we will address it promptly."
        )
      )
    }
  })
}
