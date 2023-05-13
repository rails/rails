# frozen_string_literal: true

require "syntax_tree"

require_relative "./hash_to_string"
require_relative "./multiline_to_string"

module RailInspector
  module Visitor
    class FrameworkDefault
      TargetVersionCaseFinder =
        SyntaxTree::Search.new(
          ->(node) do
            node in SyntaxTree::Case[
              value: SyntaxTree::CallNode[
                receiver: SyntaxTree::VarRef[
                  value: SyntaxTree::Ident[value: "target_version"]
                ]
              ]
            ]
          end
        )

      attr_reader :config_map

      def initialize
        @config_map = {}
      end

      def visit(node)
        case_node, *others = TargetVersionCaseFinder.scan(node).to_a
        raise "#{others.length} other cases?" unless others.empty?

        visit_when(case_node.consequent)
      end

      private
        def visit_when(node)
          version = node.arguments.parts[0].parts[0].value

          config_map[version] = VersionedConfig.new.config_for(node.statements)

          visit_when(node.consequent) if node.consequent.is_a? SyntaxTree::When
        end

        class VersionedConfig < SyntaxTree::Visitor
          attr_reader :configs

          def initialize
            @configs = {}
            @framework_stack = []
          end

          def config_for(node)
            visit(node)
            @configs
          end

          visit_methods do
            def visit_if(node)
              unless new_framework = respond_to_framework?(node.predicate)
                return super
              end

              if ENV["STRICT"] && current_framework
                raise "Potentially nested framework? Current: '#{current_framework}', found: '#{new_framework}'"
              end

              @framework_stack << new_framework
              super
              @framework_stack.pop
            end

            def visit_assign(node)
              assert_framework(node)

              target = SyntaxTree::Formatter.format(nil, node.target)
              value =
                case node.value
                when SyntaxTree::HashLiteral
                  HashToString.new.tap { |v| v.visit(node.value) }.to_s
                when SyntaxTree::StringConcat
                  MultilineToString.new.tap { |v| v.visit(node.value) }.to_s
                else
                  SyntaxTree::Formatter.format(nil, node.value)
                end
              @configs[target] = value
            end
          end

          private
            def assert_framework(node)
              framework =
                case node.target.parent
                in { value: SyntaxTree::Const } |
                     { value: SyntaxTree::Kw[value: "self"] }
                  nil
                in receiver: { value: { value: framework } }
                  framework
                in value: { value: framework }
                  framework
                end

              return if current_framework == framework

              raise "Expected #{current_framework} to match #{framework}"
            end

            def current_framework
              @framework_stack.last
            end

            def respond_to_framework?(node)
              if node in SyntaxTree::CallNode[
                   message: SyntaxTree::Ident[value: "respond_to?"],
                   arguments: SyntaxTree::ArgParen[
                     arguments: SyntaxTree::Args[
                       parts: [
                         SyntaxTree::SymbolLiteral[
                           value: SyntaxTree::Ident[value: new_framework]
                         ]
                       ]
                     ]
                   ]
                 ]
                new_framework
              end
            end
        end
    end
  end
end
