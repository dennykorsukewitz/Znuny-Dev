/**
 * Optional mock payload for /api/status (dashboard layout / cards / table testing).
 *
 * Enable: uncomment <script src="/mock-status-data.js"></script> in index.html (before app.js).
 * Disable: comment that script tag out again.
 *
 * Created / start times: port 10000 = oldest (2026-04-07), each +1 day through 10009 (2026-04-16).
 * UI shows started_at when set (see formatCreated in app.js). Mock generated_at is 2026-04-17.
 */

function mockLoginUrl(entryUrl, login, password) {
    if (!entryUrl || !login) {
        return "";
    }
    var sep = entryUrl.indexOf("?") >= 0 ? "&" : "?";
    var url =
        entryUrl +
        sep +
        "Action=Login&User=" +
        encodeURIComponent(login);
    if (password) {
        url += "&Password=" + encodeURIComponent(password);
    }
    return url;
}

function mockPaths(port) {
    var base = "http://localhost:" + port;
    return {
        znuny_script_alias: "/dev/",
        apache_script_alias: "/znuny/",
        config_script_alias: "znuny/",
        frontend_web_path: "/znuny-web/",
        agent: base + "/znuny/index.pl",
        customer: base + "/znuny/customer.pl",
        public: base + "/znuny/public.pl",
    };
}

function mockAccess(paths) {
    return {
        root: {
            login: "root@localhost",
            password: "root",
            login_url: mockLoginUrl(
                paths.agent,
                "root@localhost",
                "root"
            ),
        },
        agent: {
            login: "agent",
            password: "agent",
            login_url: mockLoginUrl(paths.agent, "agent", "agent"),
        },
        customer: {
            login: "customer",
            password: "customer",
            company_id: "DevCompany",
            login_url: mockLoginUrl(
                paths.customer,
                "customer",
                "customer"
            ),
        },
    };
}

function mockCli(framework) {
    return {
        zd_cmd: "zd",
        console: "zd console " + framework,
        shell: "zd shell " + framework,
    };
}

/** paths, access, cli, host_workspace, framework_version for mock instances. */
function mockRuntimeFields(framework, port, frameworkVersion) {
    var paths = mockPaths(port);
    return {
        host_workspace:
            "/Users/example/workspace/znuny/frameworks/" + framework,
        framework_version: frameworkVersion,
        paths: paths,
        access: mockAccess(paths),
        cli: mockCli(framework),
    };
}

function getZnunyDashboardStatusMock() {
    var devPaths = mockPaths("10000");
    return {
        generated_at: "2026-04-17T14:00:00Z",
        instances: [
            /* 1 — dev (green) */
            {
                framework: "dev",
                port: "10000",
                container_name: "znuny-dev-instance",
                instance: {
                    running: true,
                    docker_status: "Up 10 days (healthy)",
                    started_at: "2026-04-07T08:00:00.000000000Z",
                    created_at: "2026-04-07T07:59:55.000000000Z",
                    health: "healthy",
                },
                database: {
                    container: "znuny-mariadb",
                    running: true,
                    docker_status: "Up 10 days (healthy)",
                    health: "healthy",
                },
                configuration: {
                    framework_index: "0",
                    framework_name: "dev",
                    web_interface: "http://localhost:10000",
                    http_port: "10000",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://dev:dev@127.0.0.1:3307/dev",
                    instance_mode: "shared",
                    git_branch: "dev",
                    directory: "/znuny-dev/instances/dev",
                    host_workspace: "/Users/example/workspace/znuny/frameworks/dev",
                    framework_version: "7.3.x",
                },
                paths: devPaths,
                access: mockAccess(devPaths),
                cli: mockCli("dev"),
                verbose: null,
            },
            /* 2 — lts (green) */
            (function () {
                var fw = "lts";
                var paths = mockPaths("10001");
                return {
                framework: fw,
                port: "10001",
                container_name: "znuny-lts-instance",
                instance: {
                    running: true,
                    docker_status: "Up 9 days (healthy)",
                    started_at: "2026-04-08T08:00:00.000000000Z",
                    created_at: "2026-04-08T07:59:55.000000000Z",
                    health: "healthy",
                },
                database: {
                    container: "znuny-lts-mariadb",
                    running: true,
                    docker_status: "Up 9 days (healthy)",
                    health: "healthy",
                },
                configuration: {
                    framework_index: "1",
                    framework_name: fw,
                    web_interface: "http://localhost:10001",
                    http_port: "10001",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://lts:lts@127.0.0.1:3307/lts",
                    instance_mode: "shared",
                    git_branch: "lts",
                    directory: "/znuny-dev/instances/lts",
                    host_workspace: "/Users/example/workspace/znuny/frameworks/lts",
                    framework_version: "7.2.x",
                },
                paths: paths,
                access: mockAccess(paths),
                cli: mockCli(fw),
                verbose: null,
                };
            })(),
            /* 3 — rel-6_5-dev (green) */
            (function () {
                var fw = "rel-6_5-dev";
                var rt = mockRuntimeFields(fw, "10002", "6.5.x");
                return {
                framework: fw,
                port: "10002",
                container_name: "znuny-rel-6_5-dev-instance",
                instance: {
                    running: true,
                    docker_status: "Up 8 days (healthy)",
                    started_at: "2026-04-09T08:00:00.000000000Z",
                    created_at: "2026-04-09T07:59:55.000000000Z",
                    health: "healthy",
                },
                database: {
                    container: "znuny-rel-6_5-dev-mariadb",
                    running: true,
                    docker_status: "Up 8 days (healthy)",
                    health: "healthy",
                },
                configuration: {
                    framework_index: "2",
                    framework_name: fw,
                    web_interface: "http://localhost:10002",
                    http_port: "10002",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://rel65:dev@127.0.0.1:3307/rel_6_5_dev",
                    instance_mode: "shared",
                    git_branch: "dev",
                    directory: "/znuny-dev/instances/rel-6_5-dev",
                    host_workspace: rt.host_workspace,
                    framework_version: rt.framework_version,
                },
                paths: rt.paths,
                access: rt.access,
                cli: rt.cli,
                verbose: null,
                };
            })(),
            /* 4 — rel-7_3-dev */
            (function () {
                var fw = "rel-7_3-dev";
                var rt = mockRuntimeFields(fw, "10003", "7.3.x");
                return {
                framework: fw,
                port: "10003",
                container_name: "znuny-rel-7_3-dev-instance",
                instance: {
                    running: true,
                    docker_status: "Restarting (starting)",
                    started_at: "2026-04-10T08:00:00.000000000Z",
                    created_at: "2026-04-10T07:59:55.000000000Z",
                    health: "unhealthy",
                },
                database: {
                    container: "znuny-rel-7_3-dev-mariadb",
                    running: true,
                    docker_status: "Up 7 days (healthy)",
                    health: "healthy",
                },
                configuration: {
                    framework_index: "3",
                    framework_name: fw,
                    web_interface: "http://localhost:10003",
                    http_port: "10003",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://rel-7_3-dev:rel-7_3-dev@127.0.0.1:3307/rel-7_3-dev",
                    instance_mode: "dedicated",
                    git_branch: "main",
                    directory: "/znuny-dev/instances/rel-7_3-dev",
                    host_workspace: rt.host_workspace,
                    framework_version: rt.framework_version,
                },
                paths: rt.paths,
                access: rt.access,
                cli: rt.cli,
                verbose: null,
                };
            })(),
            /* 5 — demo */
            (function () {
                var fw = "demo";
                var rt = mockRuntimeFields(fw, "10004", "7.3.x");
                return {
                framework: fw,
                port: "10004",
                container_name: "znuny-demo-instance",
                instance: {
                    running: true,
                    docker_status: "Up 6 days (healthy)",
                    started_at: "2026-04-11T08:00:00.000000000Z",
                    created_at: "2026-04-11T07:59:55.000000000Z",
                    health: "healthy",
                },
                database: {
                    container: "znuny-demo-mariadb",
                    running: true,
                    docker_status: "Up 6 days (healthy)",
                    health: "healthy",
                },
                configuration: {
                    framework_index: "4",
                    framework_name: fw,
                    web_interface: "http://localhost:10004",
                    http_port: "10004",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://demo:demo@127.0.0.1:3307/demo",
                    instance_mode: "shared",
                    git_branch: "main",
                    directory: "/znuny-dev/instances/demo",
                    host_workspace: rt.host_workspace,
                    framework_version: rt.framework_version,
                },
                paths: rt.paths,
                access: rt.access,
                cli: rt.cli,
                verbose: null,
                };
            })(),
            /* 6 — itsm */
            (function () {
                var fw = "itsm";
                var rt = mockRuntimeFields(fw, "10005", "7.3.x");
                return {
                framework: fw,
                port: "10005",
                container_name: "znuny-itsm-instance",
                instance: {
                    running: true,
                    docker_status: "Up 5 days (healthy)",
                    started_at: "2026-04-12T08:00:00.000000000Z",
                    created_at: "2026-04-12T07:59:55.000000000Z",
                    health: "healthy",
                },
                database: {
                    container: "znuny-itsm-mariadb",
                    running: true,
                    docker_status: "Up 5 days (healthy)",
                    health: "healthy",
                },
                configuration: {
                    framework_index: "5",
                    framework_name: fw,
                    web_interface: "http://localhost:10005",
                    http_port: "10005",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://itsm:itsm@127.0.0.1:3307/itsm",
                    instance_mode: "shared",
                    git_branch: "develop",
                    directory: "/znuny-dev/instances/itsm",
                    host_workspace: rt.host_workspace,
                    framework_version: rt.framework_version,
                },
                paths: rt.paths,
                access: rt.access,
                cli: rt.cli,
                verbose: null,
                };
            })(),
            /* 7 — sandbox */
            (function () {
                var fw = "sandbox-qa";
                var rt = mockRuntimeFields(fw, "10006", "7.3.x");
                return {
                framework: fw,
                port: "10006",
                container_name: "znuny-sandbox-qa-instance",
                instance: {
                    running: false,
                    docker_status: "",
                    started_at: "",
                    created_at: "2026-04-13T07:59:55.000000000Z",
                    health: "stopped",
                },
                database: {
                    container: "znuny-sandbox-qa-mariadb",
                    running: false,
                    docker_status: "",
                    health: "stopped",
                },
                configuration: {
                    framework_index: "6",
                    framework_name: fw,
                    web_interface: "http://localhost:10006",
                    http_port: "10006",
                    database: "mariadb (Port: 3310)",
                    database_url:
                        "mysql://qa:qa@127.0.0.1:3307/sandbox_qa",
                    instance_mode: "dedicated",
                    git_branch: "develop",
                    directory: "/znuny-dev/instances/sandbox-qa",
                    host_workspace: rt.host_workspace,
                    framework_version: rt.framework_version,
                },
                paths: rt.paths,
                access: rt.access,
                cli: rt.cli,
                verbose: null,
                };
            })(),
            /* 8 — bugfix */
            (function () {
                var fw = "bugfix";
                var rt = mockRuntimeFields(fw, "10007", "7.3.x");
                return {
                framework: fw,
                port: "10007",
                container_name: "znuny-bugfix-instance",
                instance: {
                    running: true,
                    docker_status:
                        "Up 3 days (healthy) — very long status text for layout overflow testing",
                    started_at: "2026-04-14T08:00:00.000000000Z",
                    created_at: "2026-04-14T07:59:55.000000000Z",
                    health: "healthy",
                },
                database: {
                    container: "znuny-bugfix-mariadb",
                    running: true,
                    docker_status: "Up 3 days (healthy)",
                    health: "healthy",
                },
                configuration: {
                    framework_index: "7",
                    framework_name: fw,
                    web_interface: "http://localhost:10007",
                    http_port: "10007",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://bugfix:bugfix@127.0.0.1:3307/bugfix",
                    instance_mode: "shared",
                    git_branch: "main",
                    directory: "/znuny-dev/instances/bugfix",
                    host_workspace: rt.host_workspace,
                    framework_version: rt.framework_version,
                },
                paths: rt.paths,
                access: rt.access,
                cli: rt.cli,
                verbose: null,
                };
            })(),
            /* 9 — customer */
            (function () {
                var fw = "customer-dk";
                var rt = mockRuntimeFields(fw, "10008", "7.3.x");
                return {
                framework: fw,
                port: "10008",
                container_name: "znuny-customer-dk-instance",
                instance: {
                    running: true,
                    docker_status: "Up 2 minutes (unhealthy)",
                    started_at: "2026-04-15T08:00:00.000000000Z",
                    created_at: "2026-04-15T07:59:55.000000000Z",
                    health: "unhealthy",
                },
                database: {
                    container: "znuny-mariadb-shared",
                    running: true,
                    docker_status: "Up 2 days (healthy)",
                    health: "healthy",
                },
                configuration: {
                    framework_index: "8",
                    framework_name: fw,
                    web_interface: "http://localhost:10008",
                    http_port: "10008",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://berlin:berlin@127.0.0.1:3307/berlin",
                    instance_mode: "shared",
                    git_branch: "feature/tickets-42",
                    directory: "/znuny-dev/instances/customer-dk",
                    host_workspace: rt.host_workspace,
                    framework_version: rt.framework_version,
                },
                paths: rt.paths,
                access: rt.access,
                cli: rt.cli,
                verbose: null,
                };
            })(),
            /* 10 — customer */
            (function () {
                var fw = "customer-ak";
                var rt = mockRuntimeFields(fw, "10009", "7.3.x");
                return {
                framework: fw,
                port: "10009",
                container_name: "znuny-customer-ak-instance",
                instance: {
                    running: true,
                    docker_status: "Up 1 day (healthy)",
                    started_at: "2026-04-16T08:00:00.000000000Z",
                    created_at: "2026-04-16T07:59:55.000000000Z",
                    health: "healthy",
                },
                database: {
                    container: "znuny-customer-ak-postgres",
                    running: true,
                    docker_status: "Up 1 day (healthy)",
                    health: "no-health-check",
                },
                configuration: {
                    framework_index: "9",
                    framework_name: fw,
                    web_interface: "http://localhost:10009",
                    http_port: "10009",
                    database: "postgresql (Port: 5432)",
                    database_url:
                        "postgresql://partner:partner@127.0.0.1:5433/partner_x",
                    instance_mode: "shared",
                    git_branch: "partner/custom-theme",
                    directory: "/znuny-dev/instances/customer-ak",
                    host_workspace: rt.host_workspace,
                    framework_version: rt.framework_version,
                },
                paths: rt.paths,
                access: rt.access,
                cli: rt.cli,
                verbose: null,
                };
            })(),
        ],
    };
}
