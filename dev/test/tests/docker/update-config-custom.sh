#!/bin/bash

# Test Suite for update_config_custom (startup-instance.sh)
# Tests the logic that replaces the block between
#   "# insert your own config settings \"here\"" and
#   "# end of your own config options!!!"
# in Kernel/Config.pm with the content of configs/framework/Config.pm.

set -e

TEST_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$TEST_DIR/utils/assertions.sh"

# Same awk logic as in dev/docker/startup-instance.sh update_config_custom()
# Replaces only the placeholder lines between opening block and next # ---; keeps "data inserted" and "end of your own config options".
run_replace_block() {
    local config_pm="$1"
    local snippet_file="$2"
    local out_file="$3"
    awk -v snippet="$snippet_file" '
        /insert your own config settings/ {
            print
            while ((getline) > 0) {
                print
                if ($0 ~ /^[[:space:]]*#[[:space:]]*-+[[:space:]]*#/) break
            }
            while ((getline line < snippet) > 0) print line
            close(snippet)
            print ""
            skip = 1
            next
        }
        skip && /^[[:space:]]*#[[:space:]]*-+[[:space:]]*#/ { print; skip = 0; next }
        skip { next }
        { print }
    ' "$config_pm" > "$out_file"
}

test_block_replaced_with_snippet() {
    echo ""
    echo "Test: Block replaced with snippet content..."

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" RETURN

    # Config.pm with same structure as Config.pm.dist (opening block, placeholders, then "data inserted" and "end of your own config options")
    cat > "$tmp_dir/Config.pm" << 'CONFIGEOF'
sub Load {
    my $Self = shift;

    # ---------------------------------------------------- #
    # database settings                                    #
    # ---------------------------------------------------- #

    # The database host
    $Self->{DatabaseHost} = '127.0.0.1';

    # The database name
    $Self->{Database} = 'znuny';

    # The database user
    $Self->{DatabaseUser} = 'znuny';

    # The password of database user. You also can use bin/znuny.Console.pl Maint::Database::PasswordCrypt
    # for crypted passwords
    $Self->{DatabasePw} = 'some-pass';

    # The database DSN for MySQL ==> more: "perldoc DBD::mysql"
    $Self->{DatabaseDSN} = "DBI:mysql:database=$Self->{Database};host=$Self->{DatabaseHost};";

    # The database DSN for PostgreSQL ==> more: "perldoc DBD::Pg"
    # if you want to use a local socket connection
#    $Self->{DatabaseDSN} = "DBI:Pg:dbname=$Self->{Database};";
    # if you want to use a TCP/IP connection
#    $Self->{DatabaseDSN} = "DBI:Pg:dbname=$Self->{Database};host=$Self->{DatabaseHost};";

    # The database DSN for Oracle ==> more: "perldoc DBD::oracle"
#    $Self->{DatabaseDSN} = "DBI:Oracle://$Self->{DatabaseHost}:1521/$Self->{Database}";
#
#    $ENV{ORACLE_HOME}     = '/path/to/your/oracle';
#    $ENV{NLS_DATE_FORMAT} = 'YYYY-MM-DD HH24:MI:SS';
#    $ENV{NLS_LANG}        = 'AMERICAN_AMERICA.AL32UTF8';

    # ---------------------------------------------------- #
    # fs root directory
    # ---------------------------------------------------- #
    $Self->{Home} = '/opt/znuny';

    # ---------------------------------------------------- #
    # insert your own config settings "here"               #
    # config settings taken from Kernel/Config/Defaults.pm #
    # ---------------------------------------------------- #
    # $Self->{SessionUseCookie} = 0;
    # $Self->{CheckMXRecord} = 0;

    # ---------------------------------------------------- #

    # ---------------------------------------------------- #
    # data inserted by installer                           #
    # ---------------------------------------------------- #
    # $DIBI$

    # ---------------------------------------------------- #
    # ---------------------------------------------------- #
    #                                                      #
    # end of your own config options!!!                    #
    #                                                      #
    # ---------------------------------------------------- #
    # ---------------------------------------------------- #

    return 1;
}
CONFIGEOF

    # Snippet (like configs/framework/Config.pm)
    cat > "$tmp_dir/snippet.pm" << 'SNIPPETEOF'
    $Self->{'CustomTestSetting'} = 1;
    $Self->{'AnotherSetting'}    = 'injected';
SNIPPETEOF

    run_replace_block "$tmp_dir/Config.pm" "$tmp_dir/snippet.pm" "$tmp_dir/Config.out"

    local result
    result=$(cat "$tmp_dir/Config.out")

    echo "$result"

    # Snippet content must appear
    if ! echo "$result" | grep -q "CustomTestSetting"; then
        print_test_result "snippet_content_inserted" "FAIL" "Expected snippet line CustomTestSetting in output" ""
        return 1
    fi
    print_test_result "snippet_content_inserted" "PASS" "Snippet content appears in output" ""

    if ! echo "$result" | grep -q "AnotherSetting"; then
        print_test_result "snippet_second_line" "FAIL" "Expected snippet line AnotherSetting in output" ""
        return 1
    fi
    print_test_result "snippet_second_line" "PASS" "Second snippet line appears" ""

    # Block "# data inserted by installer" and "# end of your own config options" must remain after snippet
    if ! echo "$result" | grep -q "data inserted by installer"; then
        print_test_result "data_inserted_block_preserved" "FAIL" "Expected '# data inserted by installer' block after snippet" ""
        return 1
    fi
    print_test_result "data_inserted_block_preserved" "PASS" "'# data inserted by installer' block preserved" ""

    if ! echo "$result" | grep -q "end of your own config options"; then
        print_test_result "end_marker_preserved" "FAIL" "Expected 'end of your own config options' block after snippet" ""
        return 1
    fi
    print_test_result "end_marker_preserved" "PASS" "End marker block preserved" ""

    # return 1; must still be there
    if ! echo "$result" | grep -q "return 1;"; then
        print_test_result "return_preserved" "FAIL" "Expected 'return 1;' in Load sub" ""
        return 1
    fi
    print_test_result "return_preserved" "PASS" "return 1; preserved" ""

    # Default placeholder lines must be gone (replaced by snippet)
    if echo "$result" | grep -q "SessionUseCookie"; then
        print_test_result "default_block_removed" "FAIL" "Default # \$Self->{SessionUseCookie} should be replaced" ""
        return 1
    fi
    print_test_result "default_block_removed" "PASS" "Default block removed" ""

    # # $DIBI$ (data inserted by installer) must remain
    if ! echo "$result" | grep -q "DIBI"; then
        print_test_result "installer_placeholder_preserved" "FAIL" "Installer block # \$DIBI\$ should be preserved" ""
        return 1
    fi
    print_test_result "installer_placeholder_preserved" "PASS" "Installer block preserved" ""

    # Order: snippet must appear before "# data inserted by installer" and "end of your own config options"
    local snippet_line data_line end_line
    snippet_line=$(echo "$result" | grep -n "CustomTestSetting" | head -1 | cut -d: -f1)
    data_line=$(echo "$result" | grep -n "data inserted by installer" | head -1 | cut -d: -f1)
    end_line=$(echo "$result" | grep -n "end of your own config options" | head -1 | cut -d: -f1)
    if [ -z "$snippet_line" ] || [ -z "$data_line" ] || [ -z "$end_line" ] || [ "$snippet_line" -ge "$data_line" ] || [ "$data_line" -ge "$end_line" ]; then
        print_test_result "order_snippet_then_blocks" "FAIL" "Order: snippet then data inserted then end marker (snippet=$snippet_line data=$data_line end=$end_line)" ""
        return 1
    fi
    print_test_result "order_snippet_then_blocks" "PASS" "Snippet then data inserted then end marker" ""
}

test_no_markers_unchanged() {
    echo ""
    echo "Test: Config.pm without markers is unchanged..."

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" RETURN

    cat > "$tmp_dir/Config.pm" << 'EOF'
sub Load {
    my $Self = shift;
    return 1;
}
1;
EOF
    echo "    no snippet" > "$tmp_dir/snippet.pm"

    run_replace_block "$tmp_dir/Config.pm" "$tmp_dir/snippet.pm" "$tmp_dir/Config.out"

    if ! diff -q "$tmp_dir/Config.pm" "$tmp_dir/Config.out" >/dev/null 2>&1; then
        print_test_result "no_markers_unchanged" "FAIL" "File without markers should be unchanged" ""
        return 1
    fi
    print_test_result "no_markers_unchanged" "PASS" "Config without markers left unchanged" ""
}

test_header_and_footer_preserved() {
    echo ""
    echo "Test: Lines before and after block preserved..."

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" RETURN

    cat > "$tmp_dir/Config.pm" << 'EOF'
package Kernel::Config;
sub Load {
    my $Self = shift;
    # insert your own config settings "here"
    # config settings taken from Kernel/Config/Defaults.pm
    # ---------------------------------------------------- #
    # $Self->{SessionUseCookie} = 0;
    # ---------------------------------------------------- #
    # end of your own config options!!!
    return 1;
}
1;
EOF
    echo "    \$Self->{'Injected'} = 1;" > "$tmp_dir/snippet.pm"

    run_replace_block "$tmp_dir/Config.pm" "$tmp_dir/snippet.pm" "$tmp_dir/Config.out"

    local result
    result=$(cat "$tmp_dir/Config.out")
    if ! echo "$result" | grep -q "^package Kernel::Config;"; then
        print_test_result "header_preserved" "FAIL" "package Kernel::Config; must be preserved" ""
        return 1
    fi
    print_test_result "header_preserved" "PASS" "Header preserved" ""

    if ! echo "$result" | grep -q "^1;"; then
        print_test_result "footer_preserved" "FAIL" "Trailing 1; must be preserved" ""
        return 1
    fi
    print_test_result "footer_preserved" "PASS" "Footer preserved" ""

    if ! echo "$result" | grep -q "Injected"; then
        print_test_result "snippet_in_middle" "FAIL" "Snippet must be present" ""
        return 1
    fi
    print_test_result "snippet_in_middle" "PASS" "Snippet in middle" ""
}

# Main
run_all_tests() {
    echo "=========================================="
    echo "update_config_custom (startup-instance.sh)"
    echo "=========================================="
    test_block_replaced_with_snippet
    test_no_markers_unchanged
    test_header_and_footer_preserved
    print_test_summary
}

run_all_tests
