# frozen_string_literal: true

module Mongory
  module Utils
    # Debugger provides an internal tracing system for query matching.
    # It tracks matcher evaluation in a tree structure and provides tree-like format output.
    #
    # It captures each matcher evaluation with indentation and visualizes the hierarchy,
    # helping developers understand nested matcher flows (e.g. `$and`, `$or`, etc).
    #
    # Usage:
    #   Debugger.instance.with_indent { ... } # wraps around matcher logic
    #   Debugger.instance.display        # prints trace tree after execution
    #
    # Note:
    # The trace is recorded in post-order (leaf nodes enter first),
    # and `reorder_traces_for_display` is used to transform it into a
    # pre-order format suitable for display.
    #
    # This class is a singleton and should be accessed via `Debugger.instance`.
    #
    # @example Enable debugging
    #   Debugger.instance.enable
    #   Mongory::QueryBuilder.new(...).filter(...)
    #
    class Debugger < SingletonBuilder
      include Singleton

      def initialize
        super(self.class.name)
        @indent_level = -1
        @trace_entries = []
      end

      # Enables debug mode by aliasing `to_proc` to `debug_proc`.
      # @return [void]
      # @note Changes the behavior of to_proc to use debug_proc instead of cached_proc
      def enable
        Matchers::AbstractMatcher.alias_method :to_proc, :debug_proc
      end

      # Disables debug mode by restoring `to_proc` to `cached_proc`.
      # @return [void]
      # @note Restores the original behavior of to_proc
      def disable
        Matchers::AbstractMatcher.alias_method :to_proc, :cached_proc
      end

      # Wraps a matcher evaluation block with indentation control and records a structured trace entry.
      #
      # @param matcher [Matchers::AbstractMatcher] the matcher being evaluated
      # @param record [Object] the record value evaluated by this matcher
      # @yieldreturn [Boolean, Exception] the evaluation result
      # @return [Object] the result of the block
      def with_indent(matcher, record)
        @indent_level += 1
        result = yield
        @trace_entries << TraceEntry.new(matcher, record, result, @indent_level)
        result
      ensure
        @indent_level -= 1
      end

      # Builds structured trace tree Hashes from recorded trace entries and clears the buffer.
      #
      # Unexecuted child branches are recursively expanded from `explain_tree` with `result: :skip`.
      #
      # @return [Array<Hash>] structured trace tree root nodes
      def build_trace_trees
        trees = build_trace_nodes(@trace_entries, 0).first
        @trace_entries.clear
        trees
      end

      # Prints the visualized trace tree(s) to STDOUT.
      #
      # @return [void]
      def display
        build_trace_trees.each do |tree|
          TreeRenderer.print_trace(tree)
        end
        nil
      end

      def clear
        # Clears the internal trace buffer.
        # This is useful when re-running a query and avoiding stale trace output.
        # @return [void]
        @trace_entries.clear
      end

      private

      def build_trace_nodes(traces, level)
        nodes = []
        executed_matchers = []
        group = []

        traces.each do |entry|
          if entry.level == level
            executed_matchers << entry.matcher
            children, executed_children = build_trace_nodes(group, level + 1)
            append_skipped_children(entry.matcher, children, executed_children)
            nodes << build_trace_node(entry, children)
            group = []
          else
            group << entry
          end
        end

        [nodes, executed_matchers]
      end

      def append_skipped_children(matcher, children, executed_children)
        matcher.child_matchers.each do |child|
          next if executed_children.any? { |executed| executed.equal?(child) }

          children << TreeRenderer.mark_skipped(child.explain_tree)
        end
      end

      def build_trace_node(entry, children)
        matcher = entry.matcher
        matched = !entry.result.is_a?(Exception) && entry.result ? true : false
        node = {
          name: matcher.matcher_name,
          condition: matcher.condition,
          priority: matcher.priority,
          result: matched ? :pass : :fail,
          children: children
        }
        node[:field] = matcher.field if matcher.respond_to?(:field)
        node[:record] = entry.record unless entry.record.equal?(Matchers::AbstractMatcher::KEY_NOT_FOUND)
        node
      end

      # @private
      TraceEntry = Struct.new(:matcher, :record, :result, :level)
    end
  end
end
