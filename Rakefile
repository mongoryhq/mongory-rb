# frozen_string_literal: true

require 'rake/extensiontask'
require 'bundler/gem_tasks'
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)

  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
  # When rspec or rubocop is not installed in the CI cross-build environment, the definition of the test task is skipped
end

# Add support for rake-compiler if available
begin
  spec = Gem::Specification.load('mongory.gemspec')

  Rake::ExtensionTask.new('mongory_ext', spec) do |ext|
    abi = RUBY_VERSION.split('.').first(2).join('.')
    ext.lib_dir = "lib/core/#{abi}"
    ext.ext_dir = 'ext/mongory_ext'
    ext.source_pattern = '*.c'
    ext.gem_spec = spec
  end

  # Add tasks for building with submodule
  namespace :submodule do
    desc 'Initialize/update the mongory-core submodule'
    task :init do
      sh 'git submodule update --init --recursive'
    end

    desc 'Update the mongory-core submodule to latest'
    task :update do
      sh 'git submodule update --remote'
    end

    desc 'Build mongory-core submodule'
    task :build do
      core_dir = 'ext/mongory_ext/mongory-core'
      if Dir.exist?(core_dir)
        Dir.chdir(core_dir) do
          if File.exist?('build.sh')
            sh 'chmod +x build.sh && ./build.sh'
          else
            sh 'mkdir -p build && cd build && cmake .. && make'
          end
        end
      else
        puts 'mongory-core submodule not found. Run rake submodule:init first.'
      end
    end
  end

  desc 'Build the project (without standalone mongory-core build)'
  task build_all: ['submodule:init', :compile]

  desc 'Clean all build artifacts including submodule'
  task clean_all: :clean do
    sh 'rm -rf ext/mongory_ext/mongory-core/build' if Dir.exist?('ext/mongory_ext/mongory-core/build')
  end
rescue LoadError
  puts 'rake-compiler not available. Install it with: gem install rake-compiler'

  # Fallback tasks without rake-compiler
  desc 'Build the C extension manually'
  task :compile do
    Dir.chdir('ext/mongory_ext') do
      sh 'ruby extconf.rb && make'
    end
  end

  desc 'Clean the C extension manually'
  task :clean do
    Dir.chdir('ext/mongory_ext') do
      sh 'make clean' if File.exist?('Makefile')
      sh 'rm -f Makefile *.o foundations/*.o matchers/*.o mongory_ext.so'
    end
  end
end

# Custom build task using our build script
desc 'Build using the custom build script'
task :build_with_script do
  sh 'scripts/build_with_core.sh'
end

desc 'Build in debug mode'
task :build_debug do
  sh 'scripts/build_with_core.sh --debug'
end

task default: %i(spec rubocop)
