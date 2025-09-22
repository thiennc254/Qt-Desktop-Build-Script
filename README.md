# Qt CMake Template

A simple Qt project template with a custom build script `desktop.sh` as an
alternative to Qt Creator.

## 🔧 Requirements

- CMake ≥ 3.16
- Qt ≥ 6.x (installation path required)
- Compiler: clang/clang++ (can be overridden using `CC` and `CXX`)
- (optional) Ninja build system

## 🚀 Using the build script

```bash
./qt.sh build   [-t Debug|Release] [-p /path/to/Qt]
./qt.sh play    [-t Debug|Release] [-a <app_name>]
./qt.sh run     [-t Debug|Release] [-p /path/to/Qt] [-a <app_name>]
./qt.sh fresh   [-t Debug|Release] [-p /path/to/Qt] [-a <app_name>]
./qt.sh clean   [-t Debug|Release] [--all]
```

### Options

- `-t` : Build type (`Debug` or `Release`, default: `Debug`)
- `-p` : Qt installation path (if not provided, taken from
  `.project.ini` or `$HOME/Qt/6.9.2/gcc_64`)
- `-a` : Application name (required for `play` and `run`. Default is taken
  from `.project.ini` if available)
- `--all` : Remove all build directories and logs when used with
  `clean`

### Examples

```bash
# Build Debug
./qt.sh build -t Debug

# Build Release with a custom Qt path
./qt.sh build -t Release -p ~/Qt/6.6.3/gcc_64

# Run the app (already built)
./qt.sh play -t Debug # If default app name is set in .project.ini
./qt.sh play -t Debug -a myQtApp # Override app name

# Build + Run the app
./qt.sh run -a myQtApp

# Clean Debug build
./qt.sh clean -t Debug

# Clean everything
./qt.sh clean --all
```

## 📁 Project structure

    .
    ├── CMakeLists.txt
    ├── main.cpp
    ├── main.qml
    ├── desktop.sh
    ├── .project.ini # project config (APP_NAME, QT_PATH)
    ├── .clang-format # optional, for code formatting
    ├── build/ # build directory (created after first build)
    └── logs/ # build logs (created after first build)

## ⚠️ Notes

- If you change Qt path, compiler, or generator → run `./qt.sh fresh`
  to reconfigure.
