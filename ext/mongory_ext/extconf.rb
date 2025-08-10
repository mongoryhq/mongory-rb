# frozen_string_literal: true

require 'mkmf'
require 'rbconfig'

# Set the path to mongory-core
core_dir = File.expand_path('mongory-core', __dir__)
core_src_dir = File.join(core_dir, 'src')
core_include_dir = File.join(core_dir, 'include')

# Check if mongory-core submodule exists
unless Dir.exist?(core_dir)
  puts "Error: mongory-core submodule not found at #{core_dir}"
  puts "Please run: git submodule update --init --recursive"
  exit 1
end

# mongory-rb does not require cJSON; only mongory-core's tests use it, so we don't check cJSON here

# Normalize compiler flags across GCC/Clang on CI (Ruby 2.6 on Ubuntu may inject clang-only warn flags)
def scrub_flags_from_config!(keys, patterns)
  [RbConfig::CONFIG, RbConfig::MAKEFILE_CONFIG].uniq.each do |cfg|
    keys.each do |k|
      next unless cfg[k]
      patterns.each do |pat|
        cfg[k] = cfg[k].gsub(/\b#{Regexp.escape(pat)}\b/, '')
      end
      cfg[k] = cfg[k].squeeze(' ').strip
    end
  end
end

gcc_like = RbConfig::CONFIG['GCC'] == 'yes' || RbConfig::CONFIG['CC'].to_s =~ /(gcc|cc)/
if gcc_like
  scrub_flags_from_config!(%w[warnflags cflags optflags debugflags], [
    '-Wno-self-assign',
    '-Wno-parentheses-equality',
    '-Wno-constant-logical-operand'
  ])
end

# Add include paths
$INCFLAGS << " -I#{core_include_dir}"

# Collect source files to compile directly into the extension
foundations_src = Dir.glob(File.join(core_src_dir, 'foundations', '*.c'))
matchers_src = Dir.glob(File.join(core_src_dir, 'matchers', '*.c'))

$CFLAGS << ' -std=c99 -Wall -Wextra -Wno-incompatible-pointer-types -Wno-int-conversion'
# Silence C90-style warnings on older GCC when standard flags are not fully applied by toolchains
$CFLAGS << ' -Wno-declaration-after-statement -Wno-discarded-qualifiers'
$CFLAGS << ' -O2' unless ENV['DEBUG']
$CFLAGS << ' -g -O0 -DDEBUG' if ENV['DEBUG']

# Let mkmf generate rules by listing all sources and corresponding objects
$INCFLAGS << " -I."
$INCFLAGS << " -I#{File.join(core_src_dir, 'foundations')}"
$INCFLAGS << " -I#{File.join(core_src_dir, 'matchers')}"
all_sources = ['mongory_ext.c'] + foundations_src + matchers_src
$srcs = all_sources
$objs = all_sources.map { |src| File.basename(src, '.c') + '.o' }

# Generate Makefile
create_makefile('mongory_ext')

puts "extconf.rb completed successfully"
puts "Found #{foundations_src.length} foundation sources"
puts "Found #{matchers_src.length} matcher sources"
puts "Use 'make' to build the extension"

# Append Makefile rules: explicit compilation rules for submodule sources to avoid copying/linking files
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
