# frozen_string_literal: true

module Mongory
  # Wrapper for symbol-based operator expressions.
  #
  # Used to support DSL like `:age.gt => 18` where `gt` maps to `$gt`.
  # Converts into: `{ "age" => { "$gt" => 18 } }`
  class QueryOperator
    METHOD_TO_OPERATOR_MAPPING = {
      eq: '$eq',
      ne: '$ne',
      not: '$not',
      and: '$and',
      or: '$or',
      regex: '$regex',
      present: '$present',
      exists: '$exists',
      gt: '$gt',
      gte: '$gte',
      lt: '$lt',
      lte: '$lte',
      in: '$in',
      nin: '$nin',
      elem_match: '$elemMatch',
      every: '$every'
    }.freeze

    # Initializes a new query operator wrapper.
    #
    # @param name [String] the original field name
    # @param operator [String] the Mongo-style operator (e.g., '$gt')
    def initialize(name, operator)
      @name = name
      @operator = operator
    end

    # Converts the operator and value into a condition hash.
    #
    # Typically called by the key converter.
    #
    # @param other [Object] the value to match against
    # @return [Hash] converted query condition
    def __expr_part__(other, *)
      Converters::KeyConverter.instance.convert(@name, @operator => other)
    end
  end
end
