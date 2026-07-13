ui <- function(request) {
 page_sidebar(
  title = NULL,
  theme = bs_theme(
    version    = 5,
    primary    = "#0468B1",
    base_font  = font_google("Inter"),
    bootswatch = "lux"
  ),

  # ── Head ───────────────────────────────────────────────────────────────────
  tags$head(
    tags$meta(charset = "UTF-8"),
    tags$meta(name = "viewport",
              content = "width=device-width, initial-scale=1, viewport-fit=cover"),

    # ── JavaScript handlers ──────────────────────────────────────────────────
    tags$script(HTML("
      // Dim/show Leaflet panes via CSS — no redraw needed
      Shiny.addCustomMessageHandler('ocgsDim', function(msg) {
        var hp = document.querySelector('.leaflet-healthPane-pane');
        var sp = document.querySelector('.leaflet-schoolPane-pane');
        var cp = document.querySelector('.leaflet-carePane-pane');
        if (hp) hp.style.opacity = msg.health_opacity;
        if (sp) sp.style.opacity = msg.school_opacity;
        if (cp) cp.style.opacity = msg.care_opacity;
      });

      // Lock/unlock the refine block
      Shiny.addCustomMessageHandler('refineLock', function(msg) {
        var b = document.getElementById('refine_block');
        if (!b) return;
        if (msg.locked) b.classList.add('locked');
        else            b.classList.remove('locked');
      });

      // Update <html lang> when language toggles (helps screen readers)
      Shiny.addCustomMessageHandler('setLang', function(msg) {
        document.documentElement.lang = msg.lang;
      });

      // ── Mobile: auto-collapse the bslib sidebar so the map is the
      //    landing view. bslib's open=list() form only works on bslib >= 0.6,
      //    and this also handles screen-rotation / resize cases.
      function collapseSidebarIfMobile() {
        if (window.innerWidth > 768) return;
        var layouts = document.querySelectorAll('.bslib-sidebar-layout');
        layouts.forEach(function(layout) {
          // bslib marks the open state on the layout container; the toggle
          // button reverses it. Different bslib versions use different class
          // names, so try them in order.
          var isOpen = layout.classList.contains('sidebar-open') ||
                       layout.classList.contains('OPEN') ||
                       layout.getAttribute('data-bslib-sidebar-open') === 'open';
          if (isOpen) {
            var btn = layout.querySelector('.collapse-toggle');
            if (btn) btn.click();
          }
        });
      }
      // Run after Shiny finishes its initial render
      $(document).on('shiny:connected', function() {
        setTimeout(collapseSidebarIfMobile, 100);
      });
      // Re-apply if user rotates from desktop into mobile width
      var lastWidth = window.innerWidth;
      window.addEventListener('resize', function() {
        if (lastWidth > 768 && window.innerWidth <= 768) {
          collapseSidebarIfMobile();
        }
        lastWidth = window.innerWidth;
      });

      // Move keyboard focus to detail panel when a facility is selected
      Shiny.addCustomMessageHandler('focusDetail', function(msg) {
        var el = document.getElementById('detail_panel_heading');
        if (el) { el.focus(); }
      });

      // Escape key closes/clears detail panel
      document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
          Shiny.setInputValue('escape_pressed', Math.random());
        }
      });

      // ── Accessibility dropdown menu ─────────────────────────────────────
      function toggleA11yPanel(e) {
        if (e) e.stopPropagation();
        var p = document.getElementById('a11y_panel');
        var b = document.getElementById('a11y_toggle');
        if (!p) return;
        var open = p.style.display === 'block';
        p.style.display = open ? 'none' : 'block';
        if (b) b.setAttribute('aria-expanded', open ? 'false' : 'true');
      }
      function closeA11yPanel() {
        var p = document.getElementById('a11y_panel');
        var b = document.getElementById('a11y_toggle');
        if (p) p.style.display = 'none';
        if (b) b.setAttribute('aria-expanded', 'false');
      }
      // Click outside closes it
      document.addEventListener('click', function(e) {
        var p = document.getElementById('a11y_panel');
        var b = document.getElementById('a11y_toggle');
        if (!p || p.style.display !== 'block') return;
        if (p.contains(e.target) || (b && b.contains(e.target))) return;
        closeA11yPanel();
      });
      // Escape closes it
      document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') closeA11yPanel();
      });

      // Text size: user clicked one of A / A+ / A++ inside the panel
      function setTextSizeUI(size) {
        // Update button highlight inside the panel
        var btns = document.querySelectorAll('.a11y-size-btn');
        btns.forEach(function(b) {
          if (b.getAttribute('data-size') === size) b.classList.add('active');
          else                                       b.classList.remove('active');
        });
        // Tell Shiny
        Shiny.setInputValue('text_size_set', size);
      }

      // Apply text-size class on the page body (Normal / Large / X-Large)
      Shiny.addCustomMessageHandler('setTextSize', function(msg) {
        document.body.classList.remove('text-lg', 'text-xl');
        if (msg.size === 'lg')      document.body.classList.add('text-lg');
        else if (msg.size === 'xl') document.body.classList.add('text-xl');
      });

      // Toggle night-mode class on the page body
      Shiny.addCustomMessageHandler('setNightMode', function(msg) {
        if (msg.on) document.body.classList.add('night-mode');
        else        document.body.classList.remove('night-mode');
      });

      // Toggle high-contrast class on both map containers
      Shiny.addCustomMessageHandler('setHighContrast', function(msg) {
        ['map', 'demand_map'].forEach(function(id) {
          var el = document.getElementById(id);
          if (el) {
            if (msg.on) el.classList.add('hc-mode');
            else        el.classList.remove('hc-mode');
          }
        });
      });
    ")),

    tags$style(HTML("
      /* ── Skip-to-content link ───────────────────────────────────────── */
      .skip-link {
        position:absolute; top:-40px; left:0; z-index:9999;
        background:#0468B1; color:white; padding:8px 16px;
        font-weight:600; text-decoration:none; border-radius:0 0 4px 0;
        transition:top 0.1s;
      }
      .skip-link:focus { top:0; }

      /* ── Focus ring — visible for keyboard users ────────────────────── */
      :focus-visible {
        outline: 3px solid #0468B1 !important;
        outline-offset: 2px !important;
      }

      /* ── Reduce motion for vestibular/sensory sensitivity ───────────── */
      @media (prefers-reduced-motion: reduce) {
        *, *::before, *::after {
          animation-duration: 0.01ms !important;
          transition-duration: 0.01ms !important;
        }
      }

      /* ── Touch target minimum 44px ──────────────────────────────────── */
      .lang-btn, .hc-btn, .btn-clear-filters {
        min-height: 44px; min-width: 44px;
        display: inline-flex; align-items: center; justify-content: center;
      }

      /* ── High-contrast map mode ──────────────────────────────────────── */
      /* Invert the basemap TILE PANE ONLY: black background + bright labels.
         Hue-rotate counteracts the invert's color shift so water/land hues
         look correct. Markers live in custom panes — NOT inverted.          */
      #map.hc-mode .leaflet-tile-pane {
        filter: invert(1) hue-rotate(180deg) contrast(1.15) brightness(1.05);
      }
      /* Make markers pop with a bright drop-shadow on the dark background */
      #map.hc-mode .leaflet-carePane-pane   img,
      #map.hc-mode .leaflet-healthPane-pane img,
      #map.hc-mode .leaflet-schoolPane-pane img {
        filter: saturate(1.3) contrast(1.15)
                drop-shadow(0 0 2px white)
                drop-shadow(0 0 4px rgba(255,255,255,0.7));
        transition: filter 0.2s;
      }
      /* Dark background for the map container itself (visible behind tiles
         while they load, plus around any edge gutter) */
      #map.hc-mode { background: #1a1a1a; }
      /* Leaflet attribution: invert so it stays readable on dark */
      #map.hc-mode .leaflet-control-attribution {
        background: rgba(0,0,0,0.7) !important;
        color: #eee !important;
      }
      #map.hc-mode .leaflet-control-attribution a {
        color: #4db8ff !important;
      }
      /* Layers control: invert so it stays readable */
      #map.hc-mode .leaflet-control-layers {
        background: #222 !important;
        color: #fff !important;
        border-color: #555 !important;
      }
      #map.hc-mode .leaflet-control-zoom a {
        background: #222 !important;
        color: #fff !important;
        border-color: #555 !important;
      }
      /* ── High-contrast: demand map (same rules, different ID) ──────────── */
      #demand_map.hc-mode .leaflet-tile-pane {
        filter: invert(1) hue-rotate(180deg) contrast(1.15) brightness(1.05);
      }
      #demand_map.hc-mode .leaflet-demandPane-pane {
        filter: saturate(1.4) contrast(1.2)
                drop-shadow(0 0 3px rgba(255,255,255,0.6));
      }
      #demand_map.hc-mode { background: #1a1a1a; }
      #demand_map.hc-mode .leaflet-control-attribution {
        background: rgba(0,0,0,0.7) !important; color: #eee !important;
      }
      #demand_map.hc-mode .leaflet-control-attribution a { color: #4db8ff !important; }
      #demand_map.hc-mode .leaflet-control-layers {
        background: #222 !important; color: #fff !important; border-color: #555 !important;
      }
      #demand_map.hc-mode .leaflet-control-zoom a {
        background: #222 !important; color: #fff !important; border-color: #555 !important;
      }

      /* HC button active state */
      .hc-btn.active {
        background: white !important;
        color: #0468B1 !important;
        font-weight: 700;
      }

      /* ── Accessibility dropdown menu ─────────────────────────────────── */
      .a11y-btn {
        display: inline-flex; align-items: center;
        gap: 4px; padding: 6px 12px;
      }
      .a11y-panel {
        position: absolute; top: calc(100% + 8px); right: 0;
        background: white; color: #222;
        border-radius: 10px;
        box-shadow: 0 8px 24px rgba(0,0,0,0.20);
        padding: 14px 16px 12px 16px;
        min-width: 240px; max-width: 280px;
        z-index: 2000;
      }
      .a11y-panel-header {
        display: flex; align-items: center; justify-content: space-between;
        border-bottom: 1px solid #eee;
        padding-bottom: 8px; margin-bottom: 12px;
        color: #0468B1; font-size: 0.95rem;
      }
      .a11y-close {
        background: none; border: none; cursor: pointer;
        color: #666; font-size: 1.4rem; line-height: 1;
        padding: 0 6px; border-radius: 4px;
      }
      .a11y-close:hover { background: #f0f0f0; color: #000; }
      .a11y-section { margin-bottom: 12px; }
      .a11y-section-label {
        display: block; font-size: 0.78rem; font-weight: 600;
        color: #444; margin-bottom: 6px;
      }
      .a11y-size-group {
        display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px;
      }
      .a11y-size-btn {
        background: #f4f6f8; border: 1.5px solid #e0e0e0;
        color: #333; border-radius: 6px;
        padding: 10px 8px; cursor: pointer;
        font-weight: 700; min-height: 44px;
        transition: all 0.15s;
      }
      .a11y-size-btn:hover { background: #e8ecf0; border-color: #0468B1; }
      .a11y-size-btn.active {
        background: #0468B1; color: white; border-color: #0468B1;
      }
      .a11y-check-row {
        display: flex; align-items: center; gap: 10px;
        padding: 10px 8px; border: 1px solid #e0e0e0;
        border-radius: 6px; cursor: pointer;
        font-size: 0.88rem; margin-bottom: 8px;
        transition: background 0.15s;
      }
      .a11y-check-row:hover { background: #f4f6f8; }
      .a11y-check-row input[type='checkbox'] {
        width: 18px; height: 18px; cursor: pointer;
        accent-color: #0468B1;
      }
      /* Night-mode overrides for the panel itself */
      body.night-mode .a11y-panel { background: #1e2a45; color: #d0d0d0; }
      body.night-mode .a11y-panel-header { color: #90b4e8; border-bottom-color: #333; }
      body.night-mode .a11y-close { color: #aaa; }
      body.night-mode .a11y-close:hover { background: #2a3550; color: #fff; }
      body.night-mode .a11y-section-label { color: #bbb; }
      body.night-mode .a11y-size-btn { background: #252f47; border-color: #444; color: #d0d0d0; }
      body.night-mode .a11y-size-btn:hover { background: #2a3550; }
      body.night-mode .a11y-check-row { border-color: #444; }
      body.night-mode .a11y-check-row:hover { background: #2a3550; }

      /* ── Text size scaling ────────────────────────────────────────────
         Bumps the root font-size; every rem/em-based element scales.
         Leaflet map controls use px on purpose (UI chrome) and are
         unaffected — that's the standard convention.                */
      body.text-lg { font-size: 115%; }
      body.text-xl { font-size: 130%; }

      /* Text-size button active state (matches HC / night pattern) */
      .text-size-btn.active {
        background: white !important;
        color: #0468B1 !important;
        font-weight: 700;
      }

      /* Night mode button active state */
      .night-btn.active {
        background: #ffd700 !important;
        color: #1a1a2e !important;
        font-weight: 700;
        border-color: #ffd700 !important;
      }

      /* ── Night mode ─────────────────────────────────────────────────── */
      body.night-mode { background: #1a1a2e !important; color: #d0d0d0 !important; }
      body.night-mode .sidebar { background: #161b2e !important; color: #d0d0d0 !important; }
      body.night-mode .card,
      body.night-mode .bslib-card { background: #1e2a45 !important; color: #d0d0d0 !important; }
      body.night-mode .summary-card { background: #1e2a45 !important; }
      body.night-mode .summary-card .sm-label { color: #aaa !important; }
      body.night-mode .nav-tabs { border-color: #444 !important; }
      body.night-mode .nav-tabs .nav-link { color: #aaa !important; background: transparent !important; }
      body.night-mode .nav-tabs .nav-link.active { background: #1e2a45 !important; color: #fff !important; border-color: #444 #444 #1e2a45 !important; }
      body.night-mode .tab-content { background: #1a1a2e !important; }
      body.night-mode .bslib-page-fill,
      body.night-mode .bslib-gap-item { background: #1a1a2e !important; }
      body.night-mode .form-control,
      body.night-mode .form-select { background: #1e2a45 !important; color: #d0d0d0 !important; border-color: #444 !important; }
      body.night-mode .form-check-label,
      body.night-mode label { color: #d0d0d0 !important; }
      body.night-mode .info-label { color: #aaa !important; }
      body.night-mode .info-value { color: #d0d0d0 !important; }
      body.night-mode .info-row { border-bottom-color: #333 !important; }
      body.night-mode .click-prompt,
      body.night-mode .filter-note,
      body.night-mode .table-intro { color: #aaa !important; }
      body.night-mode .legend-item { color: #d0d0d0 !important; }
      body.night-mode hr { border-color: #444 !important; }
      body.night-mode .btn-clear-filters { color: #d0d0d0 !important; border-color: #666 !important; background: none; }
      body.night-mode .btn-clear-filters:hover { background: #2a3550 !important; }
      body.night-mode .card-text { color: #bbb !important; }
      body.night-mode .card-title { color: #90b4e8 !important; }
      body.night-mode h4, body.night-mode h5 { color: #90b4e8 !important; }
      body.night-mode p, body.night-mode li { color: #c8c8c8 !important; }
      body.night-mode .about-body h4 { color: #90b4e8 !important; }
      /* DT table */
      body.night-mode .dataTables_wrapper,
      body.night-mode .dataTables_filter label,
      body.night-mode .dataTables_length label,
      body.night-mode .dataTables_info { color: #d0d0d0 !important; }
      body.night-mode table.dataTable thead th,
      body.night-mode table.dataTable thead td { background: #1e2a45 !important; color: #d0d0d0 !important; border-color: #444 !important; }
      body.night-mode table.dataTable.stripe tbody tr.odd { background: #1e2a45 !important; }
      body.night-mode table.dataTable tbody tr { color: #d0d0d0 !important; background: #252f47 !important; }
      body.night-mode table.dataTable tbody tr:hover { background: #2a3a58 !important; }
      body.night-mode .paginate_button { color: #aaa !important; }

      body { background: #f4f6f8; }

      .app-header {
        background: linear-gradient(135deg, #0468B1, #023e6e);
        color: white; padding: 10px 20px;
        display: flex; align-items: center;
        justify-content: space-between;
        box-shadow: 0 2px 6px rgba(0,0,0,0.2); gap: 16px;
      }
      .app-header-left { display:flex; align-items:center; gap:14px; flex:1; min-width:0; }
      .app-header h1 { margin:0; font-size:1.45rem; font-weight:700;
                       color:white; line-height:1.2; }
      .app-header p  { margin:0; font-size:0.85rem; opacity:0.80; color:white; }
      .lang-btn {
        background:rgba(255,255,255,0.2); border:1px solid rgba(255,255,255,0.5);
        color:white; border-radius:4px; padding:6px 14px; cursor:pointer;
        font-size:0.82rem; white-space:nowrap; flex-shrink:0;
      }
      .lang-btn:hover  { background:rgba(255,255,255,0.35); }

      /* ── Colorblind-safe legend shapes ──────────────────────────────── */
      .legend-item { display:flex; align-items:center; gap:7px;
                     font-size:0.8rem; margin-bottom:3px; }
      .legend-shape { flex-shrink:0; }

      /* ── Summary bar ────────────────────────────────────────────────── */
      .summary-bar { display:flex; gap:10px; padding:8px 0; flex-wrap:wrap; }
      .summary-card {
        background:white; border-radius:8px; padding:8px 14px;
        flex:1; min-width:100px; text-align:center;
        box-shadow:0 1px 3px rgba(0,0,0,0.08);
        border-top:3px solid #D55E00;
      }
      .summary-card.health { border-top-color:#0072B2; }
      .summary-card.school { border-top-color:#CC79A7; }
      .summary-card .big-num { font-size:1.6rem; font-weight:700;
                                color:#D55E00; line-height:1; }
      .summary-card.health .big-num { color:#0072B2; }
      .summary-card.school .big-num { color:#CC79A7; }
      .summary-card .sm-label { font-size:0.72rem; color:#555; margin-top:2px; }

      .map-container { border-radius:8px; overflow:hidden;
                       box-shadow:0 2px 8px rgba(0,0,0,0.12); }

      /* ── Detail panel ───────────────────────────────────────────────── */
      .detail-header { padding:4px 0 0 0; }
      .detail-body   { padding:6px 2px; }
      .info-row { display:flex; gap:8px; padding:5px 0;
                  border-bottom:1px solid #f0f0f0; align-items:flex-start; }
      .info-label { font-size:0.78rem; font-weight:600; color:#555;
                    min-width:160px; flex-shrink:0; padding-top:2px; }
      .info-value { font-size:0.82rem; color:#222; flex:1; }
      .info-value a { color:#0468B1; }
      /* Bullet lists inside info-row inherit Bootstrap's default 1rem —
         force them to match the surrounding info-value text size */
      .info-row ul, .info-row ol { margin:0; padding-left:1.2em; flex:1; }
      .info-row ul li, .info-row ol li { font-size:0.82rem; color:#222; line-height:1.45; }

      /* ── Photos ─────────────────────────────────────────────────────── */
      .photo-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(150px,1fr));
                    gap:10px; padding:8px 0; }
      .photo-card img { cursor:pointer; transition:transform 0.15s; }
      .photo-card:focus img, .photo-card img:hover { transform:scale(1.03); }
      .photo-card:focus { outline:3px solid #0468B1; border-radius:6px; }

      /* ── Filter note — WCAG AA contrast (#696969 on white = 4.54:1) ── */
      .filter-note { font-size:0.72rem; color:#696969; font-style:italic;
                     margin:-6px 0 8px 0; line-height:1.35; }

      /* ── Refine block lock ──────────────────────────────────────────── */
      #refine_block.locked { opacity:0.38; pointer-events:none;
                              transition:opacity 0.15s; }
      #refine_block { transition:opacity 0.15s; }

      /* ── Clear filters button ───────────────────────────────────────── */
      .btn-clear-filters {
        width:100%; margin-top:8px; font-size:0.8rem;
        background:none; border:1px solid #696969; color:#333;
        border-radius:4px; padding:6px 10px; cursor:pointer;
      }
      .btn-clear-filters:hover { background:#f0f0f0; }

      .click-prompt { color:#555; font-size:0.88rem; text-align:center;
                      padding:40px 20px; }

      #detail_panel { height:calc(100vh - 200px); overflow-y:auto; }

      /* ── About tab ──────────────────────────────────────────────────── */
      .about-body { max-width:780px; line-height:1.7; font-size:0.9rem; }
      .about-body h4 { color:#0468B1; margin-top:1.4rem; margin-bottom:0.4rem; }
      .about-body ul { padding-left:1.4em; }

      /* ── Data table tab ─────────────────────────────────────────────── */
      .table-intro { font-size:0.88rem; color:#555; margin-bottom:12px; }

      .sidebar { background:white; }

      /* ─────────────────────────────────────────────────────────────────
         RESPONSIVE / MOBILE OPTIMIZATIONS  (≤ 768px)
         ───────────────────────────────────────────────────────────────── */
      @media (max-width: 768px) {
        /* Header: stack title + compact buttons, smaller font */
        .app-header {
          padding: 8px 12px !important;
          flex-wrap: wrap;
          gap: 8px;
        }
        .app-header-left { flex: 1 1 100%; min-width: 0; }
        .app-header h1 { font-size: 1.1rem !important; line-height: 1.15; }
        .app-header p  { font-size: 0.75rem !important; }

        /* Header button row — wrap & shrink so all fit */
        .app-header > div:last-child {
          flex-wrap: wrap;
          gap: 6px !important;
          width: 100%;
          justify-content: flex-end;
        }
        .lang-btn {
          padding: 6px 10px !important;
          font-size: 0.72rem !important;
          min-height: 40px;
        }

        /* Map: fixed sensible height instead of viewport math (which fights
           with the on-screen keyboard / mobile browser chrome bar) */
        .map-container .leaflet,
        .map-container .leaflet-container {
          height: 60vh !important;
          min-height: 360px;
        }

        /* Detail panel: don't lock to viewport-minus, let it flow naturally */
        #detail_panel {
          height: auto !important;
          max-height: none !important;
          margin-top: 16px;
          padding: 0 4px;
        }
        .click-prompt { padding: 24px 12px; font-size: 0.85rem; }

        /* Detail info rows: stack label above value (no fixed-width label) */
        .info-row { flex-direction: column; gap: 2px; padding: 6px 0; }
        .info-label { min-width: 0; font-size: 0.75rem; }
        .info-value { font-size: 0.88rem; }
        .info-row ul li, .info-row ol li { font-size: 0.88rem; }

        /* Summary cards: 3 across on phones, tighter */
        .summary-bar { gap: 6px; padding: 6px 0; }
        .summary-card { padding: 6px 8px; min-width: 0; }
        .summary-card .big-num { font-size: 1.3rem; }
        .summary-card .sm-label { font-size: 0.65rem; }

        /* Tabs: smaller, allow horizontal scroll instead of squish */
        .nav-tabs {
          flex-wrap: nowrap;
          overflow-x: auto;
          -webkit-overflow-scrolling: touch;
        }
        .nav-tabs .nav-link {
          white-space: nowrap;
          font-size: 0.82rem;
          padding: 8px 10px;
        }

        /* Photo grid: 2 columns on phones */
        .photo-grid {
          grid-template-columns: repeat(2, 1fr) !important;
          gap: 6px;
        }

        /* About + Demand tab readability */
        .about-body { font-size: 0.88rem; line-height: 1.55; }
        .about-body h4 { font-size: 1rem; margin-top: 1rem; }

        /* Demand menu cards: full width on phones */
        .card-title { font-size: 1.05rem; }

        /* Data table: smaller font + horizontal scroll */
        .dataTables_wrapper { font-size: 0.78rem; overflow-x: auto; }
        .table-intro { font-size: 0.82rem; }

        /* DT buttons stacked + clickable */
        .dt-buttons .btn { padding: 6px 10px; font-size: 0.78rem; }

        /* Login card: full width on phones */
        .card.shadow-sm { margin: 12px !important; }

        /* Sidebar (bslib handles collapse already, but tighten spacing) */
        .sidebar { padding: 8px !important; }
      }

      /* Extra-small phones (≤ 380px) */
      @media (max-width: 380px) {
        .app-header h1 { font-size: 1rem !important; }
        .summary-card .big-num { font-size: 1.15rem; }
        .lang-btn { padding: 5px 8px !important; font-size: 0.68rem !important; }
      }

      /* Prevent iOS Safari from zooming into form inputs (<16px triggers it) */
      @media (max-width: 768px) {
        input.form-control, select.form-control, textarea.form-control,
        input[type='text'], input[type='password'], input[type='email'] {
          font-size: 16px !important;
        }
      }
    "))
  ),

  # ── Skip-to-content (visually hidden until focused) ──────────────────────
  tags$a(class = "skip-link", href = "#main-content",
         textOutput("lbl_skip", inline = TRUE)),

  # ── Header ───────────────────────────────────────────────────────────────
  tags$div(
    class = "app-header",
    role  = "banner",
    style = "grid-column:1/-1; margin:-1rem -1rem 0.5rem -1rem;",
    tags$div(
      class = "app-header-left",
      tags$div(
        tags$h1(textOutput("hdr_title", inline = TRUE)),
        tags$p(textOutput("hdr_subtitle", inline = TRUE))
      )
    ),
    tags$div(
      style = "display:flex; gap:8px; flex-shrink:0; align-items:center;",
      # Logged-in indicator + logout (hidden when not authenticated)
      uiOutput("auth_header_ui"),
      # ── Accessibility menu (dropdown button) ────────────────────────────
      tags$div(
        class = "a11y-wrap",
        style = "position:relative;",
        tags$button(
          id             = "a11y_toggle",
          class          = "lang-btn a11y-btn",
          onclick        = "toggleA11yPanel(event)",
          `aria-label`   = "Accessibility menu",
          `aria-haspopup`= "true",
          `aria-expanded`= "false",
          # Person / accessibility icon (SVG, inherits currentColor)
          HTML('<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" style="vertical-align:middle; margin-right:6px;" aria-hidden="true"><circle cx="12" cy="4" r="2"/><path d="M19 7h-5v14h-2v-6h-2v6H8V7H3v2h4v12a1 1 0 0 0 2 0v-6h2v6a1 1 0 0 0 2 0V9h4V7z"/></svg>'),
          tags$span(textOutput("a11y_menu_label", inline = TRUE))
        ),
        tags$div(
          id    = "a11y_panel",
          class = "a11y-panel",
          role  = "dialog",
          `aria-label` = "Accessibility settings",
          style = "display:none;",
          # Header
          tags$div(class = "a11y-panel-header",
            tags$strong(textOutput("a11y_menu_label2", inline = TRUE)),
            tags$button(
              class          = "a11y-close",
              onclick        = "closeA11yPanel()",
              `aria-label`   = "Close",
              HTML("&times;")
            )
          ),
          # Text size row
          tags$div(class = "a11y-section",
            tags$label(class = "a11y-section-label",
                       textOutput("a11y_lbl_size", inline = TRUE)),
            tags$div(class = "a11y-size-group", role = "group",
              tags$button(class = "a11y-size-btn active",
                          `data-size` = "normal",
                          onclick = "setTextSizeUI('normal')",
                          "A"),
              tags$button(class = "a11y-size-btn",
                          `data-size` = "lg",
                          onclick = "setTextSizeUI('lg')",
                          style = "font-size:1.1em;",
                          "A+"),
              tags$button(class = "a11y-size-btn",
                          `data-size` = "xl",
                          onclick = "setTextSizeUI('xl')",
                          style = "font-size:1.25em;",
                          "A++")
            )
          ),
          # High contrast row
          tags$label(class = "a11y-check-row",
            tags$input(type = "checkbox", id = "a11y_hc",
                       onchange = "Shiny.setInputValue('hc_check', this.checked)"),
            tags$span(textOutput("a11y_lbl_hc", inline = TRUE))
          ),
          # Night mode row
          tags$label(class = "a11y-check-row",
            tags$input(type = "checkbox", id = "a11y_night",
                       onchange = "Shiny.setInputValue('night_check', this.checked)"),
            tags$span(textOutput("a11y_lbl_night", inline = TRUE))
          )
        )
      ),
      tags$button(
        id           = "lang_toggle",
        class        = "lang-btn",
        onclick      = "Shiny.setInputValue('lang_btn', Math.random())",
        `aria-label` = "Switch language / Badilisha lugha",
        textOutput("lang_btn_label", inline = TRUE)
      )
    )
  ),

  # ── Sidebar ──────────────────────────────────────────────────────────────
  sidebar = sidebar(
    width = 260,
    # Desktop: open on load. Mobile: collapsed — map shows first,
    # users tap the filter icon to slide the sidebar in.
    open  = list(desktop = "open", mobile = "closed"),

    # UNDP logo
    tags$div(
      style = "padding:12px 4px 14px 4px; border-bottom:1px solid #e0e0e0; margin-bottom:8px;",
      tags$img(src   = "undp_logo_official.png",
               alt   = "United Nations Development Programme",
               style = "width:140px; height:auto; display:block;")
    ),

    # Primary question
    tags$div(
      style = "font-weight:600; font-size:0.85rem; color:#333; margin-bottom:6px;",
      textOutput("lbl_primary_question", inline = TRUE)
    ),
    radioButtons("primary_filter", label = NULL,
                 choices = c("all" = "all"), selected = "all"),

    tags$hr(style = "margin:10px 0;"),

    # District
    selectInput("filter_district",
                label   = textOutput("lbl_district", inline = TRUE),
                choices = NULL, multiple = TRUE),

    # Care-specific refinements
    tags$div(
      id = "refine_block",
      tags$div(
        style = "font-weight:600; font-size:0.82rem; color:#0468B1;
                 padding-top:4px; margin-bottom:4px;",
        textOutput("lbl_refine_heading", inline = TRUE)
      ),
      selectInput("filter_service",
                  label   = textOutput("lbl_service", inline = TRUE),
                  choices = NULL, multiple = TRUE),
      selectInput("filter_disability",
                  label   = textOutput("lbl_disability", inline = TRUE),
                  choices = NULL, multiple = TRUE),
      selectInput("filter_access",
                  label   = textOutput("lbl_access", inline = TRUE),
                  choices = NULL, multiple = TRUE),
      selectInput("filter_fee",
                  label   = textOutput("lbl_fee", inline = TRUE),
                  choices = NULL)
    ),

    # Clear all filters
    tags$button(
      class   = "btn-clear-filters",
      onclick = "Shiny.setInputValue('clear_filters', Math.random())",
      textOutput("lbl_clear", inline = TRUE)
    ),

    tags$hr(style = "margin:10px 0;"),

    # Colorblind-safe legend: shape + colour
    tags$div(
      role = "img", `aria-label` = "Map legend",
      tags$div(class = "legend-item",
        tags$svg(class="legend-shape", width="18", height="18",
          `aria-hidden`="true", xmlns="http://www.w3.org/2000/svg",
          tags$circle(cx="9", cy="9", r="8",
                      fill=ICON_CARE_COLOR, stroke="white", `stroke-width`="2")),
        textOutput("legend_care", inline = TRUE)
      ),
      tags$div(class = "legend-item",
        tags$svg(class="legend-shape", width="14", height="14",
          `aria-hidden`="true", xmlns="http://www.w3.org/2000/svg",
          tags$rect(x="1", y="1", width="12", height="12", rx="2",
                    fill=ICON_HEALTH_COLOR, stroke="white", `stroke-width`="2")),
        textOutput("legend_health", inline = TRUE)
      ),
      tags$div(class = "legend-item",
        tags$svg(class="legend-shape", width="14", height="16",
          `aria-hidden`="true", xmlns="http://www.w3.org/2000/svg",
          tags$polygon(points="7,1 13,15 1,15",
                       fill=ICON_SCHOOL_COLOR, stroke="white", `stroke-width`="2")),
        textOutput("legend_school", inline = TRUE)
      )
    )
  ),

  # ── Main content ─────────────────────────────────────────────────────────
  tags$div(id = "main-content", role = "main",  # skip-link target

    navset_card_tab(
      id = "main_tabs",

      # ── Map tab ────────────────────────────────────────────────────────────
      nav_panel(
        title = uiOutput("tab_map_label", inline = TRUE),
        layout_columns(
          col_widths = breakpoints(xs = c(12, 12), md = c(7, 5)),
          fill = FALSE,

          # Left: summary + map
          tags$div(
            tags$div(
              class = "summary-bar", role = "region",
              `aria-label` = "Summary counts",
              tags$div(class = "summary-card",
                tags$div(textOutput("n_care"),        class = "big-num"),
                tags$div(textOutput("lbl_sum_care"),  class = "sm-label")),
              tags$div(class = "summary-card health",
                tags$div(textOutput("n_health"),      class = "big-num"),
                tags$div(textOutput("lbl_sum_health"),class = "sm-label")),
              tags$div(class = "summary-card school",
                tags$div(textOutput("n_school"),      class = "big-num"),
                tags$div(textOutput("lbl_sum_school"),class = "sm-label"))
            ),
            tags$div(
              class = "map-container",
              # Screen-reader description of map
              tags$p(id = "map-desc", class = "visually-hidden",
                     style = "position:absolute; left:-9999px;",
                     textOutput("lbl_map_desc", inline = TRUE)),
              leafletOutput("map", height = "calc(100vh - 230px)")
            )
          ),

          # Right: detail panel
          tags$div(
            id             = "detail_panel",
            role           = "region",
            `aria-label`   = "Facility details",
            `aria-live`    = "polite",
            uiOutput("detail_ui")
          )
        )
      ),

      # ── Data table tab ─────────────────────────────────────────────────────
      nav_panel(
        title = uiOutput("tab_table_label", inline = TRUE),
        tags$div(
          class = "p-3",
          tags$p(class = "table-intro",
                 textOutput("lbl_table_intro", inline = TRUE)),
          DT::dataTableOutput("facilities_table")
        )
      ),

      # ── Demand & Accessibility tab (private) ───────────────────────────────
      nav_panel(
        title = uiOutput("tab_demand_label", inline = TRUE),
        tags$div(
          style = "padding:0;",
          uiOutput("demand_tab_ui")
        )
      ),

      # ── About tab ──────────────────────────────────────────────────────────
      nav_panel(
        title = uiOutput("tab_about_label", inline = TRUE),
        tags$div(
          class = "about-body p-3",
          uiOutput("about_content")
        )
      )
    )
  )
 )
}
