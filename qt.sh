#!/usr/bin/env bash
set -Eeuo pipefail

#
# ====== Helpers ======
#
usage() {
    cat <<'EOF'
Usage:
    build   Build the project
            [-t Debug|Release] [-p /path/to/Qt]
    play    Play Application (Play only)
            [-t Debug|Release] [-a <name>]
    run     Build and Play Application
            [-t Debug|Release] [-p /path/to/Qt] [-a <name>]
    fresh   Clean, Build and Play Application
            [-t Debug|Release] [-p /path/to/Qt] [-a <name>]
    clean   Clean build files
            [-t Debug|Release] [--all]

Options:
    -t <type>    Build type (Debug or Release, default: Debug. Can be d/D/r/R)
    -p <path>    Qt installation path (default: from .project.ini or $HOME/Qt/6.9.2/gcc_64)
    -a <name>    Application name (required for 'play', can also be set in .project.ini)
    -h           Show this help
    --all        (clean only) remove all build types + all logs

Environment:
    APP_NAME     Override application name (if not using -a or .project.ini)
    QT_PATH      Override Qt path (if not using -p or .project.ini)
    CC, CXX      Override C and C++ compilers (default: clang/clang++)
EOF
    exit 1
}


#
# ====== Printer ======
#
# Colors (only if stdout is a terminal)
if [[ -t 1 ]]; then
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
    BOLD="\033[1m"
    RESET="\033[0m"
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    RESET=""
fi

is_cmd() { command -v "$1" >/dev/null 2>&1; }
blankline() { echo ""; }
msg() { echo -e "${GREEN}==>${RESET} $*"; }
info() { echo -e "${BLUE}==> INFO:${RESET} $*"; }
warn() { echo -e "${YELLOW}==> WARNING:${RESET} $*"; }
err() { echo -e "${RED}${BOLD}ERROR:${RESET} $*" >&2; exit 1; }

#
# ====== Defaults ======
#
QT_PATH_DEFAULT="$HOME/Qt/6.9.2/gcc_64"
APP_NAME_DEFAULT=""
CC_DEFAULT="clang"
CXX_DEFAULT="clang++"
BUILD_TYPE_DEFAULT="Debug"
GENERATOR_DEFAULT="Unix Makefiles"

#
# ====== Load Project Init ======
#
if [[ -f .project.ini ]]; then
    source .project.ini
fi

#
# ====== Variables ======
# flags > envs > .project.ini > defaults
#
BUILD_TYPE="${BUILD_TYPE:-$BUILD_TYPE_DEFAULT}"
QT_PATH="${QT_PATH:-$QT_PATH_DEFAULT}"
APP_NAME="${APP_NAME:-$APP_NAME_DEFAULT}"
CC="${CC:-$CC_DEFAULT}"
CXX="${CXX:-$CXX_DEFAULT}"
GENERATOR="${GENERATOR:-$GENERATOR_DEFAULT}"

CLEAN_ALL=false

#
# ====== Subcommand ======
#
ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
    echo -e "${RED}${BOLD}ERROR:${RESET} Missing action (build|run|clean...)\n" >&2
    usage
fi
shift || true

#
# ====== Parse Flags ======
#
while [[ $# -gt 0 ]]; do
    case "$1" in
    -t)
        BUILD_TYPE="$2"
        shift 2;;
    -p)
        QT_PATH="$2"
        shift 2;;
    -a)
        APP_NAME="$2"
        shift 2;;
    -h) 
        usage;;
    --all)
        CLEAN_ALL=true
        shift;;
    -*) 
        err "Invalid option: $1";;
    *) 
        break;;
    esac
done

#
# ====== Validate Build Type & Create Build Logs ======
#
case "$BUILD_TYPE" in
    [Dd]) BUILD_TYPE="Debug" ;;
    [Rr]) BUILD_TYPE="Release" ;;
esac

if [[ "$BUILD_TYPE" != "Debug" && "$BUILD_TYPE" != "Release" ]]; then
    err "Invalid build type: $BUILD_TYPE (must be Debug or Release, or d/D/r/R)"
fi

BUILD_DIR="build/${BUILD_TYPE}"
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/build_${BUILD_TYPE}.log"

#
# ====== Pre-checks ======
#
is_cmd cmake || err "Missing 'cmake'. Please install it."

[[ -d "$QT_PATH" ]] || err "Invalid Qt path: $QT_PATH (set with flag -p or QT_PATH env or in .project.ini)"
[[ -n "$APP_NAME" ]] || err "Missing application name (set with flag -a or APP_NAME env or in .project.ini)"

if is_cmd ninja; then
    GENERATOR="Ninja"
fi

for bin in "$CC" "$CXX"; do
    is_cmd "$bin" || err "Missing compiler: $bin"
done

# Detect available cores
if is_cmd nproc; then
    JOBS="$(nproc)"
elif is_cmd sysctl; then
    JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 1)"
else
    JOBS=1
fi
[[ "$JOBS" -ge 1 ]] || JOBS=1

# Show variables configured
info "Project Configuration:"
msg "Build Type: $BUILD_TYPE"
msg "Qt Path: $QT_PATH"
msg "App Name: $APP_NAME"
msg "C Compiler: $CC"
msg "C++ Compiler: $CXX"

if [[ $GENERATOR == "Ninja" ]]; then
    msg "Using Ninja generator"
else
    warn "Ninja not found, using Unix Makefiles generator."
fi

#
# ====== Actions ======
#

### Configure
do_configure() {
    blankline 
    info "Starting configuration..."
    # Check Qt path: Checked above

    local extra_flags=""
    if [[ "$BUILD_TYPE" == "Debug" ]]; then
        extra_flags="-DCMAKE_CXX_FLAGS_INIT=-DQT_QML_DEBUG"
    fi

    msg "Configuring CMake ($BUILD_TYPE) with generator: $GENERATOR"
    cmake -S . -B "${BUILD_DIR}" \
        -DCMAKE_PREFIX_PATH="${QT_PATH}" \
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
        -DCMAKE_C_COMPILER="$CC" \
        -DCMAKE_CXX_COMPILER="$CXX" \
        -DCMAKE_COLOR_DIAGNOSTICS=ON \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -G "${GENERATOR}" \
        $extra_flags

    info "Configuration done."
}

### Build
do_build() {
    blankline
    info "Starting build..."

    # Configure if not yet done
    if [[ ! -f "${BUILD_DIR}/CMakeCache.txt" ]]; then
        do_configure
    fi

    mkdir -p "$LOG_DIR"
    msg "Building ($BUILD_TYPE) with --parallel=${JOBS}${RESET}"
    msg "Logging output to ${YELLOW}$LOG_FILE${RESET}"

    # Reset log file
    : >"$LOG_FILE"

    {
        echo "[ $(date '+%Y-%m-%d %H:%M:%S') ] --- Build started ---"
        if ! cmake --build "${BUILD_DIR}" --parallel "${JOBS}"; then
            echo "[ $(date '+%Y-%m-%d %H:%M:%S') ] --- Build failed ---"
            exit 1
        fi
        echo "[ $(date '+%Y-%m-%d %H:%M:%S') ] --- Build finished ---"
    } 2>&1 | tee -a "$LOG_FILE"

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        err "Build failed. See ${YELLOW}$LOG_FILE${RESET} for details."
    fi

    if [[ -f "${BUILD_DIR}/compile_commands.json" ]]; then
        ln -sfn "${BUILD_DIR}/compile_commands.json" ./compile_commands.json
        msg "Symlink updated: compile_commands.json"
    fi
    msg "${GREEN}${BOLD}Build completed successfully.${RESET}"
}

### play
do_play() {
    blankline
    info "Starting play..."

    local exe="${BUILD_DIR}/${APP_NAME}"
    [[ -x "$exe" ]] || err "Executable not found: $exe (did you run './qt-desktop.sh build -t $BUILD_TYPE' first?)"
    msg "Running $exe"
    "$exe"
}

### run
do_run() {
    blankline
    msg "Running full pipeline: build ($BUILD_TYPE) → run $APP_NAME"
    do_build
    do_play
}

### fresh
do_fresh() {
    blankline
    msg "Fresh pipeline: clean → configure → build ($BUILD_TYPE) → run $APP_NAME"
    do_clean
    do_configure
    do_build
    do_play
}

### clean
do_clean() {
    blankline
    info "Starting clean..."

    if $CLEAN_ALL; then
        msg "Cleaning all build directories and logs"
        rm -rf build "$LOG_DIR" compile_commands.json
    else
        msg "Cleaning ${BUILD_DIR}"
        rm -rf "${BUILD_DIR}"

        if [[ -L "compile_commands.json" ]]; then
            LINK_TARGET="$(readlink compile_commands.json)"
            if [[ "$LINK_TARGET" == "${BUILD_DIR}/compile_commands.json" ]]; then
                rm -f compile_commands.json
                msg "Removed symlink compile_commands.json (was pointing to cleaned build)."
            fi
        fi

        msg "Removing log file: $LOG_FILE"
        rm -f "$LOG_FILE"
    fi

    msg "Removing runtime cache files."
    rm -rf .cache .qmlls.ini

    info "Clean completed."
}

#
# ====== Main ======
#
case "$ACTION" in
build) do_build ;;
play) do_play ;;
run) do_run ;;
fresh) do_fresh ;;
clean) do_clean ;;
*) usage ;;
esac
