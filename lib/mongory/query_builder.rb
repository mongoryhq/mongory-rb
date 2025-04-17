# frozen_string_literal: true

require_relative 'utils'

module Mongory
  # QueryBuilder provides a Mongo-like in-memory query interface.
  #
  # It supports condition chaining (`where`, `or`, `not`),
  # sorting (`asc`, `desc`), limiting, and plucking fields.
  #
  # Internally it compiles all conditions and invokes `QueryMatcher`.
  #
  # @example
  #   records.mongory
  #     .where(:age.gte => 18)
  #     .or({ :name => /J/ }, { :name.eq => 'Bob' })
  #     .desc(:age)
  #     .limit(2)
  #     .to_a
  class QueryBuilder
    include ::Enumerable
    include Utils

    # Initializes a new query builder with the given record set.
    #
    # @param records [Enumerable] the collection to query against
    def initialize(records)
      @records = records
      set_matcher
    end

    # Iterates through all records that match the current matcher.
    #
    # @yieldparam record [Object]
    # @return [Enumerator]
    def each
      return to_enum(:each) unless block_given?

      @records.each do |record|
        yield record if @matcher.match?(record)
      end
    end

    # Adds a condition to filter records using the given condition.
    #
    # @param condition [Hash]
    # @return [QueryBuilder] a new builder instance
    def where(condition)
      self.and(condition)
    end

    # Adds a negated condition to the current query.
    #
    # @param condition [Hash]
    # @return [QueryBuilder]
    def not(condition)
      self.and('$not' => condition)
    end

    # Adds one or more conditions combined with `$and`.
    #
    # @param conditions [Array<Hash>]
    # @return [QueryBuilder]
    def and(*conditions)
      dup_instance_exec do
        add_conditions('$and', conditions)
      end
    end

    # Adds one or more conditions combined with `$or`.
    #
    # @param conditions [Array<Hash>]
    # @return [QueryBuilder]
    def or(*conditions)
      operator = '$or'
      dup_instance_exec do
        if @matcher.condition.each_key.all? { |k| k == operator }
          add_conditions(operator, conditions)
        else
          set_matcher(operator => [@matcher.condition.dup, *conditions])
        end
      end
    end

    # Adds a `$or` query combined inside an `$and` block.
    # This is a semantic alias for `.and('$or' => [...])`
    #
    # @param conditions [Array<Hash>]
    # @return [QueryBuilder]
    def any_of(*conditions)
      self.and('$or' => conditions)
    end

    def in(condition)
      self.and(wrap_values_with_key(condition, '$in'))
    end

    def nin(condition)
      self.and(wrap_values_with_key(condition, '$nin'))
    end

    # Limits the number of records returned by the query.
    #
    # @param count [Integer]
    # @return [QueryBuilder]
    def limit(count)
      dup_instance_exec do
        @records = take(count)
      end
    end

    # Extracts selected fields from matching records.
    #
    # @param field [Symbol, String]
    # @param fields [Array<Symbol, String>]
    # @return [Array<Object>, Array<Array<Object>>]
    def pluck(field, *fields)
      if fields.empty?
        map { |record| record[field] }
      else
        fields.unshift(field)
        map { |record| fields.map { |key| record[key] } }
      end
    end

    # Returns the raw parsed condition for this query.
    #
    # @return [Hash] the raw compiled condition
    def condition
      @matcher.condition
    end

    alias_method :selector, :condition

    # Prints the internal matcher tree structure for the current query.
    # Will output a human-readable visual tree of matchers.
    # This is useful for debugging and visualizing complex conditions.
    #
    # @return [void]
    def explain
      @matcher.match?(@records.first)
      @matcher.render_tree
      nil
    end

    private

    # @private
    # Duplicates the query and executes the block in context.
    #
    # @yieldparam dup [QueryBuilder]
    # @return [QueryBuilder]
    def dup_instance_exec(&block)
      dup.tap do |obj|
        obj.instance_exec(&block)
      end
    end

    # @private
    # Builds the internal matcher tree from a condition hash.
    # Used to eagerly parse conditions to improve inspect/debug visibility.
    #
    # @param condition [Hash]
    # @return [void]
    def set_matcher(condition = {})
      @matcher = QueryMatcher.new(condition)
    end

    # @private
    # Merges additional conditions into the matcher.
    #
    # @param key [String, Symbol]
    # @param conditions [Array<Hash>]
    def add_conditions(key, conditions)
      condition_dup = @matcher.condition.dup
      condition_dup[key] ||= []
      condition_dup[key] += conditions
      set_matcher(condition_dup)
    end

    def wrap_values_with_key(condition, key)
      condition.transform_values do |sub_condition|
        { key => sub_condition }
      end
    end
  end
end
