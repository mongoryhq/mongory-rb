# frozen_string_literal: true

require_relative 'query_builder'

module Mongory
  class CQueryBuilder < QueryBuilder
    def each
      @records.each do |record|
        yield record if @matcher.match?(record)
      end
    end

    alias_method :fast, :each

    def explain
      @matcher.match?(@records.first)
      @matcher.explain
    end

    private

    def set_matcher(condition = {})
      @matcher = CMatcher.new(condition)
    end
  end
end
