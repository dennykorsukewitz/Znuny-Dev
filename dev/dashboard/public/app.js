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

    /**
     * All UI tooltips (title attributes and brief messages). Dynamic values use {placeholders}.
     */
    var TOOLTIPS = {
        ui: {
            reloadPage: "Reload the dashboard page",
            refreshStatus:
                "Fetch latest instance status (zd status JSON — Docker health, ports, paths)",
            themeDark:
                "Toggle light / dark dashboard theme (saved in browser)",
            themeSwitchToDark: "Switch to dark theme (saved in browser)",
            themeSwitchToLight: "Switch to light theme (saved in browser)",
            viewCards:
                "Card layout — one instance per card, click card to expand details",
            viewTable:
                "Table layout — compact rows, click a row to expand details",
            sortKey: "Choose what to sort instances by",
            sortDir: "Ascending (A→Z, oldest first) or descending",
            statusLegend:
                "Open status legend — instance and database container colors and Docker health labels",
        },
        copy: {
            clickToCopy: "Click to copy to clipboard",
            copiedDefault: "Copied",
            copyFailed: "Copy failed",
            directoryCopied: "Directory copied",
            hostWorkspaceCopied: "Host workspace copied",
            dbUrlCopied: "DB URL copied",
        },
        health: {
            targetInstance: "Instance container",
            targetDatabase: "Database container",
            instanceStopped:
                "is stopped. Use Start or zd start to run it again.",
            databaseStopped:
                "is not running. Shared database containers are started with zd start on any instance.",
            healthy:
                "is running. Docker health check passed — service responds as expected.",
            unhealthy:
                "is running but Docker health check failed. Check logs (zd log / container-log).",
            stoppedState: "reports stopped state.",
            noHealthCheck:
                "is running. No Docker health check configured for this container.",
            running: "is running.",
            statusUnknown: "status: {health}.",
        },
        action: {
            start:
                "zd start — start Docker containers for this framework instance.",
            stop: "zd stop — stop containers. Instance data and volumes are kept.",
            restart:
                "zd restart — stop and start containers (reload Apache / services).",
            build:
                "zd build — rebuild the Docker image for this instance (after Dockerfile changes).",
            remove:
                "zd remove — delete instance, containers, volumes, and the framework folder (irreversible).",
            dbStart: "Start the database Docker container for this instance.",
            dbStop: "Stop the database Docker container for this instance.",
            dbRestart: "Restart the database Docker container for this instance.",
            dbSharedNote:
                "Shared database — start/stop/restart affects all instances using this container.",
            dbSharedConfirm:
                "Shared database {container} is used by multiple instances. Continue?",
            instanceActionsMenu: "Open instance actions",
            dbActionsMenu: "Open database container actions",
        },
        link: {
            openNewTab: "Open in new tab: {url}",
            openFinder: "Open in Finder / Explorer: {path}",
            openIde: "Open in {ide}: {path}",
            frameworkWeb: "Open Znuny web interface: {url}",
        },
        login: {
            titlePrefix: "Login · ",
            titleSeparator: " / ",
            companyPrefix: "company: ",
        },
        statusDot: {
            instance: {
                healthy:
                    "OK — instance and database running, no failed health checks",
                warning:
                    "Warning — instance or database stopped or not running",
                error:
                    "Error — instance or database Docker health check failed",
            },
            container: {
                healthy:
                    "Database OK — running, Docker health passed or not configured",
                warning:
                    "Database warning — container not running or reports stopped",
                error: "Database error — Docker health check failed",
            },
        },
        legend: {
            dialogTitle: "Status legend",
            close: "Close status legend dialog",
            dotHeading: "Summary dot",
            pillHeading: "Docker health pill",
            colIndicator: "Indicator",
            colDescription: "Description",
            dotOk:
                "OK — instance and database running, no failed health checks",
            dotWarning:
                "Warning — instance or database stopped or not running",
            dotError:
                "Error — instance or database Docker health check failed",
            pillHealthy:
                "Container is running. Docker health check passed.",
            pillUnhealthy:
                "Container is running but Docker health check failed.",
            pillNoHealthCheck:
                "Container is running. No Docker health check configured.",
            pillRunning: "Container is running.",
            pillUnknown: "Unknown health status reported by Docker.",
            pillStopped: "Container is stopped.",
        },
        expand: {
            card: "Click card to show or hide details (DB URL, paths, git branch, …)",
            tableRow:
                "Click row to show or hide details (DB URL, paths, git branch, …)",
        },
        generatedAt: "Status snapshot from last Refresh: {time}",
        confirm: {
            cancel: "Close dialog without deleting anything",
            delete: "Confirm delete — runs zd remove (irreversible)",
        },
    };

    function setElementTooltip(el, text) {
        if (el && text) {
            el.title = text;
        }
    }

    function tooltipFormat(template, vars) {
        var out = String(template);
        vars = vars || {};
        Object.keys(vars).forEach(function (key) {
            out = out.split("{" + key + "}").join(String(vars[key]));
        });
        return out;
    }

    function applyStaticTooltips() {
        setElementTooltip(
            document.getElementById("site-title-reload"),
            TOOLTIPS.ui.reloadPage
        );
        setElementTooltip(
            document.getElementById("btn-refresh"),
            TOOLTIPS.ui.refreshStatus
        );

        setElementTooltip(
            document.getElementById("view-cards"),
            TOOLTIPS.ui.viewCards
        );
        setElementTooltip(
            document.getElementById("view-table"),
            TOOLTIPS.ui.viewTable
        );
        setElementTooltip(
            document.getElementById("sort-key"),
            TOOLTIPS.ui.sortKey
        );
        setElementTooltip(
            document.getElementById("sort-dir"),
            TOOLTIPS.ui.sortDir
        );

        setElementTooltip(
            document.querySelector("#confirm-dialog [data-confirm='0']"),
            TOOLTIPS.confirm.cancel
        );
        setElementTooltip(
            document.querySelector("#confirm-dialog [data-confirm='1']"),
            TOOLTIPS.confirm.delete
        );
        setElementTooltip(
            document.getElementById("btn-status-legend"),
            TOOLTIPS.ui.statusLegend
        );
        setElementTooltip(
            document.querySelector("#status-legend-dialog [data-legend-close='1'].btn"),
            TOOLTIPS.legend.close
        );
    }

    function openStatusLegendDialog() {
        var dlg = document.getElementById("status-legend-dialog");
        if (!dlg) {
            return;
        }
        dlg.hidden = false;
        document.body.classList.add("confirm-dialog-open");
        var closeBtn = dlg.querySelector("[data-legend-close='1'].btn");
        if (closeBtn) {
            closeBtn.focus();
        }
    }

    function closeStatusLegendDialog() {
        var dlg = document.getElementById("status-legend-dialog");
        if (!dlg || dlg.hidden) {
            return;
        }
        dlg.hidden = true;
        if (document.getElementById("confirm-dialog").hidden) {
            document.body.classList.remove("confirm-dialog-open");
        }
        var btn = document.getElementById("btn-status-legend");
        if (btn) {
            btn.focus();
        }
    }

    var STATUS_LEGEND_PILL_STATES = [
        { health: "healthy", running: true, descKey: "pillHealthy" },
        { health: "no-health-check", running: true, descKey: "pillNoHealthCheck" },
        { health: "", running: true, descKey: "pillRunning" },
        { health: "unknown", running: true, descKey: "pillUnknown" },
        { health: "stopped", running: false, descKey: "pillStopped" },
        { health: "unhealthy", running: true, descKey: "pillUnhealthy" },
    ];

    var STATUS_LEGEND_DOT_STATES = [
        { cls: "", key: "dotOk" },
        { cls: "warning", key: "dotWarning" },
        { cls: "error", key: "dotError" },
    ];

    function statusLegendGridHeadHtml() {
        return (
            '<li class="status-legend-grid-head">' +
            '<span class="status-legend-col-label">' +
            escapeHtml(TOOLTIPS.legend.colIndicator) +
            "</span>" +
            '<span class="status-legend-col-label">' +
            escapeHtml(TOOLTIPS.legend.colDescription) +
            "</span>" +
            "</li>"
        );
    }

    function statusLegendDotsHtml() {
        var html = '<div class="status-legend-block status-legend-block-dots">';
        html +=
            '<h4 class="status-legend-subheading">' +
            escapeHtml(TOOLTIPS.legend.dotHeading) +
            "</h4>";
        html += '<ul class="status-legend-grid status-legend-grid-dots">';
        html += statusLegendGridHeadHtml();
        var dotTips = TOOLTIPS.statusDot.instance;
        var i;
        for (i = 0; i < STATUS_LEGEND_DOT_STATES.length; i++) {
            var dotState = STATUS_LEGEND_DOT_STATES[i];
            var dotExtra = dotState.cls ? " " + dotState.cls : "";
            var dotTip =
                dotState.cls === "error"
                    ? dotTips.error
                    : dotState.cls === "warning"
                      ? dotTips.warning
                      : dotTips.healthy;
            html += '<li class="status-legend-grid-row">';
            html += '<span class="status-legend-col-mark">';
            html +=
                '<span class="instance-status status-dot status-legend-dot' +
                dotExtra +
                '" title="' +
                escapeHtml(dotTip) +
                '"></span>';
            html += "</span>";
            html +=
                '<span class="status-legend-col-desc">' +
                escapeHtml(TOOLTIPS.legend[dotState.key]) +
                "</span>";
            html += "</li>";
        }
        html += "</ul></div>";
        return html;
    }

    function statusLegendPillsHtml() {
        var html = '<div class="status-legend-block status-legend-block-pills">';
        html +=
            '<h4 class="status-legend-subheading">' +
            escapeHtml(TOOLTIPS.legend.pillHeading) +
            "</h4>";
        html += '<ul class="status-legend-grid status-legend-grid-pills">';
        html += statusLegendGridHeadHtml();
        var i;
        for (i = 0; i < STATUS_LEGEND_PILL_STATES.length; i++) {
            var pillState = STATUS_LEGEND_PILL_STATES[i];
            html += '<li class="status-legend-grid-row">';
            html += '<span class="status-legend-col-mark">';
            html +=
                healthPill(pillState.health, pillState.running, "instance");
            html += "</span>";
            html +=
                '<span class="status-legend-col-desc">' +
                escapeHtml(TOOLTIPS.legend[pillState.descKey]) +
                "</span>";
            html += "</li>";
        }
        html += "</ul></div>";
        return html;
    }

    function renderStatusLegend() {
        var root = document.getElementById("status-legend-body");
        if (!root) {
            return;
        }
        var html = '<div class="status-legend-sections status-legend-sections-stack">';
        html += statusLegendDotsHtml();
        html += statusLegendPillsHtml();
        html += "</div>";
        root.innerHTML = html;
    }

    function statusDotTooltipForKind(dotClass, kind) {
        var tips =
            kind === "database"
                ? TOOLTIPS.statusDot.container
                : TOOLTIPS.statusDot.instance;
        if (dotClass === "error") {
            return tips.error;
        }
        if (dotClass === "warning") {
            return tips.warning;
        }
        return tips.healthy;
    }

    function instanceStatusDotTooltip(row) {
        return statusDotTooltipForKind(
            instanceStatusDotClass(row),
            "instance"
        );
    }

    function instanceStatusDotHtml(row) {
        var dotClass = instanceStatusDotClass(row);
        var extra = dotClass ? " " + dotClass : "";
        return (
            '<span class="instance-status status-dot' +
            extra +
            '" title="' +
            escapeHtml(instanceStatusDotTooltip(row)) +
            '"></span>'
        );
    }

    /** Message card (bottom-right): concurrent zd / status — returns id for endOperation. */
    function beginOperation(label, opt) {
        opt = opt || {};
        var id = nextOperationId++;
        var panel = document.getElementById("global-message-panel");
        if (!panel) {
            return id;
        }
        var item = document.createElement("div");
        item.className = "zd-message";
        if (opt.tone === "ok") {
            item.classList.add("zd-message-ok");
        } else if (opt.tone === "error") {
            item.classList.add("zd-message-error");
        }
        item.setAttribute("data-op-id", String(id));
        if (opt.spinner !== false) {
            var spin = document.createElement("span");
            spin.className = "zd-message-spinner";
            spin.setAttribute("aria-hidden", "true");
            item.appendChild(spin);
        }
        var lab = document.createElement("span");
        lab.className = "zd-message-label";
        lab.textContent = label;
        item.appendChild(lab);
        panel.appendChild(item);
        panel.hidden = false;
        panel.setAttribute("aria-hidden", "false");
        return id;
    }

    /** Short message in the same message stack as loadStatus (no spinner). */
    function showBriefMessage(label, opt) {
        opt = opt || {};
        var id = beginOperation(label, {
            spinner: false,
            tone: opt.tone || "ok",
        });
        window.setTimeout(function () {
            endOperation(id);
        }, opt.durationMs || 2000);
        return id;
    }

    function endOperation(id) {
        var panel = document.getElementById("global-message-panel");
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
        var themeLabel = document.querySelector("label.toggle-switch-theme");
        var themeTip = isDark
            ? TOOLTIPS.ui.themeSwitchToLight
            : TOOLTIPS.ui.themeSwitchToDark;
        input.setAttribute(
            "aria-label",
            isDark ? "Switch to light theme" : "Switch to dark theme"
        );
        setElementTooltip(themeLabel, themeTip);
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
        syncThemeSwitch();
    }

    function escapeHtml(s) {
        return String(s)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;");
    }

    function copyTextToClipboard(text) {
        if (!text) {
            return Promise.reject(new Error("empty"));
        }
        if (navigator.clipboard && navigator.clipboard.writeText) {
            return navigator.clipboard.writeText(text);
        }
        return new Promise(function (resolve, reject) {
            var ta = document.createElement("textarea");
            ta.value = text;
            ta.setAttribute("readonly", "");
            ta.style.position = "fixed";
            ta.style.left = "-9999px";
            document.body.appendChild(ta);
            ta.select();
            try {
                if (document.execCommand("copy")) {
                    resolve();
                } else {
                    reject(new Error("copy failed"));
                }
            } catch (err) {
                reject(err);
            } finally {
                document.body.removeChild(ta);
            }
        });
    }

    function copyableValueHtml(text, opt) {
        opt = opt || {};
        var t = text && String(text).trim();
        if (!t) {
            return '<span class="cell-muted">—</span>';
        }
        var messageLabel = opt.label || TOOLTIPS.copy.copiedDefault;
        return (
            '<button type="button" class="copy-on-click" data-copy-text="' +
            escapeHtml(t) +
            '" data-copy-label="' +
            escapeHtml(messageLabel) +
            '" title="' +
            escapeHtml(TOOLTIPS.copy.clickToCopy) +
            '">' +
            "<code>" +
            escapeHtml(t) +
            "</code></button>"
        );
    }

    function copyableDetailRow(label, text, copyMessageLabel) {
        return detailRow(
            label,
            copyableValueHtml(text, {
                label: copyMessageLabel || label + " copied",
            })
        );
    }

    function handleCopyClick(btn) {
        var copyText = btn.getAttribute("data-copy-text") || "";
        var messageLabel = btn.getAttribute("data-copy-label") || TOOLTIPS.copy.copiedDefault;
        return copyTextToClipboard(copyText)
            .then(function () {
                showBriefMessage(messageLabel, { tone: "ok" });
            })
            .catch(function () {
                showBriefMessage(TOOLTIPS.copy.copyFailed, { tone: "error" });
            });
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

    function healthStatusTooltip(health, running, kind) {
        kind = kind || "instance";
        var target =
            kind === "database"
                ? TOOLTIPS.health.targetDatabase
                : TOOLTIPS.health.targetInstance;

        if (!running) {
            return (
                target +
                " " +
                (kind === "database"
                    ? TOOLTIPS.health.databaseStopped
                    : TOOLTIPS.health.instanceStopped)
            );
        }

        var h = (health || "").toLowerCase();
        if (h === "healthy") {
            return target + " " + TOOLTIPS.health.healthy;
        }
        if (h === "unhealthy") {
            return target + " " + TOOLTIPS.health.unhealthy;
        }
        if (h === "stopped") {
            return target + " " + TOOLTIPS.health.stoppedState;
        }
        if (h === "no-health-check") {
            return target + " " + TOOLTIPS.health.noHealthCheck;
        }
        if (h === "running" || !h) {
            return target + " " + TOOLTIPS.health.running;
        }
        return tooltipFormat(TOOLTIPS.health.statusUnknown, { health: health });
    }

    function healthPill(health, running, kind) {
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
        var tooltip = healthStatusTooltip(health, running, kind);
        var statusKindClass =
            kind === "database" ? "container-status" : "instance-status";
        return (
            '<span class="pill ' +
            cls +
            " " +
            statusKindClass +
            '" title="' +
            escapeHtml(tooltip) +
            '">' +
            escapeHtml(label) +
            "</span>"
        );
    }

    /** Single-container state for summary dot (instance or database). */
    function containerSummaryState(container) {
        if (!container || !container.running) {
            return "stopped";
        }
        var h = (container.health || "").toLowerCase();
        if (h === "unhealthy") {
            return "unhealthy";
        }
        if (h === "stopped") {
            return "stopped";
        }
        return "ok";
    }

    /**
     * Summary dot for a framework row: instance + database combined.
     * Error if either health check failed; warning if either stopped; OK only if both running.
     */
    function instanceStatusDotClass(row) {
        var inst = row.instance || {};
        var db = row.database || {};
        var hasDb = !!(db.container && String(db.container).trim());
        var instState = containerSummaryState(inst);
        var dbState = hasDb ? containerSummaryState(db) : "ok";
        if (instState === "unhealthy" || dbState === "unhealthy") {
            return "error";
        }
        if (instState === "stopped" || dbState === "stopped") {
            return "warning";
        }
        return "";
    }

    /** Numeric rank for status sort: lower = worse / less healthy */
    function statusRank(row) {
        var dotClass = instanceStatusDotClass(row);
        if (dotClass === "error") {
            return 0;
        }
        if (dotClass === "warning") {
            return 1;
        }
        return 4;
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

    function actionDropdownItemHtml(cmd, fw, label, tooltip, opt) {
        opt = opt || {};
        var cls = "actions-menu-item zd-action-btn";
        if (opt.danger) {
            cls += " actions-menu-item-danger";
        }
        var html =
            '<button type="button" class="' +
            cls +
            '" role="menuitem" data-zd-command="' +
            escapeHtml(cmd) +
            '" data-framework="' +
            fw +
            '"';
        if (opt.sharedDb) {
            html += ' data-shared-db="1"';
        }
        if (opt.dbContainer) {
            html += ' data-db-container="' + escapeHtml(opt.dbContainer) + '"';
        }
        html +=
            ' title="' +
            escapeHtml(tooltip) +
            '">' +
            escapeHtml(label) +
            "</button>";
        return html;
    }

    function renderActionsDropdown(kind, label, ariaLabel, bodyHtml) {
        return (
            '<div class="actions-menu actions-menu-' +
            kind +
            '" role="group" aria-label="' +
            escapeHtml(ariaLabel) +
            '">' +
            '<button type="button" class="btn btn-secondary btn-compact actions-menu-toggle" aria-expanded="false" aria-haspopup="menu" title="' +
            escapeHtml(ariaLabel) +
            '">' +
            escapeHtml(label) +
            "</button>" +
            '<div class="actions-menu-dropdown" role="menu" hidden>' +
            bodyHtml +
            "</div></div>"
        );
    }

    function renderTableInstanceActionsDropdown(row) {
        var fw = row.framework || "";
        var inst = row.instance || {};
        var running = !!inst.running;
        var safeFw = escapeHtml(fw);
        var body = "";
        if (running) {
            body += actionDropdownItemHtml(
                "stop",
                safeFw,
                "Stop",
                TOOLTIPS.action.stop
            );
            body += actionDropdownItemHtml(
                "restart",
                safeFw,
                "Restart",
                TOOLTIPS.action.restart
            );
        } else {
            body += actionDropdownItemHtml(
                "start",
                safeFw,
                "Start",
                TOOLTIPS.action.start
            );
        }
        body += actionDropdownItemHtml(
            "build",
            safeFw,
            "Build",
            TOOLTIPS.action.build
        );
        body += actionDropdownItemHtml(
            "remove",
            safeFw,
            "Delete",
            TOOLTIPS.action.remove,
            { danger: true }
        );
        return renderActionsDropdown(
            "instance",
            "Instance",
            TOOLTIPS.action.instanceActionsMenu,
            body
        );
    }

    function renderTableDbActionsDropdown(row) {
        var fw = row.framework || "";
        var db = row.database || {};
        var cfg = row.configuration || {};
        var dbRunning = !!db.running;
        var sharedDb =
            String(cfg.instance_mode || "shared").toLowerCase() === "shared";
        var safeFw = escapeHtml(fw);
        var body = "";
        if (sharedDb) {
            body +=
                '<p class="actions-menu-note">' +
                escapeHtml(TOOLTIPS.action.dbSharedNote) +
                "</p>";
        }
        var dbOpt = {
            sharedDb: sharedDb,
            dbContainer: db.container || "",
        };
        if (dbRunning) {
            body += actionDropdownItemHtml(
                "db-stop",
                safeFw,
                "Stop",
                TOOLTIPS.action.dbStop,
                dbOpt
            );
            body += actionDropdownItemHtml(
                "db-restart",
                safeFw,
                "Restart",
                TOOLTIPS.action.dbRestart,
                dbOpt
            );
        } else {
            body += actionDropdownItemHtml(
                "db-start",
                safeFw,
                "Start",
                TOOLTIPS.action.dbStart,
                dbOpt
            );
        }
        return renderActionsDropdown(
            "database",
            "Database",
            TOOLTIPS.action.dbActionsMenu,
            body
        );
    }

    function renderActionsCell(row) {
        var db = row.database || {};
        var hasDb = !!(db.container && String(db.container).trim());
        var html =
            '<div class="cell-actions-toolbar instance-actions" role="group" aria-label="Instance and database actions">';
        html += renderTableInstanceActionsDropdown(row);
        if (hasDb) {
            html += renderTableDbActionsDropdown(row);
        }
        html += "</div>";
        return html;
    }

    function closeAllActionsDropdowns() {
        var openMenus = document.querySelectorAll(".actions-menu-open");
        var i;
        for (i = 0; i < openMenus.length; i++) {
            var menu = openMenus[i];
            var panel = menu.querySelector(".actions-menu-dropdown");
            var toggle = menu.querySelector(".actions-menu-toggle");
            if (panel) {
                panel.hidden = true;
            }
            if (toggle) {
                toggle.setAttribute("aria-expanded", "false");
            }
            menu.classList.remove("actions-menu-open");
        }
    }

    function toggleActionsDropdown(toggleBtn) {
        var menu = toggleBtn.closest(".actions-menu");
        if (!menu) {
            return;
        }
        var panel = menu.querySelector(".actions-menu-dropdown");
        if (!panel) {
            return;
        }
        var willOpen = panel.hidden;
        closeAllActionsDropdowns();
        if (willOpen) {
            panel.hidden = false;
            toggleBtn.setAttribute("aria-expanded", "true");
            menu.classList.add("actions-menu-open");
        }
    }

    function confirmSharedDbAction(containerName) {
        return Promise.resolve(
            window.confirm(
                tooltipFormat(TOOLTIPS.action.dbSharedConfirm, {
                    container: containerName || "database",
                })
            )
        );
    }

    function runZdActionFromButton(zdBtn) {
        var cmd = zdBtn.getAttribute("data-zd-command") || "";
        var fw = zdBtn.getAttribute("data-framework") || "";
        var actions =
            zdBtn.closest(".cell-actions-toolbar") ||
            zdBtn.closest(".actions-menu") ||
            zdBtn.closest(".instance-actions");
        if (!cmd || !fw || !actions) {
            return;
        }

        function execute() {
            closeAllActionsDropdowns();
            postZdCommand(cmd, fw, actions);
        }

        if (cmd === "remove") {
            confirmDelete(fw).then(function (ok) {
                if (ok) {
                    execute();
                }
            });
            return;
        }

        if (
            zdBtn.getAttribute("data-shared-db") === "1" &&
            (cmd === "db-stop" || cmd === "db-restart")
        ) {
            confirmSharedDbAction(
                zdBtn.getAttribute("data-db-container") || ""
            ).then(function (ok) {
                if (ok) {
                    execute();
                }
            });
            return;
        }

        execute();
    }

    var confirmDone = null;

    function confirmDelete(framework) {
        var dlg = document.getElementById("confirm-dialog");
        var msg = document.getElementById("confirm-dialog-message");
        var safeFw = escapeHtml(framework);
        msg.innerHTML =
            "Delete <span class=\"confirm-dialog-framework\">" +
            safeFw +
            "</span>?\nThis permanently removes containers, database, instance config, and the framework folder (frameworks/<span class=\"confirm-dialog-framework\">" +
            safeFw +
            "</span>).";
        dlg.hidden = false;
        document.body.classList.add("confirm-dialog-open");
        return new Promise(function (resolve) {
            confirmDone = resolve;
        });
    }

    function finishConfirm(ok) {
        var dlg = document.getElementById("confirm-dialog");
        dlg.hidden = true;
        document.body.classList.remove("confirm-dialog-open");
        if (confirmDone) {
            var done = confirmDone;
            confirmDone = null;
            done(!!ok);
        }
    }

    function setInstanceActionsBusy(actionsEl, busy) {
        var buttons = actionsEl.querySelectorAll(
            ".zd-action-btn, .actions-menu-toggle"
        );
        var i;
        for (i = 0; i < buttons.length; i++) {
            buttons[i].disabled = !!busy;
        }
        if (busy) {
            actionsEl.classList.add("instance-actions--busy");
            closeAllActionsDropdowns();
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
            escapeHtml(tooltipFormat(TOOLTIPS.link.openNewTab, { url: url })) +
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
        html += copyableDetailRow(
            "Directory",
            cfg.directory || "",
            TOOLTIPS.copy.directoryCopied
        );
        if (cfg.host_workspace && String(cfg.host_workspace).trim()) {
            html += copyableDetailRow(
                "Host workspace",
                String(cfg.host_workspace).trim(),
                TOOLTIPS.copy.hostWorkspaceCopied
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
        html += copyableDetailRow(
            "DB URL",
            cfg.database_url || "",
            TOOLTIPS.copy.dbUrlCopied
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
            setElementTooltip(
                gen,
                tooltipFormat(TOOLTIPS.generatedAt, {
                    time: formatGeneratedAtLocal(data.generated_at),
                })
            );
        } else {
            gen.textContent = "";
            gen.removeAttribute("title");
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

        var lines =
            '<tr class="instance-table-main-row' +
            (expandable ? " instance-table-row-expandable" : "") +
            '"' +
            (expandable
                ? ' title="' + escapeHtml(TOOLTIPS.expand.tableRow) + '"'
                : "") +
            ">";
        lines +=
            '<td class="cell-status">' + instanceStatusDotHtml(row) + "</td>";
        lines += "<td><strong>" + frameworkNameLinkHtml(fw, web) + "</strong></td>";
        lines +=
            "<td>" +
            healthPill(inst.health, inst.running, "instance") +
            ' <code class="cell-muted">' +
            escapeHtml(row.container_name || "") +
            "</code></td>";
        lines += "<td>";
        if (db.container) {
            lines +=
                healthPill(db.health, db.running, "database") +
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
            renderActionsCell(row) +
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
                escapeHtml(tooltipFormat(TOOLTIPS.link.openNewTab, { url: web })) +
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
                '" target="_blank" rel="noopener" title="' +
                escapeHtml(tooltipFormat(TOOLTIPS.link.frameworkWeb, { url: web })) +
                '">' +
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
            '<button type="button" class="btn btn-accent-folder btn-compact open-workspace-link" data-framework="' +
            escapeHtml(fw) +
            '" title="' +
            escapeHtml(tooltipFormat(TOOLTIPS.link.openFinder, { path: wsTrim })) +
            '">Folder</button>';
        if (dashboardConfig.default_ide_cmd && dashboardConfig.default_ide_label) {
            html +=
                '<button type="button" class="btn btn-accent-secondary btn-compact open-ide-link" data-framework="' +
                escapeHtml(fw) +
                '" title="' +
                escapeHtml(
                    tooltipFormat(TOOLTIPS.link.openIde, {
                        ide: dashboardConfig.default_ide_label,
                        path: wsTrim,
                    })
                ) +
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
            parts.push(
                TOOLTIPS.login.companyPrefix + String(cred.company_id)
            );
        }
        return TOOLTIPS.login.titlePrefix + parts.join(TOOLTIPS.login.titleSeparator);
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
        var fw = row.framework || "";
        var expandable = hasInstanceExtra(row);
        var lines = "";
        lines +=
            '<article class="instance-card' +
            (expandable ? " instance-card-expandable" : "") +
            '"' +
            (expandable ? ' title="' + escapeHtml(TOOLTIPS.expand.card) + '"' : "") +
            ">";
        lines += '<div class="instance-header">';
        lines += '<div class="instance-name">';
        lines += "<h2>" + frameworkNameLinkHtml(fw, web) + "</h2>";
        lines += "</div>";
        lines += instanceStatusDotHtml(row);
        lines += "</div>";

        lines += '<div class="instance-details">';
        lines += '<table class="instance-detail-table"><tbody>';
        lines += detailRow(
            "Instance",
            healthPill(inst.health, inst.running, "instance") +
                " <code>" +
                escapeHtml(row.container_name || "") +
                "</code>"
        );
        if (db.container) {
            lines += detailRow(
                "Database",
                healthPill(db.health, db.running, "database") +
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

        lines += renderActionsCell(row);

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
    document
        .getElementById("btn-status-legend")
        .addEventListener("click", openStatusLegendDialog);
    document.getElementById("status-legend-dialog").addEventListener("click", function (e) {
        if (e.target.closest("[data-legend-close='1']")) {
            closeStatusLegendDialog();
        }
    });
    document.getElementById("site-title-reload").addEventListener("click", function (e) {
        e.preventDefault();
        location.reload();
    });
    document.getElementById("confirm-dialog").addEventListener("click", function (e) {
        var t = e.target.closest("[data-confirm]");
        if (t) {
            finishConfirm(t.getAttribute("data-confirm") === "1");
        }
    });
    document.addEventListener("keydown", function (e) {
        if (e.key !== "Escape") {
            return;
        }
        closeAllActionsDropdowns();
        var legendDlg = document.getElementById("status-legend-dialog");
        if (legendDlg && !legendDlg.hidden) {
            closeStatusLegendDialog();
            return;
        }
        var dlg = document.getElementById("confirm-dialog");
        if (!dlg.hidden) {
            finishConfirm(false);
        }
    });
    document
        .getElementById("theme-toggle")
        .addEventListener("change", onThemeSwitchChange);

    document.addEventListener("click", function (e) {
        if (!e.target.closest(".actions-menu")) {
            closeAllActionsDropdowns();
        }
    });

    document.getElementById("instances").addEventListener("click", function (e) {
        var copyBtn = e.target.closest(".copy-on-click");
        if (copyBtn) {
            e.preventDefault();
            e.stopPropagation();
            handleCopyClick(copyBtn);
            return;
        }

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

        var toggleBtn = e.target.closest(".actions-menu-toggle");
        if (toggleBtn) {
            e.preventDefault();
            e.stopPropagation();
            toggleActionsDropdown(toggleBtn);
            return;
        }

        var zdBtn = e.target.closest(".zd-action-btn");
        if (zdBtn) {
            e.preventDefault();
            e.stopPropagation();
            runZdActionFromButton(zdBtn);
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
    applyStaticTooltips();
    renderStatusLegend();
    initToolbar();
    loadDashboardConfig().then(function () {
        loadStatus();
    });
})();
