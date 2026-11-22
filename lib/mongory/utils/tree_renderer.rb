# frozen_string_literal: true

module Mongory
  module Utils
    # Renders structured explain_tree and trace_tree Hash structures to STDOUT.
    module TreeRenderer
      RESULT_LABELS = {
        pass: 'Matched',
        fail: 'Dismatch',
        skip: 'Skipped'
      }.freeze

      COLOR_RESULT_LABELS = {
        pass: "\e[30;42mMatched\e[0m",
        fail: "\e[30;41mDismatch\e[0m",
        skip: "\e[30;43mSkipped\e[0m"
      }.freeze

      module_function

      # Prints a structured explain_tree Hash to STDOUT.
      #
      # @param node [Hash] root explain_tree node
      # @param prefix [String] indentation prefix
      # @param is_last [Boolean] whether node is last sibling
      # @param is_root [Boolean] whether node is root
      # @return [void]
      def print_explain(node, prefix = '', is_last: true, is_root: true)
        return unless node

        connector = explain_connector(is_root: is_root, is_last: is_last)
        puts "#{prefix}#{connector}#{explain_title(node)}"

        children = node[:children] || []
        next_prefix = explain_next_prefix(prefix, is_root: is_root, is_last: is_last)
        last_index = children.length - 1
        children.each_with_index do |child, index|
          print_explain(child, next_prefix, is_last: index == last_index, is_root: false)
        end
        nil
      end

      def explain_connector(is_root:, is_last:)
        return '' if is_root

        is_last ? '└─ ' : '├─ '
      end

      def explain_next_prefix(prefix, is_root:, is_last:)
        return prefix if is_root

        "#{prefix}#{is_last ? '   ' : '│  '}"
      end

      # Prints a structured trace_tree Hash to STDOUT.
      #
      # @param node [Hash] root trace_tree node
      # @param level [Integer] indentation depth
      # @param colorful [Boolean] whether to colorize result labels
      # @return [void]
      def print_trace(node, level = 0, colorful: true)
        return unless node

        indent = '  ' * level
        puts "#{indent}#{trace_line(node, colorful: colorful)}"
        (node[:children] || []).each do |child|
          print_trace(child, level + 1, colorful: colorful)
        end
        nil
      end

      def explain_title(node)
        if node.key?(:field)
          "Field: #{node[:field].inspect}, to match: #{node[:condition].inspect}"
        else
          "#{node[:name]}: #{node[:condition].inspect}"
        end
      end

      def trace_line(node, colorful: true)
        result = node[:result]
        labels = colorful ? COLOR_RESULT_LABELS : RESULT_LABELS
        res_label = labels.fetch(result, result.to_s)
        parts = ["#{node[:name]}: #{res_label}"]
        parts << "field: #{node[:field].inspect}" if node.key?(:field)
        parts << "condition: #{node[:condition].inspect}"
        parts << "record: #{format_record(node)}" unless result == :skip
        parts.join(', ')
      end

      def format_record(node)
        return 'Nothing' unless node.key?(:record)

        node[:record].inspect
      end
    end
  end
end
