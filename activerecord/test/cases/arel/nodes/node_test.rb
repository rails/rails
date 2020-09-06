# frozen_string_literal: true

require_relative '../helper'

module Arel
  class TestNode < Arel::Test
    def test_includes_factory_methods
      assert Arel::Nodes::Node.new.respond_to?(:create_join)
    end

    def test_all_nodes_are_nodes
      Nodes.constants.map { |k|
        Nodes.const_get(k)
      }.grep(Class).each do |klass|
        next if Nodes::SqlLiteral == klass
        next if Nodes::BindParam == klass
        next if /^Arel::Nodes::(?:Test|.*Test$)/.match?(klass.name)
        assert klass.ancestors.include?(Nodes::Node), klass.name
      end
    end
  end
end
