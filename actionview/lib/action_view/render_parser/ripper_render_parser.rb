# frozen_string_literal: true

module ActionView
  module RenderParser
    class RipperRenderParser < Base # :nodoc:
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
          self[2].first
        end

        def to_string
          raise unless string?

          # s(:string_literal, s(:string_content, map))
          self[0].map do |node|
            case node.type
            when :@tstring_content
              node[0]
            when :string_embexpr
              "*"
            end
          end.join("")
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
            content.size == 1 ? content.first : content
          end
      end

      def render_calls
        parser = RenderCallExtractor.new(@code)
        parser.parse

        parser.render_calls.group_by(&:first).to_h do |method, nodes|
          [ method.to_sym, nodes.collect { |v| v[1] } ]
        end.map do |method, nodes|
          nodes.map { |n| parse_render(n) }
        end.flatten.compact
      end

      private
        def resolve_path_directory(path)
          if path.include?("/")
            path
          else
            "#{directory}/#{path}"
          end
        end

        # Convert
        #   render("foo", ...)
        # into either
        #   render(template: "foo", ...)
        # or
        #   render(partial: "foo", ...)
        def normalize_args(string, options_hash)
          if options_hash
            { partial: string, locals: options_hash }
          else
            { partial: string }
          end
        end

        def parse_render(node)
          node = node.argument_nodes

          if (node.length == 1 || node.length == 2) && !node[0].hash?
            if node.length == 1
              options = normalize_args(node[0], nil)
            elsif node.length == 2
              options = normalize_args(node[0], node[1])
            end

            return nil unless options

            parse_render_from_options(options)
          elsif node.length == 1 && node[0].hash?
            options = parse_hash_to_symbols(node[0])

            return nil unless options

            parse_render_from_options(options)
          else
            nil
          end
        end

        def parse_hash(node)
          node.hash? && node.to_hash
        end

        def parse_hash_to_symbols(node)
          hash = parse_hash(node)

          return unless hash

          hash.transform_keys do |key_node|
            key = parse_sym(key_node)

            return unless key

            key
          end
        end

        def parse_render_from_options(options_hash)
          renders = []
          keys = options_hash.keys

          if (keys & RENDER_TYPE_KEYS).size < 1
            # Must have at least one of render keys
            return nil
          end

          if (keys - ALL_KNOWN_KEYS).any?
            # de-opt in case of unknown option
            return nil
          end

          render_type = (keys & RENDER_TYPE_KEYS)[0]

          node = options_hash[render_type]

          if node.string?
            template = resolve_path_directory(node.to_string)
          else
            if node.variable_reference?
              dependency = node.variable_name.sub(/\A(?:\$|@{1,2})/, "")
            elsif node.vcall?
              dependency = node.variable_name
            elsif node.call?
              dependency = node.call_method_name
            else
              return
            end

            object_template = true
            template = "#{dependency.pluralize}/#{dependency.singularize}"
          end

          return unless template

          if spacer_template = render_template_with_spacer?(options_hash)
            virtual_path = partial_to_virtual_path(:partial, spacer_template)
            renders << virtual_path
          end

          if options_hash.key?(:object) || options_hash.key?(:collection) || object_template
            return nil if options_hash.key?(:object) && options_hash.key?(:collection)
            return nil unless options_hash.key?(:partial)
          end

          virtual_path = partial_to_virtual_path(render_type, template)
          renders << virtual_path

          # Support for rendering multiple templates (i.e. a partial with a layout)
          if layout_template = render_template_with_layout?(render_type, options_hash)
            virtual_path = partial_to_virtual_path(:layout, layout_template)

            renders << virtual_path
          end

          renders
        end

        def parse_str(node)
          node.string? && node.to_string
        end

        def parse_sym(node)
          node.symbol? && node.to_symbol
        end

        def render_template_with_layout?(render_type, options_hash)
          if render_type != :layout && options_hash.key?(:layout)
            parse_str(options_hash[:layout])
          end
        end

        def render_template_with_spacer?(options_hash)
          if options_hash.key?(:spacer_template)
            parse_str(options_hash[:spacer_template])
          end
        end
    end
  end
end
