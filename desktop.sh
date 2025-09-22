#!/usr/bin/env bash
set -Eeuo pipefail

# ====== Helpers ======
usage() {
    cat <<'EOF'
Usage:
    ./qt.sh build   Build the project
                    [-t Debug|Release] [-p /path/to/Qt]
    ./qt.sh play    Play Application (Play only)
                    [-t Debug|Release] [-a <name>]
    ./qt.sh run     Build and Play Application
                    [-t Debug|Release] [-p /path/to/Qt] [-a <name>]
    ./qt.sh fresh   Clean, Build and Play Application
                    [-t Debug|Release] [-p /path/to/Qt] [-a <name>]
    ./qt.sh clean   Clean build files
                    [-t Debug|Release] [--all]

Options:
    -t <type>    Build type (Debug or Release, default: Debug)
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

msg() { echo -e "${GREEN}==>${RESET} $*"; }
err() {
    echo -e "${RED}${BOLD}ERROR:${RESET} $*" >&2
    exit 1
}

# ====== Defaults ======
BUILD_TYPE="Debug"
QT_PATH="${QT_PATH:-$HOME/Qt/6.9.2/gcc_64}"
APP_NAME="${APP_NAME:-}"
CC="${CC:-clang}"
CXX="${CXX:-clang++}"

# ====== Load Project Init ======
if [[ -f .project.ini ]]; then
    source .project.ini
fi

# ====== Subcommand ======
ACTION="${1:-}"
[[ -z "${ACTION}" ]] && usage
shift || true

# ====== Parse flags ======
CLEAN_ALL=false
while [[ $# -gt 0 ]]; do
    case "$1" in
    -t)
        BUILD_TYPE="$2"
        shift 2
        ;;
    -p)
        QT_PATH="$2"
        shift 2
        ;;
    -a)
        APP_NAME="$2"
        shift 2
        ;;
    -h) usage ;;
    --all)
        CLEAN_ALL=true
        shift
        ;;
    -*) err "Invalid option: $1" ;;
    *) break ;;
    esac
done

# ====== Validate build type ======
if [[ "$BUILD_TYPE" != "Debug" && "$BUILD_TYPE" != "Release" ]]; then
    err "Invalid build type: $BUILD_TYPE (must be Debug or Release)"
fi

BUILD_DIR="build/${BUILD_TYPE}"
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/build_${BUILD_TYPE}.log"

# ====== Pre-checks ======
command -v cmake >/dev/null || err "Missing 'cmake'. Please install it."
if command -v ninja >/dev/null 2>&1; then
    GENERATOR="Ninja"
else
    GENERATOR="Unix Makefiles"
fi
command -v "$CC" >/dev/null || err "Missing compiler: $CC"
command -v "$CXX" >/dev/null || err "Missing compiler: $CXX"

# Detect available cores
if command -v nproc >/dev/null 2>&1; then
    JOBS="$(nproc)"
elif command -v sysctl >/dev/null 2>&1; then
    JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 1)"
else
    JOBS=1
fi
[[ "$JOBS" -ge 1 ]] || JOBS=1

# ====== Actions ======
configure() {
    # Validate Qt path
    if [[ -z "${QT_PATH:-}" ]]; then
        err "QT_PATH is not set. Define it in .project.ini, environment, or pass with -p"
    fi
    [[ -d "$QT_PATH" ]] || err "Qt path '$QT_PATH' does not exist."

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
}

do_build() {
    # Configure if not yet done
    if [[ ! -f "${BUILD_DIR}/CMakeCache.txt" ]]; then
        configure
    fi

    mkdir -p "$LOG_DIR"
    msg "${BLUE}Building ($BUILD_TYPE) with --parallel=${JOBS}${RESET}"
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

    ln -sfn "${BUILD_DIR}/compile_commands.json" ./compile_commands.json
    msg "Symlink updated: compile_commands.json -> ${BUILD_DIR}/compile_commands.json"
    msg "${GREEN}${BOLD}Build completed successfully.${RESET}"
}

do_clean() {
    if $CLEAN_ALL; then
        msg "Cleaning all build directories and logs"
        rm -rf build "$LOG_DIR" compile_commands.json
    else
        msg "Cleaning ${BUILD_DIR}"
        rm -rf "${BUILD_DIR}"

        if [[ -L "compile_commands.json" ]]; then
            TARGET="$(readlink -f compile_commands.json || true)"
            if [[ "$TARGET" == "$(readlink -f "${BUILD_DIR}/compile_commands.json" 2>/dev/null || true)" ]]; then
                rm -f compile_commands.json
                msg "Removed symlink compile_commands.json (was pointing to cleaned build)."
            fi
        fi

        msg "Removing log file: $LOG_FILE"
        rm -f "$LOG_FILE"
    fi

    msg "Cleaning runtime cache files."
    rm -rf .cache .qmlls.ini

    msg "Clean completed."
}

do_play() {
    [[ -z "$APP_NAME" ]] && err "APP_NAME not set. Use -a <name> or define in .project.ini"
    local exe="${BUILD_DIR}/${APP_NAME}"
    [[ -x "$exe" ]] || err "Executable not found: $exe (did you run './qt.sh build -t $BUILD_TYPE' first?)"
    msg "Running $exe"
    "$exe"
}

do_fresh() {
    msg "Performing fresh build ($BUILD_TYPE) and play $APP_NAME"
    do_clean
    do_build
    do_play
}

do_run() {
    msg "Building and running $APP_NAME"
    do_build
    do_play
}

case "$ACTION" in
build) do_build ;;
play) do_play ;;
run) do_run ;;
fresh) do_fresh ;;
clean) do_clean ;;
*) usage ;;
esac
