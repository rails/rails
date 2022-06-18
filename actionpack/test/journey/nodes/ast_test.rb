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

        def test_sets_memo_for_terminal_nodes
          route = Object.new
          tree = Journey::Parser.new.parse("/path")

          ast = Ast.new(tree, true)
          ast.route = route

          nodes = ast.root.grep(Nodes::Terminal)
          nodes.each do |node|
            assert_equal route, node.memo
          end
        end

        def test_contains_glob
          tree = Journey::Parser.new.parse("/*glob")
          ast = Ast.new(tree, true)

          assert_predicate ast, :glob?
        end

        def test_does_not_contain_glob
          tree = Journey::Parser.new.parse("/")
          ast = Ast.new(tree, true)

          assert_not_predicate ast, :glob?
        end

        def test_names
          tree = Journey::Parser.new.parse("/:path/:symbol")
          ast = Ast.new(tree, true)

          assert_equal ["path", "symbol"], ast.names
        end

        def test_path_params
          tree = Journey::Parser.new.parse("/:path/:symbol")
          ast = Ast.new(tree, true)

          assert_equal [:path, :symbol], ast.path_params
        end

        def test_wildcard_options_when_formatted
          tree = Journey::Parser.new.parse("/*glob")
          ast = Ast.new(tree, true)

          wildcard_options = ast.wildcard_options
          assert_equal %r{.+?}m, wildcard_options[:glob]
        end

        def test_wildcard_options_when_false
          tree = Journey::Parser.new.parse("/*glob")
          ast = Ast.new(tree, false)

          wildcard_options = ast.wildcard_options
          assert_nil wildcard_options[:glob]
        end

        def test_wildcard_options_when_nil
          tree = Journey::Parser.new.parse("/*glob")
          ast = Ast.new(tree, nil)

          wildcard_options = ast.wildcard_options
          assert_equal %r{.+?}m, wildcard_options[:glob]
        end
      end
    end
  end
end
