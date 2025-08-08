#!/bin/bash

# Build script for mongory-rb with mongory-core submodule
# This script handles submodule initialization, dependency checking, and C extension compilation

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CORE_DIR="$PROJECT_ROOT/ext/mongory_ext/mongory-core"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system dependencies
check_dependencies() {
    log $BLUE "🔍 Checking system dependencies..."

    local missing_deps=()

    # Check for required tools
    if ! command_exists git; then
        missing_deps+=("git")
    fi

    if ! command_exists make; then
        missing_deps+=("make")
    fi

    if ! command_exists gcc && ! command_exists clang; then
        missing_deps+=("gcc or clang")
    fi

    # Check for pkg-config (optional)
    if ! command_exists pkg-config; then
        missing_deps+=("pkg-config")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log $RED "❌ Missing dependencies: ${missing_deps[*]}"
        log $YELLOW "Please install the missing dependencies:"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            log $BLUE "  macOS (Homebrew): brew install ${missing_deps[*]// /}"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command_exists apt; then
                log $BLUE "  Ubuntu/Debian: sudo apt update && sudo apt install build-essential pkg-config"
            elif command_exists yum; then
                log $BLUE "  CentOS/RHEL: sudo yum install gcc make pkg-config"
            elif command_exists dnf; then
                log $BLUE "  Fedora: sudo dnf install gcc make pkg-config"
            fi
        fi

        exit 1
    fi

    log $GREEN "✅ All dependencies found"
}

# Function to initialize/update submodules
init_submodules() {
    log $BLUE "📥 Initializing/updating submodules..."

    cd "$PROJECT_ROOT"

    if [ ! -d "$CORE_DIR" ] || [ ! "$(ls -A "$CORE_DIR")" ]; then
        log $YELLOW "Submodule not initialized, initializing now..."
        git submodule update --init --recursive
    else
        log $YELLOW "Updating existing submodule..."
        git submodule update --recursive
    fi

    if [ ! -f "$CORE_DIR/README.md" ]; then
        log $RED "❌ Failed to initialize mongory-core submodule"
        exit 1
    fi

    log $GREEN "✅ Submodule initialized/updated successfully"
}

# Function to build mongory-core if needed
build_core() {
    # mongory-rb 直接由 extconf.rb 編譯 mongory-core 的源碼，不需要獨立建置靜態庫
    # 同時避免觸發 mongory-core 的 CMake（其需要 cJSON 僅用於測試）
    log $YELLOW "Skipping mongory-core standalone build (not required for mongory-rb)"
}

# Function to build the Ruby C extension
build_extension() {
    log $BLUE "🔨 Building Ruby C extension..."

    cd "$PROJECT_ROOT"

    # Clean previous builds
    if [ -d "ext/mongory_ext/Makefile" ]; then
        cd ext/mongory_ext
        make clean 2>/dev/null || true
        cd "$PROJECT_ROOT"
    fi

    # Build the extension
    cd ext/mongory_ext

    # Set DEBUG flag if requested
    if [[ "$1" == "--debug" ]]; then
        export DEBUG=1
        log $YELLOW "Building in debug mode..."
    fi

    ruby extconf.rb
    make

    if [ $? -eq 0 ]; then
        log $GREEN "✅ C extension built successfully"
    else
        log $RED "❌ Failed to build C extension"
        exit 1
    fi

    cd "$PROJECT_ROOT"
}

# Function to run tests
run_tests() {
    log $BLUE "🧪 Running tests..."

    cd "$PROJECT_ROOT"

    # Run Ruby tests
    if command_exists bundle; then
        bundle exec rspec
    else
        rspec
    fi

    if [ $? -eq 0 ]; then
        log $GREEN "✅ All tests passed"
    else
        log $RED "❌ Some tests failed"
        exit 1
    fi
}

# Function to clean build artifacts
clean() {
    log $BLUE "🧹 Cleaning build artifacts..."

    cd "$PROJECT_ROOT"

    # Clean C extension
    if [ -d "ext/mongory_ext" ]; then
        cd ext/mongory_ext
        make clean 2>/dev/null || true
        rm -f Makefile *.o foundations/*.o matchers/*.o mongory_ext.so
        cd "$PROJECT_ROOT"
    fi

    # Clean mongory-core build
    if [ -d "$CORE_DIR/build" ]; then
        rm -rf "$CORE_DIR/build"
    fi

    log $GREEN "✅ Cleaned build artifacts"
}

# Function to display help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Build script for mongory-rb with mongory-core submodule integration.

OPTIONS:
  --help          Show this help message
  --clean         Clean build artifacts and exit
  --debug         Build in debug mode
  --no-deps       Skip dependency checking
  --no-tests      Skip running tests
  --force-rebuild Force rebuild of everything

EXAMPLES:
  $0                    # Normal build
  $0 --debug            # Debug build
  $0 --clean            # Clean only
  $0 --no-tests         # Build without running tests

EOF
}

# Main execution flow
main() {
    local clean_only=false
    local skip_deps=false
    local skip_tests=false
    local force_rebuild=false
    local debug_mode=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                exit 0
                ;;
            --clean)
                clean_only=true
                shift
                ;;
            --debug)
                debug_mode=true
                shift
                ;;
            --no-deps)
                skip_deps=true
                shift
                ;;
            --no-tests)
                skip_tests=true
                shift
                ;;
            --force-rebuild)
                force_rebuild=true
                shift
                ;;
            *)
                log $RED "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    log $GREEN "🚀 Starting mongory-rb build process..."

    # Clean and exit if requested
    if $clean_only; then
        clean
        exit 0
    fi

    # Force rebuild if requested
    if $force_rebuild; then
        clean
    fi

    # Check dependencies unless skipped
    if ! $skip_deps; then
        check_dependencies
    fi

    # Initialize submodules
    init_submodules

    # Build mongory-core
    build_core

    # Build Ruby C extension
    if $debug_mode; then
        build_extension --debug
    else
        build_extension
    fi

    # Run tests unless skipped
    if ! $skip_tests; then
        run_tests
    fi

    log $GREEN "🎉 Build completed successfully!"
    log $BLUE "You can now use mongory-rb with C extension support."
}

# Run main function with all arguments
main "$@"
