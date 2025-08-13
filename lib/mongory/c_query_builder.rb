# frozen_string_literal: true

require_relative 'query_builder'

module Mongory
  class CQueryBuilder < QueryBuilder
    def each
      # deep convert
      # TODO: use shallow convert instead (Mongory.data_converter)
      converter = Mongory.condition_converter.value_converter 
      @records.each do |record|
        yield record if @matcher.match?(converter.convert(record))
      end
    end

    def fast
      # No convert
      @records.each do |record|
        yield record if @matcher.match?(record)
      end
    end

    def explain
      # deep convert
      # TODO: use shallow convert instead (Mongory.data_converter)
      converter = Mongory.condition_converter.value_converter
      @matcher.match?(converter.convert(@records.first))
      @matcher.explain
    end

    private

    def set_matcher(condition = {})
      @matcher = CMatcher.new(Mongory.condition_converter.convert(condition))
    end
  end
end
