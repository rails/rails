# frozen_string_literal: true

require_relative "../helper"

module Arel
  class TestNode < Arel::Test
    def test_includes_factory_methods
      assert Node.new.respond_to?(:create_join)
    end

    def test_all_nodes_are_nodes
      Nodes.constants.map { |k|
        Nodes.const_get(k)
      }.grep(Class).each do |klass|
        next if Nodes::SqlLiteral == klass
        next if Nodes::BindParam == klass
        next if klass.name =~ /^Arel::Nodes::(?:Test|.*Test$)/
        assert klass.ancestors.include?(Nodes::Node), klass.name
      end
    end

    def test_each
      list = []
      node = Nodes::Node.new
      node.each { |n| list << n }
      assert_equal [node], list
    end

    def test_generator
      list = []
      node = Nodes::Node.new
      node.each.each { |n| list << n }
      assert_equal [node], list
    end

    def test_enumerable
      node = Nodes::Node.new
      assert_kind_of Enumerable, node
    end
  end
end
