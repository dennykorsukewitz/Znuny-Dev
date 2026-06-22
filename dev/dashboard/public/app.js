(function () {
    var themeKey = "znuny-dashboard-theme";
    var storageView = "znuny-dashboard-view";
    var storageSortKey = "znuny-dashboard-sort";
    var storageSortDir = "znuny-dashboard-sort-dir";

    var lastData = null;
    var nextOperationId = 1;
    var dashboardConfig = {
        default_ide: null,
        default_ide_cmd: null,
        default_ide_label: null,
    };

    /** Toast card (bottom-right): concurrent zd / status — returns id for endOperation. */
    function beginOperation(label) {
        var id = nextOperationId++;
        var panel = document.getElementById("global-progress-panel");
        if (!panel) {
            return id;
        }
        var item = document.createElement("div");
        item.className = "zd-progress-toast";
        item.setAttribute("data-op-id", String(id));
        var spin = document.createElement("span");
        spin.className = "zd-progress-toast-spinner";
        spin.setAttribute("aria-hidden", "true");
        var lab = document.createElement("span");
        lab.className = "zd-progress-toast-label";
        lab.textContent = label;
        item.appendChild(spin);
        item.appendChild(lab);
        panel.appendChild(item);
        panel.hidden = false;
        panel.setAttribute("aria-hidden", "false");
        return id;
    }

    function endOperation(id) {
        var panel = document.getElementById("global-progress-panel");
        if (!panel) {
            return;
        }
        var item = panel.querySelector('[data-op-id="' + String(id) + '"]');
        if (item) {
            item.remove();
        }
        if (panel.children.length === 0) {
            panel.hidden = true;
            panel.setAttribute("aria-hidden", "true");
        }
    }

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

    /** Buttons: Start (stopped) / Stop (running), Restart, Build — same as zd start|stop|restart|build. */
    function renderInstanceActionsHtml(fw, running) {
        var safeFw = escapeHtml(fw);
        var lines =
            '<div class="instance-actions" role="group" aria-label="Instance actions">';
        if (!running) {
            /* Start temporarily hidden (use CLI `zd start` or Restart when appropriate).
            lines +=
                '<button type="button" class="btn btn-secondary btn-compact zd-action-btn" data-zd-command="start" data-framework="' +
                safeFw +
                '">Start</button>';
            */
        } else {
            lines +=
                '<button type="button" class="btn btn-secondary btn-compact zd-action-btn" data-zd-command="stop" data-framework="' +
                safeFw +
                '">Stop</button>';
        }
        lines +=
            '<button type="button" class="btn btn-secondary btn-compact zd-action-btn" data-zd-command="restart" data-framework="' +
            safeFw +
            '">Restart</button>';
        lines +=
            '<button type="button" class="btn btn-secondary btn-compact zd-action-btn" data-zd-command="build" data-framework="' +
            safeFw +
            '">Build</button>';
        lines += "</div>";
        return lines;
    }

    function setInstanceActionsBusy(actionsEl, busy) {
        var buttons = actionsEl.querySelectorAll(".zd-action-btn");
        var i;
        for (i = 0; i < buttons.length; i++) {
            buttons[i].disabled = !!busy;
        }
        if (busy) {
            actionsEl.classList.add("instance-actions--busy");
        } else {
            actionsEl.classList.remove("instance-actions--busy");
        }
    }

    function detachInstanceZdProgress(actionsEl) {
        if (!actionsEl) {
            return;
        }
        var card = actionsEl.closest(".instance-card");
        var row = actionsEl.closest("tr.instance-table-main-row");
        var host = null;
        if (card) {
            host = card.querySelector(".instance-header");
        } else if (row) {
            host = row.querySelector("td.cell-actions");
        }
        if (!host) {
            host = actionsEl;
        }
        var ex = host.querySelector(".instance-zd-progress");
        if (ex) {
            ex.remove();
        }
    }

    /**
     * Indeterminate bar while zd runs: in cards between .instance-name and
     * .instance-status; in table view above .instance-actions in the actions cell.
     */
    function attachInstanceZdProgress(actionsEl, command, framework) {
        detachInstanceZdProgress(actionsEl);
        var wrap = document.createElement("div");
        wrap.className = "instance-zd-progress";
        wrap.setAttribute("role", "status");
        wrap.setAttribute("aria-label", "zd " + command + " " + framework);
        var lab = document.createElement("div");
        lab.className = "instance-zd-progress-label";
        lab.textContent = "zd " + command + " · " + framework;
        var track = document.createElement("div");
        track.className = "instance-zd-progress-track";
        var bar = document.createElement("div");
        bar.className = "instance-zd-progress-bar";
        bar.setAttribute("aria-hidden", "true");
        track.appendChild(bar);
        wrap.appendChild(lab);
        wrap.appendChild(track);

        var card = actionsEl.closest(".instance-card");
        var tableRow = actionsEl.closest("tr.instance-table-main-row");
        if (card) {
            var header = card.querySelector(".instance-header");
            var statusDot = header
                ? header.querySelector(".instance-status.status-dot")
                : null;
            if (header && statusDot) {
                header.insertBefore(wrap, statusDot);
                return;
            }
            if (header) {
                header.appendChild(wrap);
                return;
            }
        }
        if (tableRow) {
            var cell = tableRow.querySelector("td.cell-actions");
            var ia = tableRow.querySelector("td.cell-actions .instance-actions");
            if (cell && ia) {
                cell.insertBefore(wrap, ia);
                return;
            }
            if (cell) {
                cell.appendChild(wrap);
                return;
            }
        }
        actionsEl.appendChild(wrap);
    }

    function postZdCommand(command, framework, actionsEl) {
        var banner = document.getElementById("error-banner");
        if (window.location.protocol === "file:") {
            banner.hidden = false;
            banner.textContent =
                "Open this app over HTTP (e.g. zd dashboard start), not as a local HTML file.";
            return Promise.resolve();
        }
        banner.hidden = true;
        banner.textContent = "";
        setInstanceActionsBusy(actionsEl, true);
        attachInstanceZdProgress(actionsEl, command, framework);
        return fetch("/api/zd", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                command: command,
                framework: framework,
            }),
        })
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
            .then(function () {
                return loadStatus({ showProgress: false });
            })
            .catch(function (e) {
                banner.hidden = false;
                var msg =
                    (e && e.message) || "Could not run command.";
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
            })
            .finally(function () {
                detachInstanceZdProgress(actionsEl);
                setInstanceActionsBusy(actionsEl, false);
            });
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
            (cfg.directory && String(cfg.directory).trim()) ||
            (cfg.host_workspace && String(cfg.host_workspace).trim()) ||
            (row.paths && (row.paths.agent || row.paths.customer)) ||
            (row.access && (row.access.root || row.access.agent || row.access.customer))
        ) {
            return true;
        }
        return false;
    }

    /** Agent/customer/public URL in detail view — opens in new tab. */
    function pathLineHtml(label, url) {
        if (!url) {
            return "";
        }
        return (
            escapeHtml(label) +
            ': <a href="' +
            escapeHtml(url) +
            '" target="_blank" rel="noopener noreferrer" title="' +
            escapeHtml("Open in new tab: " + url) +
            '"><code>' +
            escapeHtml(url) +
            "</code></a><br>"
        );
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
        if (cfg.host_workspace && String(cfg.host_workspace).trim()) {
            html += detailRow(
                "Host workspace",
                "<code>" + escapeHtml(String(cfg.host_workspace).trim()) + "</code>"
            );
        }
        var paths = row.paths || {};
        if (paths.agent || paths.customer || paths.public) {
            var pathLines = [
                pathLineHtml("Agent", paths.agent),
                pathLineHtml("Customer", paths.customer),
                pathLineHtml("Public", paths.public),
            ]
                .filter(Boolean)
                .join("");
            html += detailRow("Paths", pathLines);
        }
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
            "<th>Login</th>" +
            "<th>Workspace</th>" +
            '<th class="cell-actions" scope="col">Actions</th>' +
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
            '<span class="instance-status status-dot' +
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
        lines += '<td class="cell-login">' + renderLoginLinksHtml(row) + "</td>";
        lines +=
            '<td class="cell-workspace">' +
            hostWorkspaceButtonsHtml(row) +
            "</td>";
        lines +=
            '<td class="cell-actions">' +
            renderInstanceActionsHtml(fw, !!inst.running) +
            "</td>";
        lines += "</tr>";

        var moreId = "table-more-panel-" + String(rowIndex);
        if (expandable) {
            lines +=
                '<tr class="table-more-row" id="' +
                moreId +
                '" hidden>' +
                '<td colspan="9">' +
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

    /** Folder + IDE buttons (DEFAULT_IDE from configs/instance/my.env). */
    function hostWorkspaceButtonsHtml(row) {
        var cfg = row.configuration || {};
        var ws = cfg.host_workspace;
        var fw = row.framework || "";
        if (!ws || !String(ws).trim() || !fw) {
            return '<span class="cell-muted">—</span>';
        }
        var wsTrim = String(ws).trim();
        var html =
            '<span class="host-workspace-actions">' +
            '<button type="button" class="btn btn-accent btn-compact open-workspace-link" data-framework="' +
            escapeHtml(fw) +
            '" title="' +
            escapeHtml("Open in Finder / Explorer: " + wsTrim) +
            '">Folder</button>';
        if (dashboardConfig.default_ide_cmd && dashboardConfig.default_ide_label) {
            html +=
                '<button type="button" class="btn btn-accent btn-compact open-ide-link" data-framework="' +
                escapeHtml(fw) +
                '" title="Open in ' +
                escapeHtml(dashboardConfig.default_ide_label) +
                ": " +
                escapeHtml(wsTrim) +
                '">' +
                escapeHtml(dashboardConfig.default_ide_label) +
                "</button>";
        }
        html += "</span>";
        return html;
    }

    function openHostWorkspace(framework) {
        var banner = document.getElementById("error-banner");
        if (!framework) {
            return Promise.resolve();
        }
        return fetch(
            "/api/open-workspace?framework=" +
                encodeURIComponent(framework),
            { method: "POST" }
        )
            .then(function (r) {
                return r.text().then(function (text) {
                    var data = null;
                    if (text) {
                        try {
                            data = JSON.parse(text);
                        } catch (ignore) {
                            throw new Error(
                                "Invalid response: " + text.trim().slice(0, 200)
                            );
                        }
                    }
                    if (!r.ok) {
                        throw new Error(
                            (data && (data.detail || data.error)) ||
                                "HTTP " + r.status
                        );
                    }
                    return data;
                });
            })
            .then(function () {
                if (banner) {
                    banner.hidden = true;
                    banner.textContent = "";
                }
            })
            .catch(function (e) {
                if (banner) {
                    banner.hidden = false;
                    banner.textContent =
                        (e && e.message) ||
                        "Could not open host workspace. Run: zd dashboard start";
                }
            });
    }

    function openHostIde(framework) {
        var banner = document.getElementById("error-banner");
        if (!framework) {
            return Promise.resolve();
        }
        return fetch(
            "/api/open-ide?framework=" + encodeURIComponent(framework),
            { method: "POST" }
        )
            .then(function (r) {
                return r.text().then(function (text) {
                    var data = null;
                    if (text) {
                        try {
                            data = JSON.parse(text);
                        } catch (ignore) {
                            throw new Error(
                                "Invalid response: " + text.trim().slice(0, 200)
                            );
                        }
                    }
                    if (!r.ok) {
                        throw new Error(
                            (data && (data.detail || data.error)) ||
                                "HTTP " + r.status
                        );
                    }
                    return data;
                });
            })
            .then(function () {
                if (banner) {
                    banner.hidden = true;
                    banner.textContent = "";
                }
            })
            .catch(function (e) {
                if (banner) {
                    banner.hidden = false;
                    banner.textContent =
                        (e && e.message) ||
                        "Could not open IDE. Run: zd dashboard restart";
                }
            });
    }

    function loadDashboardConfig() {
        if (window.location.protocol === "file:") {
            return Promise.resolve();
        }
        return fetch("/api/config")
            .then(function (r) {
                return r.json();
            })
            .then(function (cfg) {
                if (cfg && cfg.default_ide_cmd) {
                    dashboardConfig = cfg;
                }
            })
            .catch(function () {});
    }

    /** Agent/customer login URL with User and Password query params (Action=Login). */
    function znunyLoginUrl(entryUrl, cred) {
        if (!entryUrl || !cred || !cred.login) {
            return "";
        }
        var sep = String(entryUrl).indexOf("?") >= 0 ? "&" : "?";
        var url =
            String(entryUrl) +
            sep +
            "Action=Login&User=" +
            encodeURIComponent(String(cred.login));
        if (cred.password) {
            url +=
                "&Password=" + encodeURIComponent(String(cred.password));
        }
        return url;
    }

    function loginLinkTitle(cred) {
        if (!cred || !cred.login) {
            return "";
        }
        var parts = [String(cred.login)];
        if (cred.password) {
            parts.push(String(cred.password));
        }
        if (cred.company_id) {
            parts.push("company: " + String(cred.company_id));
        }
        return "Login · " + parts.join(" / ");
    }

    /** root / agent / customer — opens Znuny login with User prefilled; tooltip shows dev password. */
    function renderLoginLinksHtml(row) {
        var paths = row.paths || {};
        var access = row.access || {};
        var agentBase = paths.agent || "";
        var customerBase = paths.customer || "";
        var parts = [];

        function pushLink(label, url, cred) {
            if (!url || !cred || !cred.login) {
                return;
            }
            parts.push(
                '<a class="btn btn-accent btn-compact login-link" href="' +
                    escapeHtml(url) +
                    '" target="_blank" rel="noopener noreferrer" title="' +
                    escapeHtml(loginLinkTitle(cred)) +
                    '">' +
                    escapeHtml(label) +
                    "</a>"
            );
        }

        pushLink("root", znunyLoginUrl(agentBase, access.root), access.root);
        pushLink(
            "agent",
            znunyLoginUrl(agentBase, access.agent),
            access.agent
        );
        pushLink(
            "customer",
            znunyLoginUrl(customerBase, access.customer),
            access.customer
        );

        if (parts.length === 0) {
            return '<span class="cell-muted">—</span>';
        }
        return '<span class="login-links">' + parts.join("") + "</span>";
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
        lines += '<div class="instance-header">';
        lines += '<div class="instance-name">';
        lines += "<h2>" + frameworkNameLinkHtml(fw, web) + "</h2>";
        lines += "</div>";
        lines +=
            '<span class="instance-status status-dot' +
            dotExtra +
            '"></span>';
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
        lines += detailRow("Login", renderLoginLinksHtml(row));
        if (cfg.host_workspace && String(cfg.host_workspace).trim()) {
            lines += detailRow("Workspace", hostWorkspaceButtonsHtml(row));
        }
        lines += "</tbody></table></div>";

        lines += renderInstanceActionsHtml(fw, !!inst.running);

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

    function loadStatus(opt) {
        var banner = document.getElementById("error-banner");
        var hideProgress = opt && opt.showProgress === false;

        if (typeof getZnunyDashboardStatusMock === "function") {
            banner.hidden = true;
            banner.textContent = "";
            var mockOpId = null;
            if (!hideProgress) {
                mockOpId = beginOperation("Status · loading");
            }
            return Promise.resolve(getZnunyDashboardStatusMock())
                .then(renderInstances)
                .finally(function () {
                    if (!hideProgress && mockOpId !== null) {
                        endOperation(mockOpId);
                    }
                });
        }

        // verbose=0 keeps /api/status fast with many instances (Docker details JSON is omitted).
        var url = "/api/status?verbose=0";

        if (window.location.protocol === "file:") {
            banner.hidden = false;
            banner.textContent =
                "Open this app over HTTP (e.g. zd dashboard start → http://127.0.0.1:9999/), not as a local HTML file.";
            return Promise.resolve();
        }

        var statusOpId = null;
        if (!hideProgress) {
            statusOpId = beginOperation("Status · loading");
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
            })
            .finally(function () {
                if (!hideProgress && statusOpId !== null) {
                    endOperation(statusOpId);
                }
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
        var wsLink = e.target.closest(".open-workspace-link");
        if (wsLink) {
            e.preventDefault();
            e.stopPropagation();
            openHostWorkspace(wsLink.getAttribute("data-framework") || "");
            return;
        }

        var ideBtn = e.target.closest(".open-ide-link");
        if (ideBtn) {
            e.preventDefault();
            e.stopPropagation();
            openHostIde(ideBtn.getAttribute("data-framework") || "");
            return;
        }

        var zdBtn = e.target.closest(".zd-action-btn");
        if (zdBtn) {
            e.preventDefault();
            e.stopPropagation();
            var cmd = zdBtn.getAttribute("data-zd-command") || "";
            var fw = zdBtn.getAttribute("data-framework") || "";
            var actions = zdBtn.closest(".instance-actions");
            if (cmd && fw && actions) {
                postZdCommand(cmd, fw, actions);
            }
            return;
        }

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
    loadDashboardConfig().then(function () {
        loadStatus();
    });
})();
