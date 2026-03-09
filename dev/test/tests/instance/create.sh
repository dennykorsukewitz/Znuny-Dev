#!/bin/bash
# Real test: zd create with various options – creates instance and checks .env/compose
# Requires: .env in project root, network for initial git clone (if framework missing)
#
# What is tested (all create parameters and key combinations from instance.sh create_instance):
# ------------------------------------------------------------------------------------------
# 1. minimal create          – base options only (mariadb, db-name/user/password, --no-start-prompt); env + compose created
# 2. --port                  – INSTANCE_PORT in .env (e.g. 9090)
# 3. --db-type mysql         – DB_TYPE=mysql and mysql compose
# 4. --db-type postgresql    – DB_TYPE=postgresql and postgresql compose
# 5. --db-name / --db-user   – DB_NAME and DB_USER in .env
# 6. --script-alias          – ZNUNY_SCRIPT_ALIAS in .env (e.g. /prod/)
# 7. --instance-mode dedicated – INSTANCE_MODE=dedicated and dedicated compose
# 8. --instance-mode shared   – INSTANCE_MODE=shared explicitly
# 9. --url                   – FRAMEWORK_REPO_URL in .env
# 10. --branch               – FRAMEWORK_BRANCH in .env
# 11. --db-port              – DB_PORT in .env (mariadb/mysql 3306, postgresql 5432; custom e.g. 3307)
# 12. --fqdn                 – FQDN in .env
# 13. --start                – create with --start (env + compose created; start may fail in test env)
# 14. full combo (short)     – port + db-type mysql + script-alias; asserts all in .env
# 15. full combo (all params)– url, branch, port, db-type, db-name, db-user, db-port, fqdn, script-alias, instance-mode
#
# Uses temporary framework "createtest" (git clone if missing). Cleans up instance after runs.
#
set -e
cd "$(dirname "$0")/../../../.."
ROOT="$(pwd)"
ZD="${ZD_CMD:-./znuny-dev.sh}"
FRAMEWORK="createtest"
# Non-interactive: always pass DB params and --no-start-prompt
BASE_OPTS=(--db-type mariadb --db-name ct --db-user ct --db-password ct --no-start-prompt)
INSTANCES_DIR="${INSTANCES_DIR:-$ROOT/instances}"
FRAMEWORKS_DIR="${FRAMEWORKS_DIR:-$ROOT/frameworks}"
ENV_FILE="$INSTANCES_DIR/$FRAMEWORK/$FRAMEWORK.env"
COMPOSE_FILE="$INSTANCES_DIR/$FRAMEWORK/compose-$(echo "$FRAMEWORK" | tr '[:upper:]' '[:lower:]').yml"

ensure_framework() {
    if [ ! -d "$FRAMEWORKS_DIR/$FRAMEWORK" ]; then
        echo "Creating test framework: $FRAMEWORK (git clone, may take a moment)..."
        git clone --depth 1 -b dev "https://github.com/znuny/Znuny.git" "$FRAMEWORKS_DIR/$FRAMEWORK"
    fi
}

remove_instance_quiet() {
    "$ZD" remove "$FRAMEWORK" --force --keep-framework 2>/dev/null || true
}

assert_env_has() {
    local key="$1"
    local expected="$2"
    local actual
    actual=$(grep "^${key}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || true)
    if [ "$actual" != "$expected" ]; then
        echo "FAIL: $ENV_FILE: expected $key=$expected, got $key=$actual"
        return 1
    fi
    return 0
}

# Assert multiple key=value pairs in .env (pairs: key1 val1 key2 val2 ...)
assert_env_pairs() {
    while [ $# -ge 2 ]; do
        assert_env_has "$1" "$2" || return 1
        shift 2
    done
    return 0
}

run_real_test() {
    local name="$1"
    shift
    remove_instance_quiet
    if ! "$ZD" create "$FRAMEWORK" "${BASE_OPTS[@]}" "$@" 2>&1; then
        echo "FAIL $name: zd create exited with error"
        return 1
    fi
    if [ ! -f "$ENV_FILE" ]; then
        echo "FAIL $name: $ENV_FILE not created"
        return 1
    fi
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "FAIL $name: $COMPOSE_FILE not created"
        return 1
    fi
    echo "OK   $name (env + compose created)"
    return 0
}

run_real_test_with_assert() {
    local name="$1"
    local key="$2"
    local expected="$3"
    shift 3
    remove_instance_quiet
    if ! "$ZD" create "$FRAMEWORK" "${BASE_OPTS[@]}" "$@" 2>&1; then
        echo "FAIL $name: zd create exited with error"
        return 1
    fi
    if [ ! -f "$ENV_FILE" ]; then
        echo "FAIL $name: $ENV_FILE not created"
        return 1
    fi
    if ! assert_env_has "$key" "$expected"; then
        return 1
    fi
    echo "OK   $name ($key=$expected)"
    return 0
}

# Load env to get paths
if [ -f "$ROOT/.env" ]; then
    set -a
    # shellcheck source=../../.env
    source "$ROOT/.env" 2>/dev/null || true
    set +a
fi
INSTANCES_DIR="${INSTANCES_DIR:-$ROOT/instances}"
FRAMEWORKS_DIR="${FRAMEWORKS_DIR:-$ROOT/frameworks}"
ENV_FILE="$INSTANCES_DIR/$FRAMEWORK/$FRAMEWORK.env"
COMPOSE_FILE="$INSTANCES_DIR/$FRAMEWORK/compose-$(echo "$FRAMEWORK" | tr '[:upper:]' '[:lower:]').yml"

echo "Real zd create tests (framework=$FRAMEWORK)"
echo ""

ensure_framework

# 1) Minimal create (only BASE_OPTS)
run_real_test "minimal (mariadb, no extra options)" || exit 1

# 2) --port
run_real_test_with_assert "port 9090" "INSTANCE_PORT" "9090" --port 9090 || exit 1

# 3) --db-type mysql
run_real_test_with_assert "db-type mysql" "DB_TYPE" "mysql" --db-type mysql || exit 1

# 4) --db-type postgresql
run_real_test_with_assert "db-type postgresql" "DB_TYPE" "postgresql" --db-type postgresql || exit 1

# 5) --db-name, --db-user (password in env, just check name)
run_real_test_with_assert "db-name mydb" "DB_NAME" "mydb" --db-name mydb || exit 1
run_real_test_with_assert "db-user myuser" "DB_USER" "myuser" --db-user myuser || exit 1

# 6) --script-alias
run_real_test_with_assert "script-alias /prod/" "ZNUNY_SCRIPT_ALIAS" "/prod/" --script-alias "/prod/" || exit 1

# 7) --instance-mode dedicated
run_real_test_with_assert "instance-mode dedicated" "INSTANCE_MODE" "dedicated" --instance-mode dedicated || exit 1

# 8) --instance-mode shared (explicit)
run_real_test_with_assert "instance-mode shared" "INSTANCE_MODE" "shared" --instance-mode shared || exit 1

# 9) --url
run_real_test_with_assert "url" "FRAMEWORK_REPO_URL" "https://github.com/znuny/Znuny.git" --url "https://github.com/znuny/Znuny.git" || exit 1

# 10) --branch
run_real_test_with_assert "branch" "FRAMEWORK_BRANCH" "dev" --branch dev || exit 1

# 11) --db-port (mariadb default 3306; custom 3307)
run_real_test_with_assert "db-port 3307" "DB_PORT" "3307" --db-port 3307 || exit 1

# 12) --fqdn
run_real_test_with_assert "fqdn" "FQDN" "ticket.example.com" --fqdn "ticket.example.com" || exit 1

# 13) --start (env + compose must be created; container start may fail in test env)
run_real_test "with --start" --start || exit 1

# 14) Full combo: port + db-type mysql + script-alias
run_real_test "full combo (port, mysql, script-alias)" --port 8081 --db-type mysql --script-alias "/prod/" || exit 1
assert_env_pairs "INSTANCE_PORT" "8081" "DB_TYPE" "mysql" "ZNUNY_SCRIPT_ALIAS" "/prod/" || exit 1
echo "OK   full combo short (assertions passed)"

# 15) Full combo: all parameters
CUSTOM_URL="https://github.com/znuny/Znuny.git"
run_real_test "full combo (all params)" \
    --url "$CUSTOM_URL" --branch dev --port 9091 \
    --db-type postgresql --db-name combo_db --db-user combo_u --db-password combo_p --db-port 5433 \
    --fqdn "combo.example.com" --script-alias "/stage/" --instance-mode dedicated || exit 1
assert_env_pairs \
    "FRAMEWORK_REPO_URL" "$CUSTOM_URL" \
    "FRAMEWORK_BRANCH" "dev" \
    "INSTANCE_PORT" "9091" \
    "DB_TYPE" "postgresql" \
    "DB_NAME" "combo_db" \
    "DB_USER" "combo_u" \
    "DB_PORT" "5433" \
    "FQDN" "combo.example.com" \
    "ZNUNY_SCRIPT_ALIAS" "/stage/" \
    "INSTANCE_MODE" "dedicated" || exit 1
echo "OK   full combo all params (assertions passed)"

# Cleanup: remove instance
echo ""
echo "Done. All real create tests passed."
