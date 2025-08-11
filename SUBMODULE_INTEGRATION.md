# Mongory-rb Submodule Integration Guide

This document describes how to integrate `mongory-core` as a Git submodule into `mongory-rb` to enable a high-performance C extension.

## Architecture Overview

```
mongory-rb/
├── lib/                    # Ruby code
│   ├── mongory.rb         # Entry, loads the C extension
│   └── mongory/           # Other Ruby modules
├── ext/                   # C extension
│   └── mongory_ext/
│       ├── mongory-core/  # Git submodule (sources only; no prior CMake build required)
│       ├── extconf.rb     # Build configuration (compiles submodule .c sources directly)
│       └── mongory_ext.c  # Ruby C wrapper
└── scripts/
    └── build_with_core.sh # (Optional) build script
```

## Quick Start

### 1. Clone and initialize

```bash
# Clone the project
git clone <your-mongory-rb-repo>
cd mongory-rb

# Initialize the submodule
git submodule update --init --recursive
```

### 2. Install system dependencies

Installing `mongory-rb` (with the C extension) only requires basic build tools and Ruby headers:

**macOS:**
```bash
xcode-select --install   # Install Xcode Command Line Tools (includes clang)
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install build-essential ruby-dev
```

**CentOS/RHEL/Fedora:**
```bash
sudo yum groupinstall "Development Tools" || sudo dnf groupinstall "Development Tools"
sudo yum install ruby-devel          || sudo dnf install ruby-devel
```

> Optional: CMake and cJSON are only needed if you want to run the core tests/benchmarks inside the `mongory-core` submodule (e.g., via CMake/ctest).

### 3. Build the project

Using Rake (recommended):

```bash
# Automatically initializes the submodule and builds the C extension (no prior CMake build needed)
bundle exec rake build_all

# If rake-compiler is not available, the fallback :compile will directly run extconf.rb + make
```

Or use the script (optional):

```bash
./scripts/build_with_core.sh         # Basic build
./scripts/build_with_core.sh --debug # Debug build
./scripts/build_with_core.sh --help  # Show all options
```

## Detailed Steps

### Submodule management

```bash
# Initialize submodule
rake submodule:init

# Update submodule to latest
rake submodule:update

# Manually update submodule
git submodule update --remote
```

### Manual build flow (without rake-compiler)

If you prefer to control the build manually:

```bash
# 1. Ensure submodule is initialized
git submodule update --init --recursive

# 2. (Optional) Only needed if you run core tests/benchmarks inside the submodule
#    Note: This step requires cJSON; typical mongory-rb usage does not.
# cd ext/mongory_ext/mongory-core
# ./build.sh --test
# cd ../../..

# 3. Build the Ruby C extension (compiles submodule sources directly via extconf.rb)
cd ext/mongory_ext
ruby extconf.rb
make
cd ../..

# 4. Run tests
bundle exec rspec
```

### Clean builds

```bash
# Clean all build artifacts
rake clean_all

# Or use the build script
./scripts/build_with_core.sh --clean
```

## Development Guide

### Modify the C extension

1. Edit `ext/mongory_ext/mongory_ext.c`
2. Rebuild:
   ```bash
   cd ext/mongory_ext
   make
   ```

### Update mongory-core

1. Enter the submodule directory:
   ```bash
   cd ext/mongory_ext/mongory-core
   ```

2. Checkout the desired version or branch:
   ```bash
   git checkout main
   git pull origin main
   ```

3. Return to the main project and commit the submodule update:
   ```bash
   cd ../../..
   git add ext/mongory_ext/mongory-core
   git commit -m "Update mongory-core submodule"
   ```

### Debug the C extension

```bash
# Build in debug mode
export DEBUG=1
cd ext/mongory_ext
ruby extconf.rb
make

# Or use the build script
./scripts/build_with_core.sh --debug
```

Debug mode will:
- Enable debug symbols (`-g`)
- Disable optimizations (`-O0`)
- Define the `DEBUG` macro

### C extension API (current public surface)

```ruby
require 'mongory'

condition = { "age" => { "$gt" => 18 } }
matcher   = Mongory::CMatcher.new(condition)

data   = { "name" => "John", "age" => 25 }
result = matcher.match(data)  # => true/false

# Optional: get explanation (runs explain on the C side, currently returns nil)
matcher.explain
```

## Troubleshooting

### Common issues

**1. Submodule is empty**
```bash
# Fix
git submodule update --init --recursive
```

**2. cJSON library not found (only required if you run mongory-core CMake tests)**
```bash
# macOS
brew install cjson

# Ubuntu/Debian
sudo apt install libcjson-dev

# Verify installation
pkg-config --exists libcjson && echo "Found" || echo "Not found"
```

**3. Build errors**
```bash
# Clean and rebuild
./scripts/build_with_core.sh --clean
./scripts/build_with_core.sh --debug
```

**4. C extension fails to load**
- Check Ruby version compatibility (>= 2.6.0)
- Ensure all system deps are installed
- Inspect error messages and compiler warnings

### Logging and debugging

Enable verbose output:
```bash
# Verbose during build
VERBOSE=1 ./scripts/build_with_core.sh

# Debug info when loading Ruby
RUBY_DEBUG=1 ruby -rmongory -e "puts Mongory::CoreInterface.version"
```

### Performance check

```ruby
require 'benchmark'
require 'mongory'

records = 10000.times.map { |i| { "id" => i, "age" => rand(18..65) } }


```

## CI/CD integration

### GitHub Actions example

```yaml
name: Build and Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ruby-version: ['2.6', '2.7', '3.0', '3.1']

    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive

    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: ${{ matrix.ruby-version }}
        bundler-cache: true

    - name: Install system dependencies
      run: |
        sudo apt update
        sudo apt install -y build-essential ruby-dev

    - name: Build with C extension
      run: bundle exec rake build_all

    - name: Run tests
      run: bundle exec rspec

    # Only needed if you also run mongory-core C tests/benchmarks (optional):
    # - name: Install CMake & cJSON (only if running core tests)
    #   run: sudo apt install -y cmake libcjson-dev
    # - name: Build mongory-core tests (optional)
    #   run: |
    #     cd ext/mongory_ext/mongory-core
    #     ./build.sh --test
```

## Contributing Guide

### Development workflow

1. Fork this repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. If you modify C code, make sure to update tests
4. Run the full test suite: `./scripts/build_with_core.sh`
5. Commit changes: `git commit -m 'Add amazing feature'`
6. Push the branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

### Coding standards

- **C code**: C99, follow mongory-core style
- **Ruby code**: follow project RuboCop config
- **Docs**: document all public APIs

### Testing requirements

- Add tests for all new features
- Ensure both C extension and Ruby fallback are covered
- Run benchmarks to prevent regressions

## References

- [mongory-core doc](https://github.com/mongoryhq/mongory-core)
- [Ruby C extension doc](https://docs.ruby-lang.org/en/master/extension_rdoc.html)
- [Git Submodules doc](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [CMake doc](https://cmake.org/documentation/)

## License

This integration follows the MIT license, consistent with mongory-core and mongory-rb.
