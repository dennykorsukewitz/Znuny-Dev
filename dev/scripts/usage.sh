#!/bin/bash

# Znuny Development Environment – Usage & Help
# Main help, examples, dev help, setup help (sourced by znuny-dev.sh)

set -e

# ========================================
# Usage Functions
# ========================================

# Function to show main menu
show_usage() {
    print_header "Znuny Development Environment"
    print_header "============================="
    echo ""
    # ========================================
    # Setup Commands
    # ========================================
    print_subheader "Setup Commands:"
    print_command "setup-status [--verbose]"                 "Show complete setup status overview"
    echo ""
    print_command "setup-all"                                "Setup everything (framework, tools, instance)"
    print_command "setup-remove"                             "Remove all frameworks, tools, and instances"
    echo ""
    print_command "setup-env"                                "Generate global .env file from template"
    print_command "setup-alias"                              "Setup global alias (zd command)"
    print_command "setup-tools"                              "Setup tools (fred, code policy, module tools)"
    print_command "setup-framework [<branch> <directory>]" "Setup framework (optional: branch, dir name)"
    print_command "setup-packages"                           "Setup packages (modules, etc.)"
    print_command "setup-compose"                            "Generate Docker Compose files for all frameworks"
    echo ""
    # ========================================
    # Instance Commands
    # ========================================
    print_subheader "Instance Commands:"
    print_command "status <framework|all> [--verbose]" "Show framework instance or all instance status"
    echo ""
    print_command "create <framework> [options]"       "Create a new framework instance"
    print_command "remove <framework|all> [options]"   "Remove framework instance or all instances"
    print_command "start <framework|all>"              "Start framework instance or all instances"
    print_command "stop <framework|all>"               "Stop framework instance or all instances"
    print_command "restart <framework|all>"            "Restart framework instance or all instances"
    print_command "build <framework|all> [--no-cache]" "Build Docker image for framework instance or all instances"
    echo ""
    print_command "shell <framework> [options]"        "Start shell session in framework container (default: as znuny user)"
    print_command "console <framework> <cmd>"          "Execute console command on framework"
    print_command "random-data-insert <framework> [options]"   "Insert random data (RandomDataInsert); options: --generate-tickets, --articles-per-ticket, etc."
    print_command "log <framework> [log_file]"         "Show framework log from container filesystem"
    print_command "container-log [framework] [lines]"  "Show Docker container log (stdout/stderr)"
    echo ""
    print_command "help"                               "Show help"
    print_command "examples"                           "Show examples for all commands"
    print_command "dev"                                "Show additional development tools and utilities"
    print_command "version"                            "Show version information"
    echo ""

    # ========================================
    # Common Commands
    # ========================================
    print_subheader "Common Commands:"
    print_command "$ZD_CMD delreb <framework>"                 "Maint::Cache::Delete + Maint::Loader::CacheCleanup + Maint::Config::Rebuild --cleanup"
    print_command "$ZD_CMD reb <framework>"                    "Maint::Config::Rebuild --cleanup"
    print_command "$ZD_CMD del <framework>"                    "Maint::Cache::Delete + Maint::Loader::CacheCleanup"
    print_command "$ZD_CMD unit <framework>"                   "Dev::UnitTest::Run --verbose --test"
    print_command "$ZD_CMD translate <framework>"              "Maint::Config::Sync + Maint::Config::Rebuild --cleanup + Dev::Tools::TranslationsUpdate --generate-po"
    print_command "$ZD_CMD contributors <framework>"          "Dev::Code::ContributorsListUpdate"
    print_command "$ZD_CMD random-data-insert <framework>"            "Dev::Tools::Database::RandomDataInsert"
    echo ""

    # ========================================
    # ModuleTools Commands
    # ========================================
    print_subheader "ModuleTools Commands:"
    print_command "$ZD_CMD link <framework> <package> [package ...]"   "Module::File::Link (mehrere Pakete möglich)"
    print_command "$ZD_CMD unlink <framework> <package> [package ...]" "Module::File::Unlink (mehrere Pakete möglich)"
    print_command "$ZD_CMD rmlinks <framework>"                   "Module::File::Unlink --all"
    echo ""
    print_command "$ZD_CMD install <framework> <package>"         "Package Install (dbinstall, codeinstall)"
    print_command "$ZD_CMD uninstall <framework> <package>"       "Package Uninstall (dbuninstall, codeuninstall)"
    echo ""
    print_command "$ZD_CMD dbinstall <framework> <package>"       "Module::Database::Install"
    print_command "$ZD_CMD dbupgrade <framework> <package>"       "Module::Database::Upgrade"
    print_command "$ZD_CMD dbuninstall <framework> <package>"     "Module::Database::Uninstall"
    echo ""
    print_command "$ZD_CMD codeinstall <framework> <package>"     "Module::Code::Install"
    print_command "$ZD_CMD codereinstall <framework> <package>"   "Module::Code::Reinstall"
    print_command "$ZD_CMD codeuninstall <framework> <package>"   "Module::Code::Uninstall"
    print_command "$ZD_CMD codeupgrade <framework> <package>"     "Module::Code::Upgrade"
    echo ""
    print_command "$ZD_CMD module-tools <framework> <command>"
    echo ""

    # ========================================
    # Fred
    # ========================================
    print_subheader "Fred Commands:"
    print_command "$ZD_CMD link-fred <framework>"                 "Link Fred module into framework"
    print_command "$ZD_CMD unlink-fred <framework>"               "Unlink Fred module from framework"
    echo ""
}

# Function to show development tools usage
show_usage_examples() {

    print_header "Znuny Development Examples"
    print_header "==========================="
    echo ""

    print_subheader "Setup Example:"
    echo ""
    print_command "$ZD_CMD setup-status" ""
    print_command "$ZD_CMD setup-status --verbose" ""
    print_command "$ZD_CMD setup-all" ""
    echo ""

    print_subheader "Status Example:"
    echo ""
    print_command "$ZD_CMD status" ""
    print_command "$ZD_CMD status dev" ""
    print_command "$ZD_CMD status all --verbose" ""
    echo ""

    print_subheader "Create Example:"
    echo ""
    print_command "$ZD_CMD create dev" ""
    print_command "$ZD_CMD create prod --url https://github.com/znuny/Znuny.git --branch dev --port 10000 --fqdn localhost --db-type mysql --db-port 3306 --db-name prod_db --db-user prod_user --db-password secret123 --script-alias /prod/ --instance-mode shared" ""
    echo ""

    print_subheader "Remove Example:"
    echo ""
    print_command "$ZD_CMD remove dev" ""
    print_command "$ZD_CMD remove all" ""
    echo ""

    print_subheader "Start | Stop | Restart | Build Example:"
    echo ""
    print_command "$ZD_CMD start dev" ""
    print_command "$ZD_CMD start all" ""
    print_command "$ZD_CMD stop dev" ""
    print_command "$ZD_CMD restart dev" ""
    print_command "$ZD_CMD build dev" ""
    print_command "$ZD_CMD build dev --no-cache" ""
    echo ""

    print_subheader "Shell | Console  | Log Example:"
    echo ""
    print_command "$ZD_CMD shell dev" ""
    print_command "$ZD_CMD console dev Dev::UnitTest::Run" ""
    print_command "$ZD_CMD log dev" ""
    print_command "$ZD_CMD container-log dev 100" ""
    echo ""

    print_subheader "Link Example:"
    echo ""
    print_command "$ZD_CMD link dev FAQ" ""
    print_command "$ZD_CMD unlink dev FAQ" ""
    print_command "$ZD_CMD rmlinks dev" ""
    echo ""

    print_subheader "Install Example:"
    echo ""
    print_command "$ZD_CMD install dev FAQ" ""
    print_command "$ZD_CMD uninstall dev FAQ" ""
    echo ""

    print_subheader "Database Install Example:"
    echo ""
    print_command "$ZD_CMD dbinstall dev FAQ" ""
    print_command "$ZD_CMD dbupgrade dev FAQ" ""
    print_command "$ZD_CMD dbuninstall dev FAQ" ""
    echo ""

    print_subheader "Code Install Example:"
    echo ""
    print_command "$ZD_CMD codeinstall dev FAQ" ""
    print_command "$ZD_CMD codereinstall dev FAQ" ""
    print_command "$ZD_CMD codeuninstall dev FAQ" ""
    print_command "$ZD_CMD codeupgrade dev FAQ" ""
    echo ""

    print_subheader "Common Commands Example:"
    echo ""
    print_command "$ZD_CMD delreb dev" ""
    print_command "$ZD_CMD reb dev" ""
    print_command "$ZD_CMD del dev" ""
    print_command "$ZD_CMD unit dev" ""
    print_command "$ZD_CMD translate dev" ""
    print_command "$ZD_CMD contributors dev" ""
    print_command "$ZD_CMD random-data-insert dev" ""
    echo ""

    print_subheader "Fred Example:"
    echo ""
    print_command "$ZD_CMD link-fred dev" ""
    print_command "$ZD_CMD unlink-fred dev" ""
    echo ""

    print_subheader "Module-Tools (direct) Example:"
    echo ""
    print_command "$ZD_CMD module-tools dev" "List available commands (parameter list)"
    print_command "$ZD_CMD module-tools dev List" ""
    echo ""
    print_command "help"                               "Show help"
    print_command "examples"                           "Show examples for all commands"
    echo ""
}

# Function to show development tools usage
show_usage_dev() {
    print_header "Znuny Development Tools & Utilities"
    print_header "===================================="
    echo ""
    print_subheader "Test Suite Options:"
    print_command "$ZD_CMD test"                    "Run all test suites"
    print_command "$ZD_CMD test --verbose"          "Run tests with detailed output"
    print_command "$ZD_CMD test --test <name>"      "Run specific test suite"
    print_command "$ZD_CMD test --help"             "Show test runner help"
    echo ""
    print_subheader "Release Management Options:"
    print_command "$ZD_CMD release"                 "Update current release information (auto-increment patch version)"
    print_command "$ZD_CMD release <version>"       "Update release to specific version (e.g. 1.0.0)"
    echo ""
    print_subheader "Direct Script Access:"
    print_command "$TEST_DIR/run.sh"  "Direct test runner access"
    print_command "$SCRIPTS_DIR/release.sh"         "Direct release script access"
    echo ""
    print_subheader "Examples:"
    print_command "$ZD_CMD test" "Run all tests"
    print_command "$ZD_CMD test -v -t instance"     "Run instance tests verbose"
    print_command "$ZD_CMD release 1.0.0"           "Update to version 1.0.0"
    echo ""
}

# Function to show setup menu (when .env is missing)
show_usage_setup() {
    print_header "Znuny Development Environment Setup"
    print_header "===================================="
    echo ""
    print_subheader "Setup Commands:"
    print_command "setup-status [--verbose]" "Show complete setup status overview"
    print_command "setup-all" "Setup everything (framework, tools, instance)"
    echo ""
    print_subheader "Utility Commands:"
    print_command "help" "Show help"
    print_command "version" "Show version information"
    echo ""
    print_subheader "Examples:"
    print_command "$ZD_CMD setup-all" ""
    print_command "$ZD_CMD setup-status --verbose" ""
}
