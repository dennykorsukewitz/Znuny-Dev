/**
 * Optional mock payload for /api/status (dashboard layout / cards / table testing).
 *
 * Enable: uncomment <script src="/mock-status-data.js"></script> in index.html (before app.js).
 * Disable: comment that script tag out again.
 *
 * Created / start times: port 10000 = oldest (2026-04-07), each +1 day through 10009 (2026-04-16).
 * UI shows started_at when set (see formatCreated in app.js). Mock generated_at is 2026-04-17.
 */
function getZnunyDashboardStatusMock() {
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
                },
                verbose: null,
            },
            /* 2 — lts (green) */
            {
                framework: "lts",
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
                    framework_name: "lts",
                    web_interface: "http://localhost:10001",
                    http_port: "10001",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://lts:lts@127.0.0.1:3307/lts",
                    instance_mode: "shared",
                    git_branch: "lts",
                    directory: "/znuny-dev/instances/lts",
                },
                verbose: null,
            },
            /* 3 — rel-6_5-dev (green) */
            {
                framework: "rel-6_5-dev",
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
                    framework_name: "rel-6_5-dev",
                    web_interface: "http://localhost:10002",
                    http_port: "10002",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://rel65:dev@127.0.0.1:3307/rel_6_5_dev",
                    instance_mode: "shared",
                    git_branch: "dev",
                    directory: "/znuny-dev/instances/rel-6_5-dev",
                },
                verbose: null,
            },
            /* 4 — rel-7_3-dev */
            {
                framework: "rel-7_3-dev",
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
                    framework_name: "rel-7_3-dev",
                    web_interface: "http://localhost:10003",
                    http_port: "10003",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://rel-7_3-dev:rel-7_3-dev@127.0.0.1:3307/rel-7_3-dev",
                    instance_mode: "dedicated",
                    git_branch: "main",
                    directory: "/znuny-dev/instances/rel-7_3-dev",
                },
                verbose: null,
            },
            /* 5 — demo */
            {
                framework: "demo",
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
                    framework_name: "demo",
                    web_interface: "http://localhost:10004",
                    http_port: "10004",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://demo:demo@127.0.0.1:3307/demo",
                    instance_mode: "shared",
                    git_branch: "main",
                    directory: "/znuny-dev/instances/demo",
                },
                verbose: null,
            },
            /* 6 — itsm */
            {
                framework: "itsm",
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
                    framework_name: "itsm",
                    web_interface: "http://localhost:10005",
                    http_port: "10005",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://itsm:itsm@127.0.0.1:3307/itsm",
                    instance_mode: "shared",
                    git_branch: "develop",
                    directory: "/znuny-dev/instances/itsm",
                },
                verbose: null,
            },
            /* 7 — sandbox */
            {
                framework: "sandbox-qa",
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
                    framework_name: "sandbox-qa",
                    web_interface: "http://localhost:10006",
                    http_port: "10006",
                    database: "mariadb (Port: 3310)",
                    database_url:
                        "mysql://qa:qa@127.0.0.1:3307/sandbox_qa",
                    instance_mode: "dedicated",
                    git_branch: "develop",
                    directory: "/znuny-dev/instances/sandbox-qa",
                },
                verbose: null,
            },
            /* 8 — bugfix */
            {
                framework: "bugfix",
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
                    framework_name: "bugfix",
                    web_interface: "http://localhost:10007",
                    http_port: "10007",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://bugfix:bugfix@127.0.0.1:3307/bugfix",
                    instance_mode: "shared",
                    git_branch: "main",
                    directory: "/znuny-dev/instances/bugfix",
                },
                verbose: null,
            },
            /* 9 — customer */
            {
                framework: "customer-dk",
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
                    framework_name: "customer-dk",
                    web_interface: "http://localhost:10008",
                    http_port: "10008",
                    database: "mariadb (Port: 3306)",
                    database_url:
                        "mysql://berlin:berlin@127.0.0.1:3307/berlin",
                    instance_mode: "shared",
                    git_branch: "feature/tickets-42",
                    directory: "/znuny-dev/instances/customer-dk",
                },
                verbose: null,
            },
            /* 10 — customer */
            {
                framework: "customer-ak",
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
                    framework_name: "customer-ak",
                    web_interface: "http://localhost:10009",
                    http_port: "10009",
                    database: "postgresql (Port: 5432)",
                    database_url:
                        "postgresql://partner:partner@127.0.0.1:5433/partner_x",
                    instance_mode: "shared",
                    git_branch: "partner/custom-theme",
                    directory: "/znuny-dev/instances/customer-ak",
                },
                verbose: null,
            },
        ],
    };
}
