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

    def explain_tree
      @matcher.match?(@records.first)
      @matcher.explain_tree
    end

    def explain
      print explain_tree
      nil
    end

    def trace_tree
      buffer = +''
      @records.each do |record|
        @context.current_record = record
        buffer << @matcher.trace_tree(record)
        yield record if block_given? && @matcher.match?(record)
      end
      buffer
    end

    def trace
      return to_enum(:trace) unless block_given?

      @records.each do |record|
        @context.current_record = record
        output = @matcher.trace_tree(record)
        print output unless output.empty?
        yield record if @matcher.match?(record)
      end
    end

    private

    def set_matcher(condition = {})
      @matcher = CMatcher.new(condition, context: @context)
    end
  end
end
