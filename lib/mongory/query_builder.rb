# frozen_string_literal: true

require_relative 'utils'

module Mongory
  # QueryBuilder provides a Mongo-like in-memory query interface.
  #
  # It supports condition chaining (`where`, `or`, `not`),
  # limiting, and plucking fields.
  #
  # Internally it compiles all conditions and invokes `QueryMatcher`.
  #
  # @example Basic query
  #   records.mongory
  #     .where(:age.gte => 18)
  #     .or({ :name => /J/ }, { :name.eq => 'Bob' })
  #     .limit(2)
  #     .to_a
  #
  # @example Complex query
  #   records.mongory
  #     .where(:status => 'active')
  #     .not(:age.lt => 18)
  #     .any_of({ :role => 'admin' }, { :role => 'moderator' })
  #     .pluck(:name, :email)
  class QueryBuilder
    include ::Enumerable
    include Utils

    # Initializes a new query builder with the given record set.
    #
    # @param records [Enumerable] the collection to query against
    def initialize(records, context: Utils::Context.new)
      @records = records
      @context = context
      set_matcher
    end

    # Iterates through all records that match the current matcher.
    # Uses the standard matcher implementation.
    #
    # @yieldparam record [Object] each matching record
    # @return [Enumerator] if no block given
    # @return [void] if block given
    def each
      return to_enum(:each) unless block_given?

      @matcher.prepare_query
      @records.each do |record|
        @context.current_record = record
        yield record if @matcher.match?(record)
      end
    end

    # Iterates through all records that match the current matcher.
    # Uses a compiled Proc for faster matching.
    #
    # @yieldparam record [Object] each matching record
    # @return [Enumerator] if no block given
    # @return [void] if block given
    def fast
      return to_enum(:fast) unless block_given?

      @context.need_convert = false
      @matcher.prepare_query
      matcher_block = @matcher.to_proc
      @records.each do |record|
        yield record if matcher_block.call(record)
      end
    end

    # Adds a condition to filter records using the given condition.
    # This is an alias for `and`.
    #
    # @param condition [Hash] the condition to add
    # @return [QueryBuilder] a new builder instance
    def where(condition)
      self.and(condition)
    end

    # Adds a negated condition to the current query.
    # Wraps the condition in a `$not` operator.
    #
    # @param condition [Hash] the condition to negate
    # @return [QueryBuilder] a new builder instance
    def not(condition)
      self.and('$not' => condition)
    end

    # Adds one or more conditions combined with `$and`.
    # All conditions must match for a record to be included.
    #
    # @param conditions [Array<Hash>] the conditions to add
    # @return [QueryBuilder] a new builder instance
    def and(*conditions)
      dup_instance_exec do
        add_conditions('$and', conditions)
      end
    end

    # Adds one or more conditions combined with `$or`.
    # Any condition can match for a record to be included.
    #
    # @param conditions [Array<Hash>] the conditions to add
    # @return [QueryBuilder] a new builder instance
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
    # @param conditions [Array<Hash>] the conditions to add
    # @return [QueryBuilder] a new builder instance
    def any_of(*conditions)
      self.and('$or' => conditions)
    end

    # Adds an `$in` condition to the query.
    # Matches records where the field value is in the given array.
    #
    # @param condition [Hash] the field and values to match
    # @return [QueryBuilder] a new builder instance
    def in(condition)
      self.and(wrap_values_with_key(condition, '$in'))
    end

    # Adds a `$nin` condition to the query.
    # Matches records where the field value is not in the given array.
    #
    # @param condition [Hash] the field and values to exclude
    # @return [QueryBuilder] a new builder instance
    def nin(condition)
      self.and(wrap_values_with_key(condition, '$nin'))
    end

    # Limits the number of records returned by the query.
    #
    # @param count [Integer] the maximum number of records to return
    # @return [QueryBuilder] a new builder instance
    def limit(count)
      dup_instance_exec do
        @records = take(count)
      end
    end

    # Extracts selected fields from matching records.
    #
    # @param field [Symbol, String] the first field to extract
    # @param fields [Array<Symbol, String>] additional fields to extract
    # @return [Array<Object>] array of single field values if one field given
    # @return [Array<Array<Object>>] array of field value arrays if multiple fields given
    def pluck(field, *fields)
      if fields.empty?
        map { |record| record[field] }
      else
        fields.unshift(field)
        map { |record| fields.map { |key| record[key] } }
      end
    end

    def with_context(addon_context = {})
      dup_instance_exec do
        @context = @context.dup
        @context.config.merge!(addon_context)
        set_matcher(@matcher.condition)
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
    # @return [QueryBuilder] the modified duplicate
    def dup_instance_exec(&block)
      dup.tap do |obj|
        obj.instance_exec(&block)
      end
    end

    # @private
    # Builds the internal matcher tree from a condition hash.
    # Used to eagerly parse conditions to improve inspect/debug visibility.
    #
    # @param condition [Hash] the condition to build the matcher from
    # @return [void]
    def set_matcher(condition = {})
      @matcher = QueryMatcher.new(condition, context: @context)
    end

    # @private
    # Merges additional conditions into the matcher.
    #
    # @param key [String, Symbol] the operator key (e.g. '$and', '$or')
    # @param conditions [Array<Hash>] the conditions to add
    # @return [void]
    def add_conditions(key, conditions)
      condition_dup = @matcher.condition.dup
      condition_dup[key] ||= []
      condition_dup[key] += conditions
      set_matcher(condition_dup)
    end

    # @private
    # Wraps values in a condition hash with a given operator key.
    #
    # @param condition [Hash] the condition to transform
    # @param key [String] the operator key to wrap with
    # @return [Hash] the transformed condition
    def wrap_values_with_key(condition, key)
      condition.transform_values do |sub_condition|
        { key => sub_condition }
      end
    end
  end
end
