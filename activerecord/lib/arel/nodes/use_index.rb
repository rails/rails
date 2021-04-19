# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class UseIndex < Unary
      def indexes
        expr[0]
      end

      FOR_OPTIONS = { join: "JOIN", order: "ORDER BY", group: "GROUP BY" }.freeze
      private_constant :FOR_OPTIONS
      def for
        FOR_OPTIONS[expr[1].to_sym] if expr[1].respond_to?(:to_sym)
      end
    end
  end
end
