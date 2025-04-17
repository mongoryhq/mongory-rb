# frozen_string_literal: true

require 'bundler'

module Mongory
  module Generators
    # Generates a Mongory initializer file with suggested configuration
    # based on detected ORMs (ActiveRecord, Mongoid, Sequel).
    #
    # This is intended to be used via:
    #   rails generate mongory:install
    #
    # @example
    #   # Will generate config/initializers/mongory.rb with appropriate snippets
    #   rails g mongory:install
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      # Generates the Mongory initializer under `config/initializers/mongory.rb`.
      # Dynamically injects converter and registration config based on detected ORMs.
      #
      # @return [void]
      def create_initializer_file
        @use_ar       = gem_used?('activerecord')
        @use_mongoid  = gem_used?('mongoid')
        @use_sequel   = gem_used?('sequel')

        template 'initializer.rb.erb', 'config/initializers/mongory.rb'
      end

      private

      # Checks whether a specific gem is listed in the locked dependencies.
      #
      # @param gem_name [String] the name of the gem to check
      # @return [Boolean] true if the gem is present in the lockfile
      def gem_used?(gem_name)
        Bundler.locked_gems.dependencies.key?(gem_name)
      end
    end
  end
end
