# frozen_string_literal: true

require_relative 'lib/mongory/version'

Gem::Specification.new do |spec|
  spec.name = 'mongory'
  spec.version = Mongory::VERSION
  spec.authors = ['koten0224']
  spec.email = ['koten0224@gmail.com']

  spec.summary = 'MongoDB-like in-memory query DSL for Ruby'
  spec.description = 'A Mongo-like in-memory query DSL for Ruby'
  spec.homepage = 'https://mongoryhq.github.io/mongory-rb/'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.6.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/mongoryhq/mongory-rb'
  spec.metadata['changelog_uri'] = 'https://github.com/mongoryhq/mongory-rb/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w(bin/ test/ spec/ features/ .git .github appveyor Gemfile))
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # C extension configuration
  spec.extensions = ['ext/mongory_ext/extconf.rb']

  # Add development dependencies for C extension
  spec.add_development_dependency 'rake-compiler', '~> 1.0'


  # Ensure submodule files are included
  spec.files += Dir['ext/mongory_ext/mongory-core/src/**/*.{c,h}']
  spec.files += Dir['ext/mongory_ext/mongory-core/include/**/*.h']
  spec.files += ['ext/mongory_ext/mongory-core/LICENSE']
  spec.files += ['ext/mongory_ext/mongory-core/README.md']
end
