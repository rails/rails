# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  module Journey
    module Nodes
      class TestAst < ActiveSupport::TestCase
        def test_ast_sets_regular_expressions
          requirements = { name: /(tender|love)/, value: /./ }
          path = "/page/:name/:value"
          tree = Journey::Parser.new.parse(path)

          ast = Ast.new(tree, true)
          ast.requirements = requirements

          nodes = ast.root.grep(Nodes::Symbol)
          assert_equal 2, nodes.length
          nodes.each do |node|
            assert_equal requirements[node.to_sym], node.regexp
          end
        end
      end
    end
  end
end
