# frozen_string_literal: true

require "prism"

require_relative "./hash_to_string"

module RailInspector
  module Visitor
    class FrameworkDefault
      attr_reader :config_map

      def initialize
        @config_map = {}
      end

      def visit(node)
        target_version_case = node.breadth_first_search do |n|
          n in Prism::CaseNode[
            predicate: Prism::CallNode[receiver: Prism::LocalVariableReadNode[name: :target_version]]
          ]
        end

        target_version_case.conditions.each { |cond| visit_when(cond) }
      end

      private
        def visit_when(node)
          version = node.conditions[0].unescaped

          config_map[version] = VersionedConfig.new.tap { |v| v.visit(node.statements) }.configs
        end

        class VersionedConfig < Prism::Visitor
          attr_reader :configs

          def initialize
            @configs = {}
            @framework_stack = []
          end

          def visit_if_node(node)
            unless new_framework = respond_to_framework?(node.predicate)
              return visit_child_nodes(node)
            end

            if ENV["STRICT"] && current_framework
              raise "Potentially nested framework? Current: '#{current_framework}', found: '#{new_framework}'"
            end

            @framework_stack << new_framework
            visit_child_nodes(node)
            @framework_stack.pop
          end

          def visit_call_node(node)
            name = node.name.to_s

            unless name.end_with? "="
              return super
            end

            handle_assignment(node, name[...-1], node.arguments.arguments[0])
          end

          def visit_call_or_write_node(node)
            name = node.write_name.to_s

            unless name.end_with? "="
              return super
            end

            handle_assignment(node, node.read_name.to_s, node.value)
          end

          def handle_assignment(node, name, value)
            prefix = case node.receiver
            in Prism::ConstantReadNode[name: constant_name]
              constant_name
            in Prism::SelfNode
              "self"
            in Prism::CallNode[receiver: nil, name: framework]
              framework_string = framework.to_s

              unless current_framework == framework_string
                raise "expected: #{current_framework}, actual: #{framework_string}"
              end

              framework_string
            else
              node.receiver.location.slice
            end

            target = "#{prefix}.#{name}"

            string_value = case value
            in Prism::ConstantPathNode
              value.full_name
            in Prism::HashNode
              HashToString.new.tap { |v| v.visit(value) }.to_s
            in Prism::InterpolatedStringNode
              "\"#{value.parts.map(&:content).join("")}\""
            in Prism::FalseNode
              "false"
            in Prism::TrueNode
              "true"
            else
              value.location.slice
            end

            @configs[target] = string_value
          end

          private
            def current_framework
              @framework_stack.last
            end

            def respond_to_framework?(node)
              if node in Prism::CallNode[
                name: :respond_to?,
                arguments: Prism::ArgumentsNode[
                  arguments: [
                    Prism::SymbolNode[unescaped: new_framework]
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
