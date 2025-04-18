# frozen_string_literal: true

require 'rails/generators'
require_relative '../install/install_generator'

module Mongory
  module Generators
    # Generates a new Mongory matcher.
    #
    # @example
    #   rails g mongory:matcher class_in
    #   # Creates:
    #   #   lib/mongory/matchers/class_in_matcher.rb
    #   #   spec/mongory/matchers/class_in_matcher_spec.rb
    #   #   config/initializers/mongory.rb (if not exists)
    #
    # @see Mongory::Matchers::AbstractOperatorMatcher
    class MatcherGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      # Generates the matcher files and updates the initializer.
      #
      # @return [void]
      def create_matcher
        @matcher_name = "#{class_name}Matcher"
        @operator_name = name.underscore
        @mongo_operator = "$#{name.camelize(:lower)}"

        template 'matcher.rb.erb', "lib/mongory/matchers/#{file_name}_matcher.rb"
        template 'matcher_spec.rb.erb', "spec/mongory/matchers/#{file_name}_matcher_spec.rb"
        update_initializer
      end

      private

      # Updates or creates the Mongory initializer.
      #
      # @return [void]
      def update_initializer
        initializer_path = 'config/initializers/mongory.rb'
        require_line = "require \"#\{Rails.root\}/lib/mongory/matchers/#{file_name}_matcher\""

        unless File.exist?(initializer_path)
          Mongory::Generators::InstallGenerator.start
        end

        content = File.read(initializer_path)
        unless content.include?(require_line)
          inject_into_file initializer_path, "\n#{require_line}", after: "# frozen_string_literal: true\n"
        end
      end
    end
  end
end
