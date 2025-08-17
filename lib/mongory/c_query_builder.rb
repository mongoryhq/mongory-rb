# frozen_string_literal: true

require_relative 'query_builder'

module Mongory
  # Mongory::CQueryBuilder is a query builder for Mongory::CMatcher.
  # It is used to build a query for a Mongory::CMatcher.
  class CQueryBuilder < QueryBuilder
    def each
      return to_enum(:each) unless block_given?

      @records.each do |record|
        @context.current_record = record
        yield record if @matcher.match?(record)
      end
    end

    alias_method :fast, :each

    def explain
      @matcher.match?(@records.first)
      @matcher.explain
    end

    def trace
      return to_enum(:trace) unless block_given?

      @matcher.enable_trace
      @records.each do |record|
        @context.current_record = record
        yield record if @matcher.match?(record)
      end
    ensure
      @matcher.print_trace
      @matcher.disable_trace
    end

    private

    def set_matcher(condition = {})
      @matcher = CMatcher.new(condition, context: @context)
    end
  end
end
