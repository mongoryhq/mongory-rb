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

# 添加源文件
foundations_src = Dir.glob(File.join(core_src_dir, 'foundations', '*.c'))
matchers_src = Dir.glob(File.join(core_src_dir, 'matchers', '*.c'))

# 設置編譯選項
$CFLAGS << ' -std=c99 -Wall -Wextra'
$CFLAGS << ' -O2' unless ENV['DEBUG']
$CFLAGS << ' -g -O0 -DDEBUG' if ENV['DEBUG']

# 創建所有源文件的編譯規則
all_sources = foundations_src + matchers_src

# 為每個 C 源文件創建對象文件
objects = all_sources.map do |src|
  obj = src.sub(/\.c$/, '.o').sub(core_src_dir, '.')
  obj_dir = File.dirname(obj)
  FileUtils.mkdir_p(obj_dir) unless Dir.exist?(obj_dir)

  # 添加編譯規則
  rule obj => src do
    sh "#{CONFIG['CC']} #{$CFLAGS} #{$INCFLAGS} -c #{src} -o #{obj}"
  end

  obj
end

# 設置對象文件
$objs = objects + ['mongory_ext.o']

# 創建 Makefile
create_makefile('mongory_ext')

# 添加清理任務
makefile_content = File.read('Makefile')
makefile_content << "\n"
makefile_content << "clean: clean-so clean-static clean-objs\n"
makefile_content << "\t@rm -f *.o foundations/*.o matchers/*.o\n"
makefile_content << "\n"

File.write('Makefile', makefile_content)

puts "extconf.rb completed successfully"
puts "Found #{foundations_src.length} foundation sources"
puts "Found #{matchers_src.length} matcher sources"
puts "Use 'make' to build the extension"
