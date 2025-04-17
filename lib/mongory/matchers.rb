# frozen_string_literal: true

require_relative 'matchers/abstract_matcher'
require_relative 'matchers/abstract_multi_matcher'
require_relative 'matchers/abstract_operator_matcher'
require_relative 'matchers/literal_matcher'
require_relative 'matchers/hash_condition_matcher'
require_relative 'matchers/and_matcher'
require_relative 'matchers/array_record_matcher'
require_relative 'matchers/elem_match_matcher'
require_relative 'matchers/every_matcher'
require_relative 'matchers/eq_matcher'
require_relative 'matchers/exists_matcher'
require_relative 'matchers/gt_matcher'
require_relative 'matchers/gte_matcher'
require_relative 'matchers/in_matcher'
require_relative 'matchers/field_matcher'
require_relative 'matchers/lt_matcher'
require_relative 'matchers/lte_matcher'
require_relative 'matchers/ne_matcher'
require_relative 'matchers/nin_matcher'
require_relative 'matchers/not_matcher'
require_relative 'matchers/or_matcher'
require_relative 'matchers/present_matcher'
require_relative 'matchers/regex_matcher'

module Mongory
  # Defines built-in Mongory matchers for query condition evaluation.
  #
  # This file loads and registers all available matcher classes
  # and maps Mongo-style operators (e.g., `$gt`, `$in`) to matcher implementations.
  # Matcher lookup and operator dispatch mapping.
  #
  # This module contains the `$operator => MatcherClass` mapping used
  # by `HashConditionMatcher` to find the correct matcher for a condition.
  #
  # Matchers are loaded from the `matchers/` directory.
  module Matchers
    # Maps Mongo-style operators to internal matcher class names.
    OPERATOR_TO_CLASS_MAPPING = {
      '$eq' => :EqMatcher,
      '$ne' => :NeMatcher,
      '$not' => :NotMatcher,
      '$and' => :AndMatcher,
      '$or' => :OrMatcher,
      '$regex' => :RegexMatcher,
      '$present' => :PresentMatcher,
      '$exists' => :ExistsMatcher,
      '$gt' => :GtMatcher,
      '$gte' => :GteMatcher,
      '$lt' => :LtMatcher,
      '$lte' => :LteMatcher,
      '$in' => :InMatcher,
      '$nin' => :NinMatcher,
      '$elemMatch' => :ElemMatchMatcher,
      '$every' => :EveryMatcher
    }.freeze

    # Returns the matcher class for the given operator.
    #
    # @param key [String] a Mongo-style operator (e.g., `$eq`)
    # @return [Class, nil] matcher class or nil if not found
    def self.lookup(key)
      return unless OPERATOR_TO_CLASS_MAPPING.include?(key)

      const_get(OPERATOR_TO_CLASS_MAPPING[key])
    end
  end
end
