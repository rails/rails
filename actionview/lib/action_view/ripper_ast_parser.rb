# frozen_string_literal: true

require "ripper"

module ActionView
  class RenderParser
    module RipperASTParser # :nodoc:
      class Node < ::Array # :nodoc:
        attr_reader :type

        def initialize(type, arr, opts = {})
          @type = type
          super(arr)
        end

        def children
          to_a
        end

        def inspect
          typeinfo = type && type != :list ? ":" + type.to_s + ", " : ""
          "s(" + typeinfo + map(&:inspect).join(", ") + ")"
        end

        def fcall?
          type == :command || type == :fcall
        end

        def fcall_named?(name)
          fcall? &&
            self[0].type == :@ident &&
            self[0][0] == name
        end

        def argument_nodes
          raise unless fcall?
          return [] if self[1].nil?
          if self[1].last == false || self[1].last.type == :vcall
            self[1][0...-1]
          else
            self[1][0..-1]
          end
        end

        def string?
          type == :string_literal
        end

        def variable_reference?
          type == :var_ref
        end

        def vcall?
          type == :vcall
        end

        def call?
          type == :call
        end

        def variable_name
          self[0][0]
        end

        def call_method_name
          self.last.first
        end

        def to_string
          raise unless string?
          self[0][0][0]
        end

        def hash?
          type == :bare_assoc_hash || type == :hash
        end

        def to_hash
          if type == :bare_assoc_hash
            hash_from_body(self[0])
          elsif type == :hash && self[0] == nil
            {}
          elsif type == :hash && self[0].type == :assoclist_from_args
            hash_from_body(self[0][0])
          end
        end

        def hash_from_body(body)
          body.to_h do |hash_node|
            return nil if hash_node.type != :assoc_new

            [hash_node[0], hash_node[1]]
          end
        end

        def symbol?
          type == :@label || type == :symbol_literal
        end

        def to_symbol
          if type == :@label && self[0] =~ /\A(.+):\z/
            $1.to_sym
          elsif type == :symbol_literal && self[0].type == :symbol && self[0][0].type == :@ident
            self[0][0][0].to_sym
          else
            raise "not a symbol?: #{self.inspect}"
          end
        end
      end

      class NodeParser < ::Ripper # :nodoc:
        PARSER_EVENTS.each do |event|
          arity = PARSER_EVENT_TABLE[event]
          if arity == 0 && event.to_s.end_with?("_new")
            module_eval(<<-eof, __FILE__, __LINE__ + 1)
            def on_#{event}(*args)
              Node.new(:list, args, lineno: lineno(), column: column())
            end
            eof
          elsif event.to_s.match?(/_add(_.+)?\z/)
            module_eval(<<-eof, __FILE__, __LINE__ + 1)
            begin; undef on_#{event}; rescue NameError; end
            def on_#{event}(list, item)
              list.push(item)
              list
            end
            eof
          else
            module_eval(<<-eof, __FILE__, __LINE__ + 1)
            begin; undef on_#{event}; rescue NameError; end
            def on_#{event}(*args)
              Node.new(:#{event}, args, lineno: lineno(), column: column())
            end
            eof
          end
        end

        SCANNER_EVENTS.each do |event|
          module_eval(<<-End, __FILE__, __LINE__ + 1)
          def on_#{event}(tok)
            Node.new(:@#{event}, [tok], lineno: lineno(), column: column())
          end
          End
        end
      end

      class RenderCallExtractor < NodeParser # :nodoc:
        attr_reader :render_calls

        METHODS_TO_PARSE = %w(render render_to_string)

        def initialize(*args)
          super

          @render_calls = []
        end

        private
          def on_fcall(name, *args)
            on_render_call(super)
          end

          def on_command(name, *args)
            on_render_call(super)
          end

          def on_render_call(node)
            METHODS_TO_PARSE.each do |method|
              if node.fcall_named?(method)
                @render_calls << [method, node]
                return node
              end
            end
            node
          end

          def on_arg_paren(content)
            content
          end

          def on_paren(content)
            content
          end
      end

      extend self

      def parse_render_nodes(code)
        parser = RenderCallExtractor.new(code)
        parser.parse

        parser.render_calls.group_by(&:first).to_h do |method, nodes|
          [ method.to_sym, nodes.collect { |v| v[1] } ]
        end
      end
    end
  end
end
