# frozen_string_literal: true

require 'mkmf'

# 設置 mongory-core 的路徑
core_dir = File.expand_path('mongory-core', __dir__)
core_src_dir = File.join(core_dir, 'src')
core_include_dir = File.join(core_dir, 'include')

# 檢查 mongory-core 是否存在
unless Dir.exist?(core_dir)
  puts "Error: mongory-core submodule not found at #{core_dir}"
  puts "Please run: git submodule update --init --recursive"
  exit 1
end

# mongory-rb 不需要 cJSON；僅 mongory-core 的測試會使用到，故不檢查 cJSON 依賴

# 添加包含路徑
$INCFLAGS << " -I#{core_include_dir}"

# 收集需要編譯的源文件（直接編進擴充套件）
foundations_src = Dir.glob(File.join(core_src_dir, 'foundations', '*.c'))
matchers_src = Dir.glob(File.join(core_src_dir, 'matchers', '*.c'))

# 設置編譯選項
$CFLAGS << ' -std=c99 -Wall -Wextra -Wno-incompatible-pointer-types -Wno-int-conversion'
$CFLAGS << ' -O2' unless ENV['DEBUG']
$CFLAGS << ' -g -O0 -DDEBUG' if ENV['DEBUG']

# 交給 mkmf 自動產生規則：指定所有來源與對應目標
$INCFLAGS << " -I."
$INCFLAGS << " -I#{File.join(core_src_dir, 'foundations')}"
$INCFLAGS << " -I#{File.join(core_src_dir, 'matchers')}"
all_sources = ['mongory_ext.c'] + foundations_src + matchers_src
$srcs = all_sources
$objs = all_sources.map { |src| File.basename(src, '.c') + '.o' }

# 產生 Makefile
create_makefile('mongory_ext')

puts "extconf.rb completed successfully"
puts "Found #{foundations_src.length} foundation sources"
puts "Found #{matchers_src.length} matcher sources"
puts "Use 'make' to build the extension"

# 補充 Makefile：為 submodule 內的來源建立顯式編譯規則，避免複製或連結檔案
mk = File.read('Makefile')

rules = +"\n# --- custom rules for mongory-core submodule sources ---\n"
(foundations_src + matchers_src).each do |src|
  obj = File.basename(src, '.c') + '.o'
  rules << <<~MAKE
  #{obj}: #{src}
	$(ECHO) compiling $<
	$(Q) $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<

  MAKE
end

File.write('Makefile', mk + rules)
