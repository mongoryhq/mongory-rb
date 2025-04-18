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
        inject_line = "require \"#\{Rails.root\}/lib/mongory/matchers/#{file_name}_matcher\""
        front_line = '# frozen_string_literal: true'

        Mongory::Generators::InstallGenerator.start unless File.exist?(initializer_path)
        content = File.read(initializer_path)
        return if content.include?(inject_line)

        required_file_lines = content.scan(/.+require\s+["'].*_matcher["'].+/)
        if required_file_lines.empty?
          inject_line = "\n#{inject_line}"
        else
          front_line = required_file_lines.last
        end

        inject_into_file initializer_path, "#{inject_line}\n", after: "#{front_line}\n"
      end
    end
  end
end
