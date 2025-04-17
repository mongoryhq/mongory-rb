# frozen_string_literal: true

module Mongory
  module Utils
    # Only loaded when Rails is present
    module RailsPatch
      # Use Object#present? which defined in Rails.
      # @param target[Object]
      # @return [Boolean]
      def is_present?(target)
        target.present?
      end

      # Use Object#blank? which defined in Rails.
      # @param target[Object]
      # @return [Boolean]
      def is_blank?(target)
        target.blank?
      end
    end
  end
end
