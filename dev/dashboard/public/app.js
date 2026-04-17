(function () {
    var themeKey = "znuny-dashboard-theme";
    var storageView = "znuny-dashboard-view";
    var storageSortKey = "znuny-dashboard-sort";
    var storageSortDir = "znuny-dashboard-sort-dir";

    var lastData = null;

    function getStoredTheme() {
        try {
            return localStorage.getItem(themeKey);
        } catch (e) {
            return null;
        }
    }

    function applyTheme(mode) {
        document.body.classList.remove("theme-light", "theme-dark");
        if (mode === "light") {
            document.body.classList.add("theme-light");
        } else if (mode === "dark") {
            document.body.classList.add("theme-dark");
        }
    }

    var themePreferenceListenerBound = false;

    function syncThemeSwitch() {
        var input = document.getElementById("theme-toggle");
        if (!input) {
            return;
        }
        var prefersDark = window.matchMedia("(prefers-color-scheme: dark)")
            .matches;
        var hasLight = document.body.classList.contains("theme-light");
        var hasDark = document.body.classList.contains("theme-dark");
        var isDark;
        if (hasDark) {
            isDark = true;
        } else if (hasLight) {
            isDark = false;
        } else {
            isDark = prefersDark;
        }
        input.checked = isDark;
    }

    function initTheme() {
        var stored = getStoredTheme();
        if (stored === "light" || stored === "dark") {
            applyTheme(stored);
        } else {
            applyTheme("");
        }
        syncThemeSwitch();
        if (!themePreferenceListenerBound) {
            themePreferenceListenerBound = true;
            var mq = window.matchMedia("(prefers-color-scheme: dark)");
            var onPrefChange = function () {
                var s = getStoredTheme();
                if (s !== "light" && s !== "dark") {
                    syncThemeSwitch();
                }
            };
            if (mq.addEventListener) {
                mq.addEventListener("change", onPrefChange);
            } else {
                mq.addListener(onPrefChange);
            }
        }
    }

    function onThemeSwitchChange() {
        var input = document.getElementById("theme-toggle");
        var mode = input.checked ? "dark" : "light";
        try {
            localStorage.setItem(themeKey, mode);
        } catch (e) {}
        applyTheme(mode);
    }

    function escapeHtml(s) {
        return String(s)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;");
    }

    function getStored(key, allowed, fallback) {
        try {
            var v = localStorage.getItem(key);
            if (allowed.indexOf(v) !== -1) {
                return v;
            }
        } catch (e) {}
        return fallback;
    }

    function setStored(key, value) {
        try {
            localStorage.setItem(key, value);
        } catch (e) {}
    }

    function healthPill(health, running) {
        var h = (health || "").toLowerCase();
        var cls = "neutral";
        if (!running) {
            cls = "warn";
        } else if (h === "healthy") {
            cls = "ok";
        } else if (h === "unhealthy") {
            cls = "bad";
        } else if (h === "stopped") {
            cls = "warn";
        } else {
            cls = "ok";
        }
        var label = running ? health || "running" : "stopped";
        return (
            '<span class="pill ' +
            cls +
            '">' +
            escapeHtml(label) +
            "</span>"
        );
    }

    /** Status dot: green (ok) / yellow (warning: instance or DB down, degraded) / red (unhealthy) */
    function statusDotClass(row) {
        var inst = row.instance || {};
        var db = row.database || {};
        if (!inst.running) {
            return "warning";
        }
        var h = (inst.health || "").toLowerCase();
        if (h === "unhealthy") {
            return "error";
        }
        if (h === "stopped") {
            return "warning";
        }
        if (db.container && !db.running) {
            return "warning";
        }
        if (h === "healthy" || h === "no-health-check" || !h) {
            return "";
        }
        return "warning";
    }

    /** Numeric rank for status sort: lower = worse / less healthy */
    function statusRank(row) {
        var inst = row.instance || {};
        var db = row.database || {};
        if (!inst.running) {
            return 0;
        }
        var h = (inst.health || "").toLowerCase();
        if (h === "unhealthy") {
            return 1;
        }
        if (db.container && !db.running) {
            return 2;
        }
        if (h === "stopped") {
            return 0;
        }
        if (h === "healthy") {
            return 4;
        }
        if (h === "no-health-check" || !h) {
            return 3;
        }
        return 2;
    }

    /** Parse Docker / ISO time (RFC3339, optional nano fraction). */
    function dockerTimeMs(s) {
        if (!s) {
            return null;
        }
        s = String(s).trim();
        if (!s) {
            return null;
        }
        var t = Date.parse(s);
        if (isNaN(t)) {
            var relaxed = s.replace(/(\.\d{3})\d+/, "$1");
            if (relaxed !== s) {
                t = Date.parse(relaxed);
            }
        }
        if (isNaN(t)) {
            return null;
        }
        return t;
    }

    function isDockerZeroStartedAt(s) {
        return String(s || "").indexOf("0001-01-01") === 0;
    }

    /** Sort / display: prefer real start time, else container Created (API: instance.created_at). */
    function effectiveCreatedMs(inst) {
        var st = inst.started_at;
        if (st && !isDockerZeroStartedAt(st)) {
            var ms = dockerTimeMs(st);
            if (ms !== null) {
                return ms;
            }
        }
        return dockerTimeMs(inst.created_at);
    }

    function formatCreated(inst) {
        var st = inst.started_at;
        if (st && !isDockerZeroStartedAt(st)) {
            var d = new Date(String(st).trim());
            if (!isNaN(d.getTime())) {
                return escapeHtml(d.toLocaleString());
            }
        }
        if (inst.created_at) {
            return formatStartedAt(inst.created_at);
        }
        return formatStartedAt(st || "");
    }

    function formatStartedAt(s) {
        if (!s) {
            return "—";
        }
        var d = new Date(s);
        if (isNaN(d.getTime())) {
            return escapeHtml(String(s));
        }
        return escapeHtml(d.toLocaleString());
    }

    function detailRow(label, valueHtml) {
        return (
            "<tr>" +
            '<th scope="row" class="detail-label">' +
            escapeHtml(label) +
            "</th>" +
            '<td class="detail-value">' +
            valueHtml +
            "</td>" +
            "</tr>"
        );
    }

    function hasInstanceExtra(row) {
        var cfg = row.configuration || {};
        var inst = row.instance || {};
        var db = row.database || {};
        if (row.verbose) {
            return true;
        }
        if (inst.docker_status || db.docker_status) {
            return true;
        }
        if (
            (cfg.framework_index !== undefined &&
                cfg.framework_index !== null &&
                String(cfg.framework_index).trim() !== "") ||
            (cfg.framework_name && String(cfg.framework_name).trim()) ||
            (cfg.database_url && String(cfg.database_url).trim()) ||
            (cfg.database && String(cfg.database).trim()) ||
            (cfg.instance_mode && String(cfg.instance_mode).trim()) ||
            (cfg.git_branch && String(cfg.git_branch).trim()) ||
            (cfg.directory && String(cfg.directory).trim())
        ) {
            return true;
        }
        return false;
    }

    function renderInstanceExtraHtml(row) {
        var inst = row.instance || {};
        var db = row.database || {};
        var cfg = row.configuration || {};
        var html = "";
        html += '<table class="instance-detail-table"><tbody>';
        html += detailRow(
            "Instance index",
            cfg.framework_index !== undefined &&
                cfg.framework_index !== null &&
                String(cfg.framework_index).trim() !== ""
                ? escapeHtml(String(cfg.framework_index))
                : '<span class="cell-muted">—</span>'
        );
        html += detailRow(
            "Framework",
            escapeHtml(cfg.framework_name || "")
        );
        html += detailRow(
            "Git branch",
            cfg.git_branch && String(cfg.git_branch).trim()
                ? "<code>" + escapeHtml(cfg.git_branch) + "</code>"
                : '<span class="cell-muted">—</span>'
        );
        html += detailRow(
            "Directory",
            "<code>" + escapeHtml(cfg.directory || "") + "</code>"
        );
        html += detailRow("Mode", escapeHtml(cfg.instance_mode || ""));
        if (cfg.database && String(cfg.database).trim()) {
            html += detailRow(
                "DB (host)",
                escapeHtml(cfg.database)
            );
        }
        if (inst.docker_status) {
            html += detailRow(
                "Instance (Docker)",
                escapeHtml(inst.docker_status)
            );
        }
        if (db.docker_status) {
            html += detailRow(
                "Database (Docker)",
                escapeHtml(db.docker_status)
            );
        }
        html += detailRow(
            "DB URL",
            "<code>" + escapeHtml(cfg.database_url || "") + "</code>"
        );
        html += "</tbody></table>";
        if (row.verbose) {
            html += '<div class="verbose-block">';
            html += "<h3>Docker (verbose JSON)</h3>";
            html +=
                "<pre>" +
                escapeHtml(JSON.stringify(row.verbose, null, 2)) +
                "</pre>";
            html += "</div>";
        }
        return html;
    }

    function sortInstances(list, sortKey, sortDir) {
        var out = list.slice();
        var asc = sortDir === "asc";
        var mult = asc ? 1 : -1;

        function cmpNum(a, b) {
            if (a === b) {
                return 0;
            }
            return a < b ? -mult : mult;
        }

        out.sort(function (ra, rb) {
            var fa = ra.framework || "";
            var fb = rb.framework || "";
            var ia = ra.instance || {};
            var ib = rb.instance || {};
            var d = 0;

            if (sortKey === "name") {
                d = fa.localeCompare(fb, undefined, {
                    sensitivity: "base",
                });
                if (!asc) {
                    d = -d;
                }
                return d;
            }

            // created: instance.started_at or instance.created_at — asc = oldest first, desc = newest; missing last
            if (sortKey === "created" || sortKey === "age") {
                var ta = effectiveCreatedMs(ia);
                var tb = effectiveCreatedMs(ib);
                var aMissing = ta === null;
                var bMissing = tb === null;
                if (aMissing !== bMissing) {
                    return aMissing ? 1 : -1;
                }
                if (!aMissing) {
                    if (ta < tb) {
                        d = -1;
                    } else if (ta > tb) {
                        d = 1;
                    } else {
                        d = 0;
                    }
                    if (d !== 0 && !asc) {
                        d = -d;
                    }
                    if (d !== 0) {
                        return d;
                    }
                }
                var nameCmpAge = fa.localeCompare(fb, undefined, {
                    sensitivity: "base",
                });
                return asc ? nameCmpAge : -nameCmpAge;
            }

            if (sortKey === "status") {
                d = cmpNum(statusRank(ra), statusRank(rb));
                if (d !== 0) {
                    return d;
                }
                return fa.localeCompare(fb, undefined, { sensitivity: "base" });
            }

            return fa.localeCompare(fb, undefined, { sensitivity: "base" });
        });

        return out;
    }

    /** ISO UTC string -> readable string in the browser locale and timezone. */
    function formatGeneratedAtLocal(isoString) {
        var d = new Date(isoString);
        if (isNaN(d.getTime())) {
            return isoString;
        }
        return d.toLocaleString(undefined, {
            dateStyle: "medium",
            timeStyle: "medium",
        });
    }

    function updateMetaFromData(data) {
        var err = document.getElementById("error-banner");
        var gen = document.getElementById("generated-at");

        err.hidden = true;
        err.textContent = "";

        if (data.error) {
            err.hidden = false;
            err.textContent = data.error;
        }

        if (data.generated_at) {
            var iso = escapeHtml(String(data.generated_at));
            var local = escapeHtml(formatGeneratedAtLocal(data.generated_at));
            gen.innerHTML =
                '<span class="hero-meta-prefix">Last updated:</span> ' +
                '<time class="hero-meta-datetime" datetime="' +
                iso +
                '">' +
                local +
                "</time>";
        } else {
            gen.textContent = "";
        }
    }

    function getToolbarState() {
        var viewTable = document.getElementById("view-table").classList.contains(
            "segment-active"
        );
        return {
            view: viewTable ? "table" : "cards",
            sortKey: (document.getElementById("sort-key").value || "").trim(),
            sortDir: (document.getElementById("sort-dir").value || "").trim(),
        };
    }

    function applyToolbarToDom(state) {
        var btnCards = document.getElementById("view-cards");
        var btnTable = document.getElementById("view-table");
        var sk = document.getElementById("sort-key");
        var sd = document.getElementById("sort-dir");

        if (state.view === "table") {
            btnCards.classList.remove("segment-active");
            btnCards.setAttribute("aria-pressed", "false");
            btnTable.classList.add("segment-active");
            btnTable.setAttribute("aria-pressed", "true");
        } else {
            btnTable.classList.remove("segment-active");
            btnTable.setAttribute("aria-pressed", "false");
            btnCards.classList.add("segment-active");
            btnCards.setAttribute("aria-pressed", "true");
        }

        sk.value = state.sortKey;
        sd.value = state.sortDir;
        updateSortDirectionLabels();
    }

    /** Option text for sort direction depends on sort key (values asc/desc unchanged). */
    function updateSortDirectionLabels() {
        var key = document.getElementById("sort-key").value;
        var sel = document.getElementById("sort-dir");
        var oAsc = sel.options[0];
        var oDesc = sel.options[1];
        if (key === "created" || key === "age") {
            oAsc.textContent = "Oldest first";
            oDesc.textContent = "Newest first";
            sel.setAttribute(
                "aria-label",
                "Order by created time: oldest or newest first"
            );
        } else if (key === "name") {
            oAsc.textContent = "A → Z";
            oDesc.textContent = "Z → A";
            sel.setAttribute("aria-label", "Sort name A to Z or Z to A");
        } else {
            oAsc.textContent = "Ascending";
            oDesc.textContent = "Descending";
            sel.setAttribute(
                "aria-label",
                "Sort direction (status: worse health first when ascending)"
            );
        }
    }

    /** Grid column layout class: 1–5 columns by count; 6+ uses max 5 per row. */
    function instancesGridColsClass(count) {
        if (count <= 0) {
            return "";
        }
        if (count >= 6) {
            return "instances-grid-cols-5";
        }
        return "instances-grid-cols-" + String(count);
    }

    function renderView() {
        var el = document.getElementById("instances");
        var data = lastData;
        if (!data) {
            el.innerHTML = "";
            return;
        }

        var list = data.instances || [];
        if (list.length === 0 && !data.error) {
            el.className = "instances-view instances-grid";
            el.innerHTML =
                '<div class="no-instances">' +
                "<h2>No instances</h2>" +
                "<p>Create a framework instance with <code>zd create &lt;framework&gt;</code>.</p>" +
                "</div>";
            return;
        }

        var t = getToolbarState();
        var sorted = sortInstances(list, t.sortKey, t.sortDir);

        if (t.view === "table") {
            el.className = "instances-view instances-table-wrap";
            el.innerHTML = renderTable(sorted);
        } else {
            var colsCls = instancesGridColsClass(sorted.length);
            el.className =
                "instances-view instances-grid" +
                (colsCls ? " " + colsCls : "");
            var html = "";
            var i;
            for (i = 0; i < sorted.length; i++) {
                html += renderCard(sorted[i], i);
            }
            el.innerHTML = html;
        }
    }

    function renderTable(rows) {
        var h =
            '<table class="instances-table"><thead><tr>' +
            '<th class="cell-status" scope="col" aria-label="Status"></th>' +
            "<th>Framework</th>" +
            "<th>Instance</th>" +
            "<th>Database</th>" +
            "<th>Created</th>" +
            "<th>Port</th>" +
            "</tr></thead><tbody>";

        var i;
        for (i = 0; i < rows.length; i++) {
            h += renderTableRow(rows[i], i);
        }

        h += "</tbody></table>";
        return h;
    }

    function renderTableRow(row, rowIndex) {
        var inst = row.instance || {};
        var db = row.database || {};
        var cfg = row.configuration || {};
        var web = cfg.web_interface || "";
        var fw = row.framework || "";
        var expandable = hasInstanceExtra(row);
        var dotClass = statusDotClass(row);
        var dotExtra = dotClass ? " " + dotClass : "";

        var lines =
            '<tr class="instance-table-main-row' +
            (expandable ? " instance-table-row-expandable" : "") +
            '">';
        lines +=
            '<td class="cell-status">' +
            '<span class="status-dot' +
            dotExtra +
            '" aria-hidden="true"></span>' +
            "</td>";
        lines += "<td><strong>" + frameworkNameLinkHtml(fw, web) + "</strong></td>";
        lines +=
            "<td>" +
            healthPill(inst.health, inst.running) +
            ' <code class="cell-muted">' +
            escapeHtml(row.container_name || "") +
            "</code></td>";
        lines += "<td>";
        if (db.container) {
            lines +=
                healthPill(db.health, db.running) +
                ' <code class="cell-muted">' +
                escapeHtml(db.container) +
                "</code>";
        } else {
            lines += '<span class="cell-muted">—</span>';
        }
        lines += "</td>";
        lines += "<td>" + formatCreated(inst) + "</td>";
        lines += "<td>" + portStackHtml(row) + "</td>";
        lines += "</tr>";

        var moreId = "table-more-panel-" + String(rowIndex);
        if (expandable) {
            lines +=
                '<tr class="table-more-row" id="' +
                moreId +
                '" hidden>' +
                '<td colspan="6">' +
                '<div class="table-more-inner">' +
                renderInstanceExtraHtml(row) +
                "</div></td></tr>";
        }

        return lines;
    }

    function renderInstances(data) {
        lastData = data;
        updateMetaFromData(data);
        renderView();
    }

    /** Port as clickable link to the web UI when URL is known (tooltip on hover). */
    function portStackHtml(row) {
        var cfg = row.configuration || {};
        var web = cfg.web_interface || "";
        var port = String(row.port || "").trim();
        if (!port && !web) {
            return "—";
        }
        if (web) {
            var label = port ? escapeHtml(port) : escapeHtml(web);
            return (
                '<a class="cell-port-link" href="' +
                escapeHtml(web) +
                '" target="_blank" rel="noopener noreferrer" title="' +
                escapeHtml("Open in new tab: " + web) +
                '">' +
                label +
                "</a>"
            );
        }
        return '<span class="cell-port-num">' + escapeHtml(port) + "</span>";
    }

    function frameworkNameLinkHtml(fw, web) {
        if (web) {
            return (
                '<a class="framework-name-link" href="' +
                escapeHtml(web) +
                '" target="_blank" rel="noopener">' +
                escapeHtml(fw) +
                "</a>"
            );
        }
        return escapeHtml(fw);
    }

    /** Toggle extra-details panel on a card (card background click). */
    function toggleInstanceExtraPanel(card) {
        var panel = card.querySelector(".instance-extra");
        if (!panel) {
            return;
        }
        var isClosed = panel.hasAttribute("hidden");
        if (isClosed) {
            panel.removeAttribute("hidden");
        } else {
            panel.setAttribute("hidden", "");
        }
    }

    function renderCard(row, cardIndex) {
        var inst = row.instance || {};
        var db = row.database || {};
        var cfg = row.configuration || {};
        var web = cfg.web_interface || "";
        var dotClass = statusDotClass(row);
        var dotExtra = dotClass ? " " + dotClass : "";

        var fw = row.framework || "";
        var expandable = hasInstanceExtra(row);
        var lines = "";
        lines +=
            '<article class="instance-card' +
            (expandable ? " instance-card-expandable" : "") +
            '">';
        lines += '<div class="instance-name">';
        lines += '<div class="instance-title-row">';
        lines += "<h2>" + frameworkNameLinkHtml(fw, web) + "</h2>";
        lines += "</div>";
        lines += '<span class="status-dot' + dotExtra + '"></span>';
        lines += "</div>";

        lines += '<div class="instance-details">';
        lines += '<table class="instance-detail-table"><tbody>';
        lines += detailRow(
            "Instance",
            healthPill(inst.health, inst.running) +
                " <code>" +
                escapeHtml(row.container_name || "") +
                "</code>"
        );
        if (db.container) {
            lines += detailRow(
                "Database",
                healthPill(db.health, db.running) +
                    " <code>" +
                    escapeHtml(db.container) +
                    "</code>"
            );
        } else {
            lines += detailRow("Database", '<span class="pill neutral">n/a</span>');
        }
        lines += detailRow("Created", formatCreated(inst));
        lines += detailRow("Port", portStackHtml(row));
        lines += "</tbody></table></div>";

        var extraPanelId = "instance-extra-" + String(cardIndex);
        if (expandable) {
            lines +=
                '<div class="instance-extra" id="' +
                extraPanelId +
                '" hidden>' +
                renderInstanceExtraHtml(row) +
                "</div>";
        }

        lines += "</article>";
        return lines;
    }

    function loadStatus() {
        var banner = document.getElementById("error-banner");
        if (typeof getZnunyDashboardStatusMock === "function") {
            banner.hidden = true;
            banner.textContent = "";
            return Promise.resolve(getZnunyDashboardStatusMock()).then(
                renderInstances
            );
        }

        // verbose=0 keeps /api/status fast with many instances (Docker details JSON is omitted).
        var url = "/api/status?verbose=0";

        if (window.location.protocol === "file:") {
            banner.hidden = false;
            banner.textContent =
                "Open this app over HTTP (e.g. zd dashboard start → http://127.0.0.1:9999/), not as a local HTML file.";
            return Promise.resolve();
        }

        return fetch(url)
            .then(function (r) {
                return r.text().then(function (text) {
                    var data = null;
                    if (text) {
                        try {
                            data = JSON.parse(text);
                        } catch (ignore) {
                            throw new Error(
                                "Invalid response (not JSON): " +
                                    text.trim().slice(0, 280)
                            );
                        }
                    }
                    if (!r.ok) {
                        var detail =
                            (data && (data.detail || data.error)) || "";
                        throw new Error(
                            detail
                                ? "HTTP " +
                                      r.status +
                                      ": " +
                                      detail
                                : "HTTP " + r.status
                        );
                    }
                    return data;
                });
            })
            .then(renderInstances)
            .catch(function (e) {
                banner.hidden = false;
                var msg =
                    (e && e.message) ||
                    "Could not load /api/status.";
                if (
                    e &&
                    (e.message === "Failed to fetch" ||
                        (e.name === "TypeError" &&
                            String(e.message).indexOf("fetch") !== -1))
                ) {
                    msg +=
                        " Is the dashboard running? Try: zd dashboard start (then http://127.0.0.1:9999/).";
                }
                banner.textContent = msg;
            });
    }

    function initToolbar() {
        try {
            if (localStorage.getItem(storageSortKey) === "age") {
                localStorage.setItem(storageSortKey, "created");
            }
        } catch (e) {}
        var state = {
            view: getStored(storageView, ["cards", "table"], "cards"),
            sortKey: getStored(
                storageSortKey,
                ["name", "created", "status"],
                "name"
            ),
            sortDir: getStored(storageSortDir, ["asc", "desc"], "desc"),
        };
        applyToolbarToDom(state);

        function persistAndRender() {
            updateSortDirectionLabels();
            var s = getToolbarState();
            setStored(storageView, s.view);
            setStored(storageSortKey, s.sortKey);
            setStored(storageSortDir, s.sortDir);
            renderView();
        }

        document.getElementById("view-cards").addEventListener("click", function () {
            applyToolbarToDom({
                view: "cards",
                sortKey: document.getElementById("sort-key").value,
                sortDir: document.getElementById("sort-dir").value,
            });
            persistAndRender();
        });
        document.getElementById("view-table").addEventListener("click", function () {
            applyToolbarToDom({
                view: "table",
                sortKey: document.getElementById("sort-key").value,
                sortDir: document.getElementById("sort-dir").value,
            });
            persistAndRender();
        });
        document.getElementById("sort-key").addEventListener("change", persistAndRender);
        document.getElementById("sort-dir").addEventListener("change", persistAndRender);
    }

    document.getElementById("btn-refresh").addEventListener("click", loadStatus);
    document.getElementById("site-title-reload").addEventListener("click", function (e) {
        e.preventDefault();
        location.reload();
    });
    document
        .getElementById("theme-toggle")
        .addEventListener("change", onThemeSwitchChange);

    document.getElementById("instances").addEventListener("click", function (e) {
        var cardHit = e.target.closest(".instance-card");
        if (cardHit) {
            if (
                e.target.closest("a") ||
                e.target.closest("button") ||
                e.target.closest(".instance-extra")
            ) {
                return;
            }
            if (cardHit.querySelector(".instance-extra")) {
                toggleInstanceExtraPanel(cardHit);
            }
            return;
        }

        var tableMain = e.target.closest("tr.instance-table-main-row");
        if (
            tableMain &&
            tableMain.classList.contains("instance-table-row-expandable") &&
            !e.target.closest("a") &&
            !e.target.closest("button")
        ) {
            var expandRow = tableMain.nextElementSibling;
            if (expandRow && expandRow.classList.contains("table-more-row")) {
                if (expandRow.hasAttribute("hidden")) {
                    expandRow.removeAttribute("hidden");
                } else {
                    expandRow.setAttribute("hidden", "");
                }
            }
        }
    });

    initTheme();
    initToolbar();
    loadStatus();
})();
