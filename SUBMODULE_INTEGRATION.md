# Mongory-rb Submodule Integration Guide

這份文檔說明了如何使用 `mongory-core` 作為 Git submodule 整合到 `mongory-rb` 中，實現高效能的 C 擴展支援。

## 架構概述

```
mongory-rb/
├── lib/                    # Ruby 程式碼
│   └── mongory/
│       └── ...            # 其他 Ruby 模組
├── ext/                   # C 擴展
│   └── mongory_ext/
│       ├── mongory-core/  # Git submodule
│       ├── extconf.rb     # 編譯配置
│       └── mongory_ext.c  # Ruby C 包裝器
└── scripts/
    └── build_with_core.sh # 構建腳本
```

## 快速開始

### 1. 複製和初始化

```bash
# 複製專案
git clone <your-mongory-rb-repo>
cd mongory-rb

# 初始化 submodule
git submodule update --init --recursive
```

### 2. 安裝系統依賴

一般安裝 `mongory-rb`（包含 C 擴充）只需要基本編譯工具：

**macOS (Homebrew):**
```bash
brew install cmake
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install cmake build-essential
```

**CentOS/RHEL/Fedora:**
```bash
# CentOS/RHEL
sudo yum install cmake gcc make

# Fedora
sudo dnf install cmake gcc make
```

注意：cJSON 僅在你進入 `mongory-core` 子模組並執行其「測試或 benchmarks」時才需要（例如以 CMake/ctest 執行）。`mongory-rb` 的正常使用與擴充編譯不需要 cJSON。

### 3. 構建專案

使用我們的自動化構建腳本：

```bash
# 基本構建
./scripts/build_with_core.sh

# 除錯模式構建
./scripts/build_with_core.sh --debug

# 強制重新構建
./scripts/build_with_core.sh --force-rebuild

# 查看所有選項
./scripts/build_with_core.sh --help
```

或者使用 Rake 任務：

```bash
# 使用 rake-compiler（如果有安裝）
rake build_all

# 或使用我們的構建腳本
rake build_with_script

# 除錯模式
rake build_debug
```

## 詳細步驟說明

### Submodule 管理

```bash
# 初始化 submodule
rake submodule:init

# 更新 submodule 到最新版本
rake submodule:update

# 手動更新 submodule
git submodule update --remote
```

### 手動構建流程

如果您想要手動控制構建過程：

```bash
# 1. 確保 submodule 已初始化
git submodule update --init --recursive

# 2.（可選）如果你要在子模組內跑測試或 benchmarks，才需要以 CMake 構建 mongory-core
#    注意：此步驟才可能需要 cJSON；一般使用 mongory-rb 不需要。
# cd ext/mongory_ext/mongory-core
# ./build.sh --test
# cd ../../..

# 3. 構建 Ruby C 擴展
cd ext/mongory_ext
ruby extconf.rb
make
cd ../..

# 4. 運行測試
bundle exec rspec
```

### 清理構建

```bash
# 清理所有構建產物
rake clean_all

# 或使用構建腳本
./scripts/build_with_core.sh --clean
```

## 開發指南

### 修改 C 擴展

1. 編輯 `ext/mongory_ext/mongory_ext.c`
2. 重新編譯：
   ```bash
   cd ext/mongory_ext
   make
   ```

### 更新 mongory-core

1. 進入 submodule 目錄：
   ```bash
   cd ext/mongory_ext/mongory-core
   ```

2. 檢出想要的版本或分支：
   ```bash
   git checkout main
   git pull origin main
   ```

3. 回到主專案並提交 submodule 更新：
   ```bash
   cd ../../..
   git add ext/mongory_ext/mongory-core
   git commit -m "Update mongory-core submodule"
   ```

### 除錯 C 擴展

```bash
# 使用除錯模式構建
export DEBUG=1
cd ext/mongory_ext
ruby extconf.rb
make

# 或使用構建腳本
./scripts/build_with_core.sh --debug
```

除錯模式會：
- 啟用除錯符號 (`-g`)
- 關閉最佳化 (`-O0`)
- 啟用 `DEBUG` 巨集定義

### C 擴展 API

主要的 C 擴展類別：

```ruby
# 記憶體池管理
pool = Mongory::MemoryPool.new

# 建立匹配器
condition = { "age" => { "$gt" => 18 } }
matcher = Mongory::Matcher.new(pool, condition)

# 執行匹配
data = { "name" => "John", "age" => 25 }
result = matcher.match(data)  # => true

# 檢查 C 擴展是否可用
Mongory::CoreInterface.c_extension_available?  # => true/false
```

## 故障排除

### 常見問題

**1. Submodule 是空的**
```bash
# 解決方案
git submodule update --init --recursive
```

**2. 找不到 cjson 庫**
```bash
# macOS
brew install cjson

# Ubuntu/Debian
sudo apt install libcjson-dev

# 檢查安裝
pkg-config --exists libcjson && echo "Found" || echo "Not found"
```

**3. 編譯錯誤**
```bash
# 清理並重新構建
./scripts/build_with_core.sh --clean
./scripts/build_with_core.sh --debug
```

**4. C 擴展無法載入**
- 檢查 Ruby 版本相容性 (>= 2.6.0)
- 確認所有依賴庫已安裝
- 查看錯誤訊息並檢查編譯警告

### 日誌和除錯

啟用詳細輸出：
```bash
# 構建時顯示詳細訊息
VERBOSE=1 ./scripts/build_with_core.sh

# Ruby 載入時顯示除錯資訊
RUBY_DEBUG=1 ruby -rmongory -e "puts Mongory::CoreInterface.version"
```

### 效能驗證

```ruby
require 'benchmark'
require 'mongory'

records = 10000.times.map { |i| { "id" => i, "age" => rand(18..65) } }

# 測試 C 擴展效能
Benchmark.bm do |x|
  x.report("Ruby DSL:") do
    records.mongory.where(:age.gte => 30).to_a
  end

  if Mongory::CoreInterface.c_extension_available?
    x.report("C Extension:") do
      pool = Mongory::MemoryPool.new
      matcher = Mongory::Matcher.new(pool, { "age" => { "$gte" => 30 } })
      records.select { |r| matcher.match(r) }
    end
  end
end
```

## CI/CD 整合

### GitHub Actions 範例

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
        sudo apt install cmake build-essential

    - name: Build with C extension
      run: ./scripts/build_with_core.sh

    - name: Run tests
      run: bundle exec rspec

    # 如果你需要在 CI 中跑 mongory-core 的測試/benchmarks（可選），才需要安裝 cJSON 並呼叫其 CMake 流程。
    # - name: Install cJSON (only if running core tests)
    #   run: sudo apt install libcjson-dev
    # - name: Build mongory-core tests (optional)
    #   run: |
    #     cd ext/mongory_ext/mongory-core
    #     ./build.sh --test
```

## 貢獻指南

### 開發流程

1. Fork 這個 repository
2. 建立功能分支：`git checkout -b feature/amazing-feature`
3. 如果修改了 C 程式碼，確保同時更新測試
4. 執行完整的測試套件：`./scripts/build_with_core.sh`
5. 提交變更：`git commit -m 'Add amazing feature'`
6. 推送到分支：`git push origin feature/amazing-feature`
7. 建立 Pull Request

### 編碼標準

- **C 程式碼**: 遵循 C99 標準，使用 mongory-core 的編碼風格
- **Ruby 程式碼**: 遵循專案的 RuboCop 配置
- **文檔**: 為所有公共 API 提供文檔

### 測試要求

- 為所有新功能添加測試
- 確保 C 擴展和 Ruby fallback 都有測試覆蓋
- 運行效能基準測試確認沒有回歸

## 參考資源

- [mongory-core 文檔](ext/mongory_ext/mongory-core/README.md)
- [Ruby C 擴展指南](https://docs.ruby-lang.org/en/master/extension_rdoc.html)
- [Git Submodules 文檔](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [CMake 文檔](https://cmake.org/documentation/)

## 授權

這個整合遵循 MIT 授權條款，與 mongory-core 和 mongory-rb 保持一致。
